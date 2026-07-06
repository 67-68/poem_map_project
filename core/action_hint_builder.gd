class_name ActionHintBuilder extends RefCounted
## 行动提示文本统一构建器 — 纯静态工具类
##
## 将所有 Action hover 提示文本的格式化逻辑集中到此处：
##   1. operator 列表 → 人类可读描述行
##   2. Action → {narrative, vector} 字典（主按钮 popup）
##   3. Action + archetype operators → 子行动预览字符串（picker popup）
##
## 消费方：action_button.gd（主按钮 hover）、picker_item.gd（picker 项 hover）


# ── 接口 2：operator 列表 → 描述行 ────────────────────────

## 将一列 BaseOperator 转为 "• {describe_preview()}" 的字符串数组。
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
		var desc: String = op.describe_preview()
		if not desc.is_empty():
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
			var top := op as TimeOperator
			if top.refresh_time or top.day <= 0:
				continue
			if is_repeated:
				lines.append("• 额外耗时 %d 天（重复行动，消耗增加20%%）" % int(top.day))
			else:
				lines.append("• 额外耗时 %d 天" % int(top.day))
		elif op is PoemRewardOperator:
			var desc := op.describe_preview()
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
	
	# 健康→AP 削减提示（通过 SurvivalManager 配置驱动，无削减时不显示）
	var ap_hint := SurvivalManager.get_active_ap_hint()
	if not ap_hint.is_empty():
		var ap_hint_color := SurvivalManager.get_active_ap_hint_color()
		vector_lines.append("[color=%s][font_size=13]%s[/font_size][/color]" % [ap_hint_color, ap_hint])
		Logging.info("ActionHintBuilder.build_action_hint: AP hint='%s' for '%s'" % [ap_hint, action.name])
	
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
## 格式: [预览]\n概率: {n}%成功，\n[成功效果]:\n• {desc}\n[失败效果]:\n• {desc}
## 数据源优先级：
##   success_ops → action.action_results → fallback「成败未卜…」
##   fail_ops    → action.failed_result.operators → fallback「后果难料…」
static func build_sub_action_preview(sub_action: Action, success_ops: Array = [], fail_ops: Array = []) -> String:
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
