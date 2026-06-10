"""
状态管理器 — 运行时状态域。

包含:
  SlidingBlacklist    维度级滑动黑名单（三阶段钩子）
  SandboxManager      沙盒缓存（预生成创作关键词）
"""

import json
import os
import random
import re
import time
from typing import TYPE_CHECKING, Optional

from tools.config import (
    BlacklistDimensionConfig,
    DimensionCombo,
    EventPipelineConfig,
    PipelineDimension,
    PipelineDimensionValue,
)

if TYPE_CHECKING:
    from tools.event_generator.llm_client import LLMClient


# ════════════════════════════════════════════════════════════════
# SlidingBlacklist — 维度级滑动黑名单运行时状态
# ════════════════════════════════════════════════════════════════

class SlidingBlacklist:
    """维度级滑动黑名单运行时状态。

    生命周期（三阶段钩子）:
      1. init_from_config(cfg) — 扫描配置，如果恰好一个维度配置了黑名单则初始化
      2. get_prompt_block(combos) — 根据当前维度值生成黑名单 prompt 片段
      3. extract_and_update(parsed, combos) — 从 AI 响应提取 summary 并更新黑名单
    """

    def __init__(self, dimension: PipelineDimension, cfg: BlacklistDimensionConfig):
        self.dimension = dimension
        self.tracked_field = cfg.tracked_field
        self.tracked_field_description = cfg.tracked_field_description or cfg.tracked_field
        self.max_items = cfg.max_items
        # val_id -> list[tracked_field_value]
        self._history: dict[str, list[str]] = {}

    @classmethod
    def init_from_config(cls, cfg: EventPipelineConfig) -> Optional["SlidingBlacklist"]:
        """扫描所有维度，找到挂载了 blacklist_config 的维度。

        Returns:
            SlidingBlacklist 实例，如果没有任何维度配置黑名单则返回 None。

        Raises:
            ValueError: 如果有超过一个维度配置了黑名单。
        """
        blacklisted = [d for d in cfg.dimensions if d.blacklist_config is not None]
        if not blacklisted:
            return None
        if len(blacklisted) > 1:
            dim_names = [d.name or d.id for d in blacklisted]
            raise ValueError(
                f"最多只能有一个维度配置黑名单，发现 {len(blacklisted)} 个: {dim_names}"
            )
        dim = blacklisted[0]
        return cls(dim, dim.blacklist_config)  # type: ignore[arg-type]

    def _get_val_id(self, combos: list[DimensionCombo]) -> str:
        """从 combos 中找到本维度对应的值 ID。"""
        for combo in combos:
            if combo.dimension.id == self.dimension.id:
                return combo.value.id
        raise ValueError(f"组合中未找到维度 '{self.dimension.id}' 对应的值")

    def get_prompt_block(self, combos: list[DimensionCombo]) -> str:
        """根据当前维度组合，生成黑名单 prompt 片段（Phase 1 消费）。

        如果该维度值尚无黑名单历史，返回空字符串。
        """
        val_id = self._get_val_id(combos)
        items = self._history.get(val_id, [])
        if not items:
            return ""
        lines = ["\n## ⛔ 黑名单（已为此维度值生成的内容，严禁重复）"]
        lines.append(
            f"以下是为当前维度值已生成的 summary.{self.tracked_field_description} "
            "列表，请确保新生成的内容与已有内容在情节上有明显区分：\n"
        )
        for i, item in enumerate(items, 1):
            text = item[:120] + "..." if len(item) > 120 else item
            lines.append(f"{i}. {text}")
        return "\n".join(lines)

    def extract_and_update(self, parsed: dict, combos: list[DimensionCombo]) -> None:
        """从解析后的 LLM 响应中提取 summary.{tracked_field} 并更新黑名单（Phase 2 消费）。

        符合 Coder 模式的穷举日志要求：每个分支都有 logging。
        """
        val_id = self._get_val_id(combos)
        summary = parsed.get("summary")
        if not isinstance(summary, dict):
            print("  ⚠️ 黑名单: parsed 中缺少 summary 块，跳过更新")
            return
        value = summary.get(self.tracked_field, "")
        if not value or not value.strip():
            print(f"  ⚠️ 黑名单: summary 中缺少 '{self.tracked_field}' 字段，跳过更新")
            return
        if val_id not in self._history:
            self._history[val_id] = []
        self._history[val_id].append(value.strip())
        print(f"  📋 黑名单已更新 [{self.dimension.name} / {val_id}]: "
              f"共 {len(self._history[val_id])} 条")
        # 滑动窗口：超出 max_items 时丢弃最老的
        if len(self._history[val_id]) > self.max_items:
            self._history[val_id] = self._history[val_id][-self.max_items:]
            print(f"  📋 黑名单滑动窗口已裁剪: 保留最近 {self.max_items} 条")


# ════════════════════════════════════════════════════════════════
# SandboxManager — 沙盒缓存运行时状态
# ════════════════════════════════════════════════════════════════

class SandboxManager:
    """沙盒缓存：为每对 dimension-value 预生成 2-3 个创作关键词。

    设计原则（源自架构师奥卡姆剃刀 🪒）:
      - 关键词粒度是 dimension-value 对，不是组合（组合太多，缓存会爆炸 💀）
      - 生成阶段随机从每个维度值的词池中 pick 一个，注入 prompt
      - 自动检测：运行时检查 ``<config_path>.sandbox`` 是否存在，
        不存在则自动调用 API 生成

    Sandbox 文件格式（JSON）:
    .. code-block:: json

        {
          "dim_id": {
            "val_id": ["keyword1", "keyword2", "keyword3"],
            ...
          },
          ...
        }
    """

    KEYWORD_COUNT = 3  # 每个 dimension-value 生成的关键词数

    def __init__(
        self,
        config_path: str | None,
        llm: "LLMClient",
        cfg: EventPipelineConfig,
    ):
        self.cfg = cfg
        self.llm = llm
        # sandbox 文件路径 = 配置文件路径 + ".sandbox"
        # 如果无配置文件（内置配置），则回退到 <cfg.id>.sandbox
        if config_path:
            self.sandbox_path = config_path + ".sandbox"
        else:
            self.sandbox_path = f"{cfg.id}.sandbox"
        # _data[dim_id][val_id] = [keyword, ...]
        self._data: dict[str, dict[str, list[str]]] = {}

    # ── 公开接口 ──────────────────────────────────────────────

    def load(self) -> bool:
        """从磁盘加载沙盒缓存。

        Returns:
            True 如果文件存在且加载成功，否则 False。
        """
        if not os.path.exists(self.sandbox_path):
            return False
        try:
            with open(self.sandbox_path, "r", encoding="utf-8") as f:
                self._data = json.load(f)
            # 简单完整性检查：至少有一个维度有数据
            if not self._data:
                print(f"  ⚠️ 沙盒文件 '{self.sandbox_path}' 为空，将重新生成")
                return False
            total_kws = sum(
                len(kws) for val_map in self._data.values() for kws in val_map.values()
            )
            print(f"  📦 沙盒已加载: {self.sandbox_path} "
                  f"({len(self._data)} 个维度, {total_kws} 个关键词)")
            return True
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ⚠️ 沙盒文件 '{self.sandbox_path}' 读取失败: {e}，将重新生成")
            return False

    def save(self) -> None:
        """将沙盒缓存写入磁盘。"""
        with open(self.sandbox_path, "w", encoding="utf-8") as f:
            json.dump(self._data, f, ensure_ascii=False, indent=2)
        total_kws = sum(
            len(kws) for val_map in self._data.values() for kws in val_map.values()
        )
        print(f"  💾 沙盒已保存: {self.sandbox_path} "
              f"({len(self._data)} 个维度, {total_kws} 个关键词)")

    def generate(self) -> None:
        """遍历所有维度值，调用 API 为每个 dimension-value 生成 2-3 个关键词。

        符合 Coder 模式的穷举日志要求：每个生成步骤都有输出。
        """
        print(f"\n🏗️  沙盒自动生成: 为 {len(self.cfg.dimensions)} 个维度的每个值生成关键词...")

        for dim in self.cfg.dimensions:
            dim_id = dim.id
            if dim_id not in self._data:
                self._data[dim_id] = {}

            for val in dim.values:
                val_id = val.id
                # 跳过已缓存的
                if val_id in self._data[dim_id] and self._data[dim_id][val_id]:
                    continue

                print(f"    🔑 [{dim.name} / {val.name}] 生成关键词...", end=" ")
                try:
                    keywords = self._generate_keywords_for(dim, val)
                    self._data[dim_id][val_id] = keywords
                    print(f"{', '.join(keywords)}")
                except Exception as e:
                    print(f"❌ 失败: {e}")
                    # 失败时用 fallback 关键词
                    fallback = [f"{val.name}相关情节"]
                    self._data[dim_id][val_id] = fallback
                    print(f"    ⚠️  使用 fallback: {fallback}")

                # API 调用间隔，避免限流
                time.sleep(0.5)

        self.save()

    def get_keywords(self, dim_id: str, val_id: str) -> list[str]:
        """获取指定 dimension-value 的关键词列表。"""
        return self._data.get(dim_id, {}).get(val_id, [])

    def get_prompt_block(self, combos: list[DimensionCombo]) -> str:
        """为当前组合随机 pick 每个维度值的 1 个关键词，组装成 prompt 块。

        每次调用都重新随机选择，确保同一组合多次重试时获得不同的种子。
        """
        picked: list[str] = []
        for combo in combos:
            kw_pool = self.get_keywords(combo.dimension.id, combo.value.id)
            if not kw_pool:
                continue
            chosen = random.choice(kw_pool)
            picked.append(f"  - {combo.dimension.name}「{combo.value.name}」→ {chosen}")

        if not picked:
            return ""

        lines = ["\n## 🎲 创作种子（沙盒关键词）",
                 "在创作时请围绕以下关键词展开情节：\n"]
        lines.extend(picked)
        return "\n".join(lines)

    # ── 内部方法 ──────────────────────────────────────────────

    def _generate_keywords_for(
        self,
        dim: PipelineDimension,
        val: PipelineDimensionValue,
    ) -> list[str]:
        """为单个 dimension-value 调用 API 生成关键词。

        使用轻量级 prompt，不包含完整事件生成的上下文。
        """
        system_prompt = (
            "你是一位精通中国古典文学和古代官场文化的叙事设计师。"
            "你的任务是针对给定的叙事维度及具体取值，"
            "生成3个创作关键词，每个关键词10字以内。"
            "关键词聚焦于该维度取值本身的典型情节场景，"
            "不要包含角色名或特定事件标题。"
        )
        user_prompt = (
            f"维度名称：{dim.name}\n"
            f"维度描述：{dim.description}\n"
            f"取值名称：{val.name}\n"
            f"取值描述：{val.description}\n\n"
            f"请为上述维度取值生成 {self.KEYWORD_COUNT} 个创作关键词，"
            f"每行一个，不要编号，不要多余内容："
        )

        response = self.llm.generate_event_text(system_prompt, user_prompt)

        # 解析响应：按行切割，去掉空行和标点符号
        raw_lines = response.strip().split("\n")
        keywords: list[str] = []
        for line in raw_lines:
            # 去除常见的列表标记（-、*、数字、引号）
            cleaned = line.strip().strip("-*·\"'“”‘’").strip()
            # 去除前置序号如 1. 1、 等
            cleaned = re.sub(r"^\d+[\.、\s)]*\s*", "", cleaned).strip()
            if cleaned and len(cleaned) <= 30:
                keywords.append(cleaned)

        # 确保不超过 KEYWORD_COUNT
        return keywords[: self.KEYWORD_COUNT]
