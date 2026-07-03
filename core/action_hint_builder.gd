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


# ── 接口 1：Action → {narrative, vector} ──────────────────

## 为行动按钮的主 hover popup 构建叙事层 + 向量层文本。
## @param action: 目标 Action 资源
## @param is_locked: 是否处于灰化锁定态（影响叙事层前缀）
## @return { "narrative": String, "vector": String }
static func build_action_hint(action: Action, is_locked: bool) -> Dictionary:
	if not action:
		Logging.err("ActionHintBuilder.build_action_hint: action is null")
		return { "narrative": "（无数据）", "vector": "" }
	
	# ── 叙事层 ──
	var narrative: String = action.description if not action.description.is_empty() else "（无叙述）"
	
	if is_locked and not action.dynamic_failed_hint.is_empty():
		narrative = "[color=#cc6666]🔒 %s[/color]\n\n%s" % [action.dynamic_failed_hint, narrative]
		Logging.info("ActionHintBuilder.build_action_hint: locked narrative for '%s'" % action.name)
	elif not is_locked and not action.success_hint.is_empty():
		narrative = "[color=#66cc66]✓ %s[/color]\n\n%s" % [action.success_hint, narrative]
		Logging.info("ActionHintBuilder.build_action_hint: unlocked with success_hint for '%s'" % action.name)
	
	# ── 向量层 ──
	var vector_lines: Array[String] = []
	
	# 概率行（非 100% 时显示）
	var prob: int = action.get_possibility_int()
	if prob < 100:
		vector_lines.append("[color=gray][font_size=13]概率: %d%%[/font_size][/color]" % prob)
		Logging.info("ActionHintBuilder.build_action_hint: possibility=%d for '%s'" % [prob, action.name])
	
	# 前提
	if not action.aciton_requirements.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 前提 ━━━[/font_size][/color]")
		for req in action.aciton_requirements:
			var desc: String = req.describe_requirement() if req.has_method("describe_requirement") else ""
			if not desc.is_empty():
				vector_lines.append("• " + desc)
		Logging.info("ActionHintBuilder.build_action_hint: %d requirements for '%s'" % [action.aciton_requirements.size(), action.name])
	
	# 成功结果
	if not action.action_results.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
		var success_lines := build_operator_preview(action.action_results)
		vector_lines.append_array(success_lines)
		Logging.info("ActionHintBuilder.build_action_hint: %d action_results → %d lines for '%s'" % [action.action_results.size(), success_lines.size(), action.name])
	
	# 失败结果（如有）
	if action.failed_result and not action.failed_result.operators.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 失败 ━━━[/font_size][/color]")
		var fail_lines := build_choice_result_preview(action.failed_result)
		vector_lines.append_array(fail_lines)
		Logging.info("ActionHintBuilder.build_action_hint: %d failed_result ops → %d lines for '%s'" % [action.failed_result.operators.size(), fail_lines.size(), action.name])
	
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
	
	# ── 成功效果 ──
	var success_descs: Array[String] = []
	# 优先级 1: 外部传入的 archetype success_ops
	if not success_ops.is_empty():
		success_descs = build_operator_preview(success_ops)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 使用 archetype success_ops (%d ops → %d descs)" % [sub_action.name, success_ops.size(), success_descs.size()])
	# 优先级 2: action.action_results（.tres 级别 operators）
	elif sub_action.action_results and not sub_action.action_results.is_empty():
		success_descs = build_operator_preview(sub_action.action_results)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 使用 action_results (%d ops → %d descs)" % [sub_action.name, sub_action.action_results.size(), success_descs.size()])
	
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
	# 优先级 1: 外部传入的 archetype fail_ops
	if not fail_ops.is_empty():
		fail_descs = build_operator_preview(fail_ops)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 使用 archetype fail_ops (%d ops → %d descs)" % [sub_action.name, fail_ops.size(), fail_descs.size()])
	# 优先级 2: action.failed_result.operators（.tres 级别 operators）
	else:
		var failed_result: ChoiceResult = sub_action.failed_result
		if failed_result and failed_result.operators and not failed_result.operators.is_empty():
			fail_descs = build_operator_preview(failed_result.operators)
			Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' 使用 failed_result.operators (%d ops → %d descs)" % [sub_action.name, failed_result.operators.size(), fail_descs.size()])
	
	if fail_descs.is_empty():
		lines.append("[失败效果]: 后果难料…")
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' fail 无有效 operator，使用 fallback" % sub_action.name)
	else:
		lines.append("[失败效果]:")
		for d in fail_descs:
			lines.append(d)
		Logging.info("ActionHintBuilder.build_sub_action_preview: sub_action='%s' fail preview: %d lines" % [sub_action.name, fail_descs.size()])
	
	return "\n".join(lines)
