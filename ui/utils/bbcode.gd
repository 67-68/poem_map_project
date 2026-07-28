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
	return color_size(TranslationServer.translate("CODE_BBCODE_E18ED459F1") % prob, COLOR_MUTED, 13)


## 时间消耗行 — 灰色 13px
static func time_cost_line(cost_detail: String) -> String:
	return color_size(TranslationServer.translate("CODE_BBCODE_2FB48A6C2F") % cost_detail, COLOR_MUTED, 13)


## 时间范围行 — 灰色 13px，如「⏱ 耗时 5天 ～ 8天」
static func time_span_line(min_detail: String, max_detail: String) -> String:
	return color_size(TranslationServer.translate("CODE_BBCODE_EAE89B1E8B") % [min_detail, max_detail], COLOR_MUTED, 13)


## 前提 section 标题 — 灰色 13px 的「━━━ 前提 ━━━」
static func req_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_B9C206F855"))


## 结果 section 标题 — 灰色 13px 的「━━━ 结果 ━━━」
static func result_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_A95858CB62"))


## 失败 section 标题 — 灰色 13px 的「━━━ 失败 ━━━」
static func fail_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_ECCD17434E"))


## 持续 section 标题 — 灰色 13px 的「━━━ 持续 ━━━」
static func duration_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_9B4C29C5F6"))


## 效果 section 标题 — 灰色 13px 的「━━━ 效果 ━━━」
static func effect_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_F17C55154D"))


## 消失后 section 标题 — 灰色 13px 的「━━━ 消失后 ━━━」
static func loss_section() -> String:
	return hint_section(TranslationServer.translate("CODE_BBCODE_LOSS_SECTION"))


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
	return color(TranslationServer.translate("CODE_BBCODE_4F9DFB5567"), COLOR_WARNING)


## Defer 行动名行 — info 色，如「⏳ 驱散云雾」，可附带描述
static func defer_what_line(name: String, desc: String) -> String:
	var line := color_size("⏳ %s" % name, COLOR_INFO, 13)
	if not desc.is_empty():
		line += "\n" + color(TranslationServer.translate(desc), COLOR_MUTED)
	return line


## Defer 等待行 — info 色，如「⏳ 等待 3/5 旬」
static func defer_waiting(remaining: int, total: int, is_failing: bool) -> String:
	var c := COLOR_DANGER if is_failing else COLOR_INFO
	return color_size(TranslationServer.translate("CODE_BBCODE_01EEBE490C") % [remaining, total], c, 13)


## Defer 消耗行 — 每旬消耗
static func defer_cost(cost_parts: Array[String], is_failing: bool) -> String:
	var c := COLOR_DANGER if is_failing else COLOR_INFO
	return color_size("  每旬: %s" % ", ".join(cost_parts), c, 13)


## Defer 未激活行 — 展示未来 Defer 信息
static func defer_pending(xun_val: int) -> String:
	return color_size(TranslationServer.translate("CODE_BBCODE_C1E9B923E7") % xun_val, COLOR_MUTED, 13)


## Defer 失败后果行
static func defer_failing(fb_msg: String) -> String:
	return color(TranslationServer.translate("CODE_BBCODE_85C48E965A") % fb_msg, COLOR_DANGER)


## AP 削减提示行
static func ap_hint_line(text: String, color_hex: String) -> String:
	return color_size(text, color_hex, 13)


## 异地行动提示 — place 色
static func place_hint(place_name: String) -> String:
	return color_size(TranslationServer.translate("CODE_BBCODE_7117939F67") % place_name, COLOR_PLACE, 13)


## SIMPLE profile 异地行动提示 — place 色，简版「赴%s」
static func simple_place_hint(place_name: String) -> String:
	return color_size(TranslationServer.translate("CODE_BBCODE_7F0CC21586") % place_name, COLOR_PLACE, 13)


## 时间不足行
static func time_insufficient(cost_detail: String, remaining_days: int) -> String:
	return color(TranslationServer.translate("CODE_BBCODE_FA6F390B49") % [cost_detail, remaining_days], COLOR_DANGER)


## 子行动预览头部
static func preview_header() -> String:
	return TranslationServer.translate("CODE_BBCODE_A8DE0CCC7F")


## 子行动概率行（非 BBCode 纯文本）
static func sub_prob_line(prob: int) -> String:
	return TranslationServer.translate("CODE_BBCODE_BB986C4BCD") % prob


## 子行动成功效果标题
static func success_header() -> String:
	return TranslationServer.translate("CODE_BBCODE_0C8ABDDBB1")


## 子行动失败效果标题
static func fail_header() -> String:
	return TranslationServer.translate("CODE_BBCODE_8B1564F7D5")


## Imaginary 等级标签
static func imaginary_level(level: int, description: String) -> String:
	var base := TranslationServer.translate("CODE_TRAIT_HINT_FORMATTER_D8663A39B4") % level
	if not description.is_empty():
		base += " — %s" % description
	return color(base, COLOR_IMAGINARY_GOLD if level >= 3 else (COLOR_IMAGINARY_WHITE if level == 2 else COLOR_IMAGINARY_GRAY))


## 修饰符属性标题行（粗体）
static func mod_prop_header(display_name: String, val: int) -> String:
	return bold("%s (%d)" % [display_name, val])


# ════════════════════════════════════════════════════════════════
# SIMPLE profile 标签方法 — 无 • / 无 、前缀，空格分割
# ════════════════════════════════════════════════════════════════

## SIMPLE profile: 可行性标签 — "可行：渺茫"
## @param text: 裸标签文本（如 "渺茫"、"不足"、"未知"）
static func simple_feasibility_label(text: String) -> String:
	return TranslationServer.translate("CODE_BBCODE_1726614F08") + text if not text.is_empty() else TranslationServer.translate("CODE_BBCODE_2C5F8B18A4")


## SIMPLE profile: 消耗标签 — "耗：⏱3天 赴洛阳"
static func simple_cost_label(lines: Array[String]) -> String:
	var joined = " ".join(lines)
	return TranslationServer.translate("CODE_BBCODE_703E75446D") + joined if not joined.is_empty() else TranslationServer.translate("CODE_NPC_ACTION_BUTTON_7CA5205A5B")


## SIMPLE profile: 产出标签 — "产：健康↑ 金钱↑↑"
static func simple_output_label(lines: Array[String]) -> String:
	var joined = " ".join(lines)
	return TranslationServer.translate("CODE_BBCODE_B082955862") + joined if not joined.is_empty() else TranslationServer.translate("CODE_NPC_ACTION_BUTTON_0F9928F317")


## SIMPLE profile: 风险标签 — "险：后果难料…"
static func simple_risk_label(lines: Array[String]) -> String:
	var joined = " ".join(lines)
	return TranslationServer.translate("CODE_NPC_ACTION_BUTTON_4D7C36AA23") + joined if not joined.is_empty() else TranslationServer.translate("CODE_NPC_ACTION_BUTTON_4D7C36AA23")


## SIMPLE profile: 锁定标签 — 红色 "锁定：条件不足"
static func simple_lock_label(reason: String) -> String:
	var text = TranslationServer.translate("CODE_BBCODE_0D46022B0E") + reason if not reason.is_empty() else TranslationServer.translate("CODE_BBCODE_E9BCBC440D")
	return color(text, COLOR_DANGER)


## SIMPLE profile: 需求标签 — "求：需 50 健 需 貂皮大衣"
## 当 lines 为空时返回空字符串（UI 层据此隐藏 label）
static func simple_requirement_label(lines: Array[String]) -> String:
	var joined = " ".join(lines)
	return TranslationServer.translate("CODE_SIMPLE_REQUIREMENT_LABEL_PREFIX") + joined if not joined.is_empty() else ""
