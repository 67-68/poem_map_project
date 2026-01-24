class_name PoetData

var id: String
var name: String
var color: Color
var birth_year: float
var death_year: float
var path_points: Array[Vector2]

# 手动写个构造函数 (Pydantic 的 parse_obj)
func _init(data: Dictionary):
	id = data.get("id", "unknown")
	name = data.get("name", "无名氏")
	birth_year = data.get("birth", 0.0)
	death_year = data.get('death',1.0)
	color = data.get('color',Color.WHITE)
	path_points = []
	for path in data.get('path',[]):
		path_points.append(Vector2(path['x'],path['y']))