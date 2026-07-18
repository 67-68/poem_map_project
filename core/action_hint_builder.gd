class_name ActionHintBuilder extends RefCounted
## 🤓☝️ 绞杀者代理 — 所有业务已迁移至 core/hints/ 下的专职 Formatter
##
## 保持对下游 UI 组件的绝对向后兼容。所有方法现为转发代理。
## 消费方零改动。
##
## 🆕 所有公开 API 增加 profile 参数（默认 DEFAULT），以支持 SIMPLE 提示模式。

const _TraitHintFormatter = preload("res://core/hints/trait_hint_formatter.gd")
const _ModifierHintFormatter = preload("res://core/hints/modifier_hint_formatter.gd")
const _OperatorPreviewFormatter = preload("res://core/hints/operator_preview_formatter.gd")
const _ActionHintFormatter = preload("res://core/hints/action_hint_formatter.gd")
const _HintContext = preload("res://core/hints/hint_context.gd")
const _ActionHint = preload("res://core/model/action_hint.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")


# ── 接口 2：operator 列表 → 描述行 ────────────────────────

## 🤓☝️ 绞杀者转发：业务已正式迁移至 OperatorPreviewFormatter
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_operator_preview(operators: Array, profile := _HintProfile.Profile.DEFAULT) -> Array[String]:
	return _OperatorPreviewFormatter.new().build_preview(operators, profile)


## 🤓☝️ 绞杀者转发：业务已正式迁移至 OperatorPreviewFormatter
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_choice_result_preview(result: ChoiceResult, profile := _HintProfile.Profile.DEFAULT) -> Array[String]:
	return _OperatorPreviewFormatter.new().build_choice_result_preview(result, profile)


## 🆕 计算当前 action 的识别 tags 并用 is_action_repeated 检查是否重复。
## SceneAction 用 main_tag + action_tags；普通 Action 用 action_tags。
func _check_repeated(action: Action) -> bool:
	if not action:
		return false
	var tags: Array[String] = []
	if action is SceneAction:
		var sa := action as SceneAction
		if not sa.main_tag.is_empty():
			tags.append(sa.main_tag)
	tags.append_array(action.action_tags)
	return PlayerState.is_action_repeated(tags)


# ── 接口 1：Action → {narrative, vector} ──────────────────

## 🤓☝️ 绞杀者转发：业务已正式迁移至 ActionHintFormatter
## 内部自动构建 HintContext（含 _check_repeated + defer 状态 + AP hint 等），
## 保持对 consumers 的向后兼容。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_action_hint(action: Action, is_locked: bool, profile := _HintProfile.Profile.DEFAULT):
	if not action:
		Logging.err("ActionHintBuilder.new().build_action_hint: action is null")
		var _empty = _ActionHint.new()
		_empty.narrative = tr("CODE_ACTION_HINT_FORMATTER_D8D33EAD9A")
		return _empty
	
	# 构建 HintContext（自动填充运行时状态）
	var ctx = _HintContext.new().populate(action)
	ctx.is_repeated = _check_repeated(action)
	
	# 临时设置 PlayerState._is_repeated_action（用于 describe_preview 展示调整值）
	var _saved_is_repeated = PlayerState._is_repeated_action
	PlayerState._is_repeated_action = ctx.is_repeated
	
	var result = _ActionHintFormatter.new().build_action_hint(action, is_locked, ctx, profile)
	
	# 恢复
	PlayerState._is_repeated_action = _saved_is_repeated
	
	return result


# ── 接口 2（子行动专用）：Action + archetype operators → 预览字符串 ──

## 🤓☝️ 绞杀者转发：业务已正式迁移至 ActionHintFormatter
## 内部自动构建 HintContext，保持对 consumers 的向后兼容。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_sub_action_preview(sub_action: Action, success_ops: Array = [], fail_ops: Array = [], parent_day_consumed: float = 0.0, profile := _HintProfile.Profile.DEFAULT, is_locked: bool = false, lock_reason: String = ""):
	if not sub_action:
		Logging.err("ActionHintBuilder.new().build_sub_action_preview: sub_action is null")
		var _empty = _ActionHint.new()
		return _empty
	
	# 构建 HintContext（自动填充运行时状态）
	var ctx = _HintContext.new().populate(sub_action)
	ctx.is_repeated = _check_repeated(sub_action)
	
	# 临时设置 PlayerState._is_repeated_action（用于 describe_preview 展示调整值）
	var _saved_is_repeated = PlayerState._is_repeated_action
	PlayerState._is_repeated_action = ctx.is_repeated
	
	var result = _ActionHintFormatter.new().build_sub_action_preview(sub_action, ctx, success_ops, fail_ops, parent_day_consumed, profile, is_locked, lock_reason)
	
	# 恢复
	PlayerState._is_repeated_action = _saved_is_repeated
	
	return result


# ── 接口 3（Trait 专用）：Trait → hint 文本 ──

## 为 TraitDemonstrator 的 hover tooltip 构建完整 hint 文本。
## 🤓☝️ 绞杀者转发：业务已正式迁移至 TraitHintFormatter
## @param trait_data: 目标 Trait 资源（或 Imaginary，因为 Imaginary extends Trait）
## @return 格式化后的 BBCode 字符串，无有效信息时返回 ""
func build_trait_hint(trait_data: Trait) -> String:
	# 🤓☝️ 绞杀者转发：业务已正式迁移至 TraitHintFormatter
	return _TraitHintFormatter.new().build_hint(trait_data)


# ════════════════════════════════════════════════════════════════
# 🆕 修饰符属性效果展示（城府/才华/定力 — S型阻尼）
# ════════════════════════════════════════════════════════════════

## 生成修饰符属性效果文本（用于 UI hover/面板展示）。
## 🤓☝️ 绞杀者转发：业务已正式迁移至 ModifierHintFormatter
## @return BBCode 格式化字符串，无有效效果时返回 ""
func build_modifier_effects_hint() -> String:
	return _ModifierHintFormatter.new().build_effects_hint()
