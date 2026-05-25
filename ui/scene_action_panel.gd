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
	
	# 🔧 标准化标签：确保三段式标签转换为四段式
	for tag in action.action_tags:
		var normalized_tag = TagManager.normalize_3part_depreciated_tag(tag)
		PlayerState.current_action_tags.append(normalized_tag)
	var context = {'main_tag': action.main_tag}
	EventManager.scan_events(0, context)

	
