class_name EventOption extends BaseOption

# 使用description作为button text
@export var choice_result: ChoiceResult
@export var requirement: BaseRequirements = null
@export var emotion_configs: Array[EmotionConfigs] = []

func init(context: Dictionary) -> Dictionary:
    var context_ = context.duplicate()
    if requirement:
        requirement.init(context_)
    if choice_result:
        choice_result.init(context_)
    return context_