class_name AmbitionData extends GameEntity

# name use parent
# Description also use parent

# stage and text; core part
var current_stage := 0
# 抛弃纯粹的属性计算，通过属性来推断阶段
# 因为这样在同时追踪多个属性的时候就不行了
var leveled_stages = []
var staged_requirements := {}
# key = each stage, value = complex requirements to next stage
# once complete, find current stage and goto next stage. Update 
# 这里是硬性的属性变化 -> 进度文本变化触发器
var staged_perceptions := {}
# 类似 {stage1: aaa, stage2: bbb, stage3:ccc}

# buff
var buffer_to_prop: DictMultiplyOperator
# buffer to property; 会在属性增加的时候被查找来计算增益
var buffer_to_region: DictMultiplyOperator
# 在某个地区干某件事的时候属性增加
# {"area": {"type_of_point": 1.5} } 在某个area，获取type_of_point类型点数，增强0.5倍
var buff_description := ""
# 未来可能需要做多个阶段的buff，不然玩家会在一个地方一直逗留
var ambition_traits = [] # 这里存储字符串，实际上从总trait数据库查找内容

# deadline
var start_year: float = Global.start_year
var deadline: float = Global.end_year
var deadline_fail_result: Array = []
var deadline_warning := ''

func _init(data):
    super._init(data)
    leveled_stages = PropParser.parse_any(data,true,'leveled_stages')
    var staged_requirements_ = PropParser.parse_any(data,true,'staged_requirements')
    if not staged_requirements_:
        staged_requirements_ = {}
        Logging.warn('no staged_requirements for ambition %s' % name)
    for stage_name in staged_requirements_:
        staged_requirements[stage_name] = PropParser.parse_and_create_cls(ComplexRequirements,staged_requirements_,true,stage_name)
    
    var staged_perceptions_ = PropParser.parse_any(data,true,'staged_perceptions')
    if not staged_perceptions_:
        staged_perceptions_ = {}
    staged_perceptions = staged_perceptions_

    buff_description = PropParser.parse_any(data,true,'buff_description') if PropParser.parse_any(data,true,'buff_description') else ''
    buffer_to_prop = PropParser.parse_and_create_cls(DictMultiplyOperator,data,true,'buffer_to_prop') if PropParser.parse_any(data,true,'buffer_to_prop') else null
    buffer_to_region = PropParser.parse_and_create_cls(DictMultiplyOperator,data,true,'buffer_to_region') if PropParser.parse_any(data,true,'buffer_to_region') else null
    ambition_traits = PropParser.parse_any(data,true,'ambition_traits') if PropParser.parse_any(data,true,'ambition_traits') else []

    start_year = PropParser.parse_any(data,true,'start_year') if PropParser.parse_any(data,true,'start_year') else Global.start_year
    deadline = PropParser.parse_any(data,true,'deadline') if PropParser.parse_any(data,true,'deadline') else Global.end_year
    deadline_warning = PropParser.parse_any(data,true,'deadline_warning') if PropParser.parse_any(data,true,'deadline_warning') else ''
    deadline_fail_result = PropParser.parse_any(data,true,'deadline_fail_result') if PropParser.parse_any(data,true,'deadline_fail_result') else []
