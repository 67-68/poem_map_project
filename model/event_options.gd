class_name EventOption extends Resource

@export var description := ''
@export var is_disabled := false
@export var disabled_reason := ""

@export var double_check := false
@export var double_check_reason := ''

@export var choice_result: ChoiceResult
@export var property_requirement: BaseRequirements = null
# 即使说着Prop requirement,但支持所有类型的requirement

# 使用description作为button text