class_name OperatorEntry extends Resource

@export var name: String
@export var operator: MultiplyOperator

func _init(data: Dictionary = {}):
	if data.is_empty(): return
	name = data.get("name", "")
	operator = MultiplyOperator.new(data.get("operator", {}))
