extends RefCounted
## Action 与 SubAction 提示文本构建器
##
## 从 ActionHintBuilder 绞杀迁移而来。收敛 build_action_hint 和
## build_sub_action_preview 的全部逻辑。
##
## 核心设计：通过 HintContext 替代对 PlayerState / ActionManager / SurvivalManager
## 的直接 autoload 依赖。HintContext 由调用方预组装传入。
##
## 🆕 返回类型: build_action_hint → ActionHint 结构化对象（含四模块 + narrative + vector）
## 🆕 支持两套 Profile：DEFAULT（详版）和 SIMPLE（简版）

const _BBCode = preload("res://ui/utils/bbcode.gd")
const _OPFormatter = preload("res://core/hints/operator_preview_formatter.gd")
const _ActionHint = preload("res://core/model/action_hint.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 为行动按钮的主 hover popup 构建叙事层 + 向量层文本。
## @param action: 目标 Action 资源
## @param is_locked: 是否处于灰化锁定态（影响叙事层前缀）
## @param ctx: 预组装的 HintContext（由调用方从运行时状态填充）
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
## @return ActionHint 结构化对象（含 narrative + feasibility/cost/output/risk/other 模块 + vector）
static func build_action_hint(action, is_locked: bool, ctx, profile := _HintProfile.Profile.DEFAULT):
	if not action:
		Logging.err("ActionHintFormatter.build_action_hint: action is null")
		return { "narrative": "（无数据）", "vector": "" }

	var hint = _ActionHint.new()
	var _is_repeated = ctx.is_repeated

	# ── 叙事层（profile 不影响，保持原样）──
	hint.narrative = action.description if not action.description.is_empty() else "（无叙述）"

	if is_locked and not action.dynamic_failed_hint.is_empty():
		hint.narrative = _BBCode.locked_prefix(action.dynamic_failed_hint) + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: locked narrative for '%s'" % action.name)
	elif not is_locked and not action.success_hint.is_empty():
		hint.narrative = _BBCode.success_prefix(action.success_hint) + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: unlocked with success_hint for '%s'" % action.name)

	if _is_repeated and not is_locked:
		hint.narrative = _BBCode.repeated_warning() + "\n\n" + hint.narrative
		Logging.info("ActionHintFormatter.build_action_hint: 重复行动警告追加到叙事层 for '%s'" % action.name)

	# ── 模块组装（extracted，profile 透传）──
	_assemble_feasibility_module(action, hint.feasibility)
	_assemble_cost_module(action, ctx, hint.cost, profile)
	_assemble_output_module(action, _is_repeated, hint.output, profile)
	_assemble_risk_module(action, hint.risk, profile)

	Logging.info("ActionHintFormatter.build_action_hint: done for '%s', narrative=%d chars, vector=%d chars" % [action.name, hint.narrative.length(), hint.vector.length()])
	return hint


## 为 sub-action picker tooltip 构建预览文本。
## 现在返回 ActionHint 结构化对象，consumer 通过 .vector 获取旧格式的完整文本。
## @param profile: 提示模式 — HintProfile.Profile.DEFAULT（默认）或 SIMPLE
static func build_sub_action_preview(sub_action, ctx, success_ops: Array = [], fail_ops: Array = [], parent_day_consumed: float = 0.0, profile := _HintProfile.Profile.DEFAULT):
	if not sub_action:
		Logging.err("ActionHintFormatter.build_sub_action_preview: sub_action is null")
		return { "narrative": "", "vector": "" }

	var hint = _ActionHint.new()
	hint.narrative = _BBCode.preview_header()

	var prob: int = sub_action.get_possibility_int()
	hint.feasibility.title = "━━━ 可行性 ━━━"
	hint.feasibility.append(_BBCode.sub_prob_line(prob))
	Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' possibility=%d" % [sub_action.name, prob])

	var _is_repeated = ctx.is_repeated

	if _is_repeated:
		hint.feasibility.append(_BBCode.repeated_warning())

	# 🆕 异地行动提示 → cost
	var _place_name = sub_action.get_required_place_name()
	if not _place_name.is_empty():
		var _req_place = sub_action.required_place
		var _cur_place_str = ctx.stay_place
		if not _cur_place_str.is_empty() and _req_place != _cur_place_str:
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
			hint.cost.append("⏱ 耗时 %s" % cost_detail)
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' time ok (need=%d, have=%d)" % [sub_action.name, cost_total, current_time])

	if not hint.cost.is_empty() and hint.cost.title.is_empty():
		hint.cost.title = "━━━ 耗费 ━━━"

	# ── 成功效果 → output ──
	var success_descs: Array[String] = []
	if not success_ops.is_empty():
		success_descs.append_array(_OPFormatter.build_preview(success_ops, profile))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' archetype success_ops (%d ops) → 已合并" % [sub_action.name, success_ops.size()])
	if sub_action.action_results and not sub_action.action_results.is_empty():
		var tres_lines = _OPFormatter.build_preview(sub_action.action_results, profile)
		if not tres_lines.is_empty():
			success_descs.append_array(tres_lines)
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' .tres action_results (%d ops → %d descs) → 已合并" % [sub_action.name, sub_action.action_results.size(), tres_lines.size()])

	if success_descs.is_empty():
		hint.output.append(_BBCode.success_header() + " 成败未卜…")
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' success 无有效 operator，使用 fallback" % sub_action.name)
	else:
		hint.output.title = "━━━ 产出 ━━━"
		hint.output.append(_BBCode.success_header())
		hint.output.append_array(success_descs)
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' success preview: %d lines" % [sub_action.name, success_descs.size()])

	# ── 失败效果 → risk ──
	var fail_descs: Array[String] = []
	if not fail_ops.is_empty():
		fail_descs.append_array(_OPFormatter.build_preview(fail_ops, profile))
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' archetype fail_ops (%d ops) → 已合并" % [sub_action.name, fail_ops.size()])
	var failed_result = sub_action.failed_result
	if failed_result and failed_result.operators and not failed_result.operators.is_empty():
		var tres_fail_lines = _OPFormatter.build_preview(failed_result.operators, profile)
		if not tres_fail_lines.is_empty():
			fail_descs.append_array(tres_fail_lines)
			Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' .tres failed_result (%d ops → %d descs) → 已合并" % [sub_action.name, failed_result.operators.size(), tres_fail_lines.size()])

	if fail_descs.is_empty():
		hint.risk.append(_BBCode.fail_header() + " 后果难料…")
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' fail 无有效 operator，使用 fallback" % sub_action.name)
	else:
		hint.risk.title = "━━━ 风险 ━━━"
		hint.risk.append(_BBCode.fail_header())
		hint.risk.append_array(fail_descs)
		Logging.info("ActionHintFormatter.build_sub_action_preview: sub_action='%s' fail preview: %d lines" % [sub_action.name, fail_descs.size()])

	Logging.info("ActionHintFormatter.build_sub_action_preview: done for '%s', vector=%d chars" % [sub_action.name, hint.vector.length()])
	return hint


# ════════════════════════════════════════════════════════════════
# Extracted 模块组装函数（building_action_hint 专用）
# ════════════════════════════════════════════════════════════════

static func _assemble_feasibility_module(action, feas_mod) -> void:
	var prob: int = action.get_possibility_int()
	if prob < 100:
		feas_mod.title = "━━━ 可行性 ━━━"
		feas_mod.append("概率: %d%%" % prob)
		Logging.info("ActionHintFormatter._assemble_feasibility_module: possibility=%d for '%s'" % [prob, action.name])


static func _assemble_cost_module(action, ctx, cost_mod, profile) -> void:
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
		cost_mod.title = "━━━ 耗费 ━━━"


static func _assemble_output_module(action, is_repeated: bool, output_mod, profile) -> void:
	if not action.action_results.is_empty():
		output_mod.title = "━━━ 产出 ━━━"
		var success_lines = _OPFormatter.build_preview(action.action_results, profile)
		output_mod.append_array(success_lines)
		Logging.info("ActionHintFormatter._assemble_output_module: %d action_results → %d lines for '%s'" % [action.action_results.size(), success_lines.size(), action.name])
	else:
		var archetype_lines = _build_archetype_qualitative_preview(action, is_repeated, profile)
		if not archetype_lines.is_empty():
			output_mod.title = "━━━ 产出 ━━━"
			output_mod.append_array(archetype_lines)
			Logging.info("ActionHintFormatter._assemble_output_module: archetype 定性预览 %d lines for '%s'" % [archetype_lines.size(), action.name])


static func _assemble_risk_module(action, risk_mod, profile) -> void:
	if action.failed_result and not action.failed_result.operators.is_empty():
		risk_mod.title = "━━━ 风险 ━━━"
		var fail_lines = _OPFormatter.build_choice_result_preview(action.failed_result, profile)
		risk_mod.append_array(fail_lines)
		Logging.info("ActionHintFormatter._assemble_risk_module: %d failed_result ops → %d lines for '%s'" % [action.failed_result.operators.size(), fail_lines.size(), action.name])


# ════════════════════════════════════════════════════════════════
# 内部：Defer 信息行
# ════════════════════════════════════════════════════════════════

static func _find_deferring_sub_action(action, ctx):
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


static func _defer_info_lines(action, ctx, cost_mod) -> void:
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
			var fb_msg = "将有不良后果" if not fb.is_empty() else "将被迫中断"
			cost_mod.append(_BBCode.defer_failing(fb_msg))
	else:
		cost_mod.append(_BBCode.defer_pending(xun_val))
		var cost_parts: Array[String] = []
		_defer_cost_parts(_defer_sub, amounts, cost_parts)
		if not cost_parts.is_empty():
			cost_mod.append(_BBCode.defer_cost(cost_parts, false))


static func _defer_cost_parts(defer_sub, amounts: Dictionary, cost_parts: Array[String]) -> void:
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
		cost_parts.append("时间 %d" % ap_val)


# ════════════════════════════════════════════════════════════════
# 内部：时间消耗行
# ════════════════════════════════════════════════════════════════

static func _time_cost_lines(action, cost_mod) -> void:
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

static func _build_archetype_qualitative_preview(action, is_repeated: bool, profile) -> Array[String]:
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
					lines.append("• %s 将会增加（重复行动，效果减少20%%）" % display_name)
				else:
					lines.append("• %s 将会消耗（重复行动，消耗增加20%%）" % display_name)
			else:
				if pop.value > 0:
					lines.append("• %s 将会增加" % display_name)
				else:
					lines.append("• %s 将会消耗" % display_name)
		elif op is TimeOperator:
			if action.day_consumed > 0:
				continue
			var top = op as TimeOperator
			if top.refresh_time or top.day <= 0:
				continue
			if is_repeated:
				lines.append("• 额外耗时 %d 天（重复行动，消耗增加20%%）" % int(top.day))
			else:
				lines.append("• 额外耗时 %d 天" % int(top.day))
		elif op is PoemRewardOperator:
			var desc = op.describe_preview()
			if not desc.is_empty():
				lines.append("• " + desc)

	Logging.info("ActionHintFormatter._build_archetype_qualitative_preview: archetype '%s' → %d 定性行 (is_repeated=%s)" % [archetype_key, lines.size(), str(is_repeated)])
	return lines


## SIMPLE profile 的 archetype 定性预览简化版
## 在 default 的 _build_archetype_qualitative_preview 基础上通过委托
## SimpleOperatorPreviewFormatter 获取简化描述行
static func _build_simple_archetype_preview(ops: Array, is_repeated: bool) -> Array[String]:
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
				lines.append("• %s%s（重复)" % [display_name, arrows])
			else:
				lines.append("• %s%s" % [display_name, arrows])
		elif op is TimeOperator:
			if op.refresh_time or op.day <= 0:
				continue
			lines.append("• ⏱%d天" % int(op.day))
		elif op is PoemRewardOperator:
			var desc = ""
			match op.mode:
				"money":
					desc = "卖诗"
				"fame":
					desc = "以诗换名"
				"baiye":
					desc = "携诗拜谒"
				_:
					desc = "卖诗"
			if not desc.is_empty():
				lines.append("• " + desc)

	return lines
