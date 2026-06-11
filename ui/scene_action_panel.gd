class_name SceneActionPanel extends VBoxContainer
# 这是更加小的那个直接的button，不是上层承载他们的scroll

@export var action: SceneAction

func initialize(action_: SceneAction = null): # 这里的info未来会用来做非对称信息
	#breakpoint
	if action_:
		action = action_
		$ActionTitleLabel.text = action.name
		$ActionOutcomeLabel.text = action.description
		$TextureRect.texture = action.icon
	else: 
		Logging.err('there\'s no action input in the init of scene action panel!!!')

func _on_button_pressed() -> void:
	#breakpoint
	if action.action_results:
		for r in action.action_results: r.operate()
	
	# ── Generator 消费 ──
	# 如果 action 上挂载了 generator，每次点击消费一个 operator
	# 全部消费完 → 锁定 action 1 旬（自动解锁）→ 清空 generator
	if action.generator:
		var has_more := action.generator.execute_next()
		if not has_more:
			# Generator 已耗尽，锁定 action 1 旬，清空 generator 引用
			var gen_name := action.generator.name
			var action_type: int = action.generator.action_type
			ActionManager.lock_action(action_type as int, 1)
			action.generator = null
			Logging.info("[SceneActionPanel] generator '%s' 已耗尽，action 锁定 1 旬，generator 已清空" % gen_name)
	
	# 🚀 革新后：不再需要标准化，前缀匹配自动忽略第4级
	for tag in action.action_tags:
		PlayerState.current_action_tags.append(tag)
	var context = {'main_tag': action.main_tag}
	EventManager.scan_events(0, context)
