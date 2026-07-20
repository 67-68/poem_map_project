@tool
class_name DeathEvent extends RandomEvent

@export var death_reason: String = ''
@export var death_tutorial: String = ''
@export var drained_resource_type: String = ''

## 舞台置景：将 death_reason / death_tutorial 注入 GameState，
## 供 SystemOperator (death_hint 为空时) 和 TombStoneScreen 读取。
func on_enter(context: Dictionary) -> void:
    Logging.info('DeathEvent.on_enter: injecting death_reason="%s" death_tutorial="%s"' % [death_reason, death_tutorial])
    GameState.death_reason = death_reason
    GameState.death_tutorial = death_tutorial
    GameState.drained_resource_type = drained_resource_type
    super.on_enter(context)