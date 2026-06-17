@tool
class_name ManiaProvider extends BaseProvider

# 狂症劫持：在现有选项前插入一条"疯批选项"
@export var crazy_option_text: String = ""     # 狂症选项文本（如"狂笑不止，踽踽独行"）
@export var crazy_event_key: String = ""       # 狂症选项触发的事件 key
@export var resist_health_cost: int = 20       # 正常选项额外消耗的健康
@export var resist_burnout_cost: int = 10      # 正常选项额外增加的 BURNOUT

## 注入狂症代价到所有现有选项
func init(_context: Dictionary) -> Dictionary:
	if _context.has("options") and _context.options is Array:
		for opt in _context.options:
			if opt is EventOption:
				# 给每个正常选项增加健康消耗和 BURNOUT
				var extra_cost = PropertyOperator.new()
				extra_cost.property = "HEALTH"
				extra_cost.value = -resist_health_cost
				opt.choice_result.operators.append(extra_cost)

				var extra_burnout = PropertyOperator.new()
				extra_burnout.property = "BURNOUT"
				extra_burnout.value = resist_burnout_cost
				opt.choice_result.operators.append(extra_burnout)
	return _context

## 返回狂症选项（插到列表最前面）
func provide(_context) -> Array:
	if crazy_option_text.is_empty() or crazy_event_key.is_empty():
		return []

	var crazy_option = EventOption.new()
	crazy_option.uuid = "mania_crazy_option"
	crazy_option.description = crazy_option_text

	# 狂症选项本身没有额外代价（已经疯了，无所谓）
	var choice_result = ChoiceResult.new()
	var sub_event_op = GuaranteeNextOperator.new()
	sub_event_op.event_key = crazy_event_key
	choice_result.operators.append(sub_event_op)
	crazy_option.choice_result = choice_result

	return [crazy_option]
