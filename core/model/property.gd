class_name Property extends GameEntity

# uuid, name, description, icon都使用父类的
@export var val: int = 0
@export var hard_max: int = -1       # 硬上限，-1 = 无限制；append_stat/set_stat_val 会 clamp 到此值
@export var soft_max: int = -1       # 软上限，-1 = 无限制；供 SurvivalManager 参考何时触发减少/溢出
@export var decay_threshold: int = -1  # 衰减阈值，-1 = 无衰减；SurvivalManager.decay() 使用的阈值
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

# 强制设值，跳过 hard_max 检查（给 debug/force_set_stat_val 用）
func force_set_val(new_val: int) -> void:
	val = new_val
