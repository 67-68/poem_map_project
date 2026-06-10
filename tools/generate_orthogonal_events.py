#!/usr/bin/env python3
"""
正交事件生成管线 - 主脚本

用法:
  export DEEPSEEK_API_KEY="sk-xxx"
  python3 tools/generate_orthogonal_events.py  --config <json_or_py>
  eg. python3 tools/generate_orthogonal_events.py --config tools/bai_ye_honeymoon_config.json

示例:
  # 使用内置默认配置（拜谒蜜月期）
  python3 tools/generate_orthogonal_events.py

  # 使用 JSON 配置文件
  python3 tools/generate_orthogonal_events.py --config my_config.json

  # dry-run 只看 prompt 不调 API
  python3 tools/generate_orthogonal_events.py --dry-run

  # trial 试运行：实际调 1 次 API，打印全部中间产物，不保存 CSV
  python3 tools/generate_orthogonal_events.py --trial

输出:
  data/generated_events/<config.id>_events.csv
"""

import argparse
import csv
import itertools
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Callable, Optional

# ── 自动将项目根目录加入 sys.path，消除 PYTHONPATH=. 的依赖 ──
_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

from openai import OpenAI

from tools.config import (
    DimensionCombo,
    EventPipelineConfig,
    FactFeature,
    load_text_features_library,
    OptionFeature,
    PipelineDimension,
    PipelineDimensionValue,
    PromptFeature,
    resolve_text_features,
)
from tools.plugin_base import (
    PLUGIN_REGISTRY,
    EventPromptPlugin,
    PluginContext,
    register_plugin,
    resolve_plugins,
)

# ── 自动注册插件（import 触发 register_plugin） ──
import tools.plugins  # noqa: F401 — 确保 PLUGIN_REGISTRY 已填充


# ════════════════════════════════════════════════════════════════
# 1. 内置示例配置（拜谒 - 蜜月期）
# ════════════════════════════════════════════════════════════════

def default_config() -> EventPipelineConfig:
    """返回默认的拜谒蜜月期配置。"""
    return EventPipelineConfig(
        id="bai_ye_honeymoon",
        name="拜谒 - 蜜月期 (0-70)",
        background_context="""
大唐天宝年间（公元742年—756年），长安城。此时正值唐玄宗在位后期，朝政日益腐败，权相李林甫把持朝纲，官场中充斥着"口蜜腹剑"的风气。

玩家是初入仕途的进士，需要在长安城中通过拜谒权贵来获得举荐和升迁机会。权贵府邸门前，从门子到清客到权贵本人，层层关卡都需要打点。这是一个表面上讲究礼数、实则处处要钱的世界。

蜜月期（玩家野心值0-70）：这个阶段玩家尚处于对官场的幻想期，遇到的阻碍虽然令人不快，但还没有到彻底打破幻想的程度。对方多少还保留着表面上的客气和礼数。
""".strip(),
        ai_persona="""
你是一位精通唐朝官场文化和人情世故的叙事设计师。你擅长用克制、白描的手法呈现官场中微妙的权力关系。你的文风接近唐传奇，简洁有力，不煽情不议论，让事实本身说话。你深刻理解"无状态叙事"——每个事件都是独立的切片，不依赖玩家的过往经历。
""".strip(),
        prompt_features=[
            PromptFeature(id="stateless_narrative", text="使用无状态叙事，不要引用玩家过去的具体经历，每次事件都当作第一次发生。"),
            PromptFeature(id="tone_cautious", text="不要过于戏剧化，保持冷静克制的叙事语气，突出官场的虚伪和客套。"),
        ],
        fact_features=[
            FactFeature(id="bai_ye_venue", text="去拜谒的地方可以是王府、右相府或六部衙门，这些地点在长安城中真实存在。"),
        ],
        dimensions=[
            PipelineDimension(
                id="power_level",
                name="权力阻击位",
                description="玩家拜谒时面对的门槛等级，级别越高付出的代价越大",
                values=[
                    PipelineDimensionValue(
                        id="L0", name="门子/家奴",
                        description="最底层的门卫、仆役，守门索贿，玩家需要打点才能进门",
                        scale=1.0,
                        operator_dsl='prop_sub(name=money; val=10)',
                    ),
                    PipelineDimensionValue(
                        id="L1", name="清客/文法吏",
                        description="中层幕僚、文书小吏，递话要钱，比直接面对权贵便宜",
                        scale=1.5,
                        operator_dsl='prop_sub(name=money; val=10)',
                    ),
                    PipelineDimensionValue(
                        id="L2", name="权贵本尊",
                        description="直接面对高官权贵，需要重大代价才能获得见面机会",
                        scale=2.0,
                        operator_dsl='prop_sub(name=money; val=10)|prop_sub(name=fatigue; val=5)',
                    ),
                ],
            ),
            PipelineDimension(
                id="extraction_type",
                name="资源掠夺机制",
                description="玩家在这次拜谒中付出的主要代价类型",
                values=[
                    PipelineDimensionValue(
                        id="TypeA", name="金钱掠夺",
                        description="对方通过明示或暗示索取钱财，这是最常见的资源掠夺方式",
                        scale=1.0,
                        operator_dsl='prop_sub(name=money; val=20)',
                    ),
                    PipelineDimensionValue(
                        id="TypeB", name="生命/健康损耗",
                        description="对方耗着玩家、让玩家长时间等候、带病工作等身体损耗",
                        scale=1.0,
                        operator_dsl='prop_sub(name=health; val=5)',
                    ),
                    PipelineDimensionValue(
                        id="TypeC", name="精神PUA",
                        description="对方通过羞辱、冷落、贬低玩家地位来获取精神快感",
                        scale=1.0,
                        operator_dsl='prop_sub(name=fatigue; val=10)',
                    ),
                ],
            ),
            PipelineDimension(
                id="evil_motive",
                name="平庸之恶动机",
                description="对方为难玩家的内在动机，这决定了事件的道德底色",
                values=[
                    PipelineDimensionValue(
                        id="M0", name="媚上邀功",
                        description="对方为了讨好上级而故意为难玩家，把玩家当投名状",
                        scale=1.0,
                        operator_dsl="",
                    ),
                    PipelineDimensionValue(
                        id="M1", name="纯粹寻租/变态",
                        description="对方纯粹为了享受支配欲和权力快感，毫无制度性理由",
                        scale=1.5,
                        operator_dsl="",
                    ),
                    PipelineDimensionValue(
                        id="M2", name="制度性冷漠",
                        description="对方并非刻意针对玩家，而是制度本身如此，玩家只是碰上了",
                        scale=1.0,
                        operator_dsl="",
                    ),
                ],
            ),
        ],
        word_count_min=80,
        word_count_max=200,
        max_retries=3,
        api_model="deepseek-reasoner",
        output_dir="data/generated_events/",
    )


# ════════════════════════════════════════════════════════════════
# 2. DSL 缩放器
# ════════════════════════════════════════════════════════════════

SCALABLE_OPS = {"prop_add", "prop_sub", "prop_set", "emo_add", "emo_sub"}
KNOWN_NON_PROP_OPS = {
    "emo_set",
    "trait_add", "trait_remove",
    "flag_bool_set", "flag_str_set", "flag_str_append",
    "flag_int_set", "flag_int_append", "flag_int_reduce_if_above",
    "use_template",
}


def scale_dsl_operator(dsl: str, scale: int) -> str:
    """对单条 DSL 语句的数值参数进行 Scale 乘算。"""
    dsl = dsl.strip()
    if not dsl:
        return ""

    paren_idx = dsl.find("(")
    if paren_idx == -1:
        raise ValueError(f"DSL 语句缺少括号: {dsl}")

    func_name = dsl[:paren_idx].strip()

    # use_template 不需要缩放，直接原样返回
    if func_name == "use_template":
        return dsl

    if func_name in KNOWN_NON_PROP_OPS:
        raise ValueError(
            f"不支持的 operator 类型: '{func_name}'。"
            f"当前只支持可缩放 Operator ({', '.join(sorted(SCALABLE_OPS))})"
        )
    if func_name not in SCALABLE_OPS:
        raise ValueError(
            f"未知 operator: '{func_name}'。"
            f"允许的可缩放 Operator: {', '.join(sorted(SCALABLE_OPS))}"
        )

    args_str = dsl[paren_idx + 1 : dsl.rfind(")")]
    args = _parse_dsl_args(args_str)

    if "val" in args:
        try:
            original_val = int(args["val"])
        except (ValueError, TypeError):
            raise ValueError(f"DSL 'val' 参数不是整数: {args['val']} (in: {dsl})")
        scaled = original_val * scale
        # 如果结果是整数，输出整数（避免 "val=15.0" 这种多余的小数点）
        if scaled == int(scaled):
            args["val"] = str(int(scaled))
        else:
            args["val"] = str(scaled)

    # 使用 ; 作为参数分隔符（Layer 1）
    # val 之外的字符串参数不加引号（NamedDSLParser 自动处理）
    new_args = "; ".join(
        f"{k}={v}"
        for k, v in args.items()
    )
    return f"{func_name}({new_args})"


def _parse_dsl_args(args_str: str) -> dict:
    """解析 DSL 的 named parameters（; 分隔，Layer 1）。"""
    args = {}
    current_key = None
    current_val = []
    in_quote = False
    i = 0
    while i < len(args_str):
        ch = args_str[i]
        if ch == '"':
            in_quote = not in_quote
            current_val.append(ch)
        elif ch == "=" and not in_quote:
            current_key = "".join(current_val).strip()
            current_val = []
        elif ch == ";" and not in_quote:
            if current_key is not None:
                val_str = "".join(current_val).strip()
                args[current_key] = _parse_dsl_value(val_str)
            current_key = None
            current_val = []
        else:
            current_val.append(ch)
        i += 1
    if current_key is not None:
        val_str = "".join(current_val).strip()
        args[current_key] = _parse_dsl_value(val_str)
    return args


def _parse_dsl_value(val_str: str):
    val_str = val_str.strip()
    if (val_str.startswith('"') and val_str.endswith('"')) or (
        val_str.startswith('"') and val_str.endswith('"')
    ):
        return val_str[1:-1]
    if val_str in ("true", "false"):
        return val_str == "true"
    try:
        return int(val_str)
    except ValueError:
        pass
    try:
        return float(val_str)
    except ValueError:
        pass
    return val_str


def scale_all_operators(operator_dsls: list[str], combined_scale: int) -> str:
    """对所有 DSL 语句进行 Scale 乘算，合并为 | 分隔字符串（Layer 0）。"""
    scaled = []
    for dsl in operator_dsls:
        dsl = dsl.strip()
        if not dsl:
            continue
        expressions = _split_dsl_expressions(dsl)
        for expr in expressions:
            expr = expr.strip()
            if expr:
                scaled.append(scale_dsl_operator(expr, combined_scale))
    return " | ".join(scaled)


def _split_dsl_expressions(dsl: str) -> list[str]:
    """分割 | 分隔的 DSL 表达式（Layer 0），注意括号内的 |。"""
    exprs = []
    current = []
    depth = 0
    for ch in dsl:
        if ch in "(":
            depth += 1
            current.append(ch)
        elif ch in ")":
            depth -= 1
            current.append(ch)
        elif ch == "|" and depth == 0:
            exprs.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
    remaining = "".join(current).strip()
    if remaining:
        exprs.append(remaining)
    return exprs


# ════════════════════════════════════════════════════════════════
# 3. Dynamic Dimension — Extractor Registry
# ════════════════════════════════════════════════════════════════
#
# Extractor 函数注册表：key → Callable(context, config) -> list[PipelineDimensionValue]
#   context: {"dimensions": {dim_id: PipelineDimensionValue, ...}}
#   config:  从 PipelineDimension.value_extractor_config 传入
#
# 注册方式:
#   register_extractor("scene_tags", _extract_scene_tags)

EXTRACTOR_REGISTRY: dict[str, Callable] = {}


def register_extractor(key: str, fn: Callable):
    """注册一个 Extractor 函数到全局注册表。"""
    EXTRACTOR_REGISTRY[key] = fn


def _extract_scene_tags(
    context: dict,
    config: dict,
) -> list[PipelineDimensionValue]:
    """从 context 中寻找带 tags 的维度值，提取 tags 生成派生维度值。
    
    遍历 context["dimensions"]，找到第一个有非空 tags 的维度值，
    提取其 tags 字段，过滤掉 exclude 列表中的标签，
    将每个剩余 tag 映射为一个 PipelineDimensionValue。
    
    context = {"dimensions": {"scene": PipelineDimensionValue(tags=[...]), ...}}
    config  = {"exclude": ["action_main_baiye"]}
    """
    for dim_id, dv in context["dimensions"].items():
        if dv.tags:
            exclude = set(config.get("exclude", []))
            filtered = [t for t in dv.tags if t not in exclude]
            return [
                PipelineDimensionValue(
                    id=t, name=t, description=f"场景标签: {t}",
                    scale=1.0, operator_dsl="",
                )
                for t in filtered
            ]
    return []  # 无合法派生值 → 跳过该场景组合


register_extractor("scene_tags", _extract_scene_tags)


# ════════════════════════════════════════════════════════════════
# 4. Dynamic Dimension — 笛卡尔积展开
# ════════════════════════════════════════════════════════════════

def expand_combinations(
    dimensions: list[PipelineDimension],
    registry: dict[str, Callable] | None = None,
):
    """展开所有维度组合，支持 Dynamic Dimension。
    
    1. 分离 static dims 和 dynamic dims
    2. static dims 正常笛卡尔积
    3. 对每个 static 组合，调用 Extractor 获取 dynamic 派生值
    4. static × dynamic 产生最终组合
    
    Yields:
        tuple[PipelineDimensionValue, ...]: 一个完整组合的维度值元组
    """
    registry = registry or EXTRACTOR_REGISTRY
    static_dims = [d for d in dimensions if not d.dynamic]
    dynamic_dims = [d for d in dimensions if d.dynamic]

    for static_values in itertools.product(*[d.values for d in static_dims]):
        # 构建上下文
        context = {
            "dimensions": {
                dim.id: val
                for dim, val in zip(static_dims, static_values)
            }
        }

        if not dynamic_dims:
            yield static_values
            continue

        # 解析 dynamic dims
        dynamic_value_lists = []
        skip = False
        for dyn_dim in dynamic_dims:
            if dyn_dim.value_extractor_key and dyn_dim.value_extractor_key in registry:
                derived = registry[dyn_dim.value_extractor_key](
                    context, dyn_dim.value_extractor_config,
                )
                if not derived:
                    skip = True
                    break
                dynamic_value_lists.append(derived)
            else:
                # fallback: 无注册的 extractor，用静态 values（降级为非动态）
                dynamic_value_lists.append(dyn_dim.values)

        if skip:
            continue  # 该 static 组合无合法 dynamic 派生值

        # static × dynamic 完整组合
        for dyn_values in itertools.product(*dynamic_value_lists):
            yield static_values + dyn_values


# ════════════════════════════════════════════════════════════════
# 5. LLM 调用（DeepSeek API）
# ════════════════════════════════════════════════════════════════

class LLMClient:
    """DeepSeek API 客户端（兼容 OpenAI SDK）。"""

    def __init__(self, api_key: str, model: str = "deepseek-chat"):
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.deepseek.com",
        )
        self.model = model

    def generate_event_text(
        self,
        system_prompt: str,
        user_prompt: str,
        timeout: int = 30,
    ) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.8,
            max_tokens=1024,
            timeout=timeout,
        )
        return response.choices[0].message.content.strip()


# ════════════════════════════════════════════════════════════════
# 6. Prompt 组装
# ════════════════════════════════════════════════════════════════

def build_system_prompt(cfg: EventPipelineConfig) -> str:
    """组装 System Prompt。"""
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

    return "\n".join(parts)


def build_user_prompt(
    combos: list[DimensionCombo],
    cfg: EventPipelineConfig,
    word_count_min: Optional[int] = None,
    word_count_max: Optional[int] = None,
    plugins: Optional[list[EventPromptPlugin]] = None,
) -> str:
    """组装 User Prompt（包含当前维度组合信息）。
    
    接受任意数量的 DimensionCombo（替代硬编码的 d1/dv1/d2/dv2/d3/dv3），
    自动生成维度组合描述。
    
    可通过 word_count_min/word_count_max 覆盖 cfg 中的默认长度约束，
    用于自适应重试时动态调整 LLM 看到的字数要求。

    如果传入了 plugins，会调用每个 plugin.get_prompt_fragment() 将
    插件自定义指令追加到 prompt 末尾（Hook 1）。
    """
    effective_min = word_count_min if word_count_min is not None else cfg.word_count_min
    effective_max = word_count_max if word_count_max is not None else cfg.word_count_max
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
        lines.append("""
## 选项
为以下每个选项生成描述文本（每个不超过20字）：""")
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

    return "\n".join(lines)


def parse_llm_response(response: str) -> dict:
    """解析 LLM 返回的 title/description/options 及任意额外字段。

    Hook 2 支持：插件声明的额外字段（如 failed_hint）会被自动捕获到
    parsed["_extra"] dict 中，供后续 enrich_context() 使用。

    返回 dict 结构:
        title:       事件标题
        description: 事件描述
        options:     {option_id: option_text, ...}
        _extra:      {field_name: field_value, ...}（非标准字段）
    """
    title = ""
    description = ""
    options: dict[str, str] = {}
    extra: dict[str, str] = {}
    in_options = False

    for raw_line in response.split("\n"):
        line = raw_line.strip()
        if not line:
            in_options = False
            continue

        if line.startswith("title:") or line.startswith("title："):
            sep = "：" if "：" in line else ":"
            title = line.split(sep, 1)[1].strip()
        elif line.startswith("description:") or line.startswith("description："):
            sep = "：" if "：" in line else ":"
            description = line.split(sep, 1)[1].strip()
        elif line.lower().startswith("options"):
            in_options = True
        elif in_options and ":" in line:
            # options 块内：仅缩进行才是选项；非缩进行自动退出 options 模式
            if raw_line[0] in (" ", "\t"):
                key, val = line.split(":", 1)
                options[key.strip()] = val.strip()
            else:
                # 非缩进 → 退出 options 模式，交给下方 extra 捕获
                in_options = False
                # 不 return，直接 fall through 到 extra 捕获逻辑
        if ":" in line and not in_options:
            # 捕获 title/description/options 之外的所有顶层 key: value 行
            if line.startswith("title:") or line.startswith("title："):
                continue
            if line.startswith("description:") or line.startswith("description："):
                continue
            if line.lower().startswith("options"):
                continue
            sep_idx = line.find(":")
            key = line[:sep_idx].strip()
            val = line[sep_idx + 1:].strip()
            # 过滤掉空 key 和数字开头（避免误抓非字段行）
            if key and not key[0].isdigit() and key not in ("title", "description", "options"):
                extra[key] = val

    return {"title": title, "description": description, "options": options, "_extra": extra}


def validate_response(
    parsed: dict,
    cfg: EventPipelineConfig,
    override_min: Optional[int] = None,
    override_max: Optional[int] = None,
) -> Optional[str]:
    """验证 LLM 响应。返回 None 表示通过，返回字符串表示错误信息。
    
    可通过 override_min/override_max 覆盖 cfg 中的默认长度约束，
    用于自适应重试时动态调整验证边界。
    """
    effective_min = override_min if override_min is not None else cfg.word_count_min
    effective_max = override_max if override_max is not None else cfg.word_count_max

    if not parsed["title"]:
        return "title 为空"
    if len(parsed["title"]) > 20:
        return f"title 过长 ({len(parsed['title'])}字，限制20字以内)"

    if not parsed["description"]:
        return "description 为空"

    desc_len = len(parsed["description"])
    if desc_len < effective_min:
        return f"description 过短 ({desc_len}字，要求{effective_min}-{effective_max}字)"
    if desc_len > effective_max * 1.2:
        return f"description 过长 ({desc_len}字，要求{effective_max}字以内)"

    # 如果定义了选项，验证每个非固定选项（fixed=False）都有 AI 生成的文本
    # 固定选项（fixed=True）直接使用配置文本，不校验
    ai_options = [of for of in (cfg.option_features or []) if not of.fixed]
    options = parsed.get("options", {})
    for of in ai_options:
        opt_text = options.get(of.id, "").strip()
        if not opt_text:
            return f"选项 '{of.id}' 为空"
        if len(opt_text) > 30:
            return f"选项 '{of.id}' 过长 ({len(opt_text)}字，限制30字以内)"

    return None


# ════════════════════════════════════════════════════════════════
# 7. CSV 输出（DSLParser 兼容格式）
# ════════════════════════════════════════════════════════════════
#
# 列名对齐 DSLParser 的 Dictionary key 访问：
#   random_event: uuid, title, description, context, requirements, on_enter
#   option:       results → option 的 choice_result DSL
#
# 注意：Godot 的 CSV 导入插件会将首行作为 key → 后续每行转为 Dictionary，
# 所以列顺序不重要，但列名必须与 DSLParser.parse_random_event() 中
# row.get('xxx') 使用的 key 完全一致。

CSV_HEADER = [
    "row_type",   # "random_event" | ">option"
    "uuid",
    "context",     # trigger_tags=xxx|weight=N 等 DSL 上下文
    "requirements",
    "title",       # 事件标题（event.name）
    "description", # 事件描述（event.description）
    "on_enter",    # 事件级舞台置景（我们不需要）
    "results",     # ⚡ 选项行的 DSL operator 放这里（option choice_result）
    "interruptions",
    "template",
    "provider",
]


def write_csv_header(writer):
    writer.writerow(CSV_HEADER)


def _build_context_column(tags: list[str], context_extras: dict[str, str] | None = None) -> str:
    """构建 CSV context 列字符串。

    基础格式: trigger_tags=[...]|weight=10
    Hook 3 支持: 通过 context_extras 追加 |key=value 对。
    """
    if tags:
        tags_expr = "[" + "/".join(tags) + "]"
    else:
        tags_expr = ""
    ctx = f"trigger_tags={tags_expr}|weight=10"
    if context_extras:
        for k, v in context_extras.items():
            if v:
                ctx += f"|{k}={v}"
    return ctx


def write_event_row(writer, uuid: str, title: str, description: str, tags: list[str] | None = None, requirement: str = "", context_extras: dict[str, str] | None = None):
    """写一个 random_event 行。结果 DSL 放在 option 行，不在 event 行。
    
    tags: 触发标签列表。统一使用 [tag1/tag2] 方括号 + / 分隔格式（DSL Parser 标准格式）。
    context_extras: 插件通过 enrich_context() 返回的额外 key=value 对（Hook 3）。
    """
    if tags is None:
        tags = ["bai_ye"]
    context = _build_context_column(tags, context_extras)
    writer.writerow([
        "random_event",
        uuid,
        context,  # context 列（含插件富化）
        requirement,  # requirements 列（universal requirement 或空）
        title,  # title 列
        description,  # description 列
        "",    # on_enter（无舞台置景）
        "",    # results（🈲 event 行禁用 results 列，DSLParser 会报错）
        "",    # interruptions
        "",    # template
        "",    # provider
    ])


def write_option_row(writer, description: str, result_dsl: str, requirement: str = ""):
    """写一个 option 子行。结果 DSL 放在 results 列。"""
    writer.writerow([
        ">option",  # row_type（> 前缀标记深度1，DSLParser PDA 支持）
        "",         # uuid
        "",         # context
        requirement,  # requirements 列 → ⚡ 选项级 requirement（如 poem_has）
        "",         # title
        description,  # description 列 → option 文本
        "",         # on_enter
        result_dsl, # results 列 → ⚡ DSL operator 放这里！
        "",         # interruptions
        "",         # template
        "",         # provider
    ])


def _build_option_dsl(
    scaled_dim_dsl: str,
    choice: OptionFeature,
    combined_scale: float,
    universal_result: str = "",
) -> str:
    """构建选项级结果 DSL = 维度开销 + 选项自己的 result（或 universal_result fallback）
    
    每个选项的结果由两部分组成：
    1. 维度开销（dimension costs）：所有维度值的 operator_dsl 缩放后拼接
    2. 选项自身 result（choice.result）：如果非空则叠加；如果为空则用 universal_result 兜底
    
    这样固定选项（如"冷眼旁观"）可以有自己的 result（prop_sub career_progress），
    而 AI 生成的选项可以继续用 universal_result。
    """
    # 决定使用哪个 result：per-option > universal_result > 空
    result_dsl = choice.result if choice.result else universal_result
    if not result_dsl:
        return scaled_dim_dsl

    try:
        scaled_result = scale_all_operators([result_dsl], combined_scale)
    except ValueError as e:
        print(f"  ⚠️ 选项 '{choice.id}' result DSL 缩放失败: {e}，跳过")
        return scaled_dim_dsl

    if scaled_dim_dsl:
        return f"{scaled_dim_dsl} | {scaled_result}"
    return scaled_result


def _build_option_requirement(
    choice: OptionFeature,
    failed_hint_val: str = "",
    universal_option_requirement: str = "",
) -> str:
    """构建选项级 requirement = 选项自己的 requirement（或 universal fallback）
    
    支持 {failed_hint} 模板变量替换。
    """
    req = choice.requirement if choice.requirement else universal_option_requirement
    if not req:
        return ""
    if "{failed_hint}" in req and failed_hint_val:
        req = req.replace("{failed_hint}", failed_hint_val)
    elif "{failed_hint}" in req:
        req = req.replace("{failed_hint}", "")
    return req


# ════════════════════════════════════════════════════════════════
# 8. 主流程
# ════════════════════════════════════════════════════════════════

def load_config_from_json(path: str) -> EventPipelineConfig:
    """从 JSON 文件加载配置，自动解析 TextFeature key 为完整对象。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 如果 prompt_features / fact_features / option_features
    # 是 list[str]（key 列表），从中央特征库解析为完整对象
    resolve_text_features(data)

    # 解析 narrative_constraint 中的 text feature key
    # 将 demand_context / action_style 等字段的 key 引用解析为实际文本
    library = load_text_features_library()
    for opt in data.get("option_features", []):
        nc = opt.get("narrative_constraint")
        if not nc or not isinstance(nc, dict):
            continue
        for field in ("demand_context", "action_style", "resolution_style"):
            val = nc.get(field, "")
            if not val or not isinstance(val, str):
                continue
            # 如果该值在 prompt_features 中有对应 entry，则解析为实际文本
            try:
                feature = library.resolve_prompt(val)
                nc[field] = feature.text
            except KeyError:
                pass  # 不是 key 引用，保持原值（向后兼容 inline text）

    return EventPipelineConfig.model_validate(data)


def _make_combos(
    dimensions: list[PipelineDimension],
    values: tuple[PipelineDimensionValue, ...],
) -> list[DimensionCombo]:
    """将维度定义列表和对应的值元组组装为 DimensionCombo 列表。"""
    if len(dimensions) != len(values):
        raise ValueError(
            f"dimensions ({len(dimensions)}) and values ({len(values)}) length mismatch"
        )
    return [
        DimensionCombo(dimension=dim, value=val)
        for dim, val in zip(dimensions, values)
    ]


# ════════════════════════════════════════════════════════════════
# 9. Plugin Hook 辅助函数
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


def main():
    parser = argparse.ArgumentParser(description="正交事件生成管线")
    parser.add_argument("--config", default=None, help="JSON 配置文件路径（默认使用内置示例配置）")
    parser.add_argument("--output-dir", default=None, help="输出目录（覆盖配置中的路径）")
    parser.add_argument("--dry-run", action="store_true", help="只打印 Prompt，不调 API")
    parser.add_argument("--trial", action="store_true", help="试运行：调1次API，打印所有中间产物，不保存CSV")
    parser.add_argument("--max-events", type=int, default=0, help="最多生成事件数（0=全部）")
    args = parser.parse_args()

    # ── 加载配置 ──
    if args.config:
        cfg = load_config_from_json(args.config)
    else:
        cfg = default_config()

    print(f"📖 配置: {cfg.name}")

    # ── 解析插件 ──
    plugins: list[EventPromptPlugin] = []
    if cfg.plugins:
        try:
            plugins = resolve_plugins(cfg.plugins)
            print(f"🔌 已加载插件: {[p.plugin_id for p in plugins]}")
        except KeyError as e:
            print(f"❌ 插件加载失败: {e}")
            sys.exit(1)

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
        f"{len(d.values)}" if not d.dynamic else f"({d.value_extractor_key})"
        for d in cfg.dimensions
    ]
    print(f"   组合数: {len(combinations)} ({'×'.join(dim_value_counts)})")

    if args.max_events > 0:
        combinations = combinations[: args.max_events]
        print(f"   限制生成: {len(combinations)} 个")

    # ── 准备输出 ──
    output_dir = args.output_dir or cfg.output_dir
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"{cfg.id}_events.csv")
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

    # 组装 system prompt
    system_prompt = build_system_prompt(cfg)
    print(f"\n📋 System Prompt ({len(system_prompt)} chars):")
    print("-" * 40)
    if args.trial:
        # trial 模式完整打印
        print(system_prompt)
    else:
        print(system_prompt[:600] + "..." if len(system_prompt) > 600 else system_prompt)
    print("-" * 40)

    if args.dry_run:
        print("\n🏁 Dry-run 模式，不会调用 API")
        first_values = combinations[0]
        first_combos = _make_combos(cfg.dimensions, first_values)
        user_prompt = build_user_prompt(first_combos, cfg, plugins=plugins)
        print(f"\n📋 示例 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)
        print("\n✅ Dry-run 完成")
        return

    # ════════════════════════════════════════════════════════════════
    # 8a. 试运行模式（--trial）
    # ════════════════════════════════════════════════════════════════

    if args.trial:
        print("\n🧪 试运行模式 — 将实际调用 API 1 次，不保存任何文件")

        # 只跑第一个组合
        values_tuple = combinations[0]
        combined_scale = 1.0
        scale_parts = []
        uuid_parts = [cfg.id]
        for val in values_tuple:
            combined_scale *= val.scale
            scale_parts.append(str(val.scale))
            uuid_parts.append(val.id)
        uuid = "_".join(uuid_parts).lower()

        current_combos = _make_combos(cfg.dimensions, values_tuple)

        print(f"\n📦 组合: {uuid}")
        print(f"  Scale: {'×'.join(scale_parts)} = {combined_scale}")

        # 打印维度详情
        print(f"\n📋 维度详情:")
        for combo in current_combos:
            print(f"  - {combo.dimension.name}: {combo.value.name} ({combo.value.description})")

        # ── 自适应边界收缩状态 ──
        current_min = cfg.word_count_min
        current_max = cfg.word_count_max
        SHRINK_STEP = 20
        MIN_GAP = 10

        user_prompt = build_user_prompt(
            current_combos, cfg,
            word_count_min=current_min, word_count_max=current_max,
            plugins=plugins,
        )
        print(f"\n📋 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)

        # ── API 调用（带重试 + 自适应收缩） ──
        success = False
        skip = False
        for attempt in range(cfg.max_retries + 1):
            if attempt > 0:
                print(f"\n  🔄 重试 {attempt}/{cfg.max_retries}...")
                time.sleep(1)

            try:
                print(f"\n🤖 调用 API ({cfg.api_model})...")
                response = llm.generate_event_text(system_prompt, user_prompt)
            except Exception as e:
                print(f"  ❌ API 调用失败: {e}")
                if attempt < cfg.max_retries:
                    continue
                print(f"  ⏭️ 跳过（已达最大重试次数）")
                skip = True
                break

            # 打印原始响应
            print(f"\n📨 API Raw Response ({len(response)} chars):")
            print("-" * 40)
            print(response)
            print("-" * 40)

            parsed = parse_llm_response(response)
            print(f"\n🔍 Parsed Result:")
            print(f"  title: {parsed['title']!r}")
            print(f"  description: {parsed['description']!r}")
            if parsed.get("options"):
                for k, v in parsed["options"].items():
                    print(f"  option [{k}]: {v!r}")

            error = validate_response(
                parsed, cfg,
                override_min=cfg.word_count_min, override_max=cfg.word_count_max,
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
                print(f"\n✅ 校验通过")
                title = parsed["title"]
                description = parsed["description"]

                # ── DSL 缩放 ──
                operator_dsls = [val.operator_dsl for val in values_tuple]
                try:
                    scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
                except ValueError as e:
                    print(f"  ❌ DSL 缩放失败: {e}")
                    break

                print(f"\n⚙️ 缩放后 DSL:")
                if scaled_dsl:
                    print(f"  {scaled_dsl}")
                else:
                    print(f"  (无操作)")

                # ── CSV 预览（使用与 write_event_row 一致的格式化）──
                print(f"\n📄 CSV 预览（不会写入文件）:")

                # ── Hook 3: 插件 context 富化 ──
                context_extras = _build_plugin_context_extras(
                    plugins, current_combos, cfg, parsed, response,
                    combined_scale, uuid,
                )

                # 🚨 从 context_extras 剥离 failed_hint，它只用于 option_req 模板替换
                failed_hint_val = context_extras.pop("failed_hint", "") if context_extras else ""

                if context_extras:
                    print(f"📎 插件 context 富化: {context_extras}")

                # 构建 context 列（与 write_event_row 一致的 tag 格式化）
                tags = cfg.universal_tags or ["bai_ye"]
                if tags:
                    tags_expr = "[" + "/".join(tags) + "]"
                else:
                    tags_expr = ""
                context = f"trigger_tags={tags_expr}|weight=10"
                if context_extras:
                    for k, v in context_extras.items():
                        if v:
                            context += f"|{k}={v}"

                # event 行（实际 CSV 格式）
                requirement_col = cfg.universal_requirement if cfg.universal_requirement else ""
                desc_csv = description.replace('"', '""')  # CSV 双引号转义
                desc_preview = desc_csv[:60] + "..." if len(desc_csv) > 60 else desc_csv
                print(f'  random_event,{uuid},{context},{requirement_col},"{title}","{desc_preview}",,,,,,')

                # ── option 行（per-option result/requirement + 固定选项支持）──
                # 每个选项独立计算 result DSL 和 requirement
                options = parsed.get("options", {})
                if cfg.option_features:
                    for choice in cfg.option_features:
                        # 文本：固定选项用 choice.text，AI 选项用 parsed response（有 fallback）
                        if choice.fixed:
                            opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
                        else:
                            opt_text = options.get(choice.id, "").strip()
                            if not opt_text:
                                opt_text = choice.text if choice.text.strip() else "（确认）"

                        # 结果 DSL：维度开销 + per-option result（或 universal_result fallback）
                        opt_dsl = _build_option_dsl(
                            scaled_dsl, choice, combined_scale,
                            universal_result=cfg.universal_result or "",
                        )
                        dsl_csv = opt_dsl.replace('"', '""')

                        # requirement：per-option（或 universal fallback），含模板替换
                        opt_req = _build_option_requirement(
                            choice, failed_hint_val,
                            universal_option_requirement=cfg.universal_option_requirement or "",
                        )
                        req_csv = f'"{opt_req}"' if opt_req else ''

                        print(f'  >option,,,{req_csv},"{opt_text}","{dsl_csv}",,,,')
                else:
                    # 无 option_features 时：用默认选项 + universal fallback
                    dsl_csv = scaled_dsl.replace('"', '""')
                    opt_req = _build_option_requirement(
                        OptionFeature(id="default"),
                        failed_hint_val,
                        universal_option_requirement=cfg.universal_option_requirement or "",
                    )
                    req_csv = f'"{opt_req}"' if opt_req else ''
                    print(f'  >option,,,{req_csv},"（确认）","{dsl_csv}",,,,')

                success = True
                break
            else:
                print(f"\n❌ 校验失败: {error}")
                if attempt < cfg.max_retries:
                    # ── 自适应边界收缩 ──
                    old_min, old_max = current_min, current_max
                    if "过短" in error:
                        current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                    elif "过长" in error:
                        current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                    if current_min != old_min or current_max != old_max:
                        print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                        user_prompt = build_user_prompt(
                            current_combos, cfg,
                            word_count_min=current_min, word_count_max=current_max,
                            plugins=plugins,
                        )
                    continue
                print(f"  ⏭️ 跳过（已达最大重试次数）")
                skip = True
                break

        if success:
            print(f"\n✅ 试运行完成 — API 调用成功，未保存任何文件")
        elif skip:
            print(f"\n⏭️ 试运行完成 — 已跳过，未保存任何文件")
        else:
            print(f"\n⚠️ 试运行完成 — 出现异常，未保存任何文件")
        return

    # ── 执行生成 ──
    success_count = 0
    skip_count = 0
    fail_count = 0

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        write_csv_header(writer)

        for idx, values_tuple in enumerate(combinations):
            # Scale: 所有维度值的 scale 乘积
            combined_scale = 1.0
            scale_parts = []
            uuid_parts = [cfg.id]
            for val in values_tuple:
                combined_scale *= val.scale
                scale_parts.append(str(val.scale))
                uuid_parts.append(val.id)
            uuid = "_".join(uuid_parts).lower()

            # 组装 DimensionCombo 列表
            current_combos = _make_combos(cfg.dimensions, values_tuple)

            print(f"\n[{idx + 1}/{len(combinations)}] {uuid}")
            print(f"  Scale: {'×'.join(scale_parts)} = {combined_scale}")

            # ── 自适应边界收缩状态（每组合独立重置） ──
            current_min = cfg.word_count_min
            current_max = cfg.word_count_max
            SHRINK_STEP = 20
            MIN_GAP = 10

            user_prompt = build_user_prompt(
                current_combos, cfg,
                word_count_min=current_min, word_count_max=current_max,
                plugins=plugins,
            )

            for attempt in range(cfg.max_retries + 1):
                if attempt > 0:
                    print(f"  🔄 重试 {attempt}/{cfg.max_retries}...")
                    time.sleep(1)

                try:
                    response = llm.generate_event_text(system_prompt, user_prompt)
                except Exception as e:
                    print(f"  ❌ API 调用失败: {e}")
                    if attempt < cfg.max_retries:
                        continue
                    print(f"  ⏭️ 跳过（已达最大重试次数）")
                    skip_count += 1
                    break

                parsed = parse_llm_response(response)
                # 🚨 校验始终使用原始字数边界，自适应收缩只影响 AI prompt 中的要求
                error = validate_response(
                    parsed, cfg,
                    override_min=cfg.word_count_min, override_max=cfg.word_count_max,
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
                    title = parsed["title"]
                    description = parsed["description"]
                    print(f"  ✅ title: {title}")
                    print(f"     desc: {description[:60]}...")

                    # ── DSL 缩放：收集所有维度值的 operator_dsl ──
                    operator_dsls = [val.operator_dsl for val in values_tuple]
                    try:
                        scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
                    except ValueError as e:
                        print(f"  ❌ DSL 缩放失败: {e}")
                        fail_count += 1
                        break

                    if scaled_dsl:
                        print(f"     DSL: {scaled_dsl}")
                    else:
                        print(f"     DSL: (无操作)")

                    # ── Hook 3: 插件 context 富化 ──
                    context_extras = _build_plugin_context_extras(
                        plugins, current_combos, cfg, parsed, response,
                        combined_scale, uuid,
                    )

                    # 🚨 从 context_extras 剥离 failed_hint，它只用于 option_req 模板替换
                    failed_hint_val = context_extras.pop("failed_hint", "") if context_extras else ""

                    if context_extras:
                        print(f"     📎 插件 context: {context_extras}")

                    write_event_row(
                        writer, uuid, title, description,
                        tags=cfg.universal_tags, requirement=cfg.universal_requirement,
                        context_extras=context_extras or None,
                    )

                    # ── 写选项行（per-option result/requirement + 固定选项支持）──
                    # 每个选项独立计算 result DSL 和 requirement
                    options = parsed.get("options", {})
                    if cfg.option_features:
                        for choice in cfg.option_features:
                            # 文本：固定选项用 choice.text，AI 选项用 parsed response（有 fallback）
                            if choice.fixed:
                                opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
                            else:
                                opt_text = options.get(choice.id, "").strip()
                                if not opt_text:
                                    opt_text = choice.text if choice.text.strip() else "（确认）"

                            # 结果 DSL：维度开销 + per-option result（或 universal_result fallback）
                            opt_dsl = _build_option_dsl(
                                scaled_dsl, choice, combined_scale,
                                universal_result=cfg.universal_result or "",
                            )

                            # requirement：per-option（或 universal fallback），含模板替换
                            opt_req = _build_option_requirement(
                                choice, failed_hint_val,
                                universal_option_requirement=cfg.universal_option_requirement or "",
                            )

                            write_option_row(writer, opt_text, opt_dsl, requirement=opt_req)
                            print(f"     option [{choice.id}]: {opt_text}")
                    else:
                        # 回退：没有 option_features 时用默认选项 + universal fallback
                        option_text = "（确认）"
                        opt_req = _build_option_requirement(
                            OptionFeature(id="default"),
                            failed_hint_val,
                            universal_option_requirement=cfg.universal_option_requirement or "",
                        )
                        write_option_row(writer, option_text, scaled_dsl, requirement=opt_req)
                        print(f"     option: {option_text}")
                    success_count += 1
                    break
                else:
                    print(f"  ❌ 验证失败: {error}")
                    if attempt < cfg.max_retries:
                        # ── 自适应边界收缩（阶梯增压）──
                        old_min, old_max = current_min, current_max
                        if "过短" in error:
                            current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                        elif "过长" in error:
                            current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                        if current_min != old_min or current_max != old_max:
                            print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                            user_prompt = build_user_prompt(
                                current_combos, cfg,
                                word_count_min=current_min, word_count_max=current_max,
                                plugins=plugins,
                            )
                        continue
                    print(f"  ⏭️ 跳过（已达最大重试次数）")
                    skip_count += 1
                    break

    print(f"\n{'=' * 40}")
    print(f"📊 生成完成")
    print(f"   成功: {success_count}")
    print(f"   跳过: {skip_count}")
    print(f"   失败: {fail_count}")
    print(f"   输出: {output_path}")
    print(f"{'=' * 40}")


if __name__ == "__main__":
    main()
