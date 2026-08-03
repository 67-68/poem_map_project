class_name Note extends GameEntity

@export var requirement: BaseRequirements = BaseRequirements.new()
# name and description use parent
# name: the title of the note
# description: some part of a poem to demonstrate the situation
@export var description_explanation: String = "" # explain the poem in plain text

@export var note_narrative: String = "" # narrative,literary text as a after note to previous life
@export var note_explanation: String = "" # small grey text to explain the note using game mechanic
@export var triggered: bool = false # if triggered then can not be trigger again and should be demonstrated
@export var note_related_demonstration: String = "" # 查表实例化场景
## 当叙事栈+队列总条目数 >= 此值时触发笔记。0 = 禁用此 StackSize 通道。
## 此通道与 requirement 互斥：threshold > 0 的 Note 不走 Property/Flag/Trait 钩子。
@export var trigger_on_stack_queue_threshold: int = 0

func get_demonstration_address():
    var table = {
        "tutorial_scroll": "res://ui/tutorial_scroll.tscn"
    }

    return table.get(note_related_demonstration)