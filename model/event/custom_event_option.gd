class_name CustomEventOption extends BaseOption
# 专门用来硬编码处理那些特殊的事件

# 使用description作为button text
@export var choice_result: ChoiceResult
@export var requirements: BaseRequirements = null # 不知道为什么inherit event option editor不让选，只能自己搞le

@export_enum(
    'upgrade_random_imagery'
) var custom_type: String

func init(context: Dictionary):
	match custom_type:
		'upgrade_random_imagery': upgrade_random_imagery()
	return context

func upgrade_random_imagery():
	# V6: level 系统已删除，改为 talent 增益
	var active_imaginaries = Database.get_active_imaginaries()
	if not active_imaginaries:
		description = '怎么连imagery都没有啊。浪费了这一次的机会'
		return
	
	var random_imaginary = active_imaginaries.keys()[randi() % active_imaginaries.size()]
	description = '获得 talen: %s 的感悟' % random_imaginary
	choice_result = ChoiceResult.new()
	choice_result.operators.append(
		OperatorFactory.create_property_operator("talent", 5)
	)
