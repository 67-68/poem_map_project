@tool
class_name MessagerManager extends Node
@export var start = false:
	set(val):
		if is_node_ready() and val:
			start = false
			send_message('luo_zhou','shan_zhou_shan_xi',MSG_TYPE.CRITICAL)

var mesh: MeshInstance2D
var path_cache: Dictionary[Array,Curve2D] = {}

func send_message(from_id, to_id, type: int): # int: MSG_TYPE
	var path: Curve2D
	if path_cache.get([from_id,to_id]):
		path = path_cache.get([from_id,to_id])
	else:
		path = PathVisualizer.get_bezier_path(from_id,to_id)
	var ids = NavigationService.get_uuid_id_path(from_id,to_id)
	
	var messager = preload("res://characters/messager.tscn").instantiate()
	if not mesh:
		Logging.err('do not found mesh')
		return
	messager.initialization(path,ids,mesh)

	Global.request_add_messager.emit(messager)
	apply_msg_type(messager,type)
	messager.start_travel()

static func apply_msg_type(msger: Messager, type: int): # int: MSG_TYPE
	"""
	给msger加上它对应的文字，图片，速度之类的效果
	"""
	var icon_path = ''
	var speed = 10
	var txt := ''

	match type:
		MSG_TYPE.CRITICAL:
			icon_path = 'msg_critical'
			speed = 30
			txt = Util.colorize('圣旨',Color.GOLD)
		MSG_TYPE.NORMAL:
			icon_path = 'msg_normal'
			txt = '消息'
		MSG_TYPE.TAX_WHEAT:
			icon_path = 'msg_tax_wheat'
			speed = 5
			txt = Util.colorize('粮税', Color.WHEAT)
	
	var sprite = msger.get_node('MsgPathFollow/MsgSprite') as Sprite2D
	sprite.texture = IconLoader.get_icon(icon_path)
	msger.speed_px_per_sec = speed
	msger.txt = txt
			
