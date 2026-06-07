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
from typing import Optional

# ── 自动将项目根目录加入 sys.path，消除 PYTHONPATH=. 的依赖 ──
_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

from openai import OpenAI

from tools.config import (
    EventPipelineConfig,
    OptionFeature,
    PipelineDimension,
    PipelineDimensionValue,
    PromptFeature,
)


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

ALLOWED_PROP_OPS = {"prop_add", "prop_sub", "prop_set"}
KNOWN_NON_PROP_OPS = {
    "emo_add", "emo_sub", "emo_set",
    "trait_add", "trait_remove",
    "flag_bool_set", "flag_str_set", "flag_str_append",
    "flag_int_set", "flag_int_append", "flag_int_reduce_if_above",
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

    if func_name in KNOWN_NON_PROP_OPS:
        raise ValueError(
            f"不支持的 operator 类型: '{func_name}'。"
            f"当前只支持 PropertyOperator ({', '.join(sorted(ALLOWED_PROP_OPS))})"
        )
    if func_name not in ALLOWED_PROP_OPS:
        raise ValueError(
            f"未知 operator: '{func_name}'。"
            f"允许的 PropertyOperator: {', '.join(sorted(ALLOWED_PROP_OPS))}"
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
# 3. LLM 调用（DeepSeek API）
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
# 4. Prompt 组装
# ════════════════════════════════════════════════════════════════

def build_system_prompt(cfg: EventPipelineConfig) -> str:
    """组装 System Prompt。"""
    parts = ["你是唐朝官场叙事设计师。你只负责生成事件文本，不要输出任何额外内容。"]

    if cfg.background_context.strip():
        parts.append(f"\n## 世界观背景\n{cfg.background_context.strip()}")

    if cfg.ai_persona.strip():
        parts.append(f"\n## 你的角色\n{cfg.ai_persona.strip()}")

    if cfg.prompt_features:
        parts.append("\n## 风格要求")
        for pf in cfg.prompt_features:
            if pf.text.strip():
                parts.append(f"- {pf.text.strip()}")

    return "\n".join(parts)


def build_user_prompt(
    d1: PipelineDimension, dv1: PipelineDimensionValue,
    d2: PipelineDimension, dv2: PipelineDimensionValue,
    d3: PipelineDimension, dv3: PipelineDimensionValue,
    cfg: EventPipelineConfig,
    word_count_min: Optional[int] = None,
    word_count_max: Optional[int] = None,
) -> str:
    """组装 User Prompt（包含当前维度组合信息）。
    
    可通过 word_count_min/word_count_max 覆盖 cfg 中的默认长度约束，
    用于自适应重试时动态调整 LLM 看到的字数要求。
    """
    effective_min = word_count_min if word_count_min is not None else cfg.word_count_min
    effective_max = word_count_max if word_count_max is not None else cfg.word_count_max
    lines = [f"""请为以下维度组合生成一个拜谒事件：

## 维度组合
1. {d1.name}: {dv1.name}（{dv1.description}）
2. {d2.name}: {dv2.name}（{dv2.description}）
3. {d3.name}: {dv3.name}（{dv3.description}）

## 输出要求
- title：15字以内的事件标题
- description：{effective_min}-{effective_max}字的事件描述
- 使用全角中文标点"""]

    # 如果有选项定义，注入到 prompt 中
    if cfg.option_features:
        lines.append("""
## 选项
为以下每个选项生成描述文本（每个不超过20字）：""")
        for of in cfg.option_features:
            if of.text.strip():
                lines.append(f"- {of.id}: {of.text.strip()}")
        # 用实际的 option id 生成格式示例
        opt_examples = "\n".join(f" {of.id}: <{of.id}文本>" for of in cfg.option_features)
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

    return "\n".join(lines)


def parse_llm_response(response: str) -> dict:
    """解析 LLM 返回的 title/description/options。"""
    title = ""
    description = ""
    options: dict[str, str] = {}
    in_options = False

    for line in response.split("\n"):
        line = line.strip()
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
            # 解析 " option_id: option text"
            key, val = line.split(":", 1)
            options[key.strip()] = val.strip()

    return {"title": title, "description": description, "options": options}


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

    # 如果定义了选项，验证每个选项都有文本
    options = parsed.get("options", {})
    for of in cfg.option_features:
        opt_text = options.get(of.id, "").strip()
        if not opt_text:
            return f"选项 '{of.id}' 为空"
        if len(opt_text) > 30:
            return f"选项 '{of.id}' 过长 ({len(opt_text)}字，限制30字以内)"

    return None


# ════════════════════════════════════════════════════════════════
# 5. CSV 输出（DSLParser 兼容格式）
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


def write_event_row(writer, uuid: str, title: str, description: str, tags: list[str] | None = None, requirement: str = ""):
    """写一个 random_event 行。结果 DSL 放在 option 行，不在 event 行。
    
    tags: 触发标签列表。单标签输出 trigger_tags=tag，多标签输出 trigger_tags=[tag1/tag2]。
    """
    if tags is None:
        tags = ["bai_ye"]
    # 多标签用方括号 + / 分隔（DSL Parser 标准格式），单标签兼容旧格式
    if len(tags) > 1:
        tags_expr = "[" + "/".join(tags) + "]"
    elif len(tags) == 1:
        tags_expr = tags[0]
    else:
        tags_expr = ""
    writer.writerow([
        "random_event",
        uuid,
        f"trigger_tags={tags_expr}|weight=10",  # context 列
        requirement,  # requirements 列（universal requirement 或空）
        title,  # title 列
        description,  # description 列
        "",    # on_enter（无舞台置景）
        "",    # results（🈲 event 行禁用 results 列，DSLParser 会报错）
        "",    # interruptions
        "",    # template
        "",    # provider
    ])


def write_option_row(writer, description: str, result_dsl: str):
    """写一个 option 子行。结果 DSL 放在 results 列。"""
    writer.writerow([
        ">option",  # row_type（> 前缀标记深度1，DSLParser PDA 支持）
        "",         # uuid
        "",         # context
        "",         # requirements
        "",         # title
        description,  # description 列 → option 文本
        "",         # on_enter
        result_dsl, # results 列 → ⚡ DSL operator 放这里！
        "",         # interruptions
        "",         # template
        "",         # provider
    ])


# ════════════════════════════════════════════════════════════════
# 6. 主流程
# ════════════════════════════════════════════════════════════════

def load_config_from_json(path: str) -> EventPipelineConfig:
    """从 JSON 文件加载配置。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return EventPipelineConfig.model_validate(data)


def main():
    parser = argparse.ArgumentParser(description="正交事件生成管线")
    parser.add_argument("--config", default=None, help="JSON 配置文件路径（默认使用内置示例配置）")
    parser.add_argument("--output-dir", default=None, help="输出目录（覆盖配置中的路径）")
    parser.add_argument("--dry-run", action="store_true", help="只打印 Prompt，不调 API")
    parser.add_argument("--max-events", type=int, default=0, help="最多生成事件数（0=全部）")
    args = parser.parse_args()

    # ── 加载配置 ──
    if args.config:
        cfg = load_config_from_json(args.config)
    else:
        cfg = default_config()

    print(f"📖 配置: {cfg.name}")

    # 检查必须有 3 个维度
    if len(cfg.dimensions) != 3:
        print(f"❌ 配置必须有恰好 3 个维度，当前有 {len(cfg.dimensions)} 个")
        sys.exit(1)

    d1, d2, d3 = cfg.dimensions

    # ── 展开所有组合 ──
    combinations = list(itertools.product(d1.values, d2.values, d3.values))
    print(f"   组合数: {len(combinations)} ({len(d1.values)}×{len(d2.values)}×{len(d3.values)})")

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
        else:
            print("❌ 请设置环境变量 DEEPSEEK_API_KEY")
            print("   export DEEPSEEK_API_KEY='sk-xxx'")
            sys.exit(1)

    llm = LLMClient(api_key=api_key or "dry-run", model=cfg.api_model)

    # 组装 system prompt
    system_prompt = build_system_prompt(cfg)
    print(f"\n📋 System Prompt ({len(system_prompt)} chars):")
    print("-" * 40)
    print(system_prompt[:600] + "..." if len(system_prompt) > 600 else system_prompt)
    print("-" * 40)

    if args.dry_run:
        print("\n🏁 Dry-run 模式，不会调用 API")
        dv1, dv2, dv3 = combinations[0]
        user_prompt = build_user_prompt(d1, dv1, d2, dv2, d3, dv3, cfg)
        print(f"\n📋 示例 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)
        print("\n✅ Dry-run 完成")
        return

    # ── 执行生成 ──
    success_count = 0
    skip_count = 0
    fail_count = 0

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        write_csv_header(writer)

        for idx, (dv1, dv2, dv3) in enumerate(combinations):
            combined_scale = dv1.scale * dv2.scale * dv3.scale
            uuid = f"{cfg.id}_{dv1.id}_{dv2.id}_{dv3.id}".lower()

            print(f"\n[{idx + 1}/{len(combinations)}] {uuid}")
            print(f"  Scale: {dv1.scale}×{dv2.scale}×{dv3.scale} = {combined_scale}")

            # ── 自适应边界收缩状态（每组合独立重置） ──
            current_min = cfg.word_count_min
            current_max = cfg.word_count_max
            SHRINK_STEP = 20
            MIN_GAP = 10

            user_prompt = build_user_prompt(
                d1, dv1, d2, dv2, d3, dv3, cfg,
                word_count_min=current_min, word_count_max=current_max,
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
                error = validate_response(
                    parsed, cfg,
                    override_min=current_min, override_max=current_max,
                )

                if error is None:
                    title = parsed["title"]
                    description = parsed["description"]
                    print(f"  ✅ title: {title}")
                    print(f"     desc: {description[:60]}...")

                    operator_dsls = [dv1.operator_dsl, dv2.operator_dsl, dv3.operator_dsl]
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

                    # ★ 追加 universal_result（也参与 Scale 缩放）
                    final_dsl = scaled_dsl
                    if cfg.universal_result:
                        try:
                            scaled_universal = scale_all_operators(
                                [cfg.universal_result], combined_scale
                            )
                        except ValueError as e:
                            print(f"  ❌ universal_result DSL 缩放失败: {e}")
                            fail_count += 1
                            break
                        if final_dsl:
                            final_dsl = f"{final_dsl} | {scaled_universal}"
                        else:
                            final_dsl = scaled_universal
                        print(f"     +universal(scaled={combined_scale}): {scaled_universal}")

                    write_event_row(writer, uuid, title, description, tags=cfg.universal_tags, requirement=cfg.universal_requirement)

                    # ── 写选项行 ──
                    options = parsed.get("options", {})
                    if cfg.option_features and options:
                        for of in cfg.option_features:
                            opt_text = options.get(of.id, "").strip()
                            if not opt_text:
                                opt_text = "（确认）"
                            write_option_row(writer, opt_text, final_dsl)
                            print(f"     option [{of.id}]: {opt_text}")
                    else:
                        # 回退：没有 option_features 时用默认选项
                        option_text = "（确认）"
                        write_option_row(writer, option_text, final_dsl)
                        print(f"     option: {option_text}")
                    success_count += 1
                    break
                else:
                    print(f"  ❌ 验证失败: {error}")
                    if attempt < cfg.max_retries:
                        # ── 自适应边界收缩（阶梯增压）──
                        old_min, old_max = current_min, current_max
                        if "过短" in error:
                            # 太短 → 硬抬下限，逼 LLM 写更长（80→100→120）
                            current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                        elif "过长" in error:
                            # 太长 → 硬压上限（200→180→160）
                            current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                        if current_min != old_min or current_max != old_max:
                            print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                            user_prompt = build_user_prompt(
                                d1, dv1, d2, dv2, d3, dv3, cfg,
                                word_count_min=current_min, word_count_max=current_max,
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
