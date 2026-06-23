#!/usr/bin/env python3
"""
正交事件生成管线 — 融合入口点 (main)

这是重构后的融合入口。用法与原有 generate_orthogonal_events.py 完全一致：

  export DEEPSEEK_API_KEY="sk-xxx"
  python3 -m tools.event_generator.main --config <json_or_py>
  python3 -m tools.event_generator.main --dry-run
  python3 -m tools.event_generator.main --trial

为保持向后兼容，也可通过 tools/generate_orthogonal_events.py 调用（指向此 main）。
"""

import argparse
import csv
import os
import random
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ── 自动将项目根目录加入 sys.path，消除 PYTHONPATH=. 的依赖 ──
_project_root = Path(__file__).resolve().parent.parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

# 🤓☝️ 契约即自由：通过严格的 imports，你能一眼看出 main 函数到底依赖了哪些领域
from tools.config import (
    default_config,
    load_config_from_json,
    EventPipelineConfig,
    DimensionCombo,
    ImageryItem,
    OptionFeature,
)
from tools.plugin_base import (
    PLUGIN_REGISTRY,
    EventPromptPlugin,
    PluginContext,
    resolve_plugins,
)

# 确保插件在 main 启动前注册
import tools.plugins  # noqa: F401

from tools.event_generator.llm_client import LLMClient, parse_llm_response, validate_response
from tools.event_generator.prompts import build_system_prompt, build_user_prompt
from tools.event_generator.io_csv import write_csv_header, write_event_row, write_option_row, _build_option_dsl, _build_option_requirement
from tools.event_generator.state_managers import SandboxManager
from tools.plugin_base import PLUGIN_REGISTRY
from tools.event_generator.dimensions import expand_combinations, _make_combos
from tools.event_generator.dsl_parser import scale_all_operators
from tools.event_generator.scorer import extract_image_pool, is_valid_combination, pick_best_image

import json

# ════════════════════════════════════════════════════════════════
# 数据类 — Pipeline 输出契约
# ════════════════════════════════════════════════════════════════

@dataclass
class OptionRow:
    """单个选项行的全部产物。"""
    choice_id: str
    text: str
    dsl: str
    requirement: str


@dataclass
class GenerationResult:
    """生成一个事件的完整结果。统一 trial 和 production 两条管线的输出契约。"""
    # ── 状态 ──
    status: str       # "success" | "skip" | "fail"
    error: str | None = None

    # ── 组合标识 ──
    uuid: str = ""
    combined_scale: float = 1.0
    scale_parts: list[str] = field(default_factory=list)
    combos: list[DimensionCombo] = field(default_factory=list)
    values_tuple: tuple = ()

    # ── LLM 响应 ──
    parsed: dict = field(default_factory=dict)
    raw_response: str = ""

    # ── 管线产物 ──
    scaled_dsl: str = ""
    context_extras: dict[str, str] | None = None
    tags_to_use: list[str] = field(default_factory=list)
    stored_to: str = ""
    selected_image_item: ImageryItem | None = None

    # ── 选项 ──
    option_rows: list[OptionRow] = field(default_factory=list)


@dataclass
class EventSnapshot:
    """从旧 CSV 解析出的可复用 AI 生成内容 — Reassembly 模式专属。

    仅存储 AI 生成的文本字段，不包含 DSL/context/requirements（它们会被重新计算覆盖）。
    """
    uuid: str
    title: str
    description: str
    option_texts: list[str]  # 按 cfg.option_features 顺序


# ════════════════════════════════════════════════════════════════
# Plugin Hook 辅助函数
# ════════════════════════════════════════════════════════════════

def _build_plugin_context_extras(
    plugins: list[EventPromptPlugin],
    combos: list[DimensionCombo],
    cfg: EventPipelineConfig,
    parsed: dict,
    raw_response: str,
    combined_scale: float,
    uuid: str,
) -> dict[str, str]:
    """调用所有插件的 enrich_context() 并合并 context_extras。

    这是 Hook 3 的调度入口。每个插件的 enrich_context() 接收 PluginContext
    （全量管线状态），返回 key=value 对，最终合并为一个 dict 传给 write_event_row。
    """
    extras: dict[str, str] = {}
    ctx = PluginContext(
        combos=combos,
        cfg=cfg,
        raw_response=raw_response,
        parsed=parsed,
        combined_scale=combined_scale,
        uuid=uuid,
    )
    for plugin in plugins:
        try:
            result = plugin.enrich_context(ctx)
            if result:
                extras.update(result)
        except Exception as e:
            print(f"  ⚠️ 插件 '{plugin.plugin_id}'.enrich_context() 异常: {e}")
    return extras


# ════════════════════════════════════════════════════════════════
# 意象正交剪枝/打分辅助函数
# ════════════════════════════════════════════════════════════════

def _select_imagery_for_combo(
    current_combos: list[DimensionCombo],
    cfg: EventPipelineConfig,
    image_dict: dict[str, ImageryItem],
    scene_dim_id: str | None,
    emotion_dim_id: str | None,
) -> ImageryItem | None:
    """
    意象正交剪枝/打分：extract → validate → pick → return ImageryItem or None。

    如果 apply_dimension_imagery 为 False，或任一步骤失败，返回 None。
    """
    if not cfg.apply_dimension_imagery:
        return None
    if scene_dim_id is None or emotion_dim_id is None:
        return None

    # Step 1: 提取意象池
    image_pool = extract_image_pool(current_combos, scene_dim_id)
    if not image_pool:
        return None

    # Step 2: 场景×情绪剪枝
    if not is_valid_combination(current_combos, scene_dim_id, emotion_dim_id):
        return None

    # Step 3: 从 combos 中提取目标情绪 ID
    target_emotion: str | None = None
    for combo in current_combos:
        if combo.dimension.id == emotion_dim_id:
            target_emotion = combo.value.id
            break
    if target_emotion is None:
        return None

    # Step 4: 按情绪亲缘度打分选择最佳意象
    image_id = pick_best_image(image_pool, target_emotion, image_dict)
    if image_id is None:
        return None

    return image_dict[image_id]


# ════════════════════════════════════════════════════════════════
# 核心管线 — 生成一个事件
# ════════════════════════════════════════════════════════════════

SHRINK_STEP = 20
MIN_GAP = 10
OPTION_SHRINK_STEP = 5


def generate_one_event(
    values_tuple: tuple,
    cfg: EventPipelineConfig,
    system_prompt: str,
    llm: LLMClient,
    sandbox: SandboxManager | None,
    plugins: list[EventPromptPlugin],
    image_dict: dict[str, ImageryItem],
    scene_dim_id: str | None,
    emotion_dim_id: str | None,
    is_trial: bool = False,
) -> GenerationResult:
    """为一个维度组合生成一个完整事件。

    这是 trial 和 production 两条管线的共同核心。调用方负责输出：
      - trial: _print_generation_result() — 动态打印所有字段
      - production: _write_result_to_csv() — 写入 CSV
    """
    # ── 计算标识符 ──
    combined_scale = 1.0
    scale_parts: list[str] = []
    uuid_parts: list[str] = [cfg.id]
    for val in values_tuple:
        combined_scale *= val.scale
        scale_parts.append(str(val.scale))
        uuid_parts.append(val.id)
    uuid = "_".join(uuid_parts).lower()
    current_combos = _make_combos(cfg.dimensions, values_tuple)

    # ── 自适应边界收缩状态（每组合独立重置） ──
    current_min = cfg.word_count_min
    current_max = cfg.word_count_max
    current_option_max = cfg.option_word_count_max

    # ── 提前计算不依赖 LLM 响应的属性 ──
    sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
    selected_image_item = _select_imagery_for_combo(current_combos, cfg, image_dict, scene_dim_id, emotion_dim_id)
    stored_to = ""
    for combo in current_combos:
        if combo.value.stored_to:
            stored_to = combo.value.stored_to
            break

    # ── 构建初始 user_prompt ──
    user_prompt = build_user_prompt(
        current_combos, cfg,
        word_count_min=current_min, word_count_max=current_max,
        option_word_count_max=current_option_max,
        plugins=plugins,
        sandbox_keywords_block=sandbox_block,
        selected_image=selected_image_item,
    )

    # ── API 调用循环（重试 + 自适应收缩） ──
    for attempt in range(cfg.max_retries + 1):
        if attempt > 0:
            print(f"  🔄 重试 {attempt}/{cfg.max_retries}...")
            time.sleep(1)

        # ── API 调用 ──
        try:
            response = llm.generate_event_text(system_prompt, user_prompt)
        except Exception as e:
            print(f"  ❌ API 调用失败: {e}")
            if attempt < cfg.max_retries:
                continue
            return GenerationResult(
                status="skip",
                uuid=uuid, combined_scale=combined_scale,
                scale_parts=scale_parts, combos=current_combos,
                values_tuple=values_tuple,
                stored_to=stored_to,
                selected_image_item=selected_image_item,
            )

        parsed = parse_llm_response(response)

        # ── 校验 ──
        error = validate_response(
            parsed, cfg,
            override_min=cfg.word_count_min, override_max=cfg.word_count_max,
            override_option_max=cfg.option_word_count_max,
        )

        # 🚨 额外校验：插件声明的字段必须在 parsed 中存在且非空
        if error is None and plugins:
            for plugin in plugins:
                for field in plugin.get_extra_output_fields():
                    val = parsed.get(field, "")
                    if not val:
                        extra = parsed.get("_extra", {})
                        val = extra.get(field, "")
                    if not val or not val.strip():
                        error = f"缺少插件字段 '{field}'（{plugin.plugin_id} 要求）"
                        print(f"  ❌ {error}")
                        break
                if error:
                    break

        if error is None:
            # ════════════════════════════════════════════
            # ✅ 校验通过 — 构建所有产物
            # ════════════════════════════════════════════
            title = parsed["title"]
            description = parsed["description"]

            # ── DSL 缩放 ──
            operator_dsls = [val.operator_dsl for val in values_tuple]
            try:
                scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
            except ValueError as e:
                print(f"  ❌ DSL 缩放失败: {e}")
                return GenerationResult(
                    status="fail", error=str(e),
                    uuid=uuid, combined_scale=combined_scale,
                    scale_parts=scale_parts, combos=current_combos,
                    values_tuple=values_tuple, parsed=parsed,
                    raw_response=response,
                    stored_to=stored_to,
                    selected_image_item=selected_image_item,
                )

            # ── Hook 3: 插件 context 富化 ──
            context_extras = _build_plugin_context_extras(
                plugins, current_combos, cfg, parsed, response,
                combined_scale, uuid,
            )

            # 将 stored_to 注入 context_extras
            if stored_to:
                if context_extras is None:
                    context_extras = {}
                context_extras["store_to"] = stored_to

            # ── 收集 tags ──
            all_tags: list[str] = []
            for combo in current_combos:
                for tag in combo.value.tags:
                    if tag.startswith("action:"):
                        all_tags.append(tag)
            tags_to_use = all_tags if all_tags else (cfg.universal_tags or ["bai_ye"])

            # ── 构建选项行 ──
            options = parsed.get("options", {})
            option_rows: list[OptionRow] = []

            if cfg.option_features:
                for choice in cfg.option_features:
                    # 文本
                    if choice.fixed:
                        opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
                    else:
                        opt_text = options.get(choice.id, "").strip()
                        if not opt_text:
                            opt_text = choice.text if choice.text.strip() else "（确认）"

                    # 结果 DSL
                    opt_dsl = _build_option_dsl(
                        current_combos, choice,
                        universal_result=cfg.universal_result or "",
                    )

                    # 🆕 管线直连：意象注入
                    if selected_image_item:
                        imagery_dsl = f"imagery_add(name={selected_image_item.id})"
                        opt_dsl = f"{opt_dsl} | {imagery_dsl}" if opt_dsl else imagery_dsl

                    # ── Hook 4: 插件选项结果 DSL 扩展 ──
                    for plugin in plugins:
                        try:
                            extra = plugin.get_option_result_extras(current_combos, choice)
                            if extra:
                                opt_dsl = f"{opt_dsl} | {extra}" if opt_dsl else extra
                        except Exception as e:
                            print(f"  ⚠️ 插件 '{plugin.plugin_id}'.get_option_result_extras() 异常: {e}")

                    # 🆕 per-option failed_hint：从 context_extras 中按 option id 查找
                    # 注意：使用 .pop() 防止重复消费/污染后续选项
                    per_option_hint = ""
                    if context_extras:
                        per_option_hint = context_extras.pop(f"failed_hint_{choice.id}", "")

                    # requirement
                    opt_req = _build_option_requirement(
                        choice, per_option_hint,
                        universal_option_requirement=cfg.universal_option_requirement or "",
                    )

                    option_rows.append(OptionRow(
                        choice_id=choice.id,
                        text=opt_text,
                        dsl=opt_dsl,
                        requirement=opt_req,
                    ))
            else:
                # 无 option_features 时：回退到默认选项
                default_dsl = scaled_dsl
                if selected_image_item:
                    imagery_dsl = f"imagery_add(name={selected_image_item.id})"
                    default_dsl = f"{default_dsl} | {imagery_dsl}" if default_dsl else imagery_dsl
                default_req = _build_option_requirement(
                    OptionFeature(id="default"),
                    failed_hint_val,
                    universal_option_requirement=cfg.universal_option_requirement or "",
                )
                option_rows.append(OptionRow(
                    choice_id="default",
                    text="（确认）",
                    dsl=default_dsl,
                    requirement=default_req,
                ))

            # 黑名单现已通过内置 BlacklistPlugin.enrich_context() 自动更新
            return GenerationResult(
                status="success",
                uuid=uuid, combined_scale=combined_scale,
                scale_parts=scale_parts, combos=current_combos,
                values_tuple=values_tuple,
                parsed=parsed, raw_response=response,
                scaled_dsl=scaled_dsl,
                context_extras=context_extras,
                tags_to_use=tags_to_use,
                stored_to=stored_to,
                selected_image_item=selected_image_item,
                option_rows=option_rows,
            )
        else:
            # ════════════════════════════════════════════
            # ❌ 校验失败 — 自适应收缩 + 重试
            # ════════════════════════════════════════════
            print(f"  ❌ 验证失败: {error}")
            if attempt < cfg.max_retries:
                old_min, old_max = current_min, current_max
                old_option_max = current_option_max
                if "选项" in error and "过长" in error:
                    current_option_max = max(current_option_max - OPTION_SHRINK_STEP, 5)
                elif "选项" in error and "过短" in error:
                    current_option_max = min(current_option_max + OPTION_SHRINK_STEP, cfg.option_word_count_max)
                elif "过短" in error:
                    current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                elif "过长" in error:
                    current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                if current_min != old_min or current_max != old_max:
                    print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                if current_option_max != old_option_max:
                    print(f"  📐 自适应收缩(选项): {old_option_max} → {current_option_max}")
                if current_min != old_min or current_max != old_max or current_option_max != old_option_max:
                    sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
                    user_prompt = build_user_prompt(
                        current_combos, cfg,
                        word_count_min=current_min, word_count_max=current_max,
                        option_word_count_max=current_option_max,
                        plugins=plugins,
                        sandbox_keywords_block=sandbox_block,
                        selected_image=selected_image_item,
                    )
                continue
            print(f"  ⏭️ 跳过（已达最大重试次数）")
            return GenerationResult(
                status="skip",
                uuid=uuid, combined_scale=combined_scale,
                scale_parts=scale_parts, combos=current_combos,
                values_tuple=values_tuple, parsed=parsed,
                raw_response=response,
                stored_to=stored_to,
                selected_image_item=selected_image_item,
            )

    # 不应到达此处
    return GenerationResult(
        status="fail", error="未知错误",
        uuid=uuid, combined_scale=combined_scale,
        scale_parts=scale_parts, combos=current_combos,
        values_tuple=values_tuple,
        stored_to=stored_to,
        selected_image_item=selected_image_item,
    )


# ════════════════════════════════════════════════════════════════
# 动态字段打印 — Trial 模式输出
# ════════════════════════════════════════════════════════════════

def _print_generation_result(result: GenerationResult, cfg: EventPipelineConfig):
    """动态打印 GenerationResult 的所有字段。

    遍历 parsed 中的所有 key（title/description/options/summary/_extra），
    确保插件新增字段后自动可见，无需修改此函数。
    """
    r = result

    # ── 组合信息 ──
    print(f"\n📦 组合: {r.uuid}")
    print(f"  Scale: {'×'.join(r.scale_parts)} = {r.combined_scale}")

    print(f"\n📋 维度详情:")
    for combo in r.combos:
        print(f"  - {combo.dimension.name}: {combo.value.name} ({combo.value.description})")

    if r.stored_to:
        print(f"\n📂 store_to 路由: {r.stored_to} (→ data/4_eras/{r.stored_to.replace('.', '/')}/)")
    else:
        print(f"\n📂 store_to 路由: (无 — 将使用 output_dir 默认路径)")

    # ── raw response ──
    print(f"\n📨 API Raw Response ({len(r.raw_response)} chars):")
    print("-" * 40)
    print(r.raw_response)
    print("-" * 40)

    # ── 选中意象 ──
    if r.selected_image_item:
        print(f"  🖼️  选中意象: {r.selected_image_item.name}")

    # ── 🆕 动态展开 parsed 所有字段 ──
    print(f"\n🔍 Parsed Result:")
    # 固定字段
    print(f"  title: {r.parsed.get('title', '')!r}")
    print(f"  description: {r.parsed.get('description', '')!r}")

    # summary 嵌套块
    summary = r.parsed.get("summary", {})
    if summary:
        print(f"  summary:")
        for k, v in summary.items():
            print(f"    {k}: {v!r}")

    # _extra 字段（插件 hook 2 注入）
    extra = r.parsed.get("_extra", {})
    if extra:
        print(f"  _extra:")
        for k, v in extra.items():
            print(f"    {k}: {v!r}")

    # options
    options = r.parsed.get("options", {})
    if options:
        print(f"  options:")
        for k, v in options.items():
            print(f"    [{k}]: {v!r}")

    # ── DSL ──
    print(f"\n⚙️ 缩放后 DSL:")
    if r.scaled_dsl:
        print(f"  {r.scaled_dsl}")
    else:
        print(f"  (无操作)")

    # ── context_extras ──
    if r.context_extras:
        print(f"\n📎 插件 context 富化: {r.context_extras}")

    # ── CSV 预览（行为不变）──
    print(f"\n📄 CSV 预览（不会写入文件）:")

    # 构建 context 列（与 write_event_row 的内部 _build_context_column 一致的格式化）
    tags_expr = ""
    if r.tags_to_use:
        tags_expr = "[" + "/".join(r.tags_to_use) + "]"
    context = f"trigger_tags={tags_expr}|weight=10"
    if cfg.era:
        context += f"|era={cfg.era}"
    if r.context_extras:
        for k, v in r.context_extras.items():
            if v:
                context += f"|{k}={v}"

    # event 行
    requirement_col = cfg.universal_requirement if cfg.universal_requirement else ""
    desc_csv = r.parsed.get("description", "").replace('"', '""')
    desc_preview = desc_csv[:60] + "..." if len(desc_csv) > 60 else desc_csv
    print(f'  random_event,{r.uuid},{context},{requirement_col},"{r.parsed.get("title", "")}","{desc_preview}",,,,,,')

    # option 行
    for opt in r.option_rows:
        dsl_csv = opt.dsl.replace('"', '""')
        req_csv = f'"{opt.requirement}"' if opt.requirement else ''
        print(f'  >option,,,{req_csv},"{opt.text}","{dsl_csv}",,,,')
        print(f"     option [{opt.choice_id}]: {opt.text}")


# ════════════════════════════════════════════════════════════════
# CSV 写入 — Production 模式输出
# ════════════════════════════════════════════════════════════════

def _write_result_to_csv(result: GenerationResult, writer, cfg: EventPipelineConfig) -> None:
    """将 GenerationResult 写入 CSV writer。"""
    r = result
    write_event_row(
        writer, r.uuid, r.parsed["title"], r.parsed["description"],
        tags=r.tags_to_use, requirement=cfg.universal_requirement or "",
        context_extras=r.context_extras or None,
        era=cfg.era,
    )
    for opt in r.option_rows:
        write_option_row(writer, opt.text, opt.dsl, requirement=opt.requirement)


# ════════════════════════════════════════════════════════════════
# Reassembly 模式 — CSV 解析 + 旧内容重算
# ════════════════════════════════════════════════════════════════

def parse_old_csv_events(csv_path: str) -> dict[str, EventSnapshot]:
    """解析旧 CSV，提取 title/description/option_texts 按 UUID 索引。

    返回: {uuid: EventSnapshot}
    不关心旧 CSV 的 DSL/context/requirements 列——它们会被重新计算覆盖。
    """
    events: dict[str, EventSnapshot] = {}
    current_uuid = None
    current_event: EventSnapshot | None = None

    with open(csv_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row or row[0] == "row_type":
                continue
            if row[0] == "random_event" and len(row) > 1:
                current_uuid = row[1]
                current_event = EventSnapshot(
                    uuid=current_uuid,
                    title=row[4] if len(row) > 4 else "",
                    description=row[5] if len(row) > 5 else "",
                    option_texts=[],
                )
                events[current_uuid] = current_event
            elif row[0] == ">option" and current_event is not None:
                # option 文本在第 5 列（CSV description 列）
                opt_text = row[5] if len(row) > 5 else ""
                current_event.option_texts.append(opt_text)

    return events


def reassembly_one_event(
    values_tuple: tuple,
    cfg: EventPipelineConfig,
    snapshot: EventSnapshot,
    # sandbox 保留签名兼容但不使用（reassembly 不调 LLM，无 prompt 构建）
    sandbox: SandboxManager | None = None,
    plugins: list[EventPromptPlugin] | None = None,
    image_dict: dict[str, ImageryItem] | None = None,
    scene_dim_id: str | None = None,
    emotion_dim_id: str | None = None,
) -> GenerationResult:
    """🔧 Reassembly 核心：不调 LLM，从旧 CSV snapshot 直接构建 GenerationResult。

    这是 generate_one_event() 的并行变体，唯一区别是
    parsed = {title, description, options} 来自旧 CSV 而非 LLM。
    后半段（DSL 缩放、意象注入、plugin hooks、option 组装）完全复用原逻辑。
    """
    plugins = plugins or []
    image_dict = image_dict or {}

    # ── 计算标识符（同 generate_one_event）──
    combined_scale = 1.0
    scale_parts: list[str] = []
    uuid_parts: list[str] = [cfg.id]
    for val in values_tuple:
        combined_scale *= val.scale
        scale_parts.append(str(val.scale))
        uuid_parts.append(val.id)
    uuid = "_".join(uuid_parts).lower()
    current_combos = _make_combos(cfg.dimensions, values_tuple)

    # ── 提前计算不依赖 LLM 响应的属性（同 generate_one_event）──
    selected_image_item = _select_imagery_for_combo(
        current_combos, cfg, image_dict, scene_dim_id, emotion_dim_id,
    )
    stored_to = ""
    for combo in current_combos:
        if combo.value.stored_to:
            stored_to = combo.value.stored_to
            break

    # ── 从 snapshot 构建 parsed dict（替代 LLM 响应）──
    options_dict: dict[str, str] = {}
    if cfg.option_features:
        for i, choice in enumerate(cfg.option_features):
            if i < len(snapshot.option_texts):
                options_dict[choice.id] = snapshot.option_texts[i]

    parsed = {
        "title": snapshot.title,
        "description": snapshot.description,
        "options": options_dict,
        "summary": {},
        "_extra": {},
    }

    # ── DSL 缩放（同 generate_one_event）──
    operator_dsls = [val.operator_dsl for val in values_tuple]
    try:
        scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
    except ValueError as e:
        print(f"  ❌ DSL 缩放失败: {e}")
        return GenerationResult(
            status="fail", error=str(e),
            uuid=uuid, combined_scale=combined_scale,
            scale_parts=scale_parts, combos=current_combos,
            values_tuple=values_tuple, parsed=parsed,
            stored_to=stored_to,
            selected_image_item=selected_image_item,
        )

    # ── Hook 3: 插件 context 富化 ──
    context_extras = _build_plugin_context_extras(
        plugins, current_combos, cfg, parsed, "",
        combined_scale, uuid,
    )
    if stored_to:
        if context_extras is None:
            context_extras = {}
        context_extras["store_to"] = stored_to

    # ── 收集 tags ──
    all_tags: list[str] = []
    for combo in current_combos:
        for tag in combo.value.tags:
            all_tags.append(tag)
    tags_to_use = all_tags if all_tags else (cfg.universal_tags or ["bai_ye"])

    # ── 构建选项行 ──
    options = parsed.get("options", {})
    option_rows: list[OptionRow] = []

    if cfg.option_features:
        for choice in cfg.option_features:
            # 文本（来自旧 CSV snapshot）
            if choice.fixed:
                opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
            else:
                opt_text = options.get(choice.id, "").strip()
                if not opt_text:
                    opt_text = choice.text if choice.text.strip() else "（确认）"

            # 结果 DSL
            opt_dsl = _build_option_dsl(
                current_combos, choice,
                universal_result=cfg.universal_result or "",
            )
            if selected_image_item:
                imagery_dsl = f"imagery_add(name={selected_image_item.id})"
                opt_dsl = f"{opt_dsl} | {imagery_dsl}" if opt_dsl else imagery_dsl

            # Hook 4: 插件选项结果 DSL 扩展
            for plugin in plugins:
                try:
                    extra = plugin.get_option_result_extras(current_combos, choice)
                    if extra:
                        opt_dsl = f"{opt_dsl} | {extra}" if opt_dsl else extra
                except Exception as e:
                    print(f"  ⚠️ 插件 '{plugin.plugin_id}'.get_option_result_extras() 异常: {e}")

            # per-option failed_hint（reassembly 中无 LLM 响应，为空）
            per_option_hint = ""
            if context_extras:
                per_option_hint = context_extras.pop(f"failed_hint_{choice.id}", "")

            opt_req = _build_option_requirement(
                choice, per_option_hint,
                universal_option_requirement=cfg.universal_option_requirement or "",
            )

            option_rows.append(OptionRow(
                choice_id=choice.id,
                text=opt_text,
                dsl=opt_dsl,
                requirement=opt_req,
            ))
    else:
        default_dsl = scaled_dsl
        if selected_image_item:
            imagery_dsl = f"imagery_add(name={selected_image_item.id})"
            default_dsl = f"{default_dsl} | {imagery_dsl}" if default_dsl else imagery_dsl
        option_rows.append(OptionRow(
            choice_id="default",
            text="（确认）",
            dsl=default_dsl,
            requirement="",
        ))

    return GenerationResult(
        status="success",
        uuid=uuid, combined_scale=combined_scale,
        scale_parts=scale_parts, combos=current_combos,
        values_tuple=values_tuple,
        parsed=parsed, raw_response="",
        scaled_dsl=scaled_dsl,
        context_extras=context_extras,
        tags_to_use=tags_to_use,
        stored_to=stored_to,
        selected_image_item=selected_image_item,
        option_rows=option_rows,
    )


def _load_registry() -> dict:
    """加载 tools/event_config_registry.json 注册表。"""
    registry_path = Path(__file__).resolve().parent.parent / "event_config_registry.json"
    if not registry_path.exists():
        print(f"❌ 注册表文件不存在: {registry_path}")
        print("   请创建 tools/event_config_registry.json")
        sys.exit(1)
    with open(registry_path, "r", encoding="utf-8") as f:
        return json.load(f)


def _run_reassembly_entry(entry_key: str, entry: dict) -> None:
    """对注册表中的一个条目执行 reassembly。

    entry: {"config": "tools/...json", "csv": "data/.../...csv"}
    """
    config_path = _project_root / entry["config"]
    csv_path = _project_root / entry["csv"]

    if not config_path.exists():
        print(f"  ⚠️ [{entry_key}] config 不存在: {config_path}，跳过")
        return
    if not csv_path.exists():
        print(f"  ⚠️ [{entry_key}] CSV 不存在: {csv_path}，跳过")
        return

    print(f"\n{'=' * 50}")
    print(f"🔧 Reassembly: [{entry_key}]")
    print(f"  Config: {entry['config']}")
    print(f"  CSV:    {entry['csv']}")
    print(f"{'=' * 50}")

    # 1. 加载 config
    cfg = load_config_from_json(str(config_path))

    # 2. 加载意象字典
    image_dict: dict[str, ImageryItem] = {}
    if cfg.apply_dimension_imagery:
        image_dict_path = _project_root / "data" / "image_dictionary.json"
        if image_dict_path.exists():
            raw = json.loads(image_dict_path.read_text(encoding="utf-8"))
            for k, v in raw.items():
                image_dict[k] = ImageryItem(**v)

    # 3. 推导场景/情绪维度 ID
    scene_dim_id: str | None = None
    emotion_dim_id: str | None = None
    for dim in cfg.dimensions:
        if dim.id == "scene":
            scene_dim_id = dim.id
        elif dim.id == "emotion":
            emotion_dim_id = dim.id

    # 4. 加载插件
    plugins: list[EventPromptPlugin] = []
    if cfg.plugins:
        try:
            plugins = resolve_plugins(cfg.plugins)
        except KeyError as e:
            print(f"  ❌ [{entry_key}] 插件加载失败: {e}，跳过")
            return

    plugin_ids = [p.plugin_id for p in plugins]
    if "_builtin_blacklist" not in plugin_ids:
        blacklist_plugin = PLUGIN_REGISTRY.get("_builtin_blacklist")
        if blacklist_plugin:
            plugins.append(blacklist_plugin)

    for plugin in plugins:
        plugin.init(cfg)

    # 5. 展开组合
    combinations = list(expand_combinations(cfg.dimensions))
    print(f"  📊 config 组合数: {len(combinations)}")

    # 6. 解析旧 CSV
    old_events = parse_old_csv_events(str(csv_path))
    print(f"  📖 旧 CSV 事件数: {len(old_events)}")

    # 7. 执行 reassembly
    success_count = 0
    not_found_count = 0
    fail_count = 0
    output_path = str(csv_path)

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        write_csv_header(writer)

        for idx, values_tuple in enumerate(combinations):
            uuid = _compute_uuid(cfg.id, values_tuple)
            snapshot = old_events.get(uuid)

            # Fallback: config auto-injects _identity_* suffix via social_identity dimension,
            # but old CSV events were generated before auto-injection and lack the suffix.
            if snapshot is None:
                import re
                base_uuid = re.sub(r'_identity_\w+$', '', uuid)
                if base_uuid != uuid:
                    snapshot = old_events.get(base_uuid)
                    if snapshot is not None:
                        print(f"  🔄 [{idx+1}/{len(combinations)}] {uuid}: fallback 匹配到 {base_uuid}")

            if snapshot is None:
                print(f"  ⏭️ [{idx+1}/{len(combinations)}] {uuid}: 旧 CSV 中未找到，跳过")
                not_found_count += 1
                continue

            result = reassembly_one_event(
                values_tuple, cfg, snapshot,
                plugins=plugins,
                image_dict=image_dict,
                scene_dim_id=scene_dim_id,
                emotion_dim_id=emotion_dim_id,
            )

            if result.status == "success":
                print(f"  ✅ [{idx+1}/{len(combinations)}] {uuid}")
                _write_result_to_csv(result, writer, cfg)
                success_count += 1
            else:
                print(f"  ❌ [{idx+1}/{len(combinations)}] {uuid}: {result.error}")
                fail_count += 1

    print(f"\n  📊 [{entry_key}] 完成: 成功={success_count}, 跳過={not_found_count}, 失败={fail_count}")


def run_reassembly_main(registry_key: str | None = None) -> None:
    """Reassembly 模式顶层入口。

    Args:
        registry_key: 注册表 key。None = 全量注册表。
    """
    registry = _load_registry()
    entries = registry.get("entries", {})

    if not entries:
        print("❌ 注册表为空")
        sys.exit(1)

    if registry_key is not None:
        # 单一条目
        if registry_key not in entries:
            print(f"❌ 注册表中未找到 key: {registry_key}")
            print(f"   可用 key: {list(entries.keys())}")
            sys.exit(1)
        _run_reassembly_entry(registry_key, entries[registry_key])
    else:
        # 全量注册表
        print(f"\n🔄 Reassembly 全量模式 — {len(entries)} 个条目")
        for key, entry in entries.items():
            _run_reassembly_entry(key, entry)

    print(f"\n{'=' * 50}")
    print("✅ Reassembly 全部完成")
    print(f"{'=' * 50}")


# ════════════════════════════════════════════════════════════════
# 试运行模式
# ════════════════════════════════════════════════════════════════

def run_trial_mode(
    combinations: list,
    cfg: EventPipelineConfig,
    system_prompt: str,
    llm: LLMClient,
    sandbox: SandboxManager | None,
    plugins: list[EventPromptPlugin],
    image_dict: dict[str, ImageryItem],
    scene_dim_id: str | None,
    emotion_dim_id: str | None,
    args,
) -> None:
    """🧪 试运行：调 1 次 API，动态打印所有中间产物，不保存 CSV。"""
    print("\n🧪 试运行模式 — 将实际调用 API 1 次，不保存任何文件")

    # 随机或默认选择组合
    if args.random and len(combinations) > 1:
        values_tuple = random.choice(combinations)
        print(f"  🎲 随机模式: 从 {len(combinations)} 个组合中随机选取")
    else:
        values_tuple = combinations[0]

    result = generate_one_event(
        values_tuple, cfg, system_prompt, llm, sandbox, plugins,
        image_dict, scene_dim_id, emotion_dim_id,
        is_trial=True,
    )

    if result.status == "success":
        _print_generation_result(result, cfg)
        print(f"\n✅ 试运行完成 — API 调用成功，未保存任何文件")
    elif result.status == "skip":
        print(f"\n⏭️ 试运行完成 — 已跳过，未保存任何文件")
    else:
        print(f"\n⚠️ 试运行完成 — 出现异常，未保存任何文件")


# ════════════════════════════════════════════════════════════════
# 生产模式
# ════════════════════════════════════════════════════════════════

def _compute_uuid(cfg_id: str, values_tuple: tuple) -> str:
    """计算维度组合对应的 UUID（与 generate_one_event 内部逻辑一致）。"""
    parts = [cfg_id] + [v.id for v in values_tuple]
    return "_".join(parts).lower()


def run_production_mode(
    combinations: list,
    cfg: EventPipelineConfig,
    system_prompt: str,
    llm: LLMClient,
    sandbox: SandboxManager | None,
    plugins: list[EventPromptPlugin],
    image_dict: dict[str, ImageryItem],
    scene_dim_id: str | None,
    emotion_dim_id: str | None,
    output_path: str,
    complete: bool = False,
    preserved_rows: list[list[str]] | None = None,
    regenerate_uuids: set[str] | None = None,
) -> None:
    """🏭 生产模式：遍历所有组合，生成事件并写入 CSV。

    complete: 补跑模式。检测已有 CSV 中成功生成的 UUID，只生成缺失的组合并追加写入。
    """
    success_count = 0
    skip_count = 0
    fail_count = 0

    # ── --complete 模式：检测已有 CSV，过滤出缺失组合 ──
    if complete:
        if os.path.exists(output_path):
            existing_uuids = set()
            with open(output_path, "r", newline="", encoding="utf-8") as f:
                reader = csv.reader(f)
                for row in reader:
                    if row and row[0] == "random_event" and len(row) > 1 and row[1]:
                        existing_uuids.add(row[1])
            original_count = len(combinations)
            combinations = [
                vt for vt in combinations
                if _compute_uuid(cfg.id, vt) not in existing_uuids
            ]
            missing_count = len(combinations)
            print(f"🔍 --complete 模式：CSV 已有 {len(existing_uuids)} 个事件，需补跑 {missing_count}/{original_count}")
            if missing_count == 0:
                print("✅ 全部组合已生成，无需补跑")
                return
        else:
            print(f"⚠️  --complete 模式：{output_path} 不存在，将从头生成")

    # ── 决定写入模式：补跑则追加，首次则新建 ──
    if regenerate_uuids is not None:
        # --complete-uuids 模式：写新文件，先写入保留行 + header，再追加新生成的行
        f = open(output_path, "w", newline="", encoding="utf-8")
        writer = csv.writer(f)
        write_csv_header(writer)
        if preserved_rows:
            for row in preserved_rows:
                writer.writerow(row)
            print(f"  📎 保留 {len(preserved_rows)} 个已有事件，将重跑 {len(combinations)} 个")
        else:
            print(f"  📎 未找到保留行，将生成 {len(combinations)} 个新事件")
    elif complete and os.path.exists(output_path):
        f = open(output_path, "a", newline="", encoding="utf-8")
        writer = csv.writer(f)
        print(f"  📎 追加模式（保留已有 {len(existing_uuids) if complete else 0} 个事件）")
    else:
        f = open(output_path, "w", newline="", encoding="utf-8")
        writer = csv.writer(f)
        write_csv_header(writer)

    try:
        for idx, values_tuple in enumerate(combinations):
            print(f"\n[{idx + 1}/{len(combinations)}] ", end="")

            result = generate_one_event(
                values_tuple, cfg, system_prompt, llm, sandbox, plugins,
                image_dict, scene_dim_id, emotion_dim_id,
            )

            if result.status == "success":
                print(f"{result.uuid}")
                print(f"  Scale: {'×'.join(result.scale_parts)} = {result.combined_scale}")
                if result.selected_image_item:
                    print(f"  🖼️  选中意象: {result.selected_image_item.name}")
                print(f"  ✅ title: {result.parsed.get('title', '')}")
                desc_preview = result.parsed.get('description', '')[:60] + "..." if len(result.parsed.get('description', '')) > 60 else result.parsed.get('description', '')
                print(f"     desc: {desc_preview}")
                if result.scaled_dsl:
                    print(f"     DSL: {result.scaled_dsl}")
                else:
                    print(f"     DSL: (无操作)")
                if result.context_extras:
                    print(f"     📎 插件 context: {result.context_extras}")
                for opt in result.option_rows:
                    print(f"     option [{opt.choice_id}]: {opt.text}")

                _write_result_to_csv(result, writer, cfg)
                success_count += 1

            elif result.status == "skip":
                print(f"{result.uuid} ⏭️ 跳过")
                skip_count += 1

            else:  # fail
                print(f"{result.uuid} ❌ 失败")
                fail_count += 1
    finally:
        f.close()

    print(f"\n{'=' * 40}")
    print(f"📊 生成完成")
    print(f"   成功: {success_count}")
    print(f"   跳过: {skip_count}")
    print(f"   失败: {fail_count}")
    print(f"   输出: {output_path}")
    print(f"{'=' * 40}")


# ════════════════════════════════════════════════════════════════
# 主流程
# ════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="正交事件生成管线")
    parser.add_argument("--config", default=None, help="JSON 配置文件路径（默认使用内置示例配置）")
    parser.add_argument("--output-dir", default=None, help="输出目录（覆盖配置中的路径）")
    parser.add_argument("--dry-run", action="store_true", help="只打印 Prompt，不调 API")
    parser.add_argument("--trial", action="store_true", help="试运行：调1次API，打印所有中间产物，不保存CSV")
    parser.add_argument("--max-events", type=int, default=0, help="最多生成事件数（0=全部）")
    parser.add_argument("--number", type=int, default=0, help="精确控制生成事件数（不能超过组合总数，与 --max-events 互斥）")
    parser.add_argument("--random", action="store_true", help="随机模式: 在 trial 模式下随机选择一个维度组合（而非总是第一个）")
    parser.add_argument("--complete", action="store_true", help="补跑模式：检测 CSV 中缺失的组合并追加生成（跳过已成功生成的事件）")
    parser.add_argument("--complete-uuids", default=None, help="重跑模式：指定要重新生成的 UUID（逗号分隔），保留其余已生成的行不变")
    parser.add_argument("--reassembly", nargs="?", const="__ALL__", default=None,
                        help="Reassembly 模式：从注册表或指定 key 对应的旧 CSV 中读取 AI 内容，"
                             "用新的 config operator 配置重新计算 DSL/context，覆盖写回 CSV。"
                             "无参数=全量注册表；有参数=注册表 key，如 'duotai_humiliation'")
    args = parser.parse_args()

    # ── Reassembly 模式：早期路由（无需 LLM、sandbox、system prompt）──
    if args.reassembly is not None:
        key = args.reassembly if args.reassembly != "__ALL__" else None
        run_reassembly_main(registry_key=key)
        return

    if args.random and not args.trial:
        print("⚠️  --random 仅在 --trial 模式下生效，已忽略")

    # ── 加载配置 ──
    if args.config:
        cfg = load_config_from_json(args.config)
    else:
        cfg = default_config()

    print(f"📖 配置: {cfg.name}")

    # ── 🆕 加载意象字典（情绪-意象正交） ──
    image_dict: dict[str, ImageryItem] = {}
    if cfg.apply_dimension_imagery:
        image_dict_path = Path(__file__).resolve().parent.parent / "data" / "image_dictionary.json"
        if image_dict_path.exists():
            raw = json.loads(image_dict_path.read_text(encoding="utf-8"))
            for k, v in raw.items():
                image_dict[k] = ImageryItem(**v)
            print(f"🖼️  意象字典已加载: {len(image_dict)} 条")

    # ── 从配置中推导场景/情绪维度 ID（用于意象正交） ──
    scene_dim_id: str | None = None
    emotion_dim_id: str | None = None
    for dim in cfg.dimensions:
        if dim.id == "scene":
            scene_dim_id = dim.id
        elif dim.id == "emotion":
            emotion_dim_id = dim.id

    # ── 解析插件 ──
    plugins: list[EventPromptPlugin] = []
    if cfg.plugins:
        try:
            plugins = resolve_plugins(cfg.plugins)
            print(f"🔌 已加载插件: {[p.plugin_id for p in plugins]}")
        except KeyError as e:
            print(f"❌ 插件加载失败: {e}")
            sys.exit(1)

    # ── 内置黑名单插件：自动注入（无需 config 声明） ──
    plugin_ids = [p.plugin_id for p in plugins]
    if "_builtin_blacklist" not in plugin_ids:
        blacklist_plugin = PLUGIN_REGISTRY.get("_builtin_blacklist")
        if blacklist_plugin:
            plugins.append(blacklist_plugin)
            print(f"🔌 内置黑名单插件已加载（无需配置声明）")
        else:
            print("  ⚠️ 内置黑名单插件未注册（BlacklistPlugin 可能未导入）")
    else:
        print(f"🔌 内置黑名单插件已在 config.plugins 中声明")

    # ── Phase 0: 插件初始化（扫描配置构建内部状态） ──
    for plugin in plugins:
        plugin.init(cfg)

    dim_count = len(cfg.dimensions)
    if dim_count < 1:
        print(f"❌ 配置至少需要 1 个维度，当前有 {dim_count} 个")
        sys.exit(1)

    # ── 展开所有组合（支持 Dynamic Dimension） ──
    combinations = list(expand_combinations(cfg.dimensions))
    dim_value_counts = [
        f"{len(d.values)}" if not getattr(d, 'dynamic', False) else f"({getattr(d, 'value_extractor_key', '?')})"
        for d in cfg.dimensions
    ]
    print(f"   组合数: {len(combinations)} ({'×'.join(dim_value_counts)})")

    # ── --number 与 --max-events 互斥检测 ──
    if args.number > 0 and args.max_events > 0:
        print("❌ --number 和 --max-events 不能同时指定，请只使用其中一个")
        sys.exit(1)

    # ── --number 逻辑：精确控制，超出总组合数时报错 ──
    if args.number > 0:
        total = len(combinations)
        if args.number > total:
            print(f"❌ --number {args.number} 超过总组合数 {total}")
            sys.exit(1)
        combinations = combinations[: args.number]
        print(f"   限制生成: {len(combinations)} 个")

    # ── --max-events 逻辑（向后兼容）：静默截断 ──
    if args.max_events > 0:
        combinations = combinations[: args.max_events]
        print(f"   限制生成: {len(combinations)} 个")

    # ── 准备输出 ──
    output_dir = args.output_dir or cfg.output_dir
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"_{cfg.id}_events.csv")
    print(f"📝 输出: {output_path}")

    # ── 初始化 LLM ──
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        if args.dry_run:
            print("⚠️  未设置 DEEPSEEK_API_KEY（dry-run 跳过）")
        elif args.trial:
            print("⚠️  未设置 DEEPSEEK_API_KEY（trial 模式无法调 API）")
            print("   export DEEPSEEK_API_KEY='sk-xxx'")
            sys.exit(1)
        else:
            print("❌ 请设置环境变量 DEEPSEEK_API_KEY")
            print("   export DEEPSEEK_API_KEY='sk-xxx'")
            sys.exit(1)

    llm = LLMClient(api_key=api_key or "dry-run", model=cfg.api_model)

    # ── 初始化沙盒缓存 ──
    sandbox: Optional[SandboxManager] = None
    if not args.dry_run:
        sandbox = SandboxManager(
            config_path=args.config,
            llm=llm,
            cfg=cfg,
        )
        if sandbox.load():
            print(f"  ✅ 沙盒缓存就绪")
        else:
            print(f"  🏗️  沙盒缓存不存在，自动生成中...")
            sandbox.generate()
        print(f"  📍 沙盒路径: {sandbox.sandbox_path}")

    # 组装 system prompt
    system_prompt = build_system_prompt(cfg)
    print(f"\n📋 System Prompt ({len(system_prompt)} chars):")
    print("-" * 40)
    if args.trial:
        print(system_prompt)
    else:
        print(system_prompt[:600] + "..." if len(system_prompt) > 600 else system_prompt)
    print("-" * 40)

    # ── Dry-run ──
    if args.dry_run:
        print("\n🏁 Dry-run 模式，不会调用 API")
        first_values = combinations[0]
        first_combos = _make_combos(cfg.dimensions, first_values)
        sandbox_block = ""
        selected_image_item = _select_imagery_for_combo(first_combos, cfg, image_dict, scene_dim_id, emotion_dim_id)
        if selected_image_item:
            print(f"  🖼️  选中意象: {selected_image_item.name}")
        user_prompt = build_user_prompt(
            first_combos, cfg,
            plugins=plugins,
            sandbox_keywords_block=sandbox_block,
            selected_image=selected_image_item,
        )
        print(f"\n📋 示例 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)
        print("\n✅ Dry-run 完成")
        return

    # ── 路由到对应模式 ──
    if args.trial:
        run_trial_mode(
            combinations, cfg, system_prompt, llm, sandbox, plugins,
            image_dict, scene_dim_id, emotion_dim_id, args,
        )
    elif args.complete_uuids:
        # --complete-uuids 模式：只重跑指定 UUID 的事件，保留其余行
        target_uuids = set(u.strip() for u in args.complete_uuids.split(",") if u.strip())
        if not target_uuids:
            print("❌ --complete-uuids 需要至少一个 UUID")
            sys.exit(1)

        # 过滤 combinations，只保留匹配目标 UUID 的
        original_count = len(combinations)
        target_combinations = [
            vt for vt in combinations
            if _compute_uuid(cfg.id, vt) in target_uuids
        ]
        found_count = len(target_combinations)
        if found_count == 0:
            print(f"❌ 未找到匹配目标 UUID 的组合")
            print(f"   目标: {target_uuids}")
            print(f"   可用组合 UUID 示例: {_compute_uuid(cfg.id, combinations[0])}")
            sys.exit(1)
        print(f"🔍 --complete-uuids 模式：共 {original_count} 个组合，匹配 {found_count} 个目标 UUID")

        # 读取现有 CSV，提取要保留的行（非目标 UUID + 其选项行）
        preserved_rows: list[list[str]] = []
        preserve_current_event = False  # 标记是否正在保留当前 event block
        if os.path.exists(output_path):
            with open(output_path, "r", newline="", encoding="utf-8") as f:
                reader = csv.reader(f)
                for row in reader:
                    if not row:
                        continue
                    if row[0] == "row_type":
                        continue
                    if row[0] == "random_event" and len(row) > 1:
                        uuid = row[1]
                        if uuid not in target_uuids:
                            preserve_current_event = True
                            preserved_rows.append(row)
                        else:
                            preserve_current_event = False
                    elif row[0] == ">option":
                        if preserve_current_event:
                            preserved_rows.append(row)
            event_count = sum(1 for r in preserved_rows if r[0] == "random_event")
            print(f"   保留 {event_count} 个已有事件（共 {len(preserved_rows)} 行）")
        else:
            print(f"⚠️  {output_path} 不存在，将从头生成目标事件")

        combinations = target_combinations
        run_production_mode(
            combinations, cfg, system_prompt, llm, sandbox, plugins,
            image_dict, scene_dim_id, emotion_dim_id, output_path,
            complete=args.complete,
            preserved_rows=preserved_rows,
            regenerate_uuids=target_uuids,
        )
    else:
        run_production_mode(
            combinations, cfg, system_prompt, llm, sandbox, plugins,
            image_dict, scene_dim_id, emotion_dim_id, output_path,
            complete=args.complete,
        )


if __name__ == "__main__":
    main()
