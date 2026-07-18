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
func build_effects_hint() -> String:
	Logging.info("ModifierHintFormatter.build_effects_hint: start")
	var lines: Array[String] = []

	# 按 source_prop 分组展示
	var grouped: Dictionary = {}
	for effect in _ModifierConfig.MODIFIER_EFFECTS:
		var sp: String = effect.source_prop
		if not grouped.has(sp):
			grouped[sp] = []
		grouped[sp].append(effect)
	Logging.debug("ModifierHintFormatter.build_effects_hint: grouped %d source_props" % grouped.size())

	var prop_display_names := {
		"astuteness": tr("TRES_ASTUTENESS_NAME_0"),
		"talent": tr("CODE_MODIFIER_HINT_FORMATTER_0288A3D9E2"),
		"composure": tr("TRES_COMPOSURE_NAME_0"),
	}

	var empty_count := 0
	for source_prop in ["astuteness", "talent", "composure"]:
		var mod_val: int = _ModifierConfig.get_modifier_val(source_prop)
		if mod_val <= 0:
			Logging.debug("ModifierHintFormatter.build_effects_hint: '%s' mod_val=%d ≤ 0, skipping" % [source_prop, mod_val])
			empty_count += 1
			continue

		var effects: Array = grouped.get(source_prop, [])
		if effects.is_empty():
			Logging.debug("ModifierHintFormatter.build_effects_hint: '%s' no effects in config, skipping" % source_prop)
			empty_count += 1
			continue

		var display_name = prop_display_names.get(source_prop, source_prop)
		lines.append(_BBCode.mod_prop_header(display_name, mod_val))

		for eff in effects:
			var pct: float = _ModifierConfig.get_pct_for_display(source_prop, eff.max_limit, eff.half_point)
			var pct_int: int = int(pct * 100.0)

			var desc: String = eff.hint_text.replace("{mod_val}", str(mod_val)).replace("{pct}", str(pct_int) + "%")
			lines.append("  • %s" % desc)
			Logging.debug("ModifierHintFormatter.build_effects_hint: '%s' effect target='%s' dir=%s → pct=%d%%" % [source_prop, eff.target_prop, eff.direction, pct_int])

		lines.append("")

	if lines.is_empty():
		Logging.info("ModifierHintFormatter.build_effects_hint: all %d props empty/zero, returning empty" % empty_count)
		return ""

	# 去掉末尾空行
	while lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.pop_back()

	Logging.info("ModifierHintFormatter.build_effects_hint: %d lines generated" % lines.size())
	return "\n".join(lines)


## 🆕 从 active_modifiers 注册表读取单属性的 modifier 效果，生成 BBCode 文本。
## 用于属性标签 hover 提示中的「buff 效果翻译」部分。
##
## @param source_prop: 修饰符属性名（"astuteness"/"talent"/"composure"）
## @return BBCode 行数组，无效果时返回空数组
func build_single_prop_effects(source_prop: String) -> Array[String]:
	Logging.info("ModifierHintFormatter.build_single_prop_effects: start for '%s'" % source_prop)
	var lines: Array[String] = []

	var mod_val: int = _ModifierConfig.get_modifier_val(source_prop)
	# 🆕 即使 mod_val=0 也展示效果清单（pct=0%），让玩家知道该属性将来做什么

	var source_key := "modifier_prop:" + source_prop
	var matched_effects: Array[Dictionary] = []

	# 🆕 从 active_modifiers 注册表读取已注册的效果条目
	var total_modifier_entries := 0
	for entry in GameSave.data.active_modifiers:
		if entry.get("type") == "modifier_prop_effect":
			total_modifier_entries += 1
		if entry.get("type") != "modifier_prop_effect":
			continue
		if entry.get("source") != source_key:
			continue
		matched_effects.append(entry)

	Logging.info("ModifierHintFormatter.build_single_prop_effects: active_modifiers 共 %d 条 modifier_prop_effect, 其中 '%s' 匹配 %d 条" % [total_modifier_entries, source_prop, matched_effects.size()])

	if matched_effects.is_empty():
		Logging.info("ModifierHintFormatter.build_single_prop_effects: '%s' 在 active_modifiers 中无注册条目，返回空" % source_prop)
		return lines

	var prop_display_names := {
		"astuteness": tr("TRES_ASTUTENESS_NAME_0"),
		"talent": tr("CODE_MODIFIER_HINT_FORMATTER_0288A3D9E2"),
		"composure": tr("TRES_COMPOSURE_NAME_0"),
	}
	var display_name = prop_display_names.get(source_prop, source_prop)

	# 标题行
	lines.append(_BBCode.mod_prop_header(display_name, mod_val))
	Logging.debug("ModifierHintFormatter.build_single_prop_effects: header='%s (%d)'" % [display_name, mod_val])

	for entry in matched_effects:
		var max_limit: float = entry.get("max_limit", 0.0)
		var half_point: float = entry.get("half_point", 0.0)
		var pct: float = _ModifierConfig.get_pct_for_display(source_prop, max_limit, half_point)
		var pct_int: int = int(pct * 100.0)

		var hint_text: String = entry.get("hint_text", "")
		var desc: String = hint_text.replace("{mod_val}", str(mod_val)).replace("{pct}", str(pct_int) + "%")
		lines.append("  • %s" % desc)
		Logging.debug("ModifierHintFormatter.build_single_prop_effects: entry target='%s' dir=%s sign=%s faction='%s' → pct=%d%%" % [entry.get("target_prop", ""), entry.get("direction", ""), entry.get("delta_sign", ""), entry.get("faction_filter", ""), pct_int])

	Logging.info("ModifierHintFormatter.build_single_prop_effects: '%s' → %d lines (mod_val=%d, %d entries)" % [source_prop, lines.size(), mod_val, matched_effects.size()])
	return lines
