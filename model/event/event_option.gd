class_name EventOption extends BaseOption

# 使用description作为button text
@export var choice_result: ChoiceResult
@export var requirement: BaseRequirements = null
@export var emotion_configs: Array[EmotionConfigs] = []

# 从 context DSL 解析出的自定义参数，init 时 merge 进 context
var custom_context_params: Dictionary = {}

func init(context: Dictionary) -> Dictionary:
    var context_ = context.duplicate()
    
    # 合并自定义参数（乘法叠加，与 RandomEvent 行为一致）
    if not custom_context_params.is_empty():
        Util.merge_context(context_, custom_context_params)
    
    if requirement:
        requirement.init(context_)
    if choice_result:
        choice_result.init(context_)
    return context_