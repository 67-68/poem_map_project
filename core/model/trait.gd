class_name Trait extends GameEntity

# name use parent
@export var buffer_to_prop: DictMultiplyOperator
@export var buffer_to_region: DictMultiplyOperator
@export var display_char: String = ""  # 阳刻印章展示字，为空时取 name[0]
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

## 此 trait 对每次行动附加的额外天数惩罚。
## 例如 sprained_ankle=1 时每次行动多扣 1 天。
## 运行时由 PlayerState.get_active_time_penalties() 聚合所有活跃 trait 的惩罚。
@export var time_penalty: int = 0

func operate_continuous_effect():
    for op in trait_effect_operations:
        op.operate()