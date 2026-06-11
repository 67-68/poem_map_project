"""
CSV 输出 — IO 域。

列名对齐 DSLParser 的 Dictionary key 访问：
  random_event: uuid, title, description, context, requirements, on_enter
  option:       results → option 的 choice_result DSL

包含:
  CSV_HEADER, write_csv_header, _build_context_column
  write_event_row, write_option_row
  _build_option_dsl, _build_option_requirement
"""

from typing import Optional

from tools.config import DimensionCombo, EventPipelineConfig, OptionFeature
from tools.event_generator.dsl_parser import scale_all_operators

# ════════════════════════════════════════════════════════════════
# CSV 列定义
# ════════════════════════════════════════════════════════════════

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


# ════════════════════════════════════════════════════════════════
# 写行函数
# ════════════════════════════════════════════════════════════════

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


# ════════════════════════════════════════════════════════════════
# Option DSL 和 Requirement 构建
# ════════════════════════════════════════════════════════════════

def _build_option_dsl(
    combos: list[DimensionCombo],
    choice: OptionFeature,
    universal_result: str = "",
) -> str:
    """构建选项级结果 DSL = 维度开销 + 选项自己的 result（或 universal_result fallback）

    支持 accept_influence 过滤：选项可以声明只接受哪些维度的影响。

    每个选项的结果由三部分组成：
    1. 维度开销（dimension costs）：根据 accept_influence 过滤后的维度 operator_dsl 缩放后拼接
    2. 选项自身 result（choice.result）：如果非空则叠加；如果为空则用 universal_result 兜底
    3. 所有数值均按过滤后的 combined_scale 缩放

    过滤规则（choice.accept_influence）：
      - None → 接受全部维度（向后兼容）
      - []   → 拒绝所有维度影响（如"拂袖而去"类选项）
      - [id] → 只接受指定 dimension.id 的 scale + operator_dsl
    """
    # ── 根据 accept_influence 过滤维度 ──
    if choice.accept_influence is not None:
        # 白名单模式：只保留在 accept_influence 列表中的维度
        accepted = [
            c for c in combos
            if c.dimension.id in choice.accept_influence
        ]
    else:
        # None = 接受全部（向后兼容）
        accepted = combos

    # ── 计算过滤后的 combined_scale ──
    combined_scale = 1.0
    for combo in accepted:
        combined_scale *= combo.value.scale

    # ── 收集并缩放维度 DSL ──
    operator_dsls = [combo.value.operator_dsl for combo in accepted]
    try:
        scaled_dim_dsl = scale_all_operators(operator_dsls, combined_scale)
    except ValueError as e:
        print(f"  ⚠️ 维度 DSL 缩放失败: {e}，跳过")
        scaled_dim_dsl = ""

    # ── 决定使用哪个 result：per-option > universal_result > 空 ──
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
    自动清洗 failed_hint_val 中的全角标点为 ASCII 标点，避免 Linter 报错。
    """
    req = choice.requirement if choice.requirement else universal_option_requirement
    if not req:
        return ""
    if "{failed_hint}" in req and failed_hint_val:
        # 🚨 清洗全角标点 → ASCII 标点（AI 生成的 failed_hint 常带全角符号）
        sanitized = _sanitize_fullwidth_punct(failed_hint_val)
        req = req.replace("{failed_hint}", sanitized)
    elif "{failed_hint}" in req:
        req = req.replace("{failed_hint}", "")
    return req


def _sanitize_fullwidth_punct(text: str) -> str:
    """将全角标点替换为 ASCII 标点，保持 DSL 字段清洁。"""
    mapping = {
        '，': ',',
        '。': '.',
        '？': '?',
        '！': '!',
        '：': ':',
        '；': ';',
        '“': '"',
        '”': '"',
        '‘': "'",
        '’': "'",
        '【': '[',
        '】': ']',
        '（': '(',
        '）': ')',
    }
    for fw, hw in mapping.items():
        text = text.replace(fw, hw)
    return text
