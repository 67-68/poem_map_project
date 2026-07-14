@tool
class_name Idea extends GameEntity

@export var idea_buffs: Array[BuffOperator] = []

@export var current_idea_level: int = -1 # 上限为 size(idea_buff-1) TODO: save to game save data

@export var idea_demonstrations: Array[String] = [] # length save as idea buffs

@export var idea_cost_name: String = 'xing' # name of prop the idea cost
@export var idea_cost_amount: int = 50
@export var counter_idea: String = ''

func increase_idea_level():
    """提升一级，解锁更多一个buff，立即 operate 对应 buff"""
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
        Logging.info("Idea.increase_idea_level: 等级 %d→%d，执行 buff: '%s'=%+d" % [next_level - 1, next_level, buff.prop_name, buff.amount])
        buff.operate()
    else:
        Logging.err("Idea.increase_idea_level: idea_buffs[%d] 为 null" % next_level)


func deactivate():
    """遍历 0..current_idea_level 所有已解锁 buff，on_exit 清理，重置 level 为 -1"""
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
            Logging.info("Idea.deactivate: 清理 buff[%d]: '%s'=%+d（反转=%+d）" % [i, buff.prop_name, buff.amount, -buff.amount])
            buff.on_exit({})
            count += 1
        else:
            Logging.warn("Idea.deactivate: idea_buffs[%d] 为 null，跳过" % i)

    Logging.info("Idea.deactivate: 清理完成，%d 个 buff 已移除，level=%d→-1" % [count, current_idea_level])
    current_idea_level = -1