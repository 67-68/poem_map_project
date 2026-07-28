extends RefCounted
## 事件选项资源可支付性检查器
##
## 输入: ChoiceResult.operators (Array[BaseOperator])
## 输出: { can_afford: bool, reasons: Array[String] }
##
## 检查逻辑按 Operator 类型分发:
##   - PropertyOperator (val < 0): 委托 ActionManager.check_archetype_property_costs()
##   - PropertyOperator (val > 0): 不拦截（溢出在 operate() 中自然 capped）
##   - TraitOperator (REMOVE):        查 PlayerState.has_trait(trait_key)
##   - TraitOperator (ADD):           不拦截（添加总是可行）
##   - 其他 operator:                 不拦截（始终可支付）
##
## 消费方: EventBtn._init_option() — 在 requirement 检查通过后调用

const _TraitOperator = preload("res://core/model/trait_operator.gd")


# ════════════════════════════════════════════════════════════════
# 公开接口
# ════════════════════════════════════════════════════════════════

## 检查一组 operators 在当前玩家状态下是否可支付。
## @param operators: Array[BaseOperator] — 来自 ChoiceResult.operators
## @return Dictionary { can_afford: bool, reasons: Array[String] }
func check(operators: Array) -> Dictionary:
	var reasons: Array[String] = []

	if operators.is_empty():
		Logging.info("[OptionAffordabilityChecker] operators 为空，全部可通过")
		return { "can_afford": true, "reasons": reasons }

	Logging.info("[OptionAffordabilityChecker] 检查 %d 个 operators" % operators.size())

	for i in range(operators.size()):
		var op = operators[i]
		if not op:
			Logging.info("[OptionAffordabilityChecker] operator[%d] 为 null，跳过" % i)
			continue

		# ── 类型分发 ──
		if op is PropertyOperator:
			var prop_reasons := _check_property(op as PropertyOperator, i)
			for r in prop_reasons:
				reasons.append(r)
		elif op is _TraitOperator:
			var trait_reasons := _check_trait(op as _TraitOperator, i)
			for r in trait_reasons:
				reasons.append(r)
		else:
			Logging.info("[OptionAffordabilityChecker] operator[%d] 类型 %s 不检查，跳过" % [i, op.get_class()])

	var can_afford := reasons.is_empty()
	Logging.info("[OptionAffordabilityChecker] 结果: can_afford=%s, %d reasons" % [can_afford, reasons.size()])
	return { "can_afford": can_afford, "reasons": reasons }


# ════════════════════════════════════════════════════════════════
# 内部: PropertyOperator
# ════════════════════════════════════════════════════════════════

func _check_property(pop: PropertyOperator, _idx: int) -> Array[String]:
	if pop.value == 0 or pop.property.is_empty():
		Logging.info("[OptionAffordabilityChecker] PropertyOperator[%d] value=0 或 property 为空，跳过" % _idx)
		return []

	if pop.value >= 0:
		# 决策: 只拦截消耗，收益溢出在 operate() 中自然 capped
		Logging.info("[OptionAffordabilityChecker] PropertyOperator[%d] prop=%s val=+%d 为正，跳过" % [_idx, pop.property, pop.value])
		return []

	Logging.info("[OptionAffordabilityChecker] PropertyOperator[%d] prop=%s val=%d → 委托 ActionManager.check_archetype_property_costs" % [_idx, pop.property, pop.value])

	# 委托现有精确检查（含 modifier 调整 + 精确数值描述）
	var reasons := ActionManager.check_archetype_property_costs([pop])
	Logging.info("[OptionAffordabilityChecker] PropertyOperator[%d] → %d reasons" % [_idx, reasons.size()])
	return reasons


# ════════════════════════════════════════════════════════════════
# 内部: TraitOperator
# ════════════════════════════════════════════════════════════════

func _check_trait(top: _TraitOperator, _idx: int) -> Array[String]:
	var trait_key: String = top.trait_key
	if trait_key.is_empty():
		Logging.info("[OptionAffordabilityChecker] TraitOperator[%d] trait_key 为空，跳过" % _idx)
		return []

	if top.operator != REQ_OPERATOR.CRUD.REMOVE:
		# ADD 总是可行
		Logging.info("[OptionAffordabilityChecker] TraitOperator[%d] ADD '%s'，跳过" % [_idx, trait_key])
		return []

	# REMOVE: 检查玩家是否拥有该 trait
	var has_it: bool = PlayerState.has_trait(trait_key)
	Logging.info("[OptionAffordabilityChecker] TraitOperator[%d] REMOVE '%s', has_trait=%s" % [_idx, trait_key, has_it])

	if not has_it:
		# 查找 trait 中文名
		var trait_obj = Database.get_trait(trait_key)
		var display_name: String = tr(trait_obj.name) if trait_obj and not trait_obj.name.is_empty() else trait_key
		var reason := tr("CODE_OPTION_AFFORDABILITY_CHECKER_0") % display_name  # "未拥有「{trait_name}」"
		Logging.info("[OptionAffordabilityChecker] TraitOperator[%d] 不可支付: '%s'" % [_idx, display_name])
		return [reason]

	Logging.info("[OptionAffordabilityChecker] TraitOperator[%d] 可支付" % _idx)
	return []
