class_name DebugView extends Control

@export var debug_script: GDScript = null
var debug_view_map := {}
var btn_map := {}

func _ready() -> void:
	if not debug_script: 
		Logging.err("do not found debug view path. Check the editor")
		return
	
	var instance_script = debug_script.new()
	var debug_index := 0

	if not instance_script.has_method('create_debug_view'):
		Logging.err("do not found func: create_debug_view. Check the editor")
		return
	if not instance_script.has_method('get_actions'):
		Logging.err('do not found func: get_actions. Check the editor')
		return
	
	var view: Node
	while true:
		view = instance_script.create_debug_view(debug_index)
		if not view:
			view.free()
			break
		debug_view_map[str(debug_index)] = view
		$HFlowContainer.add_child(view)
		debug_index += 1
	Logging.info('complete generate %s views' % (debug_index-1))
	create_btns(instance_script)

func create_btns(instance: GDScript):
	# --- actions ---
	var btn: Button
	var actions: Array[ViewTestAction] = instance.get_actions()
	if not actions:
		Logging.info("do not found actions.")
		return
	for action in actions:
		btn = Button.new()
		btn.text = action.description
		btn.pressed.connect(action.callback.bind(debug_view_map))