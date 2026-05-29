class_name StateTransistor extends Resource

@export var uuid: String
@export var target_resource_urn: String
@export var transist_value: String
@export var current_resource_urn: String
@export var triggered_event_key: String
@export var requirements: BaseRequirements
@export var operators: Array[BaseOperator]


func transition():
	# ── Phase 1: 需求检查 ────────────────────────────────────────────
	if requirements:
		if not requirements.compare(PlayerState):
			Logging.debug('state_transistor: requirements not met for %s, transition skipped' % target_resource_urn)
			return
	else:
		Logging.warn('state_transistor: no requirements set for %s, allowing transition' % target_resource_urn)

	Logging.info('state_transistor: transition started for target %s' % target_resource_urn)

	# ── Phase 2: 解析目标 URN ────────────────────────────────────────
	var target_parsed = URN.parse_urn(target_resource_urn)
	if target_parsed.is_empty():
		Logging.err('state_transistor: failed to parse target URN: %s' % target_resource_urn)
		return

	var target_resource_type: String = target_parsed.get('type', '')
	var target_resource_key: String = target_parsed.get('resource_id', '')

	if target_resource_key.is_empty():
		Logging.err('state_transistor: no resource_id in target URN: %s' % target_resource_urn)
		return

	Logging.info('state_transistor: target type=%s, key=%s' % [target_resource_type, target_resource_key])

	# 解析 current_resource_urn（可选，仅用于日志/校验上下文）
	if not current_resource_urn.is_empty():
		var current_parsed = URN.parse_urn(current_resource_urn)
		if current_parsed.is_empty():
			Logging.warn('state_transistor: failed to parse current_resource_urn: %s' % current_resource_urn)
		else:
			Logging.debug('state_transistor: current resource type=%s, key=%s' % [current_parsed.get('type', ''), current_parsed.get('resource_id', '')])

	# ── Phase 3: 执行状态转移 ────────────────────────────────────────
	match target_resource_type:
		'flag':
			_apply_flag_transition(target_resource_key)
		'trait':
			_apply_trait_transition(target_resource_key)
		_:
			Logging.warn('state_transistor: unhandled resource type "%s" for %s, falling back to generic URN lookup' % [target_resource_type, target_resource_urn])
			var resource = URN.get_resource_through_urn(target_resource_urn)
			if resource:
				Logging.info('state_transistor: loaded resource via URN lookup: %s (%s)' % [target_resource_urn, resource.get_class()])
			else:
				Logging.err('state_transistor: could not load resource for URN: %s' % target_resource_urn)

	# ── Phase 4: 执行后效 Operators ──────────────────────────────────
	_execute_operators()

	# ── Phase 5: 触发链式事件 ────────────────────────────────────────
	_trigger_event()

	Logging.info('state_transistor: transition completed for %s' % target_resource_urn)


# =============================================================================
# 内部方法
# =============================================================================

func _apply_flag_transition(flag_key: String) -> void:
	"""
	对 flag 类型的资源执行值转移。
	
	transist_value 格式约定:
	  - '=value'  → SET 操作，调用 set_flag()
	  - '^value'  → APPEND 操作，调用 append_flag()
	  - ''/null   → 隐式清空（通过 set_flag 的零值擦除机制）
	"""
	if transist_value.is_empty():
		PlayerState.set_flag(flag_key, transist_value)
		Logging.info('state_transistor: flag %s set with empty value (cleared via zero-value erase)' % flag_key)
		return

	if transist_value.begins_with('='):
		var set_val = transist_value.substr(1)
		PlayerState.set_flag(flag_key, set_val)
		Logging.info('state_transistor: flag %s SET to "%s"' % [flag_key, set_val])
	else:
		# 非 '=' 前缀 → APPEND 操作，去掉第一个字符后追加
		var append_val = transist_value.substr(1)
		if append_val.is_empty():
			Logging.warn('state_transistor: append value is empty after stripping prefix for flag %s, skip' % flag_key)
			return
		PlayerState.append_flag(flag_key, append_val)
		Logging.info('state_transistor: flag %s APPEND by "%s"' % [flag_key, append_val])


func _apply_trait_transition(trait_key: String) -> void:
	"""
	对 trait 类型的资源执行状态转移。
	
	语义:
	  - transist_value 非空 → ADD trait（激活）
	  - transist_value 为空 → REMOVE trait（清除）
	  - current_resource_urn 已设置且可解析 → 自动移除旧 trait（替换语义）
	"""
	# 如果有旧 trait（current_resource_urn），先移除它（替换语义）
	if not current_resource_urn.is_empty():
		var current_parsed = URN.parse_urn(current_resource_urn)
		if not current_parsed.is_empty():
			var current_key: String = current_parsed.get('resource_id', '')
			if not current_key.is_empty():
				PlayerState.remove_trait(current_key)
				Logging.info('state_transistor: old trait %s REMOVED (replaced by %s)' % [current_key, trait_key])
	
	# 根据 transist_value 决定 add 还是 remove
	if transist_value and not transist_value.is_empty():
		PlayerState.add_trait(trait_key)
		Logging.info('state_transistor: trait %s ADDED' % trait_key)
	else:
		PlayerState.remove_trait(trait_key)
		Logging.info('state_transistor: trait %s REMOVED' % trait_key)


func _execute_operators() -> void:
	if operators.is_empty():
		Logging.debug('state_transistor: no operators to execute')
		return

	Logging.info('state_transistor: executing %d operators' % operators.size())
	for i in operators.size():
		var op = operators[i]
		if op:
			op.operate()
			Logging.debug('state_transistor: operator[%d] (%s) executed' % [i, op.get_class()])
		else:
			Logging.warn('state_transistor: operator[%d] is null, skipping' % i)


func _trigger_event() -> void:
	if triggered_event_key.is_empty():
		Logging.debug('state_transistor: no triggered_event_key set, skip event trigger')
		return

	Logging.info('state_transistor: triggering event: %s' % triggered_event_key)
	EventBus.request_event_key.emit(triggered_event_key, {})
