class_name DebugView extends Control

@export var debug_view_path := ""
var debug_view_map := {}

func _ready() -> void:
	if not debug_view_path: 
		Logging.err("do not found debug view path. Check the editor")
		return
	
	var cls = load(debug_view_path)
	var script: GDScript = cls.new()

	var debug_index := 0

	if not script.has_method('create_debug_view'):
		Logging.err("do not found debug view path. Check the editor")
		return
	
	var view: Node
	while true:
		view = script.create_debug_view(debug_index)
		if not view:
			view.free()
			break
		debug_view_map[str(debug_index)] = view
		$HFlowContainer.add_child(view)
		debug_index += 1
	Logging.info('generate %s views' % (debug_index-1))