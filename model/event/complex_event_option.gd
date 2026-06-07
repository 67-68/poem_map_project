class_name ComplexEventOption extends EventOption

## @deprecated: 请使用 NarrativeLockRequirement 替代
@export var is_disabled := false
@export var disabled_reason := ""

@export var double_check := false
@export var double_check_reason := ''

func init(context: Dictionary) -> Dictionary:
	# 桥接 is_disabled → NarrativeLockRequirement
	if is_disabled:
		var lock = NarrativeLockRequirement.new()
		lock.failed_hint = disabled_reason if not disabled_reason.is_empty() else "选项已禁用"
		
		if requirement != null:
			var complex = ComplexRequirements.new()
			complex.current_operator = REQ_OPERATOR.LOGIC.AND
			complex.operators = [lock, requirement]
			requirement = complex
		else:
			requirement = lock
	
	return super.init(context)
