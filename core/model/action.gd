class_name Action extends GameEntity
# 这里就是场景化行动库的datamodel

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
var action_tags: Array[String]:
	get: return _action_tags.map(func(tag): return ENUMS.to_str(tag))

@export var action_results: Array[BaseOperator]
@export var aciton_requirements: Array[BaseRequirements]