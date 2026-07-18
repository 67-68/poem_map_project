class_name SchemaLinterRule extends BaseLinterRule
## Schema检查官
## 只管数据结构对不对（是不是null，数组空不空） 🤓☝️

func _init():
	rule_name = tr("CODE_SCHEMA_LINTER_RULE_3C8A35EC2B")

func execute(event_data: Node) -> void:
	errors.clear()
	warnings.clear()
	
	Logging.info("\n--- Schema检查官开始工作 ---")
	
	# 验证history_events
	if event_data.history_events.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_A043BE5907"))
	else:
		Logging.info("✓ history_events 加载成功 (包含 %d 个事件)" % event_data.history_events.size())
	
	# 验证random_events
	if event_data.random_events.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_DC58ED20ED"))
	else:
		var total_random_events = 0
		for tag_bucket in event_data.random_events:
			total_random_events += event_data.random_events[tag_bucket].size()
		Logging.info("✓ random_events 加载成功 (包含 %d 个事件，分 %d 个标签桶)" % [total_random_events, event_data.random_events.size()])
	
	# 验证end_random_events
	if event_data.end_random_events.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_46647FC669"))
	else:
		Logging.info("✓ end_random_events 加载成功 (包含 %d 个事件)" % event_data.end_random_events.size())
	
	# 验证focused_chat_data
	if event_data.focused_chat_data.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_4388E75BEC"))
	else:
		Logging.info("✓ focused_chat_data 加载成功 (包含 %d 个聊天)" % event_data.focused_chat_data.size())
	
	# 验证ambitions
	if event_data.ambitions.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_5217DB3371"))
	else:
		Logging.info("✓ ambitions 加载成功 (包含 %d 个野心)" % event_data.ambitions.size())
	
	# 验证traits
	if event_data.traits.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_92E5D440AC"))
	else:
		Logging.info("✓ traits 加载成功 (包含 %d 个特质)" % event_data.traits.size())
	
	# 验证properties
	if event_data.properties.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_947D08D6C6"))
	else:
		Logging.info("✓ properties 加载成功 (包含 %d 个属性)" % event_data.properties.size())
	
	# 验证actions
	if event_data.actions.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_FE2059569F"))
	else:
		Logging.info("✓ actions 加载成功 (包含 %d 个动作)" % event_data.actions.size())
	
	# 验证decisions
	if event_data.decisions.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_B4B36D128C"))
	else:
		Logging.info("✓ decisions 加载成功 (包含 %d 个决策)" % event_data.decisions.size())
	
	# 验证decided_events
	if event_data.decided_events.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_73ED188C58"))
	else:
		Logging.info("✓ decided_events 加载成功 (包含 %d 个已决定事件)" % event_data.decided_events.size())
	
	# 验证imaginaries
	if event_data.imaginaries.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_AB67772B4A"))
	else:
		Logging.info("✓ imaginaries 加载成功 (包含 %d 个想象)" % event_data.imaginaries.size())
	
	
	# 验证normal_poem_events
	if event_data.normal_poem_events.is_empty():
		add_error(tr("CODE_SCHEMA_LINTER_RULE_4F195BBC21"))
	else:
		Logging.info("✓ normal_poem_events 加载成功 (包含 %d 个普通诗词事件)" % event_data.normal_poem_events.size())
	
	# 验证flags（通过 Database/DataScanner 填充）
	if not event_data.flags:
		add_warning(tr("CODE_SCHEMA_LINTER_RULE_8247361078"))
	elif event_data.flags.is_empty():
		add_warning(tr("CODE_SCHEMA_LINTER_RULE_1A1F83B77A"))
	else:
		Logging.info("✓ flags 加载成功 (包含 %d 个标志位)" % event_data.flags.size())
	
	Logging.info("--- Schema检查官工作完成 ---\n")
