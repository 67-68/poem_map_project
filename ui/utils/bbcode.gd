class_name BBCode extends RefCounted
## 严格的 UI 格式化契约 — 核心业务逻辑层禁止出现任何原生 BBCode 标签 🤓☝️
##
## 所有颜色/排版常量收敛于此，消费方通过静态方法调用获得统一格式。
##
## 用法:
##   BBCode.color("解锁!", BBCode.COLOR_SUCCESS)
##   BBCode.size("概率: 80%", 13)
##   BBCode.hint_section("━━━ 效果 ━━━")
##   BBCode.warning("⚠ 重复行动…")
##   BBCode.probability_line(80)
##   BBCode.time_cost_line("3天")
##   BBCode.place_hint("洛阳")


# ════════════════════════════════════════════════════════════════
# 颜色常量（六位 hex，不含 # 前缀）
# ════════════════════════════════════════════════════════════════

const COLOR_WARNING  := "#ccaa44"   # ⚠ 警告/重复行动
const COLOR_DANGER   := "#cc6666"   # 🔒 锁定/失败/危险
const COLOR_SUCCESS  := "#66cc66"   # ✓ 成功/增益
const COLOR_INFO     := "#5588ff"   # ℹ 信息/Defer 等待
const COLOR_MUTED    := "gray"      # 次要/灰色信息
const COLOR_PLACE    := "#88aaff"   # 📍 异地行动提示
const COLOR_IMAGINARY_GOLD := "#e6c840"  # 意象等级 3 金色
const COLOR_IMAGINARY_WHITE := "#f2f2e6" # 意象等级 2 白色
const COLOR_IMAGINARY_GRAY  := "#8c8c8c" # 意象等级 1 灰色


# ════════════════════════════════════════════════════════════════
# 基础排版方法
# ════════════════════════════════════════════════════════════════

## 颜色包裹 — text 会被 [color=...] 包裹
static func color(text: String, hex_color: String) -> String:
	return "[color=%s]%s[/color]" % [hex_color, text]


## 字号包裹
static func size(text: String, font_size: int = 13) -> String:
	return "[font_size=%d]%s[/font_size]" % [font_size, text]


## 颜色 + 字号组合
static func color_size(text: String, hex_color: String, font_size: int = 13) -> String:
	return color(size(text, font_size), hex_color)


## 粗体
static func bold(text: String) -> String:
	return "[b]%s[/b]" % text


## 标准提示区块标题行（灰色 13px），如「━━━ 效果 ━━━」
static func hint_section(title: String) -> String:
	return color_size(title, COLOR_MUTED, 13)


## 概率行 — 灰色 13px，仅当 prob < 100 时显示
static func prob_line(prob: int) -> String:
	return color_size("概率: %d%%" % prob, COLOR_MUTED, 13)


## 时间消耗行 — 灰色 13px
static func time_cost_line(cost_detail: String) -> String:
	return color_size("⏱ 耗时 %s" % cost_detail, COLOR_MUTED, 13)


## 时间范围行 — 灰色 13px，如「⏱ 耗时 5天 ～ 8天」
static func time_span_line(min_detail: String, max_detail: String) -> String:
	return color_size("⏱ 耗时 %s ～ %s" % [min_detail, max_detail], COLOR_MUTED, 13)


## 前提 section 标题 — 灰色 13px 的「━━━ 前提 ━━━」
static func req_section() -> String:
	return hint_section("━━━ 前提 ━━━")


## 结果 section 标题 — 灰色 13px 的「━━━ 结果 ━━━」
static func result_section() -> String:
	return hint_section("━━━ 结果 ━━━")


## 失败 section 标题 — 灰色 13px 的「━━━ 失败 ━━━」
static func fail_section() -> String:
	return hint_section("━━━ 失败 ━━━")


## 持续 section 标题 — 灰色 13px 的「━━━ 持续 ━━━」
static func duration_section() -> String:
	return hint_section("━━━ 持续 ━━━")


## 效果 section 标题 — 灰色 13px 的「━━━ 效果 ━━━」
static func effect_section() -> String:
	return hint_section("━━━ 效果 ━━━")


# ════════════════════════════════════════════════════════════════
# 语义化包装方法
# ════════════════════════════════════════════════════════════════

## 锁定叙事前缀 — 🔒 + danger 色
static func locked_prefix(hint: String) -> String:
	return color("🔒 %s" % hint, COLOR_DANGER)


## 成功叙事前缀 — ✓ + success 色
static func success_prefix(hint: String) -> String:
	return color("✓ %s" % hint, COLOR_SUCCESS)


## 重复行动警告 — ⚠ + warning 色
static func repeated_warning() -> String:
	return color("⚠ 重复行动 — 收益减少20%%，消耗增加20%%", COLOR_WARNING)


## Defer 等待行 — info 色，如「⏳ 等待 3/5 旬」
static func defer_waiting(remaining: int, total: int, is_failing: bool) -> String:
	var c := COLOR_DANGER if is_failing else COLOR_INFO
	return color_size("⏳ 等待 %d/%d 旬" % [remaining, total], c, 13)


## Defer 消耗行 — 每旬消耗
static func defer_cost(cost_parts: Array[String], is_failing: bool) -> String:
	var c := COLOR_DANGER if is_failing else COLOR_INFO
	return color_size("  每旬: %s" % ", ".join(cost_parts), c, 13)


## Defer 未激活行 — 展示未来 Defer 信息
static func defer_pending(xun_val: int) -> String:
	return color_size("⏳ 执行后等待 %d 旬" % xun_val, COLOR_MUTED, 13)


## Defer 失败后果行
static func defer_failing(fb_msg: String) -> String:
	return color("⚠ 资源不足，%s" % fb_msg, COLOR_DANGER)


## AP 削减提示行
static func ap_hint_line(text: String, color_hex: String) -> String:
	return color_size(text, color_hex, 13)


## 异地行动提示 — place 色
static func place_hint(place_name: String) -> String:
	return color_size("📍 自动消耗1天前往%s" % place_name, COLOR_PLACE, 13)


## 时间不足行
static func time_insufficient(cost_detail: String, remaining_days: int) -> String:
	return color("⏱ 耗时 %s — 时间不足（剩余%d天）" % [cost_detail, remaining_days], COLOR_DANGER)


## 子行动预览头部
static func preview_header() -> String:
	return "[预览]"


## 子行动概率行（非 BBCode 纯文本）
static func sub_prob_line(prob: int) -> String:
	return "概率: %d%%成功，" % prob


## 子行动成功效果标题
static func success_header() -> String:
	return "[成功效果]:"


## 子行动失败效果标题
static func fail_header() -> String:
	return "[失败效果]:"


## Imaginary 等级标签
static func imaginary_level(level: int, description: String) -> String:
	var base := "Lv%d 意象" % level
	if not description.is_empty():
		base += " — %s" % description
	return color(base, COLOR_IMAGINARY_GOLD if level >= 3 else (COLOR_IMAGINARY_WHITE if level == 2 else COLOR_IMAGINARY_GRAY))


## 修饰符属性标题行（粗体）
static func mod_prop_header(display_name: String, val: int) -> String:
	return bold("%s (%d)" % [display_name, val])
