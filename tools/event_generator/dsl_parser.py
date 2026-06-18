"""
DSL 缩放器 — 纯函数模块，无外部项目依赖。

包含:
  SCALABLE_OPS, KNOWN_NON_PROP_OPS
  scale_dsl_operator, _parse_dsl_args, _parse_dsl_value
  scale_all_operators, _split_dsl_expressions
"""

SCALABLE_OPS = {"prop_add", "prop_sub", "prop_set", "emo_add", "emo_sub"}
KNOWN_NON_PROP_OPS = {
    "emo_set",
    "trait_add", "trait_remove",
    "flag_bool_set", "flag_str_set", "flag_str_append",
    "flag_int_set", "flag_int_append", "flag_int_reduce_if_above",
    "use_template",
    "imagery_add",                # 🆕 意象获取操作符（非缩放，直接 emit EventBus signal）
    "leverage_add",               # 🆕 把柄获取操作符（非缩放，不可缩放的 narratival 操作）
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

    # use_template 与 KNOWN_NON_PROP_OPS 中的 operator 不需要缩放，直接原样返回
    # 这些 operator 没有数值 val 参数（如 imagery_add, trait_add, flag_* 等）
    if func_name == "use_template" or func_name in KNOWN_NON_PROP_OPS:
        return dsl
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
        # 🚨 强制 round() 到最接近整数 — Godot 侧 get_int_param() 做 to_int() 截断，
        # 且属性系统值必须为整数。使用 round() 而非 int() 避免 IEEE 754 浮点精度损失，
        # 例如 3 * 0.95 = 2.8499999999999996 → round() → 3 (而非 int 截断为 2)
        args["val"] = str(round(scaled))

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
