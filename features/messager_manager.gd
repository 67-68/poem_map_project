@tool
class_name MessagerManager extends Node
@export var start = false:
	set(val):
		if is_node_ready() and val:
			start = false
			var d := MessagerData.new({})
			d.source_id = 'luo_zhou'
			d.target_id = 'you_zhou'
			d.msger_type = MSG_TYPE.CRITICAL
			send_message(d)

var mesh: MeshInstance2D
var path_cache: Dictionary[Array,Curve2D] = {}
var times := []
var sorted_msger_list: Array

var _next_msger_time: float

func _ready():
	sorted_msger_list = Global.msger_data.values()
	sorted_msger_list.sort_custom(func(a, b): return a.year < b.year)
	_next_msger_time = sorted_msger_list[0].year

func _process(_delta):
	if Engine.is_editor_hint():
		return
	#breakpoint
	if Global.year > _next_msger_time:
		Logging.info('messager triggered')
		send_message(DataHelper.find_item_by_filter_list(sorted_msger_list,'year',_next_msger_time))
		_next_msger_time = update_msger_time(_next_msger_time,Global.msger_data.values())


static func update_msger_time(_next_msger_time, data):
	var current_msger_time = _next_msger_time
	for item in data:
		if item.year > _next_msger_time:
			return item.year
	if _next_msger_time  == current_msger_time:
		return 1000000 # 说明到游戏尽头了；找个永远不会被触发的时间

func send_message(msger_data: MessagerData): # int: MSG_TYPE
	var from_id = msger_data.source_id
	var to_id = msger_data.target_id
	var type = msger_data.msger_type
	var path: Curve2D
	
	if path_cache.get([from_id,to_id]):
		path = path_cache.get([from_id,to_id])
	else:
		var mesh_size = Util.get_mesh_instance_size(mesh)
		path = PathVisualizer.get_bezier_path(from_id,to_id,mesh_size.x,mesh_size.y)
	var ids = NavigationService.get_uuid_id_path(from_id,to_id)
	
	var messager = preload("res://characters/messager.tscn").instantiate()
	if not mesh:
		Logging.err('do not found mesh')
		return
	messager.initialization(path,ids,mesh,msger_data)
	messager.travel_end.connect(end_msger.bind(messager))

	Global.request_add_messager.emit(messager)
	# apply msger type 改为msger自己内部执行，在执行完成它之后使用msger data 填充自己
	messager.start_travel()
	
func end_msger(msger):
	Logging.debug('free a mesger')
	msger.queue_free()
