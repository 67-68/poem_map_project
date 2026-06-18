@tool
class_name ConditionalRandomOperator extends BaseOperator

@export var base_chance: int = 50
@export var modifiers: Array[ChanceModifier] = []
@export var success_result: Array[BaseOperator] = []
@export var fail_result: Array[BaseOperator] = []
@export var success_hint: String = ""
@export var failed_hint: String = ""

func operate():
	var effective = base_chance
	for modifier in modifiers:
		if modifier.trait_key == "" or PlayerState.has_trait(modifier.trait_key):
			effective += modifier.delta
			Logging.info("ConditionalRandomOperator: modifier '%s' applied, delta=%d, effective=%d" % [modifier.label, modifier.delta, effective])
		else:
			Logging.info("ConditionalRandomOperator: modifier '%s' skipped (trait '%s' not present)" % [modifier.label, modifier.trait_key])

	effective = clampi(effective, 0, 99)
	var roll = randi() % 100
	Logging.info("ConditionalRandomOperator: base=%d, effective=%d, roll=%d" % [base_chance, effective, roll])

	if roll < effective:
		Logging.info("ConditionalRandomOperator: SUCCESS branch, %d operators" % success_result.size())
		for op in success_result:
			if op:
				op.operate()
			else:
				Logging.err("ConditionalRandomOperator: null operator in success_result")
		if not success_hint.is_empty():
			show_hint(success_hint)
	else:
		Logging.info("ConditionalRandomOperator: FAIL branch, %d operators" % fail_result.size())
		for op in fail_result:
			if op:
				op.operate()
			else:
				Logging.err("ConditionalRandomOperator: null operator in fail_result")
		if not failed_hint.is_empty():
			show_hint(failed_hint)


# ─── 契约方法 ───

func get_referenced_flags() -> Array:
	var result = []
	for op in success_result:
		if op and op.has_method('get_referenced_flags'):
			result.append_array(op.get_referenced_flags())
	for op in fail_result:
		if op and op.has_method('get_referenced_flags'):
			result.append_array(op.get_referenced_flags())
	return result


func get_provided_flags() -> Array:
	var result = []
	for op in success_result:
		if op and op.has_method('get_provided_flags'):
			result.append_array(op.get_provided_flags())
	for op in fail_result:
		if op and op.has_method('get_provided_flags'):
			result.append_array(op.get_provided_flags())
	return result


func get_referenced_traits() -> Array:
	var result = []
	for modifier in modifiers:
		if not modifier.trait_key.is_empty():
			result.append(modifier.trait_key)
	for op in success_result:
		if op and op.has_method('get_referenced_traits'):
			result.append_array(op.get_referenced_traits())
	for op in fail_result:
		if op and op.has_method('get_referenced_traits'):
			result.append_array(op.get_referenced_traits())
	return result


func get_demanded_flags() -> Array:
	var result = []
	for op in success_result:
		if op and op.has_method('get_demanded_flags'):
			result.append_array(op.get_demanded_flags())
	for op in fail_result:
		if op and op.has_method('get_demanded_flags'):
			result.append_array(op.get_demanded_flags())
	return result


func get_demanded_traits() -> Array:
	var result = []
	for modifier in modifiers:
		if not modifier.trait_key.is_empty():
			result.append(modifier.trait_key)
	for op in success_result:
		if op and op.has_method('get_demanded_traits'):
			result.append_array(op.get_demanded_traits())
	for op in fail_result:
		if op and op.has_method('get_demanded_traits'):
			result.append_array(op.get_demanded_traits())
	return result


func get_provided_traits() -> Array:
	var result = []
	for op in success_result:
		if op and op.has_method('get_provided_traits'):
			result.append_array(op.get_provided_traits())
	for op in fail_result:
		if op and op.has_method('get_provided_traits'):
			result.append_array(op.get_provided_traits())
	return result
