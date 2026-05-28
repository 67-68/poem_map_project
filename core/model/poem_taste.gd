@tool
class_name PoemTaste extends Resource

# 诗歌品味配置：定义了诗歌类型偏好和对应的结果处理
@export var uuid: String
@export var _accepted_poem_types: Array[ENUMS.POEM_TYPE] = [] # e.g. ["yan_ye", "ying_zhi"]
var accepted_poem_types: Array:
    get():
        return _accepted_poem_types.map(func(t: ENUMS.POEM_TYPE) -> Array: return ENUMS.POEM_TYPE.keys()[t])

@export var lowest_poem_level := 0
@export var accepted_result: ChoiceResult = ChoiceResult.new()
@export var rejected_result: ChoiceResult = ChoiceResult.new()
@export var not_entered_result: ChoiceResult = ChoiceResult.new()
