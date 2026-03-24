class_name Action extends GameEntity
# 这里就是场景化行动库的datamodel

# icon: use parent
# name: use parent
# description: use parent

@export var _action_tags: Array[ENUMS.ACTION_TAGS] = []
var action_tags: Array[String]:
	get: 
		var result: Array[String] = []
		for tag in _action_tags:
			result.append(ENUMS.to_str(tag))
		return result

@export var action_results: Array[BaseOperator]
@export var aciton_requirements: Array[BaseRequirements]