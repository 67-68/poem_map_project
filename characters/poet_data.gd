class_name PoetData extends MapMarker

@export var birth_year: float
@export var death_year: float
@export var path_point_keys: Array = []
# 这里解析的东西是一个诗人的Note
# 要求Property内存在birth, death, optional[color]
# 也是一个Concept的Concept_Core_Node(会生成一个箱子收纳)
