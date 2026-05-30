@tool
class_name ItemProvider extends BaseProvider

## Context 中列表的 key，例如 "guests"
@export var list_key: String

## 按钮文字模板，用 {item} 占位，例如 "走向 {item}"
@export var text_template: String

## 点击后触发的事件 key（BaseEvent.uuid 或 String key）
@export var target_event_key: String

## 传递给目标事件的 payload key，例如 "target_npc"
## 会在选项 init 时通过 custom_context_params 注入 context，
## 从而被 EventOperator._captured_context 捕获
@export var payload_key: String

## 是否使用 PushEventOperator（默认 false，使用 EventOperator/request_event_key）
@export var use_push_event: bool = false

## option 额外参数，例如 requirements、emotion_configs 等
## 如果设置，会被应用到每一个生成的选项上
@export var option_requirements: BaseRequirements = null
@export var option_emotion_configs: Array[EmotionConfigs] = []


func init(context: Dictionary) -> Dictionary:
	Logging.info("[ItemProvider] init: list_key=%s, template=%s" % [list_key, text_template])
	return context


func provide(context: Dictionary) -> Array:
	Logging.info("[ItemProvider] provide: list_key=%s, context keys=%s" % [list_key, context.keys()])
	for k in context:
		Logging.info("[ItemProvider] context[%s] = %s (type=%s)" % [k, str(context[k]), typeof(context[k])])
	var target_list: Array = context.get(list_key, [])
	var options: Array = []

	if target_list.is_empty():
		Logging.warn("[ItemProvider] 列表 '%s' 为空，没有生成任何选项" % list_key)
		return options

	Logging.info("[ItemProvider] 从列表 '%s' 生成 %d 个选项" % [list_key, target_list.size()])

	for item in target_list:
		var option = _build_option(item)
		options.append(option)

	return options


func _build_option(item) -> EventOption:
	var button_text = text_template.replace("{item}", str(item))
	var payload = {payload_key: item}

	var option = EventOption.new()
	option.description = button_text

	# 🔑 利用 custom_context_params 把 per-item payload merge 进 context
	# EventOption.init() 会先 merge custom_context_params，再传给 choice_result，
	# 从而 EventOperator._captured_context 天然包含 {payload_key: item}
	option.custom_context_params = payload

	# 构建 ChoiceResult + Operator
	var choice_result = ChoiceResult.new()
	choice_result.operators.append(_create_operator())
	option.choice_result = choice_result

	# 可选的额外配置
	if option_requirements:
		option.requirement = option_requirements
	if not option_emotion_configs.is_empty():
		option.emotion_configs = option_emotion_configs

	return option


func _create_operator() -> BaseOperator:
	var op: BaseOperator
	if use_push_event:
		op = PushEventOperator.new()
	else:
		op = EventOperator.new()
	op.event_key = target_event_key
	return op
