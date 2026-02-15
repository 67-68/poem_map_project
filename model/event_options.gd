class_name EventOption extends GameEntity

var is_disabled := true
var disabled_reason := ""
var effect

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	is_disabled = data.get('is_disabled',props.get('is_disabled',true))
	disabled_reason = data.get('disabled_reason',props.get('disabled_reason',''))
	effect = data.get('effect',props.get('effect','effect_placeholder'))