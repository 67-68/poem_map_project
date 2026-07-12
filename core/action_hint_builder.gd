class_name ActionHintBuilder extends RefCounted
## 行动提示文本统一构建器 — 纯静态工具类

const _ModifierConfig = preload("res://core/modifier_config.gd")
##
## 将所有 Action hover 提示文本的格式化逻辑集中到此处：
##   1. operator 列表 → 人类可读描述行
##   2. Action → {narrative, vector} 字典（主按钮 popup）
##   3. Action + archetype operators → 子行动预览字符串（picker popup）
##
## 消费方：action_button.gd（主按钮 hover）、picker_item.gd（picker 项 hover）


# ── 接口 2：operator 列表 → 描述行 ────────────────────────

## 将一列 BaseOperator 转为 "• {describe_preview()}" 的字符串数组。
## 🆕 PropertyOperator 会追加修饰符注解（如 "城府 -8"）。
## 自动过滤空描述和无效 operator。
static func build_operator_preview(operators: Array) -> Array[String]:
	var lines: Array[String] = []
	if operators.is_empty():
		Logging.info("ActionHintBuilder.build_operator_preview: operators empty, returning []")
		return lines
	
	for op in operators:
		if not op or not op.has_method("describe_preview"):
			Logging.warn("ActionHintBuilder.build_operator_preview: operator 无效或无 describe_preview, op=%s" % str(op))
			continue
		var desc: String

		# 🆕 PropertyOperator: 计算修饰符调整后的最终值，注入 describe_preview
		if op is PropertyOperator:
			var pop := op as PropertyOperator
			var raw_val: int = pop.value
			var adjusted_val: int = _ModifierConfig.apply_all_matching_effects(pop.property, raw_val)
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
				var annotations: Array[String] = _ModifierConfig.get_preview_annotations(pop.property, raw_val)
				if not annotations.is_empty():
					desc += " (%s)" % ", ".join(annotations)
				else:
					desc += " (%+d)" % delta
				Logging.info("ActionHintBuilder.build_operator_preview: prop=%s raw=%d adjusted=%d delta=%d annotations=%s" % [pop.property, raw_val, adjusted_val, delta, str(annotations)])
		else:
			desc = op.describe_preview()
			if desc.is_empty():
				continue

		lines.append("• " + desc)
	
	Logging.info("ActionHintBuilder.build_operator_preview: %d operators → %d lines" % [operators.size(), lines.size()])
	return lines


## 糖衣：从 ChoiceResult 解包 .operators，委托给 build_operator_preview。
static func build_choice_result_preview(result: ChoiceResult) -> Array[String]:
	if not result or result.operators.is_empty():
		Logging.info("ActionHintBuilder.build_choice_result_preview: result null or operators empty")
		return []
	return build_operator_preview(result.operators)


## 🆕 计算当前 action 的识别 tags 并用 is_action_repeated 检查是否重复。
## SceneAction 用 main_tag + action_tags；普通 Action 用 action_tags。
static func _check_repeated(action: Action) -> bool:
	if not action:
		return false
	var tags: Array[String] = []
	if action is SceneAction:
		var sa := action as SceneAction
		if not sa.main_tag.is_empty():
			tags.append(sa.main_tag)
	tags.append_array(action.action_tags)
	return PlayerState.is_action_repeated(tags)


## 🆕 从 event_archetypes.json 加载 archetype 的 PropertyOperator 并生成定性预览行。
## 不展示具体数值，只描述方向："健康 将会增加" / "金钱 将会消耗"。
## @param action: 目标 Action（需为 SceneAction 才能查找 archetype key）
## @param is_repeated: 是否为重复行动（影响后缀文本）
## @return Array[String] — "• {display_name} 将会{增加/消耗}[(重复行动, ...)]"
static func _build_archetype_qualitative_preview(action: Action, is_repeated: bool) -> Array[String]:
	var lines: Array[String] = []
	if not action or not action is SceneAction:
		Logging.info("ActionHintBuilder._build_archetype_qualitative_preview: action 非 SceneAction, 跳过")
		return lines
	
	var scene_action := action as SceneAction
	var main_tag_val := scene_action._main_tag
	var action_type := ENUMS.action_tag_to_action_type(main_tag_val)
	if action_type < 0:
		Logging.info("ActionHintBuilder._build_archetype_qualitative_preview: main_tag 无法映射到 action_type, 跳过")
		return lines
	var type_name = ENUMS.ACTION_TYPE.keys()[action_type]
	var archetype_key = type_name.to_lower().replace("_", "")
	
	var archetype = Database.action_archetypes.get(archetype_key)
	if not archetype:
		Logging.info("ActionHintBuilder._build_archetype_qualitative_preview: 未找到 archetype key='%s', 跳过" % archetype_key)
		return lines
	
	var ops: Array = archetype.operators
	if ops.is_empty():
		Logging.info("ActionHintBuilder._build_archetype_qualitative_preview: archetype '%s' operators 为空" % archetype_key)
		return lines
	
	for op in ops:
		if op is PropertyOperator:
			var pop := op as PropertyOperator
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
			# 若 action 已通过 day_consumed 声明时间消耗，跳过 archetype 中的 TimeOperator（避免重复）
			if action.day_consumed > 0:
				continue
			var top := op as TimeOperator
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
	
	Logging.info("ActionHintBuilder._build_archetype_qualitative_preview: archetype '%s' → %d 定性行 (is_repeated=%s)" % [archetype_key, lines.size(), str(is_repeated)])
	return lines


# ── 接口 1：Action → {narrative, vector} ──────────────────

## 为行动按钮的主 hover popup 构建叙事层 + 向量层文本。
## @param action: 目标 Action 资源
## @param is_locked: 是否处于灰化锁定态（影响叙事层前缀）
## @return { "narrative": String, "vector": String }
static func build_action_hint(action: Action, is_locked: bool) -> Dictionary:
	if not action:
		Logging.err("ActionHintBuilder.build_action_hint: action is null")
		return { "narrative": "（无数据）", "vector": "" }
	
	# 🆕 重复行动检测：计算一次，复用于叙事层和向量层
	var _is_repeated := _check_repeated(action)
	var _saved_is_repeated: bool = PlayerState._is_repeated_action
	PlayerState._is_repeated_action = _is_repeated
	if _is_repeated:
		Logging.info("ActionHintBuilder.build_action_hint: 重复行动 preview 激活 for '%s'" % action.name)
	
	# ── 叙事层 ──
	var narrative: String = action.description if not action.description.is_empty() else "（无叙述）"
	
	if is_locked and not action.dynamic_failed_hint.is_empty():
		narrative = "[color=#cc6666]🔒 %s[/color]\n\n%s" % [action.dynamic_failed_hint, narrative]
		Logging.info("ActionHintBuilder.build_action_hint: locked narrative for '%s'" % action.name)
	elif not is_locked and not action.success_hint.is_empty():
		narrative = "[color=#66cc66]✓ %s[/color]\n\n%s" % [action.success_hint, narrative]
		Logging.info("ActionHintBuilder.build_action_hint: unlocked with success_hint for '%s'" % action.name)
	
	# 🆕 重复行动警告（叙事层）：非锁定态时前置颜色警告
	if _is_repeated and not is_locked:
		narrative = "[color=#ccaa44]⚠ 重复行动 — 收益减少20%%，消耗增加20%%[/color]\n\n" + narrative
		Logging.info("ActionHintBuilder.build_action_hint: 重复行动警告追加到叙事层 for '%s'" % action.name)
	
	# ── 向量层 ──
	var vector_lines: Array[String] = []
	
	# 概率行（非 100% 时显示）
	var prob: int = action.get_possibility_int()
	if prob < 100:
		vector_lines.append("[color=gray][font_size=13]概率: %d%%[/font_size][/color]" % prob)
		Logging.info("ActionHintBuilder.build_action_hint: possibility=%d for '%s'" % [prob, action.name])
	
	# 🆕 Defer 信息行
	if action.defer_config and not action.defer_config.xun_defered.is_empty():
		var a_id := action.uuid
		var is_deferring := ActionManager.is_deferring(a_id)
		var amounts = NamedDSLParser._load_named_amounts()
		var xun_val: int = amounts.get(action.defer_config.xun_defered, 0)
		
		if is_deferring:
			var remaining := ActionManager.get_defer_remaining(a_id)
			var is_failing := ActionManager.is_defer_failing(a_id)
			var color_tag := "color=#cc6666" if is_failing else "color=#5588ff"
			var defer_line := "[%s][font_size=13]⏳ 等待 %d/%d 旬[/font_size][/color]" % [color_tag, remaining, xun_val]
			vector_lines.append(defer_line)
			
			# 每旬消耗信息
			var cost_parts: Array[String] = []
			if not action.defer_config.used_resource_archetype.is_empty():
				var arch = Database.action_archetypes.get(action.defer_config.used_resource_archetype)
				if arch and not arch.operators.is_empty():
					for op in arch.operators:
						if op is PropertyOperator:
							var pop := op as PropertyOperator
							var prop_data = Database.get_property(pop.property)
							var pname = prop_data.get_display_name() if prop_data else pop.property
							cost_parts.append("%s %d" % [pname, pop.value])
			if not action.defer_config.ap_cost.is_empty():
				var ap_val: int = amounts.get(action.defer_config.ap_cost, 0)
				cost_parts.append("时间 %d" % ap_val)
			if not cost_parts.is_empty():
				vector_lines.append("[%s][font_size=13]  每旬: %s[/font_size][/color]" % [color_tag, ", ".join(cost_parts)])
			
			if is_failing:
				var fb := action.defer_config.failed_fallback
				var fb_msg := "将有不良后果" if not fb.is_empty() else "将被迫中断"
				vector_lines.append("[color=#cc6666][font_size=13]⚠ 资源不足，%s[/font_size][/color]" % fb_msg)
		else:
			# 未激活但配置了 defer — 展示将来的 defer 信息
			vector_lines.append("[color=gray][font_size=13]⏳ 执行后等待 %d 旬[/font_size][/color]" % xun_val)
			var cost_parts: Array[String] = []
			if not action.defer_config.used_resource_archetype.is_empty():
				var arch = Database.action_archetypes.get(action.defer_config.used_resource_archetype)
				if arch and not arch.operators.is_empty():
					for op in arch.operators:
						if op is PropertyOperator:
							var pop := op as PropertyOperator
							var prop_data = Database.get_property(pop.property)
							var pname = prop_data.get_display_name() if prop_data else pop.property
							cost_parts.append("%s %d" % [pname, pop.value])
			if not action.defer_config.ap_cost.is_empty():
				var ap_val: int = amounts.get(action.defer_config.ap_cost, 0)
				cost_parts.append("时间 %d" % ap_val)
			if not cost_parts.is_empty():
				vector_lines.append("[color=gray][font_size=13]  每旬: %s[/font_size][/color]" % ", ".join(cost_parts))
	
	# 健康→AP 削减提示（通过 SurvivalManager 配置驱动，无削减时不显示）
	var ap_hint := SurvivalManager.get_active_ap_hint()
	if not ap_hint.is_empty():
		var ap_hint_color := SurvivalManager.get_active_ap_hint_color()
		vector_lines.append("[color=%s][font_size=13]%s[/font_size][/color]" % [ap_hint_color, ap_hint])
		Logging.info("ActionHintBuilder.build_action_hint: AP hint='%s' for '%s'" % [ap_hint, action.name])
	
	# 🆕 时间消耗行（有子行动时显示 span，无子行动时显示单一值）
	if action.day_consumed > 0:
		var has_subs := action.sub_actions and not action.sub_actions.is_empty()
		if has_subs:
			var min_day := action.day_consumed
			var max_day := action.day_consumed
			for sub_uuid in action.sub_actions:
				if sub_uuid.is_empty():
					continue
				var sub := Database.get_action(sub_uuid) as Action
				if not sub:
					continue
				var eff := sub.day_consumed if sub.day_consumed > 0 else action.day_consumed
				min_day = min(min_day, eff)
				max_day = max(max_day, eff)
			var min_detail := ActionManager.format_time_detail(min_day)
			var max_detail := ActionManager.format_time_detail(max_day)
			if min_day >= max_day - 0.01:
				vector_lines.append("[color=gray][font_size=13]⏱ 耗时 %s[/font_size][/color]" % min_detail)
			else:
				vector_lines.append("[color=gray][font_size=13]⏱ 耗时 %s ～ %s[/font_size][/color]" % [min_detail, max_detail])
			Logging.info("ActionHintBuilder.build_action_hint: time span for '%s' min=%f max=%f" % [action.name, min_day, max_day])
		else:
			var cost_detail := ActionManager.format_time_detail(action.day_consumed)
			vector_lines.append("[color=gray][font_size=13]⏱ 耗时 %s[/font_size][/color]" % cost_detail)
			Logging.info("ActionHintBuilder.build_action_hint: time cost for '%s' day_consumed=%f" % [action.name, action.day_consumed])
	
	# 前提
	if not action.aciton_requirements.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 前提 ━━━[/font_size][/color]")
		for req in action.aciton_requirements:
			var desc: String = req.describe_requirement() if req.has_method("describe_requirement") else ""
			if not desc.is_empty():
				vector_lines.append("• " + desc)
		Logging.info("ActionHintBuilder.build_action_hint: %d requirements for '%s'" % [action.aciton_requirements.size(), action.name])
	
	# 成功结果 — 优先级: action_results > archetype 定性预览
	if not action.action_results.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
		var success_lines := build_operator_preview(action.action_results)
		vector_lines.append_array(success_lines)
		Logging.info("ActionHintBuilder.build_action_hint: %d action_results → %d lines for '%s'" % [action.action_results.size(), success_lines.size(), action.name])
	else:
		# 🆕 Fallback: 从 event_archetypes.json 加载 archetype PropertyOperator 生成定性预览
		var archetype_lines := _build_archetype_qualitative_preview(action, _is_repeated)
		if not archetype_lines.is_empty():
			vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
			vector_lines.append_array(archetype_lines)
			Logging.info("ActionHintBuilder.build_action_hint: archetype 定性预览 %d lines for '%s'" % [archetype_lines.size(), action.name])
	
	# 失败结果（如有）
	if action.failed_result and not action.failed_result.operators.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 失败 ━━━[/font_size][/color]")
		var fail_lines := build_choice_result_preview(action.failed_result)
		vector_lines.append_array(fail_lines)
		Logging.info("ActionHintBuilder.build_action_hint: %d failed_result ops → %d lines for '%s'" % [action.failed_result.operators.size(), fail_lines.size(), action.name])
	
	# 🆕 恢复 _is_repeated_action 原始值
	PlayerState._is_repeated_action = _saved_is_repeated
	
	var vector_text: String = "\n".join(vector_lines)
	
	Logging.info("ActionHintBuilder.build_action_hint: done for '%s', narrative=%d chars, vector=%d chars" % [action.name, narrative.length(), vector_text.length()])
	return { "narrative": narrative, "vector": vector_text }


# ── 接口 2（子行动专用）：Action + archetype operators → 预览字符串 ──

## 为 sub-action picker tooltip 构建预览文本。
## 格式: [预览]\n概率: {n}%成功，\n耗时: ...\n[成功效果]:\n• {desc}\n[失败效果]:\n• {desc}
## 数据源优先级：
##   success_ops → action.action_results → fallback「成败未卜…」
##   fail_ops    → action.failed_result.operators → fallback「后果难料…」
## @param sub_action: 子行动 Action 资源
## @param success_ops: archetype 的成功运算符
## @param fail_ops: archetype 的失败运算符
## @param parent_day_consumed: 父行动的 day_consumed（用于子行动继承）
static func build_sub_action_preview(sub_action: Action, success_ops: Array = [], fail_ops: Array = [], parent_day_consumed: float = 0.0) -> String:
	if not sub_action:
		Logging.err("ActionHintBuilder.build_sub_action_preview: sub_action is null")
		return ""
	
	var lines: Array[String] = []
	lines.append("[预览]")
	
	# ── 概率行 ──
	var prob: int = sub_action.get_possibility_int()
	lines.append("概率: %d%%成功，" % prob)
	Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' possibility=%d" % [sub_action.name, prob])
	
	# 🆕 重复行动检测：临时设置 _is_repeated_action 以便 describe_preview 展示调整值
	var _is_repeated := _check_repeated(sub_action)
	var _saved_is_repeated: bool = PlayerState._is_repeated_action
	PlayerState._is_repeated_action = _is_repeated
	if _is_repeated:
		Logging.info("ActionHintBuilder.build_sub_action_preview: 重复行动 preview 激活 for '%s'" % sub_action.name)
	
	# 🆕 重复行动警告（picker 预览）
	if _is_repeated:
		lines.append("[color=#ccaa44]⚠ 重复行动 — 收益减少20%%，消耗增加20%%[/color]")
	
	# 🆕 异地行动提示（需要在 picker 中开启「显示异地行动」才能看到此 sub-action）
	var _place_name: String = sub_action.get_required_place_name()
	if not _place_name.is_empty():
		var _req_place: String = sub_action.required_place
		var _cur_place_str := PlayerState.stay_place
		if not _cur_place_str.is_empty() and _req_place != _cur_place_str:
			lines.append("[color=#88aaff][font_size=13]📍 自动消耗1天前往%s[/font_size][/color]" % _place_name)
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 异地行动提示 → %s" % [sub_action.name, _place_name])
	
	# ── 时间消耗行（复用 ActionManager.effective_day_consumed + format_time_detail）──
	var eff_day := ActionManager.effective_day_consumed(sub_action, parent_day_consumed)
	if eff_day > 0:
		var cost_detail := ActionManager.format_time_detail(eff_day)
		var cost_total := ActionManager.get_action_day_cost(sub_action, parent_day_consumed)
		var current_time := int(PlayerState.get_stat_val("time"))
		if current_time < cost_total:
			lines.append("[color=#cc6666]⏱ 耗时 %s — 时间不足（剩余%d天）[/color]" % [cost_detail, current_time])
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 时间不足 (need=%d, have=%d)" % [sub_action.name, cost_total, current_time])
		else:
			lines.append("⏱ 耗时 %s" % cost_detail)
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' time ok (need=%d, have=%d)" % [sub_action.name, cost_total, current_time])
	
	# ── 成功效果 ──
	var success_descs: Array[String] = []
	# 合并两个数据源：archetype + .tres action_results（不再互斥）
	if not success_ops.is_empty():
		success_descs.append_array(build_operator_preview(success_ops))
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' archetype success_ops (%d ops) → 已合并" % [sub_action.name, success_ops.size()])
	if sub_action.action_results and not sub_action.action_results.is_empty():
		var tres_lines := build_operator_preview(sub_action.action_results)
		if not tres_lines.is_empty():
			success_descs.append_array(tres_lines)
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' .tres action_results (%d ops → %d descs) → 已合并" % [sub_action.name, sub_action.action_results.size(), tres_lines.size()])
	
	if success_descs.is_empty():
		lines.append("[成功效果]: 成败未卜…")
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' success 无有效 operator，使用 fallback" % sub_action.name)
	else:
		lines.append("[成功效果]:")
		for d in success_descs:
			lines.append(d)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' success preview: %d lines" % [sub_action.name, success_descs.size()])
	
	# ── 失败效果 ──
	var fail_descs: Array[String] = []
	# 合并两个数据源：archetype fail_ops + .tres failed_result.operators（不再互斥）
	if not fail_ops.is_empty():
		fail_descs.append_array(build_operator_preview(fail_ops))
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' archetype fail_ops (%d ops) → 已合并" % [sub_action.name, fail_ops.size()])
	var failed_result: ChoiceResult = sub_action.failed_result
	if failed_result and failed_result.operators and not failed_result.operators.is_empty():
		var tres_fail_lines := build_operator_preview(failed_result.operators)
		if not tres_fail_lines.is_empty():
			fail_descs.append_array(tres_fail_lines)
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' .tres failed_result (%d ops → %d descs) → 已合并" % [sub_action.name, failed_result.operators.size(), tres_fail_lines.size()])
	
	if fail_descs.is_empty():
		lines.append("[失败效果]: 后果难料…")
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' fail 无有效 operator，使用 fallback" % sub_action.name)
	else:
		lines.append("[失败效果]:")
		for d in fail_descs:
			lines.append(d)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' fail preview: %d lines" % [sub_action.name, fail_descs.size()])
	
	# 🆕 恢复 _is_repeated_action 原始值
	PlayerState._is_repeated_action = _saved_is_repeated
	
	return "\n".join(lines)


# ── 接口 3（Trait 专用）：Trait → hint 文本 ──

## 为 TraitDemonstrator 的 hover tooltip 构建完整 hint 文本。
## 包含：name → description → 效果清单 → 持续时间 → hover_narrative。
## 🆕 Imaginary 分支：显示 level/get_hint/trait_effect_operations，不显示 buffer/prop/时间惩罚/持续区。
## @param trait_data: 目标 Trait 资源（或 Imaginary，因为 Imaginary extends Trait）
## @return 格式化后的 BBCode 字符串，无有效信息时返回 ""
static func build_trait_hint(trait_data: Trait) -> String:
	if not trait_data:
		Logging.err("ActionHintBuilder.build_trait_hint: trait_data is null")
		return ""
	
	var lines: Array[String] = []
	
	# ── 名称行 ──
	var display_name := trait_data.name if not trait_data.name.is_empty() else "（未知道）"
	lines.append("【%s】" % display_name)
	Logging.info("ActionHintBuilder.build_trait_hint: trait='%s', is_imaginary=%s" % [display_name, str(trait_data is Imaginary)])
	
	# 🆕 Imaginary 分支：显示等级 / get_hint / description / trait_effect_operations / duration / hover_narrative
	if trait_data is Imaginary:
		var imag := trait_data as Imaginary
		
		# 等级 + description（如果有）
		var level_label := "Lv%d 意象" % imag.level
		if not trait_data.description.is_empty():
			level_label += " — %s" % trait_data.description
		lines.append("[color=#66cc66]%s[/color]" % level_label)
		Logging.info("ActionHintBuilder.build_trait_hint: Imaginary level=%d, has_desc=%s" % [imag.level, str(not trait_data.description.is_empty())])
		
		# get_hint（获取时的叙事文本）
		if not imag.get_hint.is_empty():
			lines.append("")
			lines.append(imag.get_hint)
			Logging.info("ActionHintBuilder.build_trait_hint: Imaginary get_hint present (%d chars)" % imag.get_hint.length())
		
		# 效果区
		lines.append("")
		lines.append("[color=gray][font_size=13]━━━ 效果 ━━━[/font_size][/color]")
		if not trait_data.trait_effect_operations.is_empty():
			for op in trait_data.trait_effect_operations:
				if not op:
					continue
				var desc: String = op.describe_preview() if op.has_method("describe_preview") else ""
				if not desc.is_empty():
					lines.append("• 每旬：%s" % desc)
			Logging.info("ActionHintBuilder.build_trait_hint: Imaginary trait_effect_operations → %d lines" % trait_data.trait_effect_operations.size())
		else:
			lines.append("（持有期无副作用）")
			Logging.info("ActionHintBuilder.build_trait_hint: Imaginary 无 trait_effect_operations")
		
		# 持续时间（统一走 Trait 的 duration_xun 逻辑）
		if trait_data.duration_xun > 0:
			lines.append("")
			lines.append("[color=gray][font_size=13]━━━ 持续 ━━━[/font_size][/color]")
			var already := trait_data.lasting_xun
			var remaining: int = max(0, trait_data.duration_xun - already)
			if not trait_data.expiry_trait.is_empty():
				var expiry_name := _get_trait_display_name(trait_data.expiry_trait)
				lines.append("• %d旬后转化为「%s」（已持续%d旬）" % [remaining, expiry_name, already])
			else:
				lines.append("• %d旬后自动移除（已持续%d旬）" % [remaining, already])
			Logging.info("ActionHintBuilder.build_trait_hint: Imaginary duration=%d, lasting=%d" % [trait_data.duration_xun, already])
		
		# hover_narrative（获取途径等）
		if not trait_data.hover_narrative.is_empty():
			lines.append("")
			lines.append(trait_data.hover_narrative)
			Logging.info("ActionHintBuilder.build_trait_hint: Imaginary hover_narrative present (%d chars)" % trait_data.hover_narrative.length())
		
		var result := "\n".join(lines)
		Logging.info("ActionHintBuilder.build_trait_hint: done for Imaginary '%s', result=%d chars" % [display_name, result.length()])
		return result
	
	# ── 以下为普通 Trait 的完整逻辑 ──
	
	# ── 描述行 ──
	if not trait_data.description.is_empty():
		lines.append(trait_data.description)
		Logging.info("ActionHintBuilder.build_trait_hint: description present (%d chars)" % trait_data.description.length())
	
	# ── 效果区 ──
	var effect_lines: Array[String] = []
	
	# 1. trait_effect_operations（每旬结算）
	if not trait_data.trait_effect_operations.is_empty():
		for op in trait_data.trait_effect_operations:
			if not op:
				continue
			var desc: String = op.describe_preview() if op.has_method("describe_preview") else ""
			if not desc.is_empty():
				effect_lines.append("• 每旬：%s" % desc)
		Logging.info("ActionHintBuilder.build_trait_hint: trait_effect_operations → %d effect lines" % effect_lines.size())
	
	# 2. buffer_to_prop（属性倍率修正）
	if trait_data.buffer_to_prop and not trait_data.buffer_to_prop.operators.is_empty():
		for mul_op in trait_data.buffer_to_prop.operators:
			if not mul_op or mul_op.key.is_empty():
				continue
			var prop_display := _get_prop_display_name(mul_op.key)
			var mode_str := _mul_operator_mode_string(mul_op.operator)
			effect_lines.append("• %s %s ×%.1f" % [prop_display, mode_str, mul_op.value])
		Logging.info("ActionHintBuilder.build_trait_hint: buffer_to_prop → %d ops" % trait_data.buffer_to_prop.operators.size())
	
	# 3. buffer_to_region（区域倍率修正）
	if trait_data.buffer_to_region and not trait_data.buffer_to_region.operators.is_empty():
		for mul_op in trait_data.buffer_to_region.operators:
			if not mul_op or mul_op.key.is_empty():
				continue
			var prop_display := _get_prop_display_name(mul_op.key)
			var mode_str := _mul_operator_mode_string(mul_op.operator)
			effect_lines.append("• %s（区域）%s ×%.1f" % [prop_display, mode_str, mul_op.value])
		Logging.info("ActionHintBuilder.build_trait_hint: buffer_to_region → %d ops" % trait_data.buffer_to_region.operators.size())
	
	# 4. time_penalty（全局行动天数惩罚）
	if trait_data.time_penalty > 0:
		effect_lines.append("• 所有行动 +%d天" % trait_data.time_penalty)
		Logging.info("ActionHintBuilder.build_trait_hint: time_penalty=+%d" % trait_data.time_penalty)
	
	# 5. conditional_time_penalties（条件天数惩罚）
	if not trait_data.conditional_time_penalties.is_empty():
		for ctp in trait_data.conditional_time_penalties:
			if not ctp or ctp.penalty_days <= 0:
				continue
			if ctp.add_to_all:
				var desc_suffix := "（%s）" % ctp.description if not ctp.description.is_empty() else ""
				effect_lines.append("• 所有行动：+%d天%s" % [ctp.penalty_days, desc_suffix])
			else:
				var label := ctp.description if not ctp.description.is_empty() else ctp.action_tag_match
				effect_lines.append("• %s：+%d天" % [label, ctp.penalty_days])
		Logging.info("ActionHintBuilder.build_trait_hint: conditional_time_penalties → %d entries" % trait_data.conditional_time_penalties.size())
	
	# 6. ap_penalty（AP 上限削减）
	if trait_data.ap_penalty != 0:
		effect_lines.append("• 行动力上限 %+d" % trait_data.ap_penalty)
		Logging.info("ActionHintBuilder.build_trait_hint: ap_penalty=%+d" % trait_data.ap_penalty)
	
	# 效果区输出
	lines.append("[color=gray][font_size=13]━━━ 效果 ━━━[/font_size][/color]")
	if effect_lines.is_empty():
		lines.append("（无特殊效果）")
		Logging.info("ActionHintBuilder.build_trait_hint: 无任何活跃效果字段")
	else:
		lines.append_array(effect_lines)
		Logging.info("ActionHintBuilder.build_trait_hint: 效果区 %d lines" % effect_lines.size())
	
	# ── 持续区 ──
	if trait_data.duration_xun > 0:
		lines.append("[color=gray][font_size=13]━━━ 持续 ━━━[/font_size][/color]")
		var already := trait_data.lasting_xun
		var remaining: int = max(0, trait_data.duration_xun - already)
		if not trait_data.expiry_trait.is_empty():
			var expiry_name := _get_trait_display_name(trait_data.expiry_trait)
			lines.append("• %d旬后转化为「%s」（已持续%d旬）" % [remaining, expiry_name, already])
			Logging.info("ActionHintBuilder.build_trait_hint: duration=%d, expiry_trait='%s', lasting=%d" % [trait_data.duration_xun, trait_data.expiry_trait, trait_data.lasting_xun])
		else:
			lines.append("• %d旬后自动移除（已持续%d旬）" % [remaining, already])
			Logging.info("ActionHintBuilder.build_trait_hint: duration=%d, no expiry, lasting=%d" % [trait_data.duration_xun, trait_data.lasting_xun])
	
	# ── hover_narrative（获取途径等硬编码叙事文本，末尾）──
	if not trait_data.hover_narrative.is_empty():
		lines.append("")
		lines.append(trait_data.hover_narrative)
		Logging.info("ActionHintBuilder.build_trait_hint: hover_narrative present (%d chars)" % trait_data.hover_narrative.length())
	
	var result := "\n".join(lines)
	Logging.info("ActionHintBuilder.build_trait_hint: done for '%s', result=%d chars, %d lines" % [display_name, result.length(), lines.size()])
	return result


# ── 辅助函数（Trait Hint 专用）──

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
			Logging.warn("ActionHintBuilder._mul_operator_mode_string: 未知 op_enum=%d" % op_enum)
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


# ════════════════════════════════════════════════════════════════
# 🆕 修饰符属性效果展示（城府/才华/定力 — S型阻尼）
# ════════════════════════════════════════════════════════════════

## 生成修饰符属性效果文本（用于 UI hover/面板展示）。
## @return BBCode 格式化字符串，无有效效果时返回 ""
static func build_modifier_effects_hint() -> String:
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
		lines.append("[b]%s (%d)[/b]" % [display_name, mod_val])
		
		for eff in effects:
			var dir_label := "+" if eff.direction == "amplify" else "-"
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
	
	return "\n".join(lines)
