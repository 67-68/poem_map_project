extends RefCounted
## Operator 预览文本格式化器 — 单一职责，干净映射
##
## 从 ActionHintBuilder 绞杀迁移而来。收敛 operator 列表 → 人类可读描述行的
## 全部逻辑，包括 PropertyOperator 的 ModifierConfig 注解集成。
##
## 🆕 支持两套 Profile：DEFAULT（完整 describe_preview）和 SIMPLE（简版）。
##
## 消费方：ActionHintFormatter, choice_result.gd, picker_item.gd,
##         sub_action_button.gd, poem_crafter.gd
##
## 依赖：BBCode（UI 契约）, ModifierConfig（修饰符注解）,
##       HintProfile, SimpleOperatorPreviewFormatter

const _ModifierConfig = preload("res://core/modifier_config.gd")
const _ModifierRegistry = preload("res://core/modifier_registry.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")
const _SimpleFormatter = preload("res://core/hints/simple_operator_preview_formatter.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 将一列 BaseOperator 转为 "• {describe_preview()}" 的字符串数组。
## 🆕 PropertyOperator 会追加修饰符注解（如 "城府 -8"）。
## 自动过滤空描述和无效 operator。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_preview(operators: Array, profile := _HintProfile.Profile.DEFAULT) -> Array[String]:
	# 🆕 SIMPLE 模式：委托 SimpleOperatorPreviewFormatter
	if profile == _HintProfile.Profile.SIMPLE:
		return _SimpleFormatter.new().build_simple_preview(operators)

	var lines: Array[String] = []
	if operators.is_empty():
		Logging.info("OperatorPreviewFormatter.build_preview: operators empty, returning []")
		return lines

	for op in operators:
		if not op or not op.has_method("describe_preview"):
			Logging.warn("OperatorPreviewFormatter.build_preview: operator 无效或无 describe_preview, op=%s" % str(op))
			continue
		var desc: String

		# 🆕 PropertyOperator: 计算修饰符调整后的最终值，注入 describe_preview
		if op is PropertyOperator:
			var pop = op as PropertyOperator
			var raw_val: int = pop.value
			var adjusted_val: int = _ModifierRegistry.get_modifier_prop_adjusted_delta(pop.property, raw_val)
			var delta: int = adjusted_val - raw_val

			# 临时替换为调整后的值，让 describe_preview 展示最终数值
			var saved_val: int = pop.value
			pop.value = adjusted_val
			desc = op.describe_preview()
			pop.value = saved_val

			if desc.is_empty():
				continue

			# 追加注解：原始值 ≠ 调整后值时
			if delta != 0:
				var annotations: Array[String] = _ModifierConfig.new().get_preview_annotations(pop.property, raw_val)
				if not annotations.is_empty():
					desc += " (%s)" % ", ".join(annotations)
				else:
					desc += " (%+d)" % delta
				Logging.info("OperatorPreviewFormatter.build_preview: prop=%s raw=%d adjusted=%d delta=%d annotations=%s" % [pop.property, raw_val, adjusted_val, delta, str(annotations)])
		else:
			desc = op.describe_preview()
			if desc.is_empty():
				continue

		lines.append("• " + desc)

	Logging.info("OperatorPreviewFormatter.build_preview: %d operators → %d lines" % [operators.size(), lines.size()])
	return lines


## 糖衣：从 ChoiceResult 解包 .operators，委托给 build_preview。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_choice_result_preview(result, profile := _HintProfile.Profile.DEFAULT) -> Array[String]:
	if not result or result.operators.is_empty():
		Logging.info("OperatorPreviewFormatter.build_choice_result_preview: result null or operators empty")
		return []
	return build_preview(result.operators, profile)
