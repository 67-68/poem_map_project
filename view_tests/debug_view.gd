class_name DebugView extends Control

@export var debug_script: GDScript = null
var debug_view_map := {}
var btn_map := {}
var _active_script_instance: RefCounted = null 

func create_btns(instance):
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
		$HBoxContainer/ViewTestBtnContainer.add_child(btn)

func _ready() -> void:
	if not debug_script: 
		Logging.err("do not found debug view path. Check the editor")
		return
	
	_active_script_instance = debug_script.new()
	var debug_index := 0

	if not _active_script_instance.has_method('create_debug_view'):
		Logging.err("do not found func: create_debug_view. Check the editor")
		return
	if not _active_script_instance.has_method('get_actions'):
		Logging.err('do not found func: get_actions. Check the editor')
		return
	
	var view: Node
	while true:
		view = _active_script_instance.create_debug_view(debug_index)
		if not view:
			break
		debug_view_map[str(debug_index)] = view
		$HBoxContainer/ViewGallery.add_child(view)
		debug_index += 1
	Logging.info('complete generate %s views' % (debug_index))
	create_btns(_active_script_instance)
