@tool
class_name ScanAndPushOperator extends BaseOperator

## 要匹配的 tag 列表
## 这些 tags 会被设置到 PlayerState.current_action_tags，
## 由 ActionTagFilter.filter() 通过字符串相等匹配筛选事件
@export var tags: PackedStringArray = PackedStringArray()

## 无事发生权重倍数（同 EventManager.scan_events 的 nothing_multiplication_weight）
## 默认 10.0 = 90% 概率无事发生（当总权重很小时）
## 设置为 0.0 则强制触发事件
@export var weight_multiplier: float = 10.0

## 当无事发生时的保底事件 key
@export var fallback_event: String = ""

## 当前事件的 context，在 init 时注入，push_event 时一并传递
var _captured_context: Dictionary = {}


func operate():
	Logging.info("[ScanAndPushOperator] 开始扫描并推送事件，tags=%s, weight_mult=%.1f, fallback=%s" % [str(tags), weight_multiplier, fallback_event])

	if tags.is_empty():
		Logging.err("[ScanAndPushOperator] tags 为空，无法扫描")
		_push_fallback_or_silent()
		return

	# ── 设置当前操作标签，使 ActionTagFilter 能通过前缀匹配筛选事件 ──
	# PackedStringArray 不可直接赋值给 Array[String]，需要显式转换
	var action_tags: Array[String] = []
	for tag in tags:
		action_tags.append(tag)
	PlayerState.current_action_tags = action_tags

	# ── 复用 EventManager 的扫描管道（RequirementFilter + ActionTagFilter + 权重滚动） ──
	# 使用 return_only=true 模式：EventManager 不发射 request_event_key，
	# 而是直接返回选中事件的 UUID，由本 operator 通过 push_event 推入事件栈
	var context = _captured_context.duplicate()
	var ev_name = EventManager.scan_events_from_tickets(
		_all_events_tickets(),
		weight_multiplier,
		"",       # fallback 由本 operator 的 _push_fallback_or_silent 处理
		context,
		true      # return_only: 返回 UUID，不发射 request_event_key
	)

	if ev_name and not ev_name.is_empty():
		Logging.info("[ScanAndPushOperator] 选中事件 %s，推送至事件栈" % ev_name)
		EventBus.push_event.emit(ev_name, _captured_context)
	else:
		Logging.info("[ScanAndPushOperator] 未选中事件（权重落空/所有事件被过滤），推送 fallback")
		_push_fallback_or_silent()


## 将 Database.random_events 中所有事件转为 EventTicket 数组
## 注意：这里不做 tag 前缀匹配，匹配逻辑由 EventManager 的 ActionTagFilter 完成
func _all_events_tickets() -> Array[EventTicket]:
	var result: Array[EventTicket] = []
	for bucket_key in Database.get_random_events_all():
		var bucket = Database.get_random_events_all()[bucket_key] as Dictionary
		if bucket.is_empty():
			continue
		for event_uuid in bucket:
			var event = bucket[event_uuid]
			if event == null:
				continue
			var ticket = EventTicket.new()
			ticket.event_uuid = event.uuid
			ticket.weight = float(event.weight) if "weight" in event else 1.0
			ticket.original_weight = ticket.weight
			result.append(ticket)
	return result


func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("[ScanAndPushOperator.init] 捕获 context，keys: %s" % str(_captured_context.keys()))
	return context


## 推送 fallback 事件，或无事发生
func _push_fallback_or_silent() -> void:
	if not fallback_event.is_empty():
		Logging.info("[ScanAndPushOperator] 推送 fallback 事件: %s" % fallback_event)
		EventBus.push_event.emit(fallback_event, _captured_context)
	else:
		Logging.info("[ScanAndPushOperator] 无事发生，无 fallback")


# ─── 契约方法 ───

func get_referenced_flags() -> Array:
	return []

func get_provided_flags() -> Array:
	return []

func get_demanded_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []

func get_provided_traits() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
