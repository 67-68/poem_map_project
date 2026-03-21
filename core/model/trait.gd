class_name Trait extends GameEntity

@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator

func _init(data):
    super._init(data)
    buffer_to_prop = PropParser.parse_and_create_cls(DictMultiplyOperator,data,true,'buffer_to_prop')
    buffer_to_region = PropParser.parse_and_create_cls(DictMultiplyOperator,data,true,'buffer_to_region')
