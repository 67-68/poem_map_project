class_name Trait extends GameEntity

# name use parent
@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator
@export var lasting_xun: int
@export var operators: Array[ConditionalOperator] = []

func operate():
    for op in operators:
        op.operate()