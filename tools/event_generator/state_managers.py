"""
状态管理器 — 运行时状态域。

包含:
  SandboxManager      沙盒缓存（预生成创作关键词）
"""

import json
import os
import random
import re
import time
from typing import TYPE_CHECKING

from tools.config import (
    DimensionCombo,
    EventPipelineConfig,
)

if TYPE_CHECKING:
    from tools.event_generator.llm_client import LLMClient


# ════════════════════════════════════════════════════════════════
# SandboxManager — 沙盒缓存运行时状态
# ════════════════════════════════════════════════════════════════

class SandboxManager:
    """沙盒缓存：为每个维度组合预生成创作关键词。

    设计原则（源自架构师奥卡姆剃刀 🪒）:
      - 关键词粒度是维度组合（如 L0×TypeA），不是单个维度值
      - 每个组合的关键词是整体性的，描述完整情节场景
      - 生成阶段从组合词池中随机 pick 1 个关键词，注入 prompt
      - 自动检测：运行时检查 ``<config_path>_sandbox.json`` 是否存在，
        不存在则自动调用 API 生成

    Sandbox 文件格式（JSON）:
    .. code-block:: json

        {
          "L0": {
            "TypeA": ["门子横棍拦路时锦盒暗递", ...],
            "TypeB": [...]
          },
          "L1": {
            "TypeA": [...],
            ...
          }
        }

    第一层 key = 第一个维度值 ID, 第二层 key = 第二个维度值 ID。
    """

    KEYWORD_COUNT = 3  # 每个组合生成的关键词数

    def __init__(
        self,
        config_path: str | None,
        llm: "LLMClient",
        cfg: EventPipelineConfig,
    ):
        self.cfg = cfg
        self.llm = llm
        # sandbox 文件路径 = 配置文件去掉 .json 后缀 + "_sandbox.json"
        # 如 event_base_config_bai_ye_real_appearance_sandbox.json
        if config_path:
            base = config_path.rsplit(".json", 1)[0] if config_path.endswith(".json") else config_path
            self.sandbox_path = base + "_sandbox.json"
        else:
            self.sandbox_path = f"{cfg.id}_sandbox.json"
        # _data[val1_id][val2_id] = [keyword, ...]  (嵌套 dict)
        self._data: dict[str, dict[str, list[str]]] = {}

    # ── 公开接口 ──────────────────────────────────────────────

    def load(self) -> bool:
        """从磁盘加载沙盒缓存。

        支持两种格式：
          - 嵌套（多维度）: {"dim1_id": {"val1_id": ["seed1", ...], ...}, ...}
          - 扁平（单维度）: {"val1_id": ["seed1", ...], "val2_id": [...]}
          扁平格式在加载时自动转换为嵌套。

        Returns:
            True 如果文件存在且加载成功，否则 False。
        """
        if not os.path.exists(self.sandbox_path):
            return False
        try:
            with open(self.sandbox_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if not raw:
                print(f"  ⚠️ 沙盒文件 '{self.sandbox_path}' 为空，将重新生成")
                return False

            # ── 检测扁平格式（单维度）并自动封装 ──
            first_val = next(iter(raw.values()))
            if isinstance(first_val, list):
                dim_id = self.cfg.dimensions[0].id
                print(f"  🔄 检测到单维度沙盒格式，自动封装 dim={dim_id}")
                self._data = {dim_id: raw}
            else:
                self._data = raw

            total_kws = self._count_keywords()
            print(f"  📦 沙盒已加载: {self.sandbox_path} "
                  f"({len(self._data)} 个一级维度, {total_kws} 个关键词)")
            return True
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ⚠️ 沙盒文件 '{self.sandbox_path}' 读取失败: {e}，将重新生成")
            return False

    # ── 内部工具 ────────────────────────────────────────────

    def _count_keywords(self) -> int:
        """统计所有维度组合的关键词总数（兼容嵌套/扁平结构）。"""
        return sum(
            len(kws)
            for inner in self._data.values()
            for kws in inner.values()
        )

    def save(self) -> None:
        """将沙盒缓存写入磁盘。"""
        with open(self.sandbox_path, "w", encoding="utf-8") as f:
            json.dump(self._data, f, ensure_ascii=False, indent=2)
        total_kws = self._count_keywords()
        print(f"  💾 沙盒已保存: {self.sandbox_path} "
              f"({len(self._data)} 个一级维度, {total_kws} 个关键词)")

    def generate(self) -> None:
        """遍历所有维度组合，调用 API 为每个组合生成关键词。

        每个组合的关键词是整体性的，描述该组合下的完整情节场景。
        支持单维度和多维度配置。
        """
        from tools.event_generator.dimensions import expand_combinations, _make_combos

        print(f"\n🏗️  沙盒自动生成: 展开 {len(self.cfg.dimensions)} 个维度的组合并生成关键词...")

        # ── 单维度：扁平存储 _data[dim_id][val_id] ──
        is_single_dim = len(self.cfg.dimensions) == 1
        if is_single_dim:
            dim_id = self.cfg.dimensions[0].id
            if dim_id not in self._data:
                self._data[dim_id] = {}

        for dim_values in expand_combinations(self.cfg.dimensions):
            combos = _make_combos(self.cfg.dimensions, dim_values)

            if is_single_dim:
                # 单维度：_data[dim_id][val_id]
                val_id = combos[0].value.id
                if val_id in self._data[dim_id] and self._data[dim_id][val_id]:
                    continue
                label = combos[0].value.name
                print(f"    🔑 [{label}] 生成关键词...", end=" ")
                try:
                    keywords = self._generate_keywords_for(combos)
                    self._data[dim_id][val_id] = keywords
                    print(f"{', '.join(keywords)}")
                except Exception as e:
                    print(f"❌ 失败: {e}")
                    self._data[dim_id][val_id] = [f"{label}相关情节"]
                    print(f"    ⚠️  使用 fallback")
            else:
                # 多维度：_data[val1_id][val2_id]
                key1 = combos[0].value.id
                key2 = combos[1].value.id

                if key1 not in self._data:
                    self._data[key1] = {}

                if key2 in self._data[key1] and self._data[key1][key2]:
                    continue

                label = f"{combos[0].value.name} × {combos[1].value.name}"
                print(f"    🔑 [{label}] 生成关键词...", end=" ")
                try:
                    keywords = self._generate_keywords_for(combos)
                    self._data[key1][key2] = keywords
                    print(f"{', '.join(keywords)}")
                except Exception as e:
                    print(f"❌ 失败: {e}")
                    self._data[key1][key2] = [f"{label}相关情节"]
                    print(f"    ⚠️  使用 fallback")

            # API 调用间隔，避免限流
            time.sleep(0.5)

        self.save()

    def get_keywords(self, combos: list[DimensionCombo]) -> list[str]:
        """获取指定组合的关键词列表。

        支持单维度（扁平）和多维度（嵌套）两种沙盒结构。

        Args:
            combos: 当前维度组合的 DimensionCombo 列表

        Returns:
            list[str]: 该组合对应的关键词列表，如果不存在则返回空列表
        """
        if not combos:
            return []
        if len(combos) == 1:
            # 单维度：_data[dim_id][val_id]
            dim_id = combos[0].dimension.id
            val_id = combos[0].value.id
            return self._data.get(dim_id, {}).get(val_id, [])
        # 多维度：_data[val1_id][val2_id]
        key1 = combos[0].value.id
        key2 = combos[1].value.id
        return self._data.get(key1, {}).get(key2, [])

    def get_prompt_block(self, combos: list[DimensionCombo]) -> str:
        """为当前组合从词池中随机 pick 1 个关键词，组装成 prompt 块。

        每次调用都重新随机选择，确保同一组合多次重试时获得不同的创作种子。
        """
        kw_pool = self.get_keywords(combos)
        if not kw_pool:
            return ""

        chosen = random.choice(kw_pool)

        lines = [
            "\n## 🎲 创作种子（沙盒关键词）",
            "在创作时请围绕以下关键词展开情节：\n",
            f"  - {chosen}",
        ]
        return "\n".join(lines)

    # ── 内部方法 ──────────────────────────────────────────────

    def _generate_keywords_for(
        self,
        combos: list[DimensionCombo],
    ) -> list[str]:
        """为完整的维度组合调用 API 生成整体性关键词。

        每个关键词描述该组合下可能发生的具体情节片段，包含所有维度的交互。
        """
        dim_parts: list[str] = []
        for combo in combos:
            dim_parts.append(f"  维度：{combo.dimension.name}（{combo.dimension.description}）")
            dim_parts.append(f"  取值：{combo.value.name} — {combo.value.description}\n")

        dim_context = "\n".join(dim_parts)

        system_prompt = (
            "你是一位精通中国古典文学和古代官场文化的叙事设计师。"
            "你的任务是针对给定的维度组合，"
            f"生成{self.KEYWORD_COUNT}个创作关键词，每个关键词15字以内。"
            "关键词应描述该组合下可能发生的具体情节、动作或意象，"
            "要兼顾组合中所有维度的特征，形成有画面感的叙事种子。"
            "不要包含角色名或特定事件标题。"
        )
        user_prompt = (
            f"维度组合：\n"
            f"{dim_context}"
            f"背景上下文：{self.cfg.background_context}\n\n"
            f"请为上述维度组合生成 {self.KEYWORD_COUNT} 个创作关键词，"
            f"每行一个，不要编号，不要多余内容："
        )

        # 🆕 沙盒特征指令（如果有配置）
        sandbox_feature = self.cfg.sandbox_feature
        if sandbox_feature and sandbox_feature.text.strip():
            user_prompt += f"\n\n附加创作指引：{sandbox_feature.text.strip()}"

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
