@tool
class_name ScanAndPushOperator extends BaseOperator

## 要匹配的 tag 前缀列表（4 段式标签，如 ["scene:tavern:gambling:high", "npc:rogue:encounter:random"]）
## 使用 TagManager.prefix_match() 与事件 target_tags 做方向无关的前缀匹配
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
	
	# ── Step 1: 跨桶扫描，按 tag 前缀匹配 ──
	var tickets: Array[EventTicket] = _scan_and_match_tickets()
	if tickets.is_empty():
		Logging.warn("[ScanAndPushOperator] 没有匹配到任何事件（tags=%s），直接推送 fallback" % str(tags))
		_push_fallback_or_silent()
		return
	
	Logging.info("[ScanAndPushOperator] tag 匹配完成，获得 %d 个候选事件" % tickets.size())
	
	# ── Step 2: 运行 RequirementFilter ──
	tickets = _run_requirement_filter(tickets)
	if tickets.is_empty():
		Logging.warn("[ScanAndPushOperator] RequirementFilter 后无可用事件，推送 fallback")
		_push_fallback_or_silent()
		return
	
	Logging.info("[ScanAndPushOperator] RequirementFilter 通过，剩余 %d 个事件" % tickets.size())
	
	# ── Step 3: 运行 ActionTagFilter ──
	tickets = _run_action_tag_filter(tickets)
	if tickets.is_empty():
		Logging.warn("[ScanAndPushOperator] ActionTagFilter 后无可用事件，推送 fallback")
		_push_fallback_or_silent()
		return
	
	Logging.info("[ScanAndPushOperator] ActionTagFilter 通过，剩余 %d 个事件" % tickets.size())
	
	# ── Step 4: 权重滚动 ──
	var selected_uuid = _roll(tickets)
	if selected_uuid.is_empty():
		Logging.info("[ScanAndPushOperator] 权重滚动落在无事发生区间")
		_push_fallback_or_silent()
		return
	
	# ── Step 5: 推送到事件栈最顶层 ──
	Logging.info("[ScanAndPushOperator] 选中事件 %s，推送至事件栈" % selected_uuid)
	EventBus.push_event.emit(selected_uuid, _captured_context)


func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("[ScanAndPushOperator.init] 捕获 context，keys: %s" % str(_captured_context.keys()))
	return context


# ──────────────────────────────────────────────
# 内部方法
# ──────────────────────────────────────────────

## 遍历所有 random_events 桶，用 TagManager.prefix_match 匹配 tag
func _scan_and_match_tickets() -> Array[EventTicket]:
	var result: Array[EventTicket] = []
	
	if tags.is_empty():
		Logging.err("[ScanAndPushOperator] tags 为空，无法扫描")
		return result
	
	for bucket_key in Database.random_events:
		var bucket = Database.random_events[bucket_key] as Dictionary
		if bucket.is_empty():
			continue
		
		for event_uuid in bucket:
			var event = bucket[event_uuid]
			if event == null:
				continue
			
			# 检查事件的 target_tags 是否匹配任何输入的 tag
			var event_tags: Array[String] = event.target_tags if "target_tags" in event else []
			if event_tags.is_empty():
				# 无 tag 的全局事件 — 永远放行
				pass
			else:
				var matched := false
				for input_tag in tags:
					for event_tag in event_tags:
						if TagManager.prefix_match(event_tag, input_tag):
							matched = true
							break
					if matched:
						break
				if not matched:
					continue
			
			# 创建 ticket
			var ticket = EventTicket.new()
			ticket.event_uuid = event.uuid
			ticket.weight = float(event.weight) if "weight" in event else 1.0
			ticket.original_weight = ticket.weight
			result.append(ticket)
	
	return result


## 运行 RequirementFilter（复用现有静态方法）
func _run_requirement_filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
	var result = RequirementFilter.filter(tickets, _captured_context)
	if result is Array:
		return result as Array[EventTicket]
	return []


## 运行 ActionTagFilter（复用现有静态方法）
func _run_action_tag_filter(tickets: Array[EventTicket]) -> Array[EventTicket]:
	var result = ActionTagFilter.filter(tickets, _captured_context)
	if result is Array:
		return result as Array[EventTicket]
	return []


## 权重滚动（同 EventManager.roll_events 算法）
func _roll(tickets: Array[EventTicket]) -> String:
	if tickets.is_empty():
		return ""
	
	var total_weight := 0.0
	for ticket in tickets:
		total_weight += ticket.weight
		Logging.info("[ScanAndPushOperator] 事件 '%s' 权重: %.1f" % [ticket.event_uuid, ticket.weight])
	
	Logging.info("[ScanAndPushOperator] 总权重: %.1f" % total_weight)
	
	# 无事发生权重
	var null_weight = total_weight * weight_multiplier
	var final_total = total_weight + null_weight
	Logging.info("[ScanAndPushOperator] 空转权重: %.1f, 最终总权重: %.1f" % [null_weight, final_total])
	
	var roll: float = randf() * final_total
	var current_accumulated := 0.0
	Logging.info("[ScanAndPushOperator] 随机值: %.2f" % roll)
	
	for ticket in tickets:
		current_accumulated += ticket.weight
		if roll <= current_accumulated:
			Logging.info("[ScanAndPushOperator] 选中事件: %s" % ticket.event_uuid)
			return ticket.event_uuid
	
	# 落在无事发生区间
	return ""


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
