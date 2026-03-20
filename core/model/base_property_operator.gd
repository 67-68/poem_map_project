class_name BasePropertyOperator extends GameEntity

func _init(data: Dictionary = {}):
	super._init(data)

func compare(data) -> bool:
	if data:
		return true
	return false