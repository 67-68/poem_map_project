# ================================================================
# GuaranteeNextOperator — 保证事件机制运行时测试
# ================================================================
# 覆盖场景：
#   - GuaranteeNextOperator.operate() 发射信号
#   - EventManager._on_guarantee_next 存储 event_key + main_tag
#   - roll_events 三路分支：
#     A: 无 main_tag → find_triggerable_item 旁路 pool
#     B: main_tag 匹配 → 在 pool 中搜索
#     C: main_tag 不匹配 → 保留 guarantee
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 信号跟踪（用类级方法替代 lambda，避免 Godot 4 lambda 变量捕获问题）
# ════════════════════════════════════════════════════════════

var _emitted_key: String = ""
var _emitted_tag: String = ""

func _on_guarantee_next(key: String, tag: String) -> void:
	_emitted_key = key
	_emitted_tag = tag


# ════════════════════════════════════════════════════════════
# 测试辅助
# ════════════════════════════════════════════════════════════

func _make_event(uuid: String, weight: float = 10.0) -> RandomEvent:
	var evt = RandomEvent.new()
	evt.uuid = uuid
	evt.weight = weight
	return evt


func _make_ticket(uuid: String, weight: float = 10.0) -> EventTicket:
	var ticket = EventTicket.new()
	ticket.event_uuid = uuid
	ticket.weight = weight
	ticket.original_weight = weight
	return ticket


func _make_tickets(arr: Array) -> Array[EventTicket]:
	"""将普通 Array 转换为 Array[EventTicket]，避免类型化数组传递问题"""
	var result: Array[EventTicket] = []
	for item in arr:
		result.append(item)
	return result


func _inject_test_data():
	"""在 Database.random_events 中注入 1 个桶，包含 2 个事件"""
	Database.random_events["TEST_BUCKET"] = {
		"evt_guaranteed": _make_event("evt_guaranteed", 30.0),
		"evt_other": _make_event("evt_other", 10.0),
	}


func _clear_injected_data():
	if Database.random_events.has("TEST_BUCKET"):
		Database.random_events.erase("TEST_BUCKET")


# ════════════════════════════════════════════════════════════
# 生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 重置 EventManager 的 guarantee 状态
	EventManager._guaranteed_event_key = ""
	EventManager._guaranteed_main_tag = ""
	# 信号跟踪：断开旧连接 → 建立新连接 → 清空历史
	if EventManager.guarantee_next.is_connected(_on_guarantee_next):
		EventManager.guarantee_next.disconnect(_on_guarantee_next)
	EventManager.guarantee_next.connect(_on_guarantee_next)
	_emitted_key = ""
	_emitted_tag = ""
	_inject_test_data()


func after_each():
	_clear_injected_data()
	# 恢复 guarantee 状态
	EventManager._guaranteed_event_key = ""
	EventManager._guaranteed_main_tag = ""
	# 断开信号连接，防止跨测试残留
	if EventManager.guarantee_next.is_connected(_on_guarantee_next):
		EventManager.guarantee_next.disconnect(_on_guarantee_next)


# ════════════════════════════════════════════════════════════
# 测试: GuaranteeNextOperator 发射信号
# ════════════════════════════════════════════════════════════

func test_operator_emit_with_main_tag():
	"""GuaranteeNextOperator.operate() 应发射 guarantee_next 信号并携带 main_tag"""
	var op = GuaranteeNextOperator.new()
	op.event_key = "evt_test"
	op.main_tag = "TEST_BUCKET"
	op.operate()
	
	assert_eq(_emitted_key, "evt_test", "信号应携带 event_key")
	assert_eq(_emitted_tag, "TEST_BUCKET", "信号应携带 main_tag")


func test_operator_emit_empty_tag():
	"""GuaranteeNextOperator.operate() main_tag 为空时应发射空字符串"""
	var op = GuaranteeNextOperator.new()
	op.event_key = "evt_test"
	op.main_tag = ""  # 显式空字符串
	op.operate()
	
	assert_eq(_emitted_tag, "", "main_tag 应为空字符串")
	assert_eq(_emitted_key, "evt_test", "event_key 应被发射")


# ════════════════════════════════════════════════════════════
# 测试: EventManager 存储 guarantee
# ════════════════════════════════════════════════════════════

func test_event_manager_stores_both_values():
	"""EventManager._on_guarantee_next 应同时存储 event_key 和 main_tag"""
	EventManager._on_guarantee_next("evt_stored", "STORED_TAG")
	
	assert_eq(EventManager._guaranteed_event_key, "evt_stored", "_guaranteed_event_key 应被存储")
	assert_eq(EventManager._guaranteed_main_tag, "STORED_TAG", "_guaranteed_main_tag 应被存储")


func test_event_manager_stores_empty_tag():
	"""main_tag 为空时应正确存储空字符串"""
	EventManager._on_guarantee_next("evt_empty_tag", "")
	
	assert_eq(EventManager._guaranteed_event_key, "evt_empty_tag", "_guaranteed_event_key 应被存储")
	assert_eq(EventManager._guaranteed_main_tag, "", "_guaranteed_main_tag 应为空字符串")


# ════════════════════════════════════════════════════════════
# 测试: roll_events 分支 A — 无 main_tag（通用保证）
# ════════════════════════════════════════════════════════════

func test_branch_a_no_tag_finds_item():
	"""分支A: 无 main_tag → find_triggerable_item 找到事件 → 直接返回 event_key"""
	EventManager._guaranteed_event_key = "evt_guaranteed"
	EventManager._guaranteed_main_tag = ""
	
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([]), 0.0, "", {}, true
	)
	
	assert_eq(result, "evt_guaranteed", "无 tag 保证应直接返回 event_key")
	assert_eq(EventManager._guaranteed_event_key, "", "guarantee 应被消费")


func test_branch_a_no_tag_missing_item():
	"""分支A: 无 main_tag → find_triggerable_item 找不到 → 回退正常抽取"""
	EventManager._guaranteed_event_key = "evt_nonexistent"
	EventManager._guaranteed_main_tag = ""
	
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_other", 10.0)]), 0.0, "", {}, true
	)
	
	assert_eq(EventManager._guaranteed_event_key, "", "guarantee 应被消费")
	assert_eq(result, "evt_other", "应回退正常 roll 选中 evt_other")


# ════════════════════════════════════════════════════════════
# 测试: roll_events 分支 B — main_tag 匹配
# ════════════════════════════════════════════════════════════

func test_branch_b_tag_matches_finds_in_pool():
	"""分支B: main_tag 匹配 → 在 pool 中搜索 → 找到并返回"""
	EventManager._guaranteed_event_key = "evt_guaranteed"
	EventManager._guaranteed_main_tag = "TEST_BUCKET"
	
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_guaranteed", 30.0)]),
		0.0, "", {"main_tag": "TEST_BUCKET"}, true
	)
	
	assert_eq(result, "evt_guaranteed", "应返回被保证的事件")
	assert_eq(EventManager._guaranteed_event_key, "", "guarantee 应被消费")


func test_branch_b_tag_matches_not_in_pool():
	"""分支B: main_tag 匹配但事件不在 pool 中 → 回退正常抽取"""
	EventManager._guaranteed_event_key = "evt_guaranteed"
	EventManager._guaranteed_main_tag = "TEST_BUCKET"
	
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_other", 10.0)]),
		0.0, "", {"main_tag": "TEST_BUCKET"}, true
	)
	
	assert_eq(EventManager._guaranteed_event_key, "", "guarantee 应被消费")
	assert_eq(result, "evt_other", "应回退正常 roll")


# ════════════════════════════════════════════════════════════
# 测试: roll_events 分支 C — main_tag 不匹配
# ════════════════════════════════════════════════════════════

func test_branch_c_tag_mismatch_preserves_guarantee():
	"""分支C: main_tag 不匹配 → 保留 guarantee，跳过，正常抽取"""
	EventManager._guaranteed_event_key = "evt_guaranteed"
	EventManager._guaranteed_main_tag = "TEST_BUCKET"
	
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_other", 10.0)]),
		0.0, "", {"main_tag": "OTHER_BUCKET"}, true
	)
	
	assert_eq(EventManager._guaranteed_event_key, "evt_guaranteed", "guarantee 应被保留")
	assert_eq(EventManager._guaranteed_main_tag, "TEST_BUCKET", "guarantee main_tag 应被保留")
	assert_eq(result, "evt_other", "应正常抽取其他事件")


func test_branch_c_tag_mismatch_allows_subsequent_match():
	"""分支C: 不匹配保留后，下一次匹配的抽奖应能消费 guarantee"""
	EventManager._guaranteed_event_key = "evt_guaranteed"
	EventManager._guaranteed_main_tag = "TEST_BUCKET"
	
	# Act 1: 第一次抽奖（不匹配）→ guarantee 保留
	EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_other", 10.0)]),
		0.0, "", {"main_tag": "OTHER_BUCKET"}, true
	)
	assert_eq(EventManager._guaranteed_event_key, "evt_guaranteed", "guarantee 应仍保留")
	
	# Act 2: 第二次抽奖（匹配）→ guarantee 消费
	var result = EventManager.scan_events_from_tickets(
		_make_tickets([_make_ticket("evt_guaranteed", 30.0)]),
		0.0, "", {"main_tag": "TEST_BUCKET"}, true
	)
	
	assert_eq(result, "evt_guaranteed", "匹配的抽奖应消费 guarantee")
	assert_eq(EventManager._guaranteed_event_key, "", "guarantee 应已被消费")


# ════════════════════════════════════════════════════════════
# 测试: 契约方法
# ════════════════════════════════════════════════════════════

func test_contract_methods_return_empty():
	"""所有契约方法应返回空数组"""
	var op = GuaranteeNextOperator.new()
	
	assert_eq(op.get_referenced_flags(), [], "referenced_flags 为空")
	assert_eq(op.get_provided_flags(), [], "provided_flags 为空")
	assert_eq(op.get_demanded_flags(), [], "demanded_flags 为空")
	assert_eq(op.get_referenced_traits(), [], "referenced_traits 为空")
	assert_eq(op.get_provided_traits(), [], "provided_traits 为空")
	assert_eq(op.get_demanded_traits(), [], "demanded_traits 为空")
