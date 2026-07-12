extends Control


func _ready() -> void:
	visible = false
	if not EventBus.has_signal("request_toggle_debug_controller"):
		Logging.err("Controller: EventBus 缺少 signal request_toggle_debug_controller")
		return
	EventBus.request_toggle_debug_controller.connect(_on_toggle_debug_controller)


func _on_toggle_debug_controller() -> void:
	visible = not visible
	if visible:
		$Controller.grab_focus()

func _on_text_submitted(new_text: String) -> void:
	if new_text.split('\n').size() > 1:
		var texts = new_text.split('\n')
		for t in texts:
			parse(t.strip_edges())
		return
	parse(new_text)

func parse(new_text):
	var parts = new_text.split(' ')
	Logging.info('try to execute %s' % new_text)
	if parts.size() < 2 or not parts[1]: return
	match parts[1]:
		'send_signal':
			var sig = EventBus.has_signal(parts[2])
			if not sig:
				Logging.err('do not found signal %s' % parts[2])
				return
			EventBus.emit_signal(parts[2],str_to_var(parts[3]))
		'give_trait':
			var trait_ = Database.get_trait(parts[3])
			if not trait_:
				Logging.err('can not found trait %s ' % parts[3])
				return
			PlayerState.traits.append(trait_.uuid)
		'event_result':
			var ev = Database.resolve(parts[2])
			# 🤓☝️ 鸭子类型：检查对象是否具有事件的必要属性
			if not ev or not ev.has_method("get") or ev.get("uuid") == null or ev.get("options") == null:
				Logging.err('can not found event for %s' % parts[2])
				return
			EventBus.event_shown.emit(ev)
		'add_imaginary':
			EventBus.request_add_imaginary.emit(parts[2])

	if parts[0] == '$':
		if parts.size() >= 3 and parts[1] == 'dsl':
			# $ dsl {consequence_operators} — 直接解析并执行 DSL 操作符
			var dsl_content = new_text.substr(new_text.find('dsl') + 4).strip_edges()
			var operators = MicroDSLParser.parse_consequence_operators(dsl_content)
			Logging.info('Executing DSL: %s, got %d operators' % [dsl_content, operators.size()])
			for op in operators:
				op.operate()
		elif parts.size() >= 3 and parts[1] == 'set_tag':
			# $ set_tag lilinfu — 设置 last_event["target_tag"] 用于测试派系效果
			PlayerState.last_event["target_tag"] = parts[2]
			Logging.info('[Controller] last_event["target_tag"] = "%s"' % parts[2])
		elif parts.size() >= 3 and parts[1] == 'clear_tag':
			# $ clear_tag — 清除 last_event["target_tag"]
			PlayerState.last_event.erase("target_tag")
			Logging.info('[Controller] last_event["target_tag"] 已清除')
		elif parts.size() >= 3 and parts[1] == 'time':
			# $ time <year> — 跳转到指定年份，重建事件队列
			var target_year = float(parts[2])
			Logging.info('Jump to year %s' % target_year)
			TimeService.jump_to(target_year)
		elif parts.size() >= 3 and parts[1] == 'time_clean':
			# $ time_clean <year> — 跳转到指定年份，不触发任何事件
			var target_year = float(parts[2])
			Logging.info('Clean jump to year %s' % target_year)
			TimeService.jump_to_clean(target_year)
		elif parts.size() == 2:
			# $ event_key — 触发事件（原有逻辑）
			EventBus.push_event.emit(parts[1], {})
	elif new_text.begins_with("#"):
		# 🆕 # 前缀 → GDScript 表达式求值
		# 支持任意表达式，如: # PlayerState.set_stat_val("astuteness", 50)
		var expr_str = new_text.substr(1).strip_edges()
		var expression = Expression.new()
		var err = expression.parse(expr_str, ["PlayerState", "GameState", "Database", "EventBus", "TimeService", "GameSave"])
		if err != OK:
			Logging.err("[Controller] 表达式解析失败: %s → %s" % [expr_str, expression.get_error_text()])
			return
		var result = expression.execute([PlayerState, GameState, Database, EventBus, TimeService, GameSave])
		if expression.has_execute_failed():
			Logging.err("[Controller] 表达式执行失败: %s → %s" % [expr_str, expression.get_error_text()])
			return
		Logging.info("[Controller] 表达式执行成功: %s → %s" % [expr_str, str(result)])
	elif parts.size() == 2:
		if GameState.has_method(parts[0]):
			GameState.callv(parts[0],[parts[1]])
		elif Database.has_method(parts[0]):
			Database.callv(parts[0],[parts[1]])
		elif PlayerState.has_method(parts[0]):
			PlayerState.callv(parts[0],[parts[1]])

func _on_button_pressed() -> void:
	#breakpoint
	var current_text = $Controller.text
	if not current_text.is_empty():
		_on_text_submitted(current_text)
		$Controller.text = ""
