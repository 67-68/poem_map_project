class_name Action extends GameEntity

@export var _action_tags: Array[StorableItem.TAGS] = []
var action_tags: Array[String]:
	get: return _action_tags.map(func(tag): return StorableItem.to_str(tag))

var action_results: Array[BaseOperator]