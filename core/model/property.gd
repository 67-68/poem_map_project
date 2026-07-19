class_name Property extends GameEntity

# uuid, name, description, icon都使用父类的
@export var val: int = 0
@export var hard_max: int = -1       # 硬上限，-1 = 无限制；append_stat/set_stat_val 会 clamp 到此值
@export var soft_max: int = -1       # 软上限，-1 = 无限制；供 SurvivalManager 参考何时触发减少/溢出
@export var decay_threshold: int = -1  # 衰减阈值，-1 = 无衰减；SurvivalManager.decay() 使用的阈值
@export var lowest: int = 0          # 🆕 最低允许值，用于 convert_prop_limit_requirement() 中判断消耗是否越界
@export var not_show_on_left: bool = false  # true 时不显示在左侧玩家面板的 PropGrid 中
@export var staged_perceptions: Array[PropStagedPerceptionData] = []
## 变化量 → 模糊文本映射（用于飘字系统，避免暴露裸数值）
## 在 .tres 中配置，格式: { min_delta, max_delta, gain_text, loss_text }
## 未配置时 fallback 到 get_staged_perception_text()
@export var change_perceptions: Array[PropChangePerceptionData] = []
var default_staged_perception: Array[PropStagedPerceptionData] = _init_default_staged_perception()

static func _init_default_staged_perception() -> Array[PropStagedPerceptionData]:
	var arr: Array[PropStagedPerceptionData] = []
	var p1 = PropStagedPerceptionData.new()
	p1.stage_val = 0; p1.perception_text = TranslationServer.translate("CODE_PROPERTY_599ABC8C57")
	arr.append(p1)
	var p2 = PropStagedPerceptionData.new()
	p2.stage_val = 20; p2.perception_text = TranslationServer.translate("CODE_PROPERTY_ADF6F87B42")
	arr.append(p2)
	var p3 = PropStagedPerceptionData.new()
	p3.stage_val = 40; p3.perception_text = TranslationServer.translate("CODE_PROPERTY_1613904BFA")
	arr.append(p3)
	var p4 = PropStagedPerceptionData.new()
	p4.stage_val = 60; p4.perception_text = "GoodGood"
	arr.append(p4)
	return arr

## 返回当前数值对应的阶段感知文本（最高匹配档位）
## 例如 stage_val=[0,25,50,75], val=60 → 返回 stage_val=50 的文本
## .tres 中按升序配置，代码从高到低匹配确保返回最高档
func get_staged_perception_text() -> String:
	# 从高到低遍历 staged_perceptions，返回最高匹配档位
	for i in range(staged_perceptions.size() - 1, -1, -1):
		var perception = staged_perceptions[i]
		if perception.stage_val <= val:
			return tr(perception.perception_text)

	# fallback 默认感知
	for i in range(default_staged_perception.size() - 1, -1, -1):
		var perception = default_staged_perception[i]
		if perception.stage_val <= val:
			return tr(perception.perception_text)
	
	return tr("CODE_RANGE_REQUIREMENT_EC0D9BDB00")

## 根据变化量 delta 返回描述性文本（用于飘字系统）
## delta > 0: 增加, delta < 0: 减少
## 优先匹配 change_perceptions 配置，未配置时 fallback 到 get_staged_perception_text()

## 获取本地化显示名称
## 将 name 转换为 PROPERTY_NAME_* 翻译 key，通过 tr() 获取中文显示名
## 如果翻译表中没有对应条目，则回退到原始 name
func get_display_name() -> String:
	if name.is_empty():
		return ""
	var key = "PROPERTY_NAME_" + name.to_upper()
	var translated = tr(key)
	# 如果翻译结果等于 key 本身（未找到翻译），则回退到原始 name
	if translated == key:
		# 🆕 name 本身可能是翻译键（如 TRES_INSPIRATION_NAME_0），尝试 tr(name)
		var from_name = tr(name)
		return from_name if from_name != name else name
	return translated
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
			return tr(perception.perception_text)

	# fallback 默认感知
	for i in range(default_staged_perception.size() - 1, -1, -1):
		var perception = default_staged_perception[i]
		if perception.stage_val <= threshold:
			return tr(perception.perception_text)

	return tr("CODE_RANGE_REQUIREMENT_EC0D9BDB00")

# 强制设值，跳过 hard_max 检查（给 debug/force_set_stat_val 用）
func force_set_val(new_val: int) -> void:
	val = new_val

## 安全设值，自动 clamp 到 [0, hard_max] 范围
## hard_max == -1 时只 clamp 到 >= 0
func set_val(new_val: int) -> void:
	var clamped: int = new_val
	if clamped < 0:
		clamped = 0
	if hard_max >= 0 and clamped > hard_max:
		clamped = hard_max
	val = clamped
