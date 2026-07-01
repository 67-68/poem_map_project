"""
Prompt 组装 — 通信域。

包含:
  build_system_prompt  组装 System Prompt
  build_user_prompt    组装 User Prompt（含维度组合、插件、沙盒、语义锚点）

注意：黑名单功能已移至内置 BlacklistPlugin，不再通过 build_user_prompt 参数注入。
"""

import json
import os
from typing import TYPE_CHECKING, Optional

from tools.config import DimensionCombo, EventPipelineConfig, OptionFeature

if TYPE_CHECKING:
    from tools.plugin_base import EventPromptPlugin

# ── Operator → Prompt 语义翻译器（单例懒加载） ──
_translator_instance = None

def get_translator() -> Optional[object]:
    """
    模块级单例懒加载 OperatorSemanticTranslator。

    只在 semantic_anchors.enabled=True 时才会加载数据文件。
    返回 None 表示翻译器不可用（文件缺失或未启用）。
    """
    global _translator_instance
    if _translator_instance is not None:
        return _translator_instance

    # 检查数据文件是否齐全
    data_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data')
    required_files = [
        os.path.join(data_dir, 'semantic_properties.json'),
        os.path.join(data_dir, 'semantic_traits.json'),
        os.path.join(data_dir, 'semantic_emotions.json'),
    ]
    for fpath in required_files:
        if not os.path.isfile(fpath):
            return None  # 数据文件不全，不初始化

    try:
        from tools.event_generator.operator_translator import OperatorSemanticTranslator
        _translator_instance = OperatorSemanticTranslator(*required_files)
        return _translator_instance
    except (ImportError, FileNotFoundError, json.JSONDecodeError):
        return None


def build_system_prompt(cfg: EventPipelineConfig) -> str:
    """组装 System Prompt。

    利用 Recency Bias：最核心的约束（final_directive）放在绝对末尾。
    """
    parts = [f"你是{cfg.name}叙事设计师。你只负责生成事件文本，不要输出任何额外内容。"]

    if cfg.background_context.strip():
        parts.append(f"\n## 世界观背景\n{cfg.background_context.strip()}")

    if cfg.ai_persona.strip():
        parts.append(f"\n## 你的角色\n{cfg.ai_persona.strip()}")

    if cfg.prompt_features:
        parts.append("\n## 风格要求")
        for pf in cfg.prompt_features:
            if pf.text.strip():
                parts.append(f"- {pf.text.strip()}")

    if cfg.fact_features:
        parts.append("\n## 你必须严格遵循的事实")
        for ff in cfg.fact_features:
            if ff.text.strip():
                parts.append(f"- {ff.text.strip()}")
        parts.append("\n以上是你要严格遵循的事实陈述，除此之外不要自己编造任何设定。")

    # 🚨 指令后置：final_directive 永远放在 Prompt 最后一行
    if cfg.final_directive and cfg.final_directive.strip():
        parts.append(f"\n## ⚠️ 绝对指令（最后一行，优先级最高）\n{cfg.final_directive.strip()}")

    return "\n".join(parts)


def build_user_prompt(
    combos: list[DimensionCombo],
    cfg: EventPipelineConfig,
    word_count_min: Optional[int] = None,
    word_count_max: Optional[int] = None,
    option_word_count_max: Optional[int] = None,
    plugins: Optional[list["EventPromptPlugin"]] = None,
    sandbox_keywords_block: Optional[str] = None,
) -> str:
    """组装 User Prompt（包含当前维度组合信息）。

    接受任意数量的 DimensionCombo（替代硬编码的 d1/dv1/d2/dv2/d3/dv3），
    自动生成维度组合描述。

    可通过 word_count_min/word_count_max 覆盖 cfg 中的默认长度约束，
    用于自适应重试时动态调整 LLM 看到的字数要求。
    可通过 option_word_count_max 覆盖 cfg 中的默认选项字数约束，
    用于自适应重试时动态调整 LLM 看到的选项字数要求。

    如果传入了 plugins，会调用每个 plugin.get_prompt_fragment() 将
    插件自定义指令追加到 prompt 末尾（Hook 1）。

    注意：黑名单功能已移至内置 BlacklistPlugin，通过插件 Hook 1 注入，
    不再通过 build_user_prompt 参数传递。

    如果传入了 sandbox_keywords_block（非空字符串），会在插件 Hook 之前
    追加"🎲 创作种子"区块，引导 AI 围绕沙盒关键词展开创作。
    """
    effective_min = word_count_min if word_count_min is not None else cfg.word_count_min
    effective_max = word_count_max if word_count_max is not None else cfg.word_count_max
    effective_option_max = option_word_count_max if option_word_count_max is not None else cfg.option_word_count_max
    combo_lines = "\n".join(
        f"{i}. {combo.dimension.name}: {combo.value.name}（{combo.value.description}）"
        for i, combo in enumerate(combos, 1)
    )
    lines = [f"""请为以下维度组合生成一个{cfg.name}事件：

## 维度组合
{combo_lines}

## 输出要求
- title：15字以内的事件标题
- description：{effective_min}-{effective_max}字的事件描述
- 使用全角中文标点"""]

    # 如果有选项定义，注入到 prompt 中
    # 只注入非固定选项（fixed=False），固定选项直接使用配置文本，不劳烦 AI
    ai_options = [of for of in (cfg.option_features or []) if not of.fixed]
    if ai_options:
        lines.append(f"""
## 选项
为以下每个选项生成描述文本（每个不超过{effective_option_max}字）：""")
        for of in ai_options:
            # 使用 prompt 字段，如果为空则回退到 text（向后兼容）
            instruction = of.prompt if of.prompt.strip() else of.text
            if instruction.strip():
                lines.append(f"- {of.id}: {instruction.strip()}")
        # 用实际的 option id 生成格式示例
        opt_examples = "\n".join(f" {of.id}: <{of.id}文本>" for of in ai_options)
        lines.append(f"""
输出格式如下，不要多余的内容：

title: <你的标题>
description: <你的描述>
options:
{opt_examples}""")
    else:
        lines.append("""
- 只返回以下格式的两行，不要多余的内容：

title: <你的标题>
description: <你的描述>""")

    # ── 🆕 Sematic Anchor: 语义锚点注入（Operator → Prompt 翻译） ──
    # 将 option_features[].operator_dsl 和 dimension values 的 operator_dsl
    # 翻译为语义锚点文本，插入在选项描述之后、写作契约之前。
    translator = get_translator()
    semantic_enabled = bool(
        cfg.semantic_anchors
        and cfg.semantic_anchors.get('enabled', False)
        and translator is not None
    )
    if semantic_enabled:
        # 收集所有需要翻译的 DSL（按选项分组）
        option_dsls: list[tuple[str, str]] = []  # (option_id, dsl_string)
        for of in (cfg.option_features or []):
            if of.operator_dsl.strip():
                option_dsls.append((of.id, of.operator_dsl.strip()))

        # 也收集维度 values 的 operator_dsl（如果有）
        # 只收集当前 combo 中选中的维度值，避免注入无关语义锚点
        dimension_dsls: list[tuple[str, str]] = []  # (dim_value_id, dsl_string)
        selected_val_ids = {c.value.id for c in combos}  # 当前 combo 选中的维度值 ID 集合
        for dim in (cfg.dimensions or []):
            for val in (dim.values or []):
                if val.id not in selected_val_ids:
                    continue
                if val.operator_dsl.strip():
                    dimension_dsls.append((val.id, val.operator_dsl.strip()))

        if option_dsls or dimension_dsls:
            lines.append('\n## 🤖 语义锚点（Operator DSL 翻译）')

            if option_dsls:
                for opt_id, dsl in option_dsls:
                    # 翻译每个选项的 DSL
                    anchor_set = translator.translate(dsl)
                    if not anchor_set.is_empty():
                        fragment = translator.to_prompt_fragment(
                            anchor_set,
                            local_emotions=cfg.emotion_registry,
                        )
                        if fragment.strip():
                            lines.append(f'\n### 选项 "{opt_id}" 的语义锚点')
                            lines.append(fragment)

            if dimension_dsls:
                for val_id, dsl in dimension_dsls:
                    anchor_set = translator.translate(dsl)
                    if not anchor_set.is_empty():
                        fragment = translator.to_prompt_fragment(
                            anchor_set,
                            local_emotions=cfg.emotion_registry,
                        )
                        if fragment.strip():
                            lines.append(f'\n### 维度值 "{val_id}" 的语义锚点')
                            lines.append(fragment)

    # ── Narrative Constraint: 结构化"写作契约"区块 ──
    # 收集所有维度的 narrative_constraint
    dim_constrained = [
        combo for combo in combos
        if combo.value.narrative_constraint is not None
    ]
    # 遍历所有选项，对有 narrative_constraint 且字段非空的选项渲染固定格式约束
    constrained_options = [
        of for of in (cfg.option_features or [])
        if of.narrative_constraint is not None
    ]
    if dim_constrained or constrained_options:
        lines.append("\n## 📜 写作契约 (Narrative Constraint)")

        # ── 维度级约束 ──
        for combo in dim_constrained:
            nc = combo.value.narrative_constraint
            type_tag = f" [{nc.type}]" if nc.type else ""
            lines.append(f"\n### 维度 \"{combo.value.name}\"{type_tag}")
            if nc.demand_context:
                lines.append(f"- 📣 索取层 (NPC Demand): {nc.demand_context}")
            if nc.action_style:
                lines.append(f"- 🎭 执行层 (Player Action): {nc.action_style}")
            if nc.resolution_style:
                lines.append(f"- 💀 揭晓层 (System Resolution): {nc.resolution_style}")
            if nc.negative_examples:
                lines.append(f"\n  ⛔ 反面教材（禁止出现以下写法）:")
                for ex in nc.negative_examples:
                    if ex.bad:
                        lines.append(f"    ❌ [{ex.field}] \"{ex.bad}\"")
                    if ex.reason:
                        lines.append(f"      原因: {ex.reason}")

        # ── 选项级约束 ──
        for of in constrained_options:
            nc = of.narrative_constraint
            type_tag = f" [{nc.type}]" if nc.type else ""
            lines.append(f"\n### 选项 \"{of.id}\"{type_tag}")
            if nc.demand_context:
                lines.append(f"- 📣 索取层 (NPC Demand): {nc.demand_context}")
            if nc.action_style:
                lines.append(f"- 🎭 执行层 (Player Action): {nc.action_style}")
            if nc.resolution_style:
                lines.append(f"- 💀 揭晓层 (System Resolution): {nc.resolution_style}")
            # ── 反面教材（Negative Prompting）──
            if nc.negative_examples:
                lines.append(f"\n  ⛔ 反面教材（禁止出现以下写法）:")
                for ex in nc.negative_examples:
                    if ex.bad:
                        lines.append(f"    ❌ [{ex.field}] \"{ex.bad}\"")
                    if ex.reason:
                        lines.append(f"      原因: {ex.reason}")

    # ── Hook 1: 插件 Prompt 片段注入 ──
    if plugins:
        for plugin in plugins:
            fragment = plugin.get_prompt_fragment(combos, cfg)
            if fragment.strip():
                lines.append(f"\n## 额外要求（{plugin.plugin_id}）\n{fragment.strip()}")

    # ── 沙盒关键词注入 ──
    if sandbox_keywords_block and sandbox_keywords_block.strip():
        lines.append(sandbox_keywords_block)

    return "\n".join(lines)
