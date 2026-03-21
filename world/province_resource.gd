class_name Territory extends WorldEvent

@export var stability: float
@export var capital: String
@export var sub_ids: Array[String]
@export var dirty: bool = true

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
