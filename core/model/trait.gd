class_name Trait extends GameEntity

# name use parent
@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator
@export_enum(
    'RELATION', 'POEM', 'MAIN_ROUTE'
) var topic: String

@export_enum(
    'HATE', 'HEARD', "GOOD", "CORE"
) var specific_topic: String # 为了社交系统准备

@export var _relate_to: ENUMS.RELATION_TARGET = -1
var relate_to: String:
    get: return ENUMS.to_relation_str(_relate_to)
@export var lasting_xun: int

# 内生的效果：自己进化和持续的影响
@export var trait_effect_operations: Array[PropertyOperator] = []

# 内生进化的效果：可能静默进化或者出事件
# 比如醉酒 -> 大醉，但和外部相关的（比如社交）不能这么搞
@export var trait_endogenous_operations: Array[BaseOperator] = []

func operate_continuous_effect():
    for op in trait_effect_operations:
        op.operate()

func operate_endogenous():
    for op in trait_endogenous_operations:
        op.operate()