class_name Disease extends Trait

# 诊断事件 key — trait 获得时触发 guarantee_next
@export var on_enter_event: String = ""

# 进展目标：达到 progression_xun 后替换为此 trait
@export var progression_target: String = ""
@export var progression_xun: int = 0

# 选项劫持 Provider（如狂症的 ManiaProvider）
@export var hijack_provider: BaseProvider = null
