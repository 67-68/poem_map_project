class_name SchemaLinterRule extends BaseLinterRule
## Schema检查官
## 只管数据结构对不对（是不是null，数组空不空） 🤓☝️

func _init():
	rule_name = "Schema检查官"

func execute(event_data: Node) -> void:
	errors.clear()
	warnings.clear()
	
	print("\n--- Schema检查官开始工作 ---")
	
	# 验证history_events
	if event_data.history_events.is_empty():
		add_error("history_events 为空")
	else:
		print("✓ history_events 加载成功 (包含 %d 个事件)" % event_data.history_events.size())
	
	# 验证random_events
	if event_data.random_events.is_empty():
		add_error("random_events 为空")
	else:
		var total_random_events = 0
		for tag_bucket in event_data.random_events:
			total_random_events += event_data.random_events[tag_bucket].size()
		print("✓ random_events 加载成功 (包含 %d 个事件，分 %d 个标签桶)" % [total_random_events, event_data.random_events.size()])
	
	# 验证end_random_events
	if event_data.end_random_events.is_empty():
		add_error("end_random_events 为空")
	else:
		print("✓ end_random_events 加载成功 (包含 %d 个事件)" % event_data.end_random_events.size())
	
	# 验证focused_chat_data
	if event_data.focused_chat_data.is_empty():
		add_error("focused_chat_data 为空")
	else:
		print("✓ focused_chat_data 加载成功 (包含 %d 个聊天)" % event_data.focused_chat_data.size())
	
	# 验证ambitions
	if event_data.ambitions.is_empty():
		add_error("ambitions 为空")
	else:
		print("✓ ambitions 加载成功 (包含 %d 个野心)" % event_data.ambitions.size())
	
	# 验证traits
	if event_data.traits.is_empty():
		add_error("traits 为空")
	else:
		print("✓ traits 加载成功 (包含 %d 个特质)" % event_data.traits.size())
	
	# 验证properties
	if event_data.properties.is_empty():
		add_error("properties 为空")
	else:
		print("✓ properties 加载成功 (包含 %d 个属性)" % event_data.properties.size())
	
	# 验证actions
	if event_data.actions.is_empty():
		add_error("actions 为空")
	else:
		print("✓ actions 加载成功 (包含 %d 个动作)" % event_data.actions.size())
	
	# 验证decisions
	if event_data.decisions.is_empty():
		add_error("decisions 为空")
	else:
		print("✓ decisions 加载成功 (包含 %d 个决策)" % event_data.decisions.size())
	
	# 验证decided_events
	if event_data.decided_events.is_empty():
		add_error("decided_events 为空")
	else:
		print("✓ decided_events 加载成功 (包含 %d 个已决定事件)" % event_data.decided_events.size())
	
	# 验证imaginaries
	if event_data.imaginaries.is_empty():
		add_error("imaginaries 为空")
	else:
		print("✓ imaginaries 加载成功 (包含 %d 个想象)" % event_data.imaginaries.size())
	
	# 验证legendary_poems
	if event_data.legendary_poems.is_empty():
		add_error("legendary_poems 为空")
	else:
		print("✓ legendary_poems 加载成功 (包含 %d 个传奇诗词)" % event_data.legendary_poems.size())
	
	# 验证normal_poem_events
	if event_data.normal_poem_events.is_empty():
		add_error("normal_poem_events 为空")
	else:
		print("✓ normal_poem_events 加载成功 (包含 %d 个普通诗词事件)" % event_data.normal_poem_events.size())
	
	# 验证flags（通过 Database/DataScanner 填充）
	if not event_data.flags:
		add_warning("flags 为 null (Database 尚未填充 flags 数据)")
	elif event_data.flags.is_empty():
		add_warning("flags 为空 (Database.flags 无内容)")
	else:
		print("✓ flags 加载成功 (包含 %d 个标志位)" % event_data.flags.size())
	
	print("--- Schema检查官工作完成 ---\n")