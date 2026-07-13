extends RefCounted
## 修饰符属性效果展示（城府/才华/定力 — S型阻尼）
##
## 从 ActionHintBuilder 绞杀迁移而来。生成修饰符属性效果文本，
## 用于 UI hover/面板展示。
##
## 依赖：BBCode（UI 契约）, ModifierConfig（效果配置表）

const _BBCode = preload("res://ui/utils/bbcode.gd")
const _ModifierConfig = preload("res://core/modifier_config.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 生成修饰符属性效果文本（用于 UI hover/面板展示）。
## @return BBCode 格式化字符串，无有效效果时返回 ""
static func build_effects_hint() -> String:
	var lines: Array[String] = []

	# 按 source_prop 分组展示
	var grouped: Dictionary = {}
	for effect in _ModifierConfig.MODIFIER_EFFECTS:
		var sp: String = effect.source_prop
		if not grouped.has(sp):
			grouped[sp] = []
		grouped[sp].append(effect)

	var prop_display_names := {
		"astuteness": "城府",
		"talent": "才华",
		"composure": "定力",
	}

	for source_prop in ["astuteness", "talent", "composure"]:
		var mod_val: int = _ModifierConfig.get_modifier_val(source_prop)
		if mod_val <= 0:
			continue

		var effects: Array = grouped.get(source_prop, [])
		if effects.is_empty():
			continue

		var display_name = prop_display_names.get(source_prop, source_prop)
		lines.append(_BBCode.mod_prop_header(display_name, mod_val))

		for eff in effects:
			var pct: float = _ModifierConfig.get_pct_for_display(source_prop, eff.max_limit, eff.half_point)
			var pct_int: int = int(pct * 100.0)

			var desc: String = eff.hint_text.replace("{mod_val}", str(mod_val)).replace("{pct}", str(pct_int) + "%")
			lines.append("  • %s" % desc)

		lines.append("")

	if lines.is_empty():
		return ""

	# 去掉末尾空行
	while lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.pop_back()

	Logging.info("ModifierHintFormatter.build_effects_hint: %d lines generated" % lines.size())
	return "\n".join(lines)
