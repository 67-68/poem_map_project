class_name Property extends GameEntity

# uuid, name, description, icon都使用父类的
@export var val: int = 0
@export var staged_perceptions: Array[PropStagedPerceptionData] = []
var default_staged_perception: Array[PropStagedPerceptionData]

func _ready():
    default_staged_perception.append(PropStagedPerceptionData.new(0, "初始状态"))
    default_staged_perception.append(PropStagedPerceptionData.new(20, "成长中"))
    default_staged_perception.append(PropStagedPerceptionData.new(40, "成熟"))
    default_staged_perception.append(PropStagedPerceptionData.new(60, "GoodGood"))

func get_staged_perception_text() -> String:
    for perception in staged_perceptions:
        if perception.stage_val <= val:
            return perception.perception_text

    for perception in default_staged_perception:
        if perception.stage_val <= val:
            return perception.perception_text
            
    return "未知状态"