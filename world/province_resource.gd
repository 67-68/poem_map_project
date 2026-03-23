class_name Territory extends MapMarker

@export var stability: float
@export var capital: String
@export var sub_ids: Array
@export var dirty: bool = true
# 1. 影子变量 (仅供编辑器和策划填表用)
# 用下划线开头，表示它是私有的底层数据，业务代码绝对不要碰它！
@export var _editor_area_tags: Array[ENUMS.AREA_TAGS] = []

# 2. 真实属性 (供你的所有业务逻辑和老虎机调用)
# 不加 @export，它是纯粹的代码接口。声明为 Array[String]！
var area_tags: Array[String]:
	get:
		# 完美继承你的优美 map 语法，且绝对不会死循环！
		return _editor_area_tags.map(func(tag): return ENUMS.to_str(tag))

func _get_deprecated_position():
	# 🔴 Fail Loudly: 在编辑器和运行时直接喷红字
	if position_dirty:
		push_error("🚨 [DEPRECATED] 试图访问 Territory.position！像素坐标已作废。
		请改用 uv_position 并结合地图尺寸计算。
		错误源自: ", get_stack()[1].source, " 第 ", get_stack()[1].line, " 行")
	else:
		return _position

func _set_deprecated_position(_val):
	if position_dirty:
		self._position = _val

func _init(data):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	stability = float(data.get('stability',props.get('stability',1.0)))
	capital = data.get('capital',props.get('capital','important_city'))
	sub_ids = data.get('sub_ids',props.get('sub_ids',[]))

func merge(other: Territory) -> void:
	tags = other.tags	