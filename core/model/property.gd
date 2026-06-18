class_name Property extends GameEntity

# uuid, name, description, icon都使用父类的
@export var val: int = 0
@export var hard_max: int = -1       # 硬上限，-1 = 无限制；append_stat/set_stat_val 会 clamp 到此值
@export var soft_max: int = -1       # 软上限，-1 = 无限制；供 SurvivalManager 参考何时触发减少/溢出
@export var decay_threshold: int = -1  # 衰减阈值，-1 = 无衰减；SurvivalManager.decay() 使用的阈值
@export var staged_perceptions: Array[PropStagedPerceptionData] = []
## 变化量 → 模糊文本映射（用于飘字系统，避免暴露裸数值）
## 在 .tres 中配置，格式: { min_delta, max_delta, gain_text, loss_text }
## 未配置时 fallback 到 get_staged_perception_text()
@export var change_perceptions: Array[PropChangePerceptionData] = []
var default_staged_perception: Array[PropStagedPerceptionData]

func _ready():
	var p1 = PropStagedPerceptionData.new()
	p1.stage_val = 0; p1.perception_text = "初始状态"
	default_staged_perception.append(p1)
	var p2 = PropStagedPerceptionData.new()
	p2.stage_val = 20; p2.perception_text = "成长中"
	default_staged_perception.append(p2)
	var p3 = PropStagedPerceptionData.new()
	p3.stage_val = 40; p3.perception_text = "成熟"
	default_staged_perception.append(p3)
	var p4 = PropStagedPerceptionData.new()
	p4.stage_val = 60; p4.perception_text = "GoodGood"
	default_staged_perception.append(p4)

## 返回当前数值对应的阶段感知文本（最高匹配档位）
## 例如 stage_val=[0,25,50,75], val=60 → 返回 stage_val=50 的文本
## .tres 中按升序配置，代码从高到低匹配确保返回最高档
func get_staged_perception_text() -> String:
	# 从高到低遍历 staged_perceptions，返回最高匹配档位
	for i in range(staged_perceptions.size() - 1, -1, -1):
		var perception = staged_perceptions[i]
		if perception.stage_val <= val:
			return perception.perception_text

	# fallback 默认感知
	for i in range(default_staged_perception.size() - 1, -1, -1):
		var perception = default_staged_perception[i]
		if perception.stage_val <= val:
			return perception.perception_text
	
	return "未知状态"

## 根据变化量 delta 返回描述性文本（用于飘字系统）
## delta > 0: 增加, delta < 0: 减少
## 优先匹配 change_perceptions 配置，未配置时 fallback 到 get_staged_perception_text()
func get_change_perception_text(delta: int) -> String:
	var abs_delta = abs(delta)
	
	# 优先匹配 change_perceptions 区间
	for perception in change_perceptions:
		if perception.min_delta <= abs_delta and abs_delta <= perception.max_delta:
			return perception.get_text(delta)
	
	# fallback: 使用阶段感知文本（当前状态的描述）
	return get_staged_perception_text()

## 根据指定阈值返回对应的阶段感知文本（用于 Alt 预览 requirement 翻译）。
## 例如 threshold=5000，stage_val=[0, 2000, 5000, 10000] → 返回 stage_val=5000 的文本。
## 与 get_staged_perception_text() 不同，此方法基于传入的 threshold 而非 this.val。
func get_staged_perception_at_threshold(threshold: int) -> String:
	# 从高到低遍历 staged_perceptions，返回最高匹配档位
	for i in range(staged_perceptions.size() - 1, -1, -1):
		var perception = staged_perceptions[i]
		if perception.stage_val <= threshold:
			return perception.perception_text

	# fallback 默认感知
	for i in range(default_staged_perception.size() - 1, -1, -1):
		var perception = default_staged_perception[i]
		if perception.stage_val <= threshold:
			return perception.perception_text

	return "未知状态"

# 强制设值，跳过 hard_max 检查（给 debug/force_set_stat_val 用）
func force_set_val(new_val: int) -> void:
	val = new_val
