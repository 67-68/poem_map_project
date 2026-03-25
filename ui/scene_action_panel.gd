class_name SceneActionPanel extends VBoxContainer
# 这是更加小的那个直接的button，不是上层承载他们的scroll

@export var action: Action

func initialize(action_: Action = null): # 这里的info未来会用来做非对称信息
	#breakpoint
	if action_:
		action = action_
		$ActionOutcomeLabel.text = action.name
		$ActionTitleLabel.text = action.description
		$TextureRect.texture = action.icon
	else: 
		Logging.err('there\'s no action input in the init of scene action panel!!!')

func _on_button_pressed() -> void:
	#breakpoint
	if action.action_results:
		for r in action.action_results: r.operate()
	
	PlayerState.current_action_tags.append_array(action.action_tags)# 暂时和current action 使用同一个池子
	EventManager.scan_events(0)

	
