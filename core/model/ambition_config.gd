class_name AmbitionData extends GameEntity

# name use parent
# Description also use parent

# stage and text; core part
@export var current_stage := 0
# 抛弃纯粹的属性计算，通过属性来推断阶段
# 因为这样在同时追踪多个属性的时候就不行了
@export var leveled_stages: Array[String] = []
@export var staged_requirements: Array[StagedRequirementData]
# key = each stage, value = complex requirements to next stage
# once complete, find current stage and goto next stage. Update 
# 这里是硬性的属性变化 -> 进度文本变化触发器
@export var staged_perceptions: Array[StagedPerceptionData]
# 类似 {stage1: aaa, stage2: bbb, stage3:ccc}
@export var ambition_traits: Array[String] = [] # 这里存储字符串，实际上从总trait数据库查找内容

# deadline (display only; execution logic removed)
@export var deadline: float = 907.0
@export var deadline_warning: String = ''

func get_stage_perception() -> String:
	if current_stage < 0 or current_stage >= staged_perceptions.size():
		Logging.err("AmbitionConfig: current_stage %d out of bounds [0, %d] for ambition %s" % [current_stage, staged_perceptions.size() - 1, name])
		return "阶段状态未知"
	if not staged_perceptions[current_stage].get('perception'): 
		Logging.err('阶段状态未知: %s' % staged_perceptions[current_stage])
		return "阶段状态未知"
	return staged_perceptions[current_stage].perception
