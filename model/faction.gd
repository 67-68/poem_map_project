class_name Faction extends GameEntity
@export var nominal_ruler: String    # 存uuid
@export var actual_ruler: String     # 存uuid
@export var prestige: float          # 威望
@export var finance: float           # 财政
@export var primary_ethnicity: String # 主体民族
@export var map_color: Color         # 势力基准色
@export var provinces: Array[String] # 州府ID列表
@export var capital: String          # 首都ID

func _init(data: Dictionary = {}):
	# 首先调用基类的反序列化逻辑
	super._init(data)
	if data.is_empty(): return

	var props = data.get("properties", data.get("property", {}))
	
	# 1. 基础属性解析
	nominal_ruler = str(props.get("nominal_ruler", ""))
	actual_ruler = str(props.get("actual_ruler", ""))
	prestige = float(props.get("prestige", 100.0))
	finance = float(props.get("finance", 0.0))
	primary_ethnicity = props.get("primary_ethnicity", "汉")
	capital = str(props.get("capital", ""))

	# 2. 颜色解析 (支持 "#ffffff" 字符串或 [r,g,b,a] 数组)
	var raw_color = props.get("map_color")
	if raw_color is String:
		map_color = Color.from_string(raw_color, Color.WHITE)
	elif raw_color is Array:
		# 容错处理：确保数组长度足够
		var r = raw_color[0] if raw_color.size() > 0 else 1.0
		var g = raw_color[1] if raw_color.size() > 1 else 1.0
		var b = raw_color[2] if raw_color.size() > 2 else 1.0
		var a = raw_color[3] if raw_color.size() > 3 else 1.0
		map_color = Color(r, g, b, a)
	else:
		map_color = Color(0.2, 0.6, 0.4, 1.0) # 默认青绿

	# 3. 领土列表赋值
	var raw_provs = props.get("provinces", [])
	provinces.assign(raw_provs)
