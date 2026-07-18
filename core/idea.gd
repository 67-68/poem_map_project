@tool
class_name Idea extends GameEntity

@export var idea_buffs: Array[BaseOperator] = []

@export var current_idea_level: int = -1 # 上限为 size(idea_buff-1) TODO: save to game save data

@export var idea_demonstrations: Array[String] = [] # length save as idea buffs

@export var idea_cost_name: String = 'xing' # name of prop the idea cost
@export var idea_cost_amount: int = 50
@export var counter_idea: String = ''

func increase_idea_level():
    if idea_buffs.is_empty():
        Logging.err("Idea.increase_idea_level: idea_buffs 为空，无法提升")
        return

    var next_level := current_idea_level + 1
    if next_level >= idea_buffs.size():
        Logging.warn("Idea.increase_idea_level: 已达上限 level=%d, buffs=%d，跳过" % [current_idea_level, idea_buffs.size()])
        return

    current_idea_level = next_level
    var buff := idea_buffs[next_level]
    if buff:
        _inject_source_and_operate(buff)
    else:
        Logging.err("Idea.increase_idea_level: idea_buffs[%d] 为 null" % next_level)


func _inject_source_and_operate(buff: BaseOperator) -> void:
    if buff is BuffOperator:
        buff.source_uuid = uuid
        Logging.info("Idea: 执行 buff — type='%s', named_key='%s'" % [buff.modifier_type, buff.named_amount_key])
        buff.operate()
    elif buff is MultiBuffOperator:
        buff.source_uuid = uuid
        Logging.info("Idea: 执行复合 buff (MultiBuffOperator, %d 子 buff)" % buff.buffs.size())
        buff.operate()
    else:
        Logging.warn("Idea: 未知 buff 类型 %s，尝试直接调用 operate" % buff.get_class())
        buff.operate()


func _inject_source_and_deactivate(buff: BaseOperator) -> void:
    if buff is BuffOperator:
        buff.source_uuid = uuid
        Logging.info("Idea: 清理 buff — type='%s', named_key='%s'" % [buff.modifier_type, buff.named_amount_key])
        buff.on_exit({})
    elif buff is MultiBuffOperator:
        buff.source_uuid = uuid
        Logging.info("Idea: 清理复合 buff (MultiBuffOperator, %d 子 buff)" % buff.buffs.size())
        buff.on_exit({})
    else:
        Logging.warn("Idea: 未知 buff 类型 %s，尝试直接调用 on_exit" % buff.get_class())
        buff.on_exit({})


func deactivate():
    if current_idea_level < 0:
        Logging.debug("Idea.deactivate: 无已激活 buff (level=%d)，跳过清理" % current_idea_level)
        return

    if idea_buffs.is_empty():
        Logging.warn("Idea.deactivate: idea_buffs 为空但 level=%d，强制重置" % current_idea_level)
        current_idea_level = -1
        return

    var count := 0
    for i in range(min(current_idea_level + 1, idea_buffs.size())):
        var buff := idea_buffs[i]
        if buff:
            Logging.info("Idea.deactivate: 清理 buff[%d]: %s" % [i, buff.get_class()])
            _inject_source_and_deactivate(buff)
            count += 1
        else:
            Logging.warn("Idea.deactivate: idea_buffs[%d] 为 null，跳过" % i)

    Logging.info("Idea.deactivate: 清理完成，%d 个 buff 已移除，level=%d→-1" % [count, current_idea_level])
    current_idea_level = -1
