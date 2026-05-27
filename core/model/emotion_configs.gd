class_name EmotionConfigs extends Resource
# 这个和emotion requirement 不一样，单纯是一个用来校验的数据模型, 其他人操作他

@export var target_imagenary_blueprint: ImaginaryTag # 直接引用ImaginaryTag资源，消灭String查表
@export var context_tags: Array[String] = [] # 专门存上下文，如 ["with_li_bai", "sad"]
@export var requirements: Array[BaseRequirements]