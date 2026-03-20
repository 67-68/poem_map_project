class_name EventOption extends GameEntity

var is_disabled := false
var disabled_reason := ""
var effect

var double_check := false
var double_check_reason := ''

var choice_result: ChoiceResult
var property_requirement: PropertyRequirement = null
# 使用description作为button text

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	is_disabled = data.get('is_disabled',props.get('is_disabled',true))
	disabled_reason = data.get('disabled_reason',props.get('disabled_reason',''))
	if not disabled_reason: data.get('reason',props.get('reason',''))
	effect = data.get('effect',props.get('effect','effect_placeholder'))
	double_check = data.get('double_check',props.get('double_check',false))
	double_check_reason = data.get('double_check_reason',props.get('double_check_reason',''))

	choice_result = PropParser.parse_and_create_cls(ChoiceResult,data,true,'choice_result')
	if not choice_result:
		Logging.info('create a choice without result %s; it can not trigger furthur analogue; notice!' % name)
	var property_requirement_ = PropParser.parse_any(data,true,'property_requirement')
	if property_requirement_: property_requirement = PropertyRequirement.new(property_requirement_)