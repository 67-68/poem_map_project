extends RefCounted
## Action 与 SubAction 提示文本构建器 + 🆕 属性标签 hover
##
## 从 ActionHintBuilder 绞杀迁移而来。收敛 build_action_hint 和
## build_sub_action_preview 的全部逻辑。
##
## 核心设计：通过 HintContext 替代对 PlayerState / ActionManager / SurvivalManager
## 的直接 autoload 依赖。HintContext 由调用方预组装传入。
##
## 🆕 返回类型: build_action_hint → ActionHint 结构化对象（含四模块 + narrative + vector）
## 🆕 支持两套 Profile：DEFAULT（详版）和 SIMPLE（简版）
## 🆕 build_prop_hint(prop_key) — 属性标签 hover 提示（含 modifier 效果翻译）

const _BBCode = preload("res://ui/utils/bbcode.gd")
const _OPFormatter = preload("res://core/hints/operator_preview_formatter.gd")
const _ActionHint = preload("res://core/model/action_hint.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")
const _ModifierHintFormatter = preload("res://core/hints/modifier_hint_formatter.gd")


# ════════════════════════════════════════════════════════════════
# SIMPLE profile feasibility mapping: level prefix -> named_amount value
const _SIMPLE_FEASIBILITY_VALUES: Dictionary = {
	"xxs": 20,
	"xs":  30,
	"s":   50,
	"ms":  60,
	"m":   80,
	"l":  100,
}

# SIMPLE profile feasibility labels (2-character Chinese)
var _SIMPLE_FEASIBILITY_TEXT: Dictionary = {
	"xxs": tr("CODE_ACTION_HINT_FORMATTER_B3A5CEA754"),
	"xs":  tr("CODE_ACTION_HINT_FORMATTER_0094D495FD"),
	"s":   tr("CODE_ACTION_HINT_FORMATTER_F30071FA50"),
	"ms":  tr("CODE_ACTION_HINT_FORMATTER_5B7E1F080F"),
	"m":   tr("CODE_ACTION_HINT_FORMATTER_2508765118"),
	"l":   tr("CODE_ACTION_HINT_FORMATTER_23FB1D474F"),
}


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 为行动按钮的主 hover popup 构建叙事层 + 向量层文本。
## @param action: 目标 Action 资源
## @param is_locked: 是否处于灰化锁定态（影响叙事层前缀）
## @param ctx: 预组装的 HintContext（由调用方从运行时状态填充）
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
## @return ActionHint 结构化对象（含 narrative + feasibility/cost/output/risk/other 模块 + vector）
func build_action_hint(action, is_locked: bool, ctx, profile := _HintProfile.Profile.DEFAULT):
	if not action:
		Logging.err("ActionHintFormatter.build_action_hint: action is null")
		return { "narrative": tr("CODE_ACTION_HINT_FORMATTER_D8D33EAD9A"), "vector": "" }

	var hint = _ActionHint.new()
	var _is_repeated = ctx.is_repeated

	# ── 叙事层（profile 不影响，保持原样）──
	hint.narrative = action.description if not action.description.is_empty() else tr("CODE_ACTION_HINT_FORMATTER_BF10FD5886")

	if is_locked and not action.dynamic_failed_hint.is_empty():
		hint.narrative = _BBCode.locked_prefix(action.dynamic_failed_hint) + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: locked narrative for '%s'" % action.name)
	elif not is_locked and not action.success_hint.is_empty():
		hint.narrative = _BBCode.success_prefix(action.success_hint) + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: unlocked with success_hint for '%s'" % action.name)

	if _is_repeated and not is_locked and GameState.current_era != "755_backhome":
		hint.narrative = _BBCode.repeated_warning() + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: 重复行动警告追加到叙事层 for '%s'" % action.name)

	# ── 模块组装（extracted，profile 透传）──
	_assemble_feasibility_module(action, hint.feasibility, profile)      # 🆕 pass profile
	_assemble_cost_module(action, ctx, hint.cost, profile)
	_assemble_output_module(action, _is_repeated, hint.output, profile)
	_assemble_risk_module(action, hint.risk, profile)

	Logging.info("ActionHintFormatter.build_action_hint: done for '%s', narrative=%d chars, vector=%d chars" % [action.name, hint.narrative.length(), hint.vector.length()])
	return hint


## 为 sub-action picker tooltip 构建预览文本。
## 现在返回 ActionHint 结构化对象，consumer 通过 .vector 获取旧格式的完整文本。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
func build_sub_action_preview(sub_action, ctx, success_ops: Array = [], fail_ops: Array = [], parent_day_consumed: float = 0.0, profile := _HintProfile.Profile.DEFAULT, is_locked: bool = false, lock_reason: String = ""):
	if not sub_action:
		Logging.err("ActionHintFormatter.build_sub_action_preview: sub_action is null")
		return { "narrative": "", "vector": "" }

	var hint = _ActionHint.new()
	hint.narrative = _BBCode.preview_header()

	var prob: int = sub_action.get_possibility_int()
	if profile == _HintProfile.Profile.SIMPLE:
		# SIMPLE: 存裸标签文本，供 _build_simple_labels 使用
		var best_level := ""
		var best_distance := 999999
		for level in _SIMPLE_FEASIBILITY_VALUES:
			var val = _SIMPLE_FEASIBILITY_VALUES[level]
			var dist = absi(prob - val)
			if dist < best_distance or (dist == best_distance and level < best_level):
				best_distance = dist
				best_level = level
		var label = _SIMPLE_FEASIBILITY_TEXT.get(best_level, tr("CODE_POEM_CRAFTING_CALCULATOR_4D8C1C5B42"))
		hint.feasibility.append(label)
		Logging.info("ActionHintFormatter.build_sub_action_preview(SIMPLE): sub_action='%s' prob=%d → %s" % [sub_action.name, prob, label])
	else:
		hint.feasibility.title = tr("CODE_ACTION_HINT_FORMATTER_C5ECC3C43D")
		hint.feasibility.append(_BBCode.sub_prob_line(prob))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' possibility=%d" % [sub_action.name, prob])

	var _is_repeated = ctx.is_repeated

	if _is_repeated:
		hint.feasibility.append(_BBCode.repeated_warning())

	# 🆕 异地行动提示 → cost（SIMPLE profile 使用简版「赴%s」）
	var _place_name = sub_action.get_required_place_name()
	if not _place_name.is_empty():
		var _req_place = sub_action.required_place
		var _cur_place_str = ctx.stay_place
		if not _cur_place_str.is_empty() and _req_place != _cur_place_str:
			if profile == _HintProfile.Profile.SIMPLE:
				hint.cost.append(_BBCode.simple_place_hint(_place_name))
				Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' 异地行动提示(SIMPLE) → 赴%s" % [sub_action.name, _place_name])
			else:
				hint.cost.append(_BBCode.place_hint(_place_name))
				Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' 异地行动提示 → %s" % [sub_action.name, _place_name])

	# ── 时间消耗行 → cost ──
	var eff_day = ActionManager.effective_day_consumed(sub_action, parent_day_consumed)
	if eff_day > 0:
		var cost_detail = ActionManager.format_time_detail(eff_day)
		var cost_total = ActionManager.get_action_day_cost(sub_action, parent_day_consumed)
		var current_time = ctx.current_time
		if current_time < cost_total:
			hint.cost.append(_BBCode.time_insufficient(cost_detail, current_time))
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' 时间不足 (need=%d, have=%d)" % [sub_action.name, cost_total, current_time])
		else:
			hint.cost.append(tr("CODE_BBCODE_2FB48A6C2F") % cost_detail)
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' time ok (need=%d, have=%d)" % [sub_action.name, cost_total, current_time])

	# 🆕 cost archetype operators（花钱/耗材等）→ cost 模块
	var cost_arch = Database.get_archetype_by_uuid(sub_action.uuid, "cost")
	if cost_arch and not cost_arch.operators.is_empty():
		var cost_lines = _OPFormatter.new().build_preview(cost_arch.operators, profile)
		if not cost_lines.is_empty():
			hint.cost.append_array(cost_lines)
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' cost archetype (%d ops → %d lines) → 已合并" % [sub_action.name, cost_arch.operators.size(), cost_lines.size()])

	if not hint.cost.is_empty() and hint.cost.title.is_empty():
		hint.cost.title = tr("CODE_ACTION_HINT_FORMATTER_C611D44ACD")

	# ── 成功效果 → output ──
	var success_descs: Array[String] = []
	if not success_ops.is_empty():
		success_descs.append_array(_OPFormatter.new().build_preview(success_ops, profile))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' archetype success_ops (%d ops) → 已合并" % [sub_action.name, success_ops.size()])
	if sub_action.action_results and not sub_action.action_results.is_empty():
		var tres_lines = _OPFormatter.new().build_preview(sub_action.action_results, profile)
		if not tres_lines.is_empty():
			success_descs.append_array(tres_lines)
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' .tres action_results (%d ops → %d descs) → 已合并" % [sub_action.name, sub_action.action_results.size(), tres_lines.size()])

	if success_descs.is_empty():
		if profile == _HintProfile.Profile.SIMPLE:
			hint.output.append(tr("CODE_ACTION_HINT_FORMATTER_213F14AD2B"))
		else:
			hint.output.append(_BBCode.success_header() + tr("CODE_ACTION_HINT_FORMATTER_OUTCOME_UNKNOWN"))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' success 无有效 operator，使用 fallback" % sub_action.name)
	else:
		if profile == _HintProfile.Profile.SIMPLE:
			hint.output.append_array(success_descs)
		else:
			hint.output.title = tr("CODE_ACTION_HINT_FORMATTER_7D295E9E17")
			hint.output.append(_BBCode.success_header())
			hint.output.append_array(success_descs)
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' success preview: %d lines" % [sub_action.name, success_descs.size()])

	# ── 失败效果 → risk（仅使用 failure archetype，不 fallback 到 .tres failed_result）──
	var fail_descs: Array[String] = []
	if not fail_ops.is_empty():
		fail_descs.append_array(_OPFormatter.new().build_preview(fail_ops, profile))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' archetype fail_ops (%d ops → %d lines) → 已合并" % [sub_action.name, fail_ops.size(), fail_descs.size()])

	if fail_descs.is_empty():
		if profile == _HintProfile.Profile.SIMPLE:
			hint.risk.append(tr("CODE_ACTION_HINT_FORMATTER_400F1725F5"))
		else:
			hint.risk.append(_BBCode.fail_header() + tr("CODE_ACTION_HINT_FORMATTER_CONSEQ_UNKNOWN"))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' fail 无有效 operator，使用 fallback" % sub_action.name)
	else:
		if profile == _HintProfile.Profile.SIMPLE:
			hint.risk.append_array(fail_descs)
		else:
			hint.risk.title = tr("CODE_ACTION_HINT_FORMATTER_AED2FEF5AE")
			hint.risk.append(_BBCode.fail_header())
			hint.risk.append_array(fail_descs)
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' fail preview: %d lines" % [sub_action.name, fail_descs.size()])

	if profile == _HintProfile.Profile.SIMPLE:
		hint._requirements_lines = _collect_simple_requirements(sub_action)
		_build_simple_labels(hint, is_locked, lock_reason)

	Logging.info("ActionHintFormatter.build_sub_action_preview: done for '%s', vector=%d chars" % [sub_action.name, hint.vector.length()])
	return hint


## 🆕 为属性标签 hover 构建提示文本。
## narrative = Property.description（属性介绍）
## vector = modifier 效果翻译（仅城府/才华/定力有，其他属性为空）
##
## @param prop_key: 属性名（"health"/"money"/"talent"/"astuteness"/"composure" 等）
## @return ActionHint 结构化对象
func build_prop_hint(prop_key: String):
	var hint = _ActionHint.new()

	# ── narrative: 属性描述 ──
	var prop: Property = Database.get_property(prop_key)
	if prop and not prop.description.is_empty():
		hint.narrative = tr(prop.description)
		Logging.info("ActionHintFormatter.build_prop_hint: '%s' description=%d chars" % [prop_key, prop.description.length()])
	else:
		var display_name := prop.get_display_name() if prop else prop_key
		hint.narrative = "（%s）" % display_name
		Logging.info("ActionHintFormatter.build_prop_hint: '%s' 无 description，使用降级文本" % prop_key)

	# ── vector: modifier 效果翻译 ──
	var modifier_props := ["astuteness", "talent", "composure"]
	if prop_key in modifier_props:
		var effect_lines: Array[String] = _ModifierHintFormatter.new().build_single_prop_effects(prop_key)
		if not effect_lines.is_empty():
			hint.vector = "\n".join(effect_lines)
			Logging.info("ActionHintFormatter.build_prop_hint: '%s' modifier effects → %d lines" % [prop_key, effect_lines.size()])
		else:
			Logging.info("ActionHintFormatter.build_prop_hint: '%s' modifier prop but no registered effects" % prop_key)
	else:
		Logging.info("ActionHintFormatter.build_prop_hint: '%s' 非 modifier 属性，无 vector" % prop_key)

	Logging.info("ActionHintFormatter.build_prop_hint: done for '%s', narrative=%d chars, vector=%d chars" % [prop_key, hint.narrative.length(), hint.vector.length()])
	return hint


# ════════════════════════════════════════════════════════════════
# Extracted 模块组装函数（building_action_hint 专用）
# ════════════════════════════════════════════════════════════════

func _assemble_feasibility_module(action, feas_mod, profile) -> void:
	var prob: int = action.get_possibility_int()

	if profile == _HintProfile.Profile.SIMPLE:
		# Find the closest named amount level to prob
		var best_level := ""
		var best_distance := 999999
		for level in _SIMPLE_FEASIBILITY_VALUES:
			var val = _SIMPLE_FEASIBILITY_VALUES[level]
			var dist = absi(prob - val)
			if dist < best_distance or (dist == best_distance and level < best_level):
				best_distance = dist
				best_level = level

		if not best_level.is_empty():
			var label = _SIMPLE_FEASIBILITY_TEXT.get(best_level, "")
			if not label.is_empty():
				# Store raw label word; BBCode.simple_feasibility_label will add "可行：" prefix
				feas_mod.append(label)
				Logging.info("ActionHintFormatter._assemble_feasibility_module(SIMPLE): prob=%d → %s (%s)" % [prob, best_level, label])
		return

	# DEFAULT profile – original logic unchanged
	if prob < 100:
		feas_mod.title = tr("CODE_ACTION_HINT_FORMATTER_C5ECC3C43D")
		feas_mod.append(tr("CODE_BBCODE_E18ED459F1") % prob)
		Logging.info("ActionHintFormatter._assemble_feasibility_module: possibility=%d for '%s'" % [prob, action.name])


func _assemble_cost_module(action, ctx, cost_mod, profile) -> void:
	# Defer 信息
	_defer_info_lines(action, ctx, cost_mod)

	# AP 削减提示
	if not ctx.ap_hint.is_empty():
		cost_mod.append(_BBCode.ap_hint_line(ctx.ap_hint, ctx.ap_hint_color))
		Logging.info("ActionHintFormatter._assemble_cost_module: AP hint='%s' for '%s'" % [ctx.ap_hint, action.name])

	# 时间消耗行
	_time_cost_lines(action, cost_mod)

	# 前提
	if not action.aciton_requirements.is_empty():
		cost_mod.append(_BBCode.req_section())
		for req in action.aciton_requirements:
			var desc = req.describe_requirement() if req.has_method("describe_requirement") else ""
			if not desc.is_empty():
				cost_mod.append("• " + desc)
		Logging.info("ActionHintFormatter._assemble_cost_module: %d requirements for '%s'" % [action.aciton_requirements.size(), action.name])

	# 如果 cost 模块非空，设标题
	if not cost_mod.is_empty() and cost_mod.title.is_empty():
		cost_mod.title = tr("CODE_ACTION_HINT_FORMATTER_C611D44ACD")


func _assemble_output_module(action, is_repeated: bool, output_mod, profile) -> void:
	if not action.action_results.is_empty():
		output_mod.title = tr("CODE_ACTION_HINT_FORMATTER_7D295E9E17")
		var success_lines = _OPFormatter.new().build_preview(action.action_results, profile)
		output_mod.append_array(success_lines)
		Logging.info("ActionHintFormatter._assemble_output_module: %d action_results → %d lines for '%s'" % [action.action_results.size(), success_lines.size(), action.name])
	else:
		var archetype_lines = _build_archetype_qualitative_preview(action, is_repeated, profile)
		if not archetype_lines.is_empty():
			output_mod.title = tr("CODE_ACTION_HINT_FORMATTER_7D295E9E17")
			output_mod.append_array(archetype_lines)
			Logging.info("ActionHintFormatter._assemble_output_module: archetype 定性预览 %d lines for '%s'" % [archetype_lines.size(), action.name])


func _assemble_risk_module(action, risk_mod, profile) -> void:
	if action.failed_result and not action.failed_result.operators.is_empty():
		risk_mod.title = tr("CODE_ACTION_HINT_FORMATTER_AED2FEF5AE")
		var fail_lines = _OPFormatter.new().build_choice_result_preview(action.failed_result, profile)
		risk_mod.append_array(fail_lines)
		Logging.info("ActionHintFormatter._assemble_risk_module: %d failed_result ops → %d lines for '%s'" % [action.failed_result.operators.size(), fail_lines.size(), action.name])


# ════════════════════════════════════════════════════════════════
# 内部：Defer 信息行
# ════════════════════════════════════════════════════════════════

func _find_deferring_sub_action(action, ctx):
	if action.defer_config and not action.defer_config.xun_defered.is_empty():
		var ds = ctx.get_defer_state(action.uuid)
		if ds.get("is_deferring", false):
			return action
	for sub_uuid in action.sub_actions:
		var sub = Database.get_action(sub_uuid) as Action
		if sub and sub.defer_config and not sub.defer_config.xun_defered.is_empty():
			var ds = ctx.get_defer_state(sub_uuid)
			if ds.get("is_deferring", false):
				return sub
	return null


func _defer_info_lines(action, ctx, cost_mod) -> void:
	var _defer_sub = _find_deferring_sub_action(action, ctx)
	if not _defer_sub:
		return

	var a_id = _defer_sub.uuid
	var ds = ctx.get_defer_state(a_id)
	var is_deferring = ds.get("is_deferring", false)
	var amounts = ctx.named_amounts
	var xun_val = amounts.get(_defer_sub.defer_config.xun_defered, 0)

	if is_deferring:
		var remaining = ds.get("remaining", 0)
		var is_failing = ds.get("is_failing", false)

		cost_mod.append(_BBCode.defer_waiting(remaining, xun_val, is_failing))

		var cost_parts: Array[String] = []
		_defer_cost_parts(_defer_sub, amounts, cost_parts)
		if not cost_parts.is_empty():
			cost_mod.append(_BBCode.defer_cost(cost_parts, is_failing))

		if is_failing:
			var fb = _defer_sub.defer_config.failed_fallback
			var fb_msg = tr("CODE_ACTION_HINT_FORMATTER_E9186A064E") if not fb.is_empty() else tr("CODE_ACTION_HINT_FORMATTER_C7E5FDA3A3")
			cost_mod.append(_BBCode.defer_failing(fb_msg))
	else:
		cost_mod.append(_BBCode.defer_pending(xun_val))
		var cost_parts: Array[String] = []
		_defer_cost_parts(_defer_sub, amounts, cost_parts)
		if not cost_parts.is_empty():
			cost_mod.append(_BBCode.defer_cost(cost_parts, false))


func _defer_cost_parts(defer_sub, amounts: Dictionary, cost_parts: Array[String]) -> void:
	if not defer_sub.defer_config.used_resource_archetype.is_empty():
		var arch = Database.action_archetypes.get(defer_sub.defer_config.used_resource_archetype)
		if arch and not arch.operators.is_empty():
			for op in arch.operators:
				if op is PropertyOperator:
					var pop = op as PropertyOperator
					var prop_data = Database.get_property(pop.property)
					var pname = prop_data.get_display_name() if prop_data else pop.property
					cost_parts.append("%s %d" % [pname, pop.value])
	if not defer_sub.defer_config.ap_cost.is_empty():
		var ap_val = amounts.get(defer_sub.defer_config.ap_cost, 0)
		cost_parts.append(tr("CODE_ACTION_HINT_FORMATTER_537A21D6E2") % ap_val)


# ════════════════════════════════════════════════════════════════
# 内部：时间消耗行
# ════════════════════════════════════════════════════════════════

func _time_cost_lines(action, cost_mod) -> void:
	if action.day_consumed <= 0:
		return

	var has_subs = action.sub_actions and not action.sub_actions.is_empty()
	if has_subs:
		var min_day = action.day_consumed
		var max_day = action.day_consumed
		for sub_uuid in action.sub_actions:
			if sub_uuid.is_empty():
				continue
			var sub = Database.get_action(sub_uuid) as Action
			if not sub:
				continue
			var eff = sub.day_consumed if sub.day_consumed > 0 else action.day_consumed
			min_day = min(min_day, eff)
			max_day = max(max_day, eff)
		var min_detail = ActionManager.format_time_detail(min_day)
		var max_detail = ActionManager.format_time_detail(max_day)
		if min_day >= max_day - 0.01:
			cost_mod.append(_BBCode.time_cost_line(min_detail))
		else:
			cost_mod.append(_BBCode.time_span_line(min_detail, max_detail))
		Logging.info("ActionHintFormatter._time_cost_lines: time span for '%s' min=%f max=%f" % [action.name, min_day, max_day])
	else:
		var cost_detail = ActionManager.format_time_detail(action.day_consumed)
		cost_mod.append(_BBCode.time_cost_line(cost_detail))
		Logging.info("ActionHintFormatter._time_cost_lines: time cost for '%s' day_consumed=%f" % [action.name, action.day_consumed])


# ════════════════════════════════════════════════════════════════
# 内部：Archetype 定性预览（支持 SIMPLE profile）
# ════════════════════════════════════════════════════════════════

func _build_archetype_qualitative_preview(action, is_repeated: bool, profile) -> Array[String]:
	var lines: Array[String] = []
	if not action or not action is SceneAction:
		Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: action 非 SceneAction, 跳过")
		return lines

	var scene_action = action as SceneAction
	var main_tag_val = scene_action._main_tag
	var action_type = ENUMS.action_tag_to_action_type(main_tag_val)
	if action_type < 0:
		Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: main_tag 无法映射到 action_type, 跳过")
		return lines
	var type_name = ENUMS.ACTION_TYPE.keys()[action_type]
	var archetype_key = type_name.to_lower().replace("_", "")

	var archetype = Database.action_archetypes.get(archetype_key)
	if not archetype:
		Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: 未找到 archetype key='%s', 跳过" % archetype_key)
		return lines

	var ops: Array = archetype.operators
	if ops.is_empty():
		Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: archetype '%s' operators 为空" % archetype_key)
		return lines

	# SIMPLE profile: 委托 SimpleOperatorPreviewFormatter
	if profile == _HintProfile.Profile.SIMPLE:
		return _build_simple_archetype_preview(ops, is_repeated)

	for op in ops:
		if op is PropertyOperator:
			var pop = op as PropertyOperator
			if pop.value == 0 or pop.property.is_empty():
				continue
			var prop = Database.get_property(pop.property)
			var display_name = prop.get_display_name() if prop and not prop.name.is_empty() else pop.property

			if is_repeated:
				if pop.value > 0:
					lines.append(tr("CODE_ACTION_HINT_FORMATTER_E90E20838E") % display_name)
				else:
					lines.append(tr("CODE_ACTION_HINT_FORMATTER_2EEE8E4508") % display_name)
			else:
				if pop.value > 0:
					lines.append(tr("CODE_ACTION_HINT_FORMATTER_92A049E66F") % display_name)
				else:
					lines.append(tr("CODE_ACTION_HINT_FORMATTER_389509B135") % display_name)
		elif op is TimeOperator:
			if action.day_consumed > 0:
				continue
			var top = op as TimeOperator
			if top.refresh_time or top.day <= 0:
				continue
			if is_repeated:
				lines.append(tr("CODE_ACTION_HINT_FORMATTER_BA06578EC5") % int(top.day))
			else:
				lines.append(tr("CODE_ACTION_HINT_FORMATTER_0BBC7EDA2B") % int(top.day))
		elif op is TraitOperator:
			var desc = op.describe_preview()
			if not desc.is_empty():
				lines.append("• " + desc)
			Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: TraitOperator '%s' → '%s'" % [op.trait_key, desc])
		elif op is PoemRewardOperator:
			var desc = op.describe_preview()
			if not desc.is_empty():
				lines.append("• " + desc)
		elif op is PoemConversionOperator:
			var desc = op.describe_preview()
			if not desc.is_empty():
				lines.append("• " + desc)

	Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: archetype '%s' → %d 定性行 (is_repeated=%s)" % [archetype_key, lines.size(), str(is_repeated)])
	return lines


## SIMPLE profile 的 archetype 定性预览简化版
## 在 default 的 _build_archetype_qualitative_preview 基础上通过委托
## SimpleOperatorPreviewFormatter 获取简化描述行（无 • 前缀）。
func _build_simple_archetype_preview(ops: Array, is_repeated: bool) -> Array[String]:
	var lines: Array[String] = []
	for op in ops:
		if op is PropertyOperator:
			var pop = op as PropertyOperator
			if pop.value == 0 or pop.property.is_empty():
				continue
			var prop = Database.get_property(pop.property)
			var display_name = prop.get_display_name() if prop and not prop.name.is_empty() else pop.property

			var arrow_char = "↑" if pop.value > 0 else "↓"
			var arrow_count = PropertyOperator._get_arrow_count(pop.property, pop.value)
			var arrows = ""
			for i in arrow_count:
				arrows += arrow_char

			if is_repeated:
				lines.append(tr("CODE_ACTION_HINT_FORMATTER_6391FF1D34") % [display_name, arrows])
			else:
				lines.append("%s%s" % [display_name, arrows])
		elif op is TimeOperator:
			if op.refresh_time or op.day <= 0:
				continue
			lines.append(tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_20C021DFAA") % int(op.day))
		elif op is TraitOperator:
			if not op.trait_key.is_empty():
				var trait_obj = Database.get_trait(op.trait_key)
				var cn_name = tr(trait_obj.name) if trait_obj and not trait_obj.name.is_empty() else op.trait_key
				if op.operator == REQ_OPERATOR.CRUD.ADD:
					lines.append(tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_52AC4C7A26") % cn_name)
				elif op.operator == REQ_OPERATOR.CRUD.REMOVE:
					lines.append(tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_F8ABBE184F") % cn_name)
				Logging.info("ActionHintFormatter._build_simple_archetype_preview: TraitOperator '%s' add=%s" % [op.trait_key, str(op.operator == REQ_OPERATOR.CRUD.ADD)])
		elif op is PoemRewardOperator:
			var desc = ""
			match op.mode:
				"money":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_49638608D2")
				"fame":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_A7B388A324")
				"baiye":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_D00FB77ACE")
				_:
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_49638608D2")
			if not desc.is_empty():
				lines.append(desc)
		elif op is PoemConversionOperator:
			var desc = ""
			match op.resource_uuid:
				"money":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_49638608D2")
				"prestige":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_A7B388A324")
				"progress":
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_D00FB77ACE")
				_:
					desc = tr("CODE_SIMPLE_OPERATOR_PREVIEW_FORMATTER_49638608D2")
			if not desc.is_empty():
				lines.append(desc)

	return lines


## 使用 BBCode 方法替代原来带 • / 、的 _finalize_simple_labels
## SIMPLE 模式标签：空格分割，无 • 无 、
func _build_simple_labels(hint, is_locked: bool, lock_reason: String) -> void:
	var labels := {}
	if is_locked:
		labels["feasibility"] = _BBCode.simple_feasibility_label(tr("CODE_ACTION_HINT_FORMATTER_1A5219A827"))
		labels["cost"] = _BBCode.simple_cost_label([])
		labels["output"] = _BBCode.simple_output_label([])
		labels["risk"] = _BBCode.simple_lock_label(lock_reason)
		labels["requirements"] = _BBCode.simple_requirement_label(hint._requirements_lines)
	else:
		var feas_line = hint.feasibility.lines[0] if not hint.feasibility.lines.is_empty() else ""
		labels["feasibility"] = _BBCode.simple_feasibility_label(feas_line if not feas_line.is_empty() else tr("CODE_POEM_CRAFTING_CALCULATOR_4D8C1C5B42"))

		labels["cost"] = _BBCode.simple_cost_label(hint.cost.lines)
		labels["output"] = _BBCode.simple_output_label(hint.output.lines)
		labels["risk"] = _BBCode.simple_risk_label(hint.risk.lines)
		labels["requirements"] = _BBCode.simple_requirement_label(hint._requirements_lines)

	hint.simple_labels = labels


# ════════════════════════════════════════════════════════════════
# 🆕 SIMPLE profile: requirements 收集（type-based dispatch）
# ════════════════════════════════════════════════════════════════

## 情绪英文键 → 中文名静态映射（与 EmotionRequirement._EMOTION_CN 保持同步）
const _SIMPLE_EMOTION_CN: Dictionary = {
	"sorrow":      "CODE_EMOTION_REQUIREMENT_192BC492B2",
	"arrogance":   "CODE_EMOTION_REQUIREMENT_9A85FF3DCC",
	"anger":       "CODE_EMOTION_REQUIREMENT_DC917B1566",
	"tranquility": "CODE_EMOTION_REQUIREMENT_A62908DEDA",
	"ambition":    "CODE_EMOTION_REQUIREMENT_0AB342DF06",
}

## 遍历 action.aciton_requirements，为每种 Requirement 生成 SIMPLE 格式行。
## 返回值: Array[String]，空数组表示无有效需求展示。
static func _collect_simple_requirements(action) -> Array[String]:
	var lines: Array[String] = []
	if not action or action.aciton_requirements.is_empty():
		Logging.info("ActionHintFormatter._collect_simple_requirements: 无 requirements")
		return lines

	for req in action.aciton_requirements:
		if not req:
			continue
		var line := ""
		if req is PropertyRequirement:
			line = _simple_req_property(req as PropertyRequirement)
		elif req is PropRangeRequirement:
			line = _simple_req_prop_range(req as PropRangeRequirement)
		elif req is TraitRequirement:
			line = _simple_req_trait(req as TraitRequirement)
		elif req is EmotionRequirement:
			line = _simple_req_emotion(req as EmotionRequirement)
		elif req is PoemRequirement:
			line = TranslationServer.translate("CODE_POEM_REQUIREMENT_SIMPLE_DESC")
		elif req is XunDayLimitRequirement:
			line = _simple_req_xun_day(req as XunDayLimitRequirement)
		elif req is ActionMatchRequirement:
			line = _simple_req_action_match(req as ActionMatchRequirement)
		elif req is ComplexRequirements:
			var children = req.operators
			if not children.is_empty():
				for child in children:
					if child is TraitRequirement:
						var tl = _simple_req_trait(child as TraitRequirement)
						if not tl.is_empty():
							lines.append(tl)
					elif child is PropertyRequirement:
						var pl = _simple_req_property(child as PropertyRequirement)
						if not pl.is_empty():
							lines.append(pl)
					elif child is PoemRequirement:
						lines.append(TranslationServer.translate("CODE_POEM_REQUIREMENT_SIMPLE_DESC"))
					elif child is EmotionRequirement:
						var el = _simple_req_emotion(child as EmotionRequirement)
						if not el.is_empty():
							lines.append(el)
					else:
						Logging.info("ActionHintFormatter._collect_simple_requirements: ComplexRequirements 子项类型 %s 不展示" % child.get_script().resource_path.get_file())
				continue
			else:
				Logging.info("ActionHintFormatter._collect_simple_requirements: ComplexRequirements 无子项")
				continue
		else:
			Logging.info("ActionHintFormatter._collect_simple_requirements: 跳过类型 %s" % req.get_script().resource_path.get_file())
			continue

		if not line.is_empty():
			lines.append(line)

	Logging.info("ActionHintFormatter._collect_simple_requirements: %d requirements → %d SIMPLE 行" % [action.aciton_requirements.size(), lines.size()])
	return lines


static func _simple_req_property(req: PropertyRequirement) -> String:
	if req.property.is_empty() or req.value == 0:
		return ""
	var prop = Database.get_property(req.property)
	if not prop:
		return ""
	var perception = prop.get_staged_perception_at_threshold(req.value)
	if perception.is_empty() or perception == TranslationServer.translate("CODE_RANGE_REQUIREMENT_EC0D9BDB00"):
		return ""
	return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_PROPERTY_FMT") % [req.value, perception]


static func _simple_req_prop_range(req: PropRangeRequirement) -> String:
	if req.property.is_empty():
		return ""
	var prop = Database.get_property(req.property)
	if not prop:
		return ""
	var perception = prop.get_staged_perception_at_threshold(int(req.min_value))
	if perception.is_empty() or perception == TranslationServer.translate("CODE_RANGE_REQUIREMENT_EC0D9BDB00"):
		return ""
	return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_PROPERTY_FMT") % [int(req.min_value), perception]


static func _simple_req_trait(req: TraitRequirement) -> String:
	if req.trait_name.is_empty():
		return ""
	var trait_obj = Database.get_trait(req.trait_name)
	var cn_name = TranslationServer.translate(trait_obj.name) if trait_obj and not trait_obj.name.is_empty() else req.trait_name
	if req.operator == REQ_OPERATOR.EXIST.HAS:
		return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_TRAIT_NEED_FMT") % cn_name
	elif req.operator == REQ_OPERATOR.EXIST.NOT_HAS:
		return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_TRAIT_NONE_FMT") % cn_name
	return ""


static func _simple_req_emotion(req: EmotionRequirement) -> String:
	if req.volatile_stat.is_empty():
		return ""
	var cn_key = _SIMPLE_EMOTION_CN.get(req.volatile_stat, "")
	var cn = TranslationServer.translate(cn_key) if not cn_key.is_empty() else req.volatile_stat
	return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_EMOTION_FMT") % [cn, req.value]


static func _simple_req_xun_day(req: XunDayLimitRequirement) -> String:
	var human_day: int = req.max_day + 1
	return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_XUN_DAY_FMT") % human_day


static func _simple_req_action_match(req: ActionMatchRequirement) -> String:
	if req.action_id.is_empty():
		return ""
	return TranslationServer.translate("CODE_SIMPLE_ACTION_REQUIREMENT_ACTION_MATCH_FMT") % req.action_id
