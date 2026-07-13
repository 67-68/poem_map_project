extends RefCounted
## Trait 与意象（Imaginary）领域的提示构建器 — 单一职责，纯净映射
##
## 从 ActionHintBuilder 绞杀迁移而来。所有 Trait/Imaginary hover 提示文本
## 构建逻辑收敛于此。
##
## 消费方：trait_demonstrator.gd, dump_trait_hints.gd, vtest_trait_hints.gd
##
## 依赖：BBCode（UI 契约）, Database（get_property / get_trait）

const _BBCode = preload("res://ui/utils/bbcode.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 为 TraitDemonstrator 的 hover tooltip 构建完整 hint 文本。
## 包含：name → description → 效果清单 → 持续时间 → hover_narrative。
## 🆕 Imaginary 分支：显示 level/get_hint/trait_effect_operations，不显示 buffer/prop/时间惩罚/持续区。
## @param trait_data: 目标 Trait 资源（或 Imaginary，因为 Imaginary extends Trait）
## @return 格式化后的 BBCode 字符串，无有效信息时返回 ""
static func build_hint(trait_data) -> String:
	if not trait_data:
		Logging.err("TraitHintFormatter.build_hint: trait_data is null, check upstream caller!")
		return ""

	var lines: Array[String] = []

	# ── 名称行 ──
	var display_name = trait_data.name if not trait_data.name.is_empty() else "（未知道）"
	lines.append("【%s】" % display_name)
	Logging.info("TraitHintFormatter.build_hint: trait='%s', is_imaginary=%s" % [display_name, str(trait_data is Imaginary)])

	# 🆕 Imaginary 分支
	if trait_data is Imaginary:
		return _build_imaginary_hint(trait_data as Imaginary, lines, display_name)

	# ── 以下为普通 Trait 的完整逻辑 ──
	return _build_standard_trait_hint(trait_data, lines, display_name)


# ════════════════════════════════════════════════════════════════
# 内部：Imaginary 分支
# ════════════════════════════════════════════════════════════════

static func _build_imaginary_hint(imag: Imaginary, lines: Array[String], display_name: String) -> String:
	# 等级 + description（如果有）
	var level_label = "Lv%d 意象" % imag.level
	if not imag.description.is_empty():
		level_label += " — %s" % imag.description
	lines.append(_BBCode.color(level_label, _BBCode.COLOR_IMAGINARY_GOLD if imag.level >= 3 else (_BBCode.COLOR_IMAGINARY_WHITE if imag.level == 2 else _BBCode.COLOR_IMAGINARY_GRAY)))
	Logging.info("TraitHintFormatter._build_imaginary_hint: level=%d, has_desc=%s" % [imag.level, str(not imag.description.is_empty())])

	# get_hint（获取时的叙事文本）
	if not imag.get_hint.is_empty():
		lines.append("")
		lines.append(imag.get_hint)
		Logging.info("TraitHintFormatter._build_imaginary_hint: get_hint present (%d chars)" % imag.get_hint.length())

	# 效果区
	lines.append("")
	lines.append(_BBCode.effect_section())
	if not imag.trait_effect_operations.is_empty():
		for op in imag.trait_effect_operations:
			if not op:
				continue
			var desc: String = op.describe_preview() if op.has_method("describe_preview") else ""
			if not desc.is_empty():
				lines.append("• 每旬：%s" % desc)
		Logging.info("TraitHintFormatter._build_imaginary_hint: trait_effect_operations → %d lines" % imag.trait_effect_operations.size())
	else:
		lines.append("（持有期无副作用）")
		Logging.info("TraitHintFormatter._build_imaginary_hint: 无 trait_effect_operations")

	# 持续时间
	if imag.duration_xun > 0:
		lines.append("")
		lines.append(_BBCode.duration_section())
		var already = imag.lasting_xun
		var remaining = max(0, imag.duration_xun - already)
		if not imag.expiry_trait.is_empty():
			var expiry_name = _get_trait_display_name(imag.expiry_trait)
			lines.append("• %d旬后转化为「%s」（已持续%d旬）" % [remaining, expiry_name, already])
		else:
			lines.append("• %d旬后自动移除（已持续%d旬）" % [remaining, already])
		Logging.info("TraitHintFormatter._build_imaginary_hint: duration=%d, lasting=%d" % [imag.duration_xun, already])

	# hover_narrative
	if not imag.hover_narrative.is_empty():
		lines.append("")
		lines.append(imag.hover_narrative)
		Logging.info("TraitHintFormatter._build_imaginary_hint: hover_narrative present (%d chars)" % imag.hover_narrative.length())

	var result = "\n".join(lines)
	Logging.info("TraitHintFormatter._build_imaginary_hint: done for '%s', result=%d chars" % [display_name, result.length()])
	return result


# ════════════════════════════════════════════════════════════════
# 内部：普通 Trait 分支
# ════════════════════════════════════════════════════════════════

static func _build_standard_trait_hint(t, lines: Array[String], display_name: String) -> String:
	# ── 描述行 ──
	if not t.description.is_empty():
		lines.append(t.description)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: description present (%d chars)" % t.description.length())

	# ── 效果区 ──
	var effect_lines: Array[String] = []

	# 1. trait_effect_operations（每旬结算）
	if not t.trait_effect_operations.is_empty():
		for op in t.trait_effect_operations:
			if not op:
				continue
			var desc: String = op.describe_preview() if op.has_method("describe_preview") else ""
			if not desc.is_empty():
				effect_lines.append("• 每旬：%s" % desc)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: trait_effect_operations → %d effect lines" % effect_lines.size())

	# 2. buffer_to_prop（属性倍率修正）
	if t.buffer_to_prop and not t.buffer_to_prop.operators.is_empty():
		for mul_op in t.buffer_to_prop.operators:
			if not mul_op or mul_op.key.is_empty():
				continue
			var prop_display = _get_prop_display_name(mul_op.key)
			var mode_str = _mul_operator_mode_string(mul_op.operator)
			effect_lines.append("• %s %s ×%.1f" % [prop_display, mode_str, mul_op.value])
		Logging.info("TraitHintFormatter._build_standard_trait_hint: buffer_to_prop → %d ops" % t.buffer_to_prop.operators.size())

	# 3. buffer_to_region（区域倍率修正）
	if t.buffer_to_region and not t.buffer_to_region.operators.is_empty():
		for mul_op in t.buffer_to_region.operators:
			if not mul_op or mul_op.key.is_empty():
				continue
			var prop_display = _get_prop_display_name(mul_op.key)
			var mode_str = _mul_operator_mode_string(mul_op.operator)
			effect_lines.append("• %s（区域）%s ×%.1f" % [prop_display, mode_str, mul_op.value])
		Logging.info("TraitHintFormatter._build_standard_trait_hint: buffer_to_region → %d ops" % t.buffer_to_region.operators.size())

	# 4. time_penalty（全局行动天数惩罚）
	if t.time_penalty > 0:
		effect_lines.append("• 所有行动 +%d天" % t.time_penalty)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: time_penalty=+%d" % t.time_penalty)

	# 5. conditional_time_penalties（条件天数惩罚）
	if not t.conditional_time_penalties.is_empty():
		for ctp in t.conditional_time_penalties:
			if not ctp or ctp.penalty_days <= 0:
				continue
			if ctp.add_to_all:
				var desc_suffix = "（%s）" % ctp.description if not ctp.description.is_empty() else ""
				effect_lines.append("• 所有行动：+%d天%s" % [ctp.penalty_days, desc_suffix])
			else:
				var label = ctp.description if not ctp.description.is_empty() else ctp.action_tag_match
				effect_lines.append("• %s：+%d天" % [label, ctp.penalty_days])
		Logging.info("TraitHintFormatter._build_standard_trait_hint: conditional_time_penalties → %d entries" % t.conditional_time_penalties.size())

	# 6. ap_penalty（AP 上限削减）
	if t.ap_penalty != 0:
		effect_lines.append("• 行动力上限 %+d" % t.ap_penalty)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: ap_penalty=%+d" % t.ap_penalty)

	# 效果区输出
	lines.append(_BBCode.effect_section())
	if effect_lines.is_empty():
		lines.append("（无特殊效果）")
		Logging.info("TraitHintFormatter._build_standard_trait_hint: 无任何活跃效果字段")
	else:
		lines.append_array(effect_lines)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: 效果区 %d lines" % effect_lines.size())

	# ── 持续区 ──
	if t.duration_xun > 0:
		lines.append(_BBCode.duration_section())
		var already = t.lasting_xun
		var remaining = max(0, t.duration_xun - already)
		if not t.expiry_trait.is_empty():
			var expiry_name = _get_trait_display_name(t.expiry_trait)
			lines.append("• %d旬后转化为「%s」（已持续%d旬）" % [remaining, expiry_name, already])
			Logging.info("TraitHintFormatter._build_standard_trait_hint: duration=%d, expiry_trait='%s', lasting=%d" % [t.duration_xun, t.expiry_trait, t.lasting_xun])
		else:
			lines.append("• %d旬后自动移除（已持续%d旬）" % [remaining, already])
			Logging.info("TraitHintFormatter._build_standard_trait_hint: duration=%d, no expiry, lasting=%d" % [t.duration_xun, t.lasting_xun])

	# ── hover_narrative（获取途径等硬编码叙事文本，末尾）──
	if not t.hover_narrative.is_empty():
		lines.append("")
		lines.append(t.hover_narrative)
		Logging.info("TraitHintFormatter._build_standard_trait_hint: hover_narrative present (%d chars)" % t.hover_narrative.length())

	var result = "\n".join(lines)
	Logging.info("TraitHintFormatter._build_standard_trait_hint: done for '%s', result=%d chars, %d lines" % [display_name, result.length(), lines.size()])
	return result


# ════════════════════════════════════════════════════════════════
# 辅助函数
# ════════════════════════════════════════════════════════════════

## MultiplyOperator.operator 枚举 → 中文展示文本
static func _mul_operator_mode_string(op_enum: int) -> String:
	match op_enum:
		MultiplyOperator.MUL_OPERATOR.POSITIVE_ONLY:
			return "正面效果"
		MultiplyOperator.MUL_OPERATOR.NEGATIVE_ONLY:
			return "负面效果"
		MultiplyOperator.MUL_OPERATOR.BOTH:
			return "所有变动"
		_:
			Logging.warn("TraitHintFormatter._mul_operator_mode_string: 未知 op_enum=%d" % op_enum)
			return "变动"


## prop key → display_name，复用 Database.get_property().get_display_name()
static func _get_prop_display_name(prop_key: String) -> String:
	var prop = Database.get_property(prop_key)
	if prop:
		var dn = prop.get_display_name()
		if not dn.is_empty():
			return dn
	return prop_key


## trait_uuid → display_name，复用 Database.get_trait
static func _get_trait_display_name(trait_uuid: String) -> String:
	var t = Database.get_trait(trait_uuid)
	if t and not t.name.is_empty():
		return t.name
	return trait_uuid
