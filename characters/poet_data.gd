extends Resource
class_name PoetData

@export var id: String
@export var title: String
@export var color: Color
@export var birth_year: float
@export var death_year: float
@export var description: String
@export var path_points: Array[PoetLifePoint] = []

# 这里解析的东西是一个诗人的Note
# 要求Property内存在birth, death, optional[color]
# 也是一个Concept的Concept_Core_Node(会生成一个箱子收纳)

# path 就是这个Concept内的东西; property need to contain 'position": { x: .., y: .. }'
func _init(concept_core_note: Dictionary, life_point_notes: Array):
	id = concept_core_note.get("uuid", "unknown")
	title = concept_core_note.get("title", "无名氏")
	description = concept_core_note.get('text','')

	var properties = concept_core_note.get('properties',{})
	birth_year = properties.get("birth", 0.0)
	death_year = properties.get('death',1.0)
	var hex_color = concept_core_note.get('properties', {}).get('color', "#ffffff")
	color = Color.from_string(hex_color, Color.WHITE)
	
	for path in life_point_notes:
		path_points.append(PoetLifePoint.new(path))