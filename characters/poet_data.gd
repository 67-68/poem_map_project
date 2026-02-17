class_name PoetData extends WorldEvent

@export var birth_year: float
@export var death_year: float
@export var path_point_keys: Array = []
static var repo_id = "POET_REPO"
# 这里解析的东西是一个诗人的Note
# 要求Property内存在birth, death, optional[color]
# 也是一个Concept的Concept_Core_Node(会生成一个箱子收纳)

# path 就是这个Concept内的东西; property need to contain 'position": { x: .., y: .. }'
func _init(notes: Dictionary):
	super._init(notes)
	var properties = notes.get('properties',{})
	birth_year = properties.get("birth", 0.0)
	death_year = properties.get('death',1.0)

func get_rich_poet():
	return Util.colorize_underlined_link(name,Color.GRAY,uuid)
