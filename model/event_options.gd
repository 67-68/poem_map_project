class_name EventOption extends Resource

@export var description := ''
@export var is_disabled := false
@export var disabled_reason := ""
@export var effect: Variant

@export var double_check := false
@export var double_check_reason := ''

@export var choice_result: ChoiceResult
@export var property_requirement: PropertyRequirement = null
# 使用description作为button text