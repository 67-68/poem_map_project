class_name Territory extends MapMarker

@export var stability: float
@export var capital: String
@export var sub_ids: Array
@export var dirty: bool = true
# 1. 影子变量 (仅供编辑器和策划填表用)
# 用下划线开头，表示它是私有的底层数据，业务代码绝对不要碰它！

@export var _editor_area_tags: Array[ENUMS.AREA_TAGS] = []
@export var _province_tags: Array[ENUMS.PROVINCES] = []
# 2. 真实属性 (供你的所有业务逻辑和老虎机调用)
# 不加 @export，它是纯粹的代码接口。声明为 Array[String]！
var area_tags: Array[String]:
	get:
		# 完美继承你的优美 map 语法，且绝对不会死循环！
		var result_tags = _editor_area_tags.map(func(tag): return ENUMS.to_str(tag))
		result_tags.append_array(_province_tags.map(func(tag): return ENUMS.to_str(tag)))
		return result_tags

func _get_deprecated_position():
	if position_dirty:
		var stack = get_stack()
		# 必须检查堆栈深度，防止 C++ 调用时越界崩溃！
		if stack.size() > 1:
			push_error("🚨 [DEPRECATED] 试图访问 Territory.position！坐标已作废。源自: %s 第 %d 行" % [stack[1].source, stack[1].line])
		elif not Engine.is_editor_hint(): 
			# 只有在非编辑器环境下才报警告，防止 Inspector 抽风
			push_error("🚨 [DEPRECATED] 试图访问 Territory.position！")
			
	return _position

func _set_deprecated_position(_val):
	if position_dirty:
		self._position = _val

func _init(data = {}):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	stability = float(data.get('stability',props.get('stability',1.0)))
	capital = data.get('capital',props.get('capital','important_city'))
	sub_ids = data.get('sub_ids',props.get('sub_ids',[]))

func merge(other: Territory) -> void:
	tags = other.tags	