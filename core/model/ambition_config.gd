class_name AmbitionData extends GameEntity

# name use parent
# Description also use parent
@export var underscored_prop: String = '' # 最多三个会被展示

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

# buff
@export var buffer_to_prop: DictMultiplyOperator
# buffer to property; 会在属性增加的时候被查找来计算增益
@export var buffer_to_region: DictMultiplyOperator
# 在某个地区干某件事的时候属性增加
# {"area": {"type_of_point": 1.5} } 在某个area，获取type_of_point类型点数，增强0.5倍
@export var buff_description: String = ""
# 未来可能需要做多个阶段的buff，不然玩家会在一个地方一直逗留
@export var ambition_traits: Array[String] = [] # 这里存储字符串，实际上从总trait数据库查找内容
@export var ambition_trais_comes_from := PlayerState.Traits

# deadline
@export var start_year: float = Global.start_year
@export var deadline: float = Global.end_year
@export var deadline_fail_result: Array[StatOperator] = []
@export var deadline_warning: String = ''

func get_stage_perception() -> String:
    return staged_perceptions[current_stage].perception