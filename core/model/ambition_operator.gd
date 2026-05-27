@tool
class_name AmbitionOperator extends BaseOperator

@export var ambition_name: String

func operate():
    PlayerState.set_ambition(ambition_name)
	
