class_name SceneActionPanel extends VBoxContainer

@export var action: Action

func _init(action_: Action = null): # 这里的info未来会用来做非对称信息
	if action:
		action = action_
		$ActionOutcomeLabel.text = action.name
		$ActionTitleLabel.text = action.description
		$TextureRect.texture = action.icon
	else: 
		Logging.err('there\'s no action input in the init of scene action panel!!!')

func _on_button_pressed() -> void:
	for r in action.action_results:
		r.operate()
