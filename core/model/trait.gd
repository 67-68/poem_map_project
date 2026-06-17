class_name Trait extends GameEntity

# name use parent
@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator
@export_enum(
    'RELATION', 'POEM', 'MAIN_ROUTE', 'DISEASE', 'MENTAL_ILLNESS'
) var topic: String

@export_enum(
    'HATE', 'HEARD', 'GOOD', 'CORE',
    'GAN_YE', 'YING_ZHI', 'DENG_GAO', 'HUAI_GU', 'JI_LV', 'SHAN_SHUI',
    'ACUTE', 'CHRONIC', 'DEPRESSION', 'MANIA'
) var specific_topic: String # 为了社交系统准备；诗词类型也复用此字段

@export var _relate_to: ENUMS.RELATION_TARGET = -1
var relate_to: String:
    get: return ENUMS.to_relation_str(_relate_to)
@export var lasting_xun: int # 这个不是说可以last多少，而是当前last了多少

# 内生的效果：自己进化和持续的影响
@export var trait_effect_operations: Array[PropertyOperator] = []

func operate_continuous_effect():
    for op in trait_effect_operations:
        op.operate()