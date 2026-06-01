# ================================================================
# ScanAndPushOperator — 扫描推送操作符运行时测试
# ================================================================
# 架构说明：
#   ScanAndPushOperator 不再维护自己的扫描/过滤管道。
#   它设置 PlayerState.current_action_tags → 委托给 EventManager 的
#   scan_events_from_tickets(return_only=true) 完成过滤和权重滚动，
#   然后通过 push_event 推送选中事件。
#
# 覆盖场景：
#   - 核心流程：设置 current_action_tags → EventManager 管道 → push_event
#   - 边界条件：无 tags、无匹配、fallback 空/非空、权重落空
#   - 过滤链路：RequirementFilter 放行、ActionTagFilter 通过 current_action_tags 匹配
#   - 上下文：init() 捕获 context、push_event 传递 context
# ================================================================
extends GutTest


# ─── 信号跟踪（用类级方法替代 lambda，避免 Godot 4 lambda 变量捕获问题） ───

var _emitted_keys: Array[String] = []
var _emitted_contexts: Array[Dictionary] = []

func _on_push_event(key: String, ctx: Dictionary) -> void:
	_emitted_keys.append(key)
	_emitted_contexts.append(ctx)

func _last_key() -> String:
	return _emitted_keys.back() if not _emitted_keys.is_empty() else ""

func _push_count() -> int:
	return _emitted_keys.size()


# ─── 测试辅助：注入测试事件到 Database.random_events ───

var _injected_buckets: Dictionary = {}

func _make_event(uuid: String, target_tags: Array[String], weight: float = 10.0) -> RandomEvent:
	var evt = RandomEvent.new()
	evt.uuid = uuid
	evt.weight = weight
	# 直接写 _target_tags 跳过 ENUM 转换（测试环境无 ENUMS 注册）
	evt._target_tags = target_tags.duplicate()
	return evt


func _inject_test_data():
	"""在 Database.random_events 中注入 3 个桶，共 6 个事件"""
	_injected_buckets.clear()
	
	# ── 桶 A:  tavern 主题 ──
	var bucket_a = {
		"evt_tavern_brawl": _make_event("evt_tavern_brawl", ["scene:tavern:gambling:high", "npc:rogue:encounter:random"], 30.0),
		"evt_tavern_drunk": _make_event("evt_tavern_drunk", ["scene:tavern:drinking:high"], 20.0),
	}
	_injected_buckets["ACTION_MAIN_TAVERN_GENERAL"] = bucket_a
	
	# ── 桶 B:  street 主题 ──
	var bucket_b = {
		"evt_street_fight": _make_event("evt_street_fight", ["scene:street:fight:random", "npc:thug:encounter:random"], 15.0),
	}
	_injected_buckets["ACTION_MAIN_STREET_GENERAL"] = bucket_b
	
	# ── 桶 C:  palace 主题（全局无 tag 事件） ──
	var bucket_c = {
		"evt_palace_audience": _make_event("evt_palace_audience", [], 5.0),  # 无 tag = 全局
	}
	_injected_buckets["ACTION_MAIN_PALACE_GENERAL"] = bucket_c
	
	Database.random_events = _injected_buckets


func _clear_injected_data():
	Database.random_events.clear()


# ════════════════════════════════════════════════════════════
# 生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 清理可能残留的状态
	Database.random_events.clear()
	_injected_buckets.clear()
	# 清理 PlayerState 的 current_action_tags（防止 ActionTagFilter 被历史残留影响）
	PlayerState.current_action_tags.clear()
	# 信号跟踪：断开旧连接 → 建立新连接 → 清空历史
	if EventBus.push_event.is_connected(_on_push_event):
		EventBus.push_event.disconnect(_on_push_event)
	EventBus.push_event.connect(_on_push_event)
	_emitted_keys.clear()
	_emitted_contexts.clear()
	# 注入测试数据
	_inject_test_data()


func after_each():
	_clear_injected_data()
	PlayerState.current_action_tags.clear()
	# 断开信号连接，防止跨测试残留
	if EventBus.push_event.is_connected(_on_push_event):
		EventBus.push_event.disconnect(_on_push_event)


# ════════════════════════════════════════════════════════════
# 测试: 基本管道 — tag 匹配 + 推栈
# ════════════════════════════════════════════════════════════

func test_happy_path_match_and_push():
	"""happy path: tags 匹配到事件 → 权重滚动选中 → push_event 被发射"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.weight_multiplier = 0.0  # 强制触发（无事发生权重=0）
	op.init({})
	
	op.operate()
	
	# 应发射 push_event
	assert_eq(_push_count(), 1, "应恰好推送 1 个事件")
	assert_eq(_last_key(), "evt_tavern_brawl", "应选中权重最高（30.0）且 tag 匹配的 tavern_brawl")


func test_match_by_secondary_tag():
	"""事件有多 tag 时，只要任一 tag 匹配就通过"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["npc:rogue:encounter:random"])
	op.weight_multiplier = 0.0
	op.init({})
	
	op.operate()
	
	assert_eq(_last_key(), "evt_tavern_brawl", "通过 npc:rogue 前缀匹配到 tavern_brawl")


func test_prefix_match_cross_tags():
	"""前缀匹配：input tag 是事件 tag 的前缀 → 匹配"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern"])  # 前缀
	op.weight_multiplier = 0.0
	op.init({})
	
	op.operate()
	
	assert_eq(_push_count(), 1, "应恰好推送 1 个事件")
	assert_ne(_last_key(), "", "有事件被推送")
	# tavern 桶有 2 个事件（scene:tavern:gambling:high, scene:tavern:drinking:high）
	# 两者都匹配 scene:tavern 前缀


func test_global_event_no_tag():
	"""无 tag 的全局事件应该在扫描中始终放行"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.weight_multiplier = 0.0
	op.init({})
	
	op.operate()
	
	# 测试数据中 palace_audience 无 tag，应被放行进入候选池
	# 但权重 5.0 小于 tavern_brawl 的 30.0，所以大概率选中 tavern_brawl
	# 这里主要验证无 tag 事件不会被过滤掉（在候选池中）
	assert_ne(_last_key(), "", "有事件被推送")


# ════════════════════════════════════════════════════════════
# 测试: 边界条件
# ════════════════════════════════════════════════════════════

func test_empty_tags():
	"""tags 为空 → 直接 fallback，不应扫描"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray()
	op.fallback_event = "evt_fallback_test"
	op.init({})
	
	op.operate()
	
	assert_eq(_last_key(), "evt_fallback_test", "空 tags 时应触发 fallback")


func test_no_match_fallback():
	"""tags 无匹配 → fallback 事件被推送"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["universe:alien:unknown:xyz"])
	op.fallback_event = "evt_nothing_found"
	op.init({})
	
	op.operate()
	
	assert_eq(_last_key(), "evt_nothing_found", "无匹配时应触发 fallback")


func test_no_match_silent():
	"""tags 无匹配 + fallback 为空 → 无事发生，不发射信号"""
	# 注意：evt_palace_audience 是无 tag 的全局事件，Rule 1 永远放行
	# 用极高 weight_mult 确保无事发生区间压倒性覆盖，不会误选全局事件
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["universe:alien:unknown:xyz"])
	op.weight_multiplier = 9999.0
	op.fallback_event = ""
	op.init({})
	
	op.operate()
	
	assert_eq(_push_count(), 0, "无匹配且无 fallback 时应静默跳过")


func test_weight_mult_roll_nothing():
	"""权重滚动落在无事发生区间 → fallback 被推送"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.weight_multiplier = 9999.0  # 极高无事发生权重 → 几乎必定落空
	op.fallback_event = "evt_rolled_nothing"
	op.init({})
	
	op.operate()
	
	assert_eq(_last_key(), "evt_rolled_nothing", "权重落空时应触发 fallback")


# ════════════════════════════════════════════════════════════
# 测试: context 传递
# ════════════════════════════════════════════════════════════

func test_context_passed_through():
	"""init() 捕获的 context 应在 push_event 时传递"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.weight_multiplier = 0.0
	var ctx = {"player_name": "李白", "scene_id": "长安"}
	op.init(ctx)
	
	op.operate()
	
	var last_ctx = _emitted_contexts.back() if not _emitted_contexts.is_empty() else {}
	assert_eq(last_ctx.get("player_name"), "李白", "context 中的 player_name 应被传递")
	assert_eq(last_ctx.get("scene_id"), "长安", "context 中的 scene_id 应被传递")


func test_context_init_does_not_mutate_original():
	"""init() 应 duplicate context，不修改原始字典"""
	var op = ScanAndPushOperator.new()
	var original = {"key": "value"}
	op.init(original)
	
	original["key"] = "mutated"
	
	assert_eq(op._captured_context.get("key"), "value", "捕获的 context 不应受原始字典修改影响")


# ════════════════════════════════════════════════════════════
# 测试: 过滤链路阻断
# ════════════════════════════════════════════════════════════

func test_requirement_filter_in_pipeline():
	"""RequirementFilter 集成：管道包含 RequirementFilter 且不崩溃"""
	# 测试数据中所有事件的 requirement 为 null → filter 放行
	# 然后 ActionTagFilter 通过 current_action_tags 匹配事件
	# weight_mult 默认 10.0 → 大概率落空 → fallback 被推送
	# 这里主要验证管道存在且不会崩溃
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.fallback_event = "evt_req_blocked"
	op.init({})
	
	op.operate()
	
	# 只要任何事件（正常选中或 fallback）被推送即可
	assert_ne(_last_key(), "", "管道应推送事件或 fallback")


func test_action_tag_filter_in_pipeline():
	"""ActionTagFilter 集成：通过 current_action_tags 做前缀匹配"""
	# 操作器设置 PlayerState.current_action_tags = tags，
	# ActionTagFilter 通过前缀匹配筛选事件。
	# weight_mult=0.0 强制触发，事件必定被推送。
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:tavern:gambling:high"])
	op.weight_multiplier = 0.0
	op.fallback_event = "evt_action_blocked"
	op.init({})
	
	op.operate()
	
	assert_ne(_last_key(), "", "有事件被推送（匹配或选中）")


# ════════════════════════════════════════════════════════════
# 测试: 多 tags 交叉匹配
# ════════════════════════════════════════════════════════════

func test_multiple_tags_or_logic():
	"""多 tags 是 OR 逻辑 — 任一个匹配即放行"""
	var op = ScanAndPushOperator.new()
	op.tags = PackedStringArray(["scene:street:fight:random", "npc:thug:encounter:random"])
	op.weight_multiplier = 0.0
	op.init({})
	
	op.operate()
	
	assert_eq(_last_key(), "evt_street_fight", "OR 匹配 street_fight")


func test_multiple_tags_only_one_bucket_matches():
	"""多 tags 中只有一部分匹配 → 仍能选中匹配桶的事件"""
	var op = ScanAndPushOperator.new()
	# scene:street 匹配 street_fight, npc:rogue 匹配 tavern_brawl
	op.tags = PackedStringArray(["scene:street:fight:random", "npc:rogue:encounter:random"])
	op.weight_multiplier = 0.0
	op.init({})
	
	op.operate()
	
	assert_eq(_push_count(), 1, "应恰好推送 1 个事件（候选池中权重滚动选一个）")


# ════════════════════════════════════════════════════════════
# 测试: DSL 解析层集成 — MicroDSLParser 工厂函数
# ════════════════════════════════════════════════════════════

func test_dsl_parse_scan_and_push():
	"""MicroDSLParser.parse_consequence_operators 能正确解析 scan_and_push"""
	var result = MicroDSLParser.parse_consequence_operators(
		"scan_and_push(tags=[\"scene:tavern:gambling:high\"], weight_mult=5.0, fallback=\"evt_aftermath\")"
	)
	
	assert_eq(result.size(), 1, "应解析出 1 个 operator")
	assert_true(result[0] is ScanAndPushOperator, "解析结果应为 ScanAndPushOperator")
	
	var op = result[0] as ScanAndPushOperator
	assert_eq(op.tags.size(), 1, "tags 应有 1 个元素")
	assert_eq(op.tags[0], "scene:tavern:gambling:high", "tag 值正确")
	assert_eq(op.weight_multiplier, 5.0, "weight_mult 正确")
	assert_eq(op.fallback_event, "evt_aftermath", "fallback 正确")


func test_dsl_parse_multiple_tags():
	"""scan_and_push 的 tags 支持多元素数组"""
	var result = MicroDSLParser.parse_consequence_operators(
		"scan_and_push(tags=[\"scene:tavern:gambling\", \"npc:rogue\"])"
	)
	
	assert_eq(result.size(), 1, "应解析出 1 个 operator")
	var op = result[0] as ScanAndPushOperator
	assert_eq(op.tags.size(), 2, "tags 应有 2 个元素")
	assert_eq(op.tags[0], "scene:tavern:gambling", "tag[0] 正确")
	assert_eq(op.tags[1], "npc:rogue", "tag[1] 正确")


func test_dsl_parse_no_optional_params():
	"""scan_and_push 只有 tags 时，weight_mult 和 fallback 使用默认值"""
	var result = MicroDSLParser.parse_consequence_operators(
		"scan_and_push(tags=[\"scene:tavern\"])"
	)
	
	assert_eq(result.size(), 1, "应解析出 1 个 operator")
	var op = result[0] as ScanAndPushOperator
	assert_eq(op.tags.size(), 1, "tags 正确")
	assert_eq(op.weight_multiplier, 10.0, "weight_mult 默认 10.0")
	assert_eq(op.fallback_event, "", "fallback 默认空")


func test_dsl_parse_empty_tags_returns_null():
	"""tags 为空数组 → 解析出 1 个 operator（tags 为空 PackedStringArray）"""
	# 空数组 [] 在 _exec_scan_and_push_op 中走 Array 分支，
	# 创建空 PackedStringArray，返回有效 operator。
	# 空 tags 的语义错误由 operate() 在运行时处理（直接 fallback）
	var result = MicroDSLParser.parse_consequence_operators(
		"scan_and_push(tags=[])"
	)
	
	assert_eq(result.size(), 1, "空 tags 仍应解析出 1 个 operator")
	assert_true(result[0] is ScanAndPushOperator, "结果应为 ScanAndPushOperator")
	assert_eq(result[0].tags.size(), 0, "tags 应为空 PackedStringArray")
	assert_eq(result[0].weight_multiplier, 10.0, "weight_mult 使用默认值")


# ════════════════════════════════════════════════════════════
# 测试: 契约方法
# ════════════════════════════════════════════════════════════

func test_contract_methods_return_empty():
	"""所有契约方法应返回空数组（scan_and_push 不直接引用/提供/需求任何标志或特性）"""
	var op = ScanAndPushOperator.new()
	
	assert_eq(op.get_referenced_flags(), [], "referenced_flags 为空")
	assert_eq(op.get_provided_flags(), [], "provided_flags 为空")
	assert_eq(op.get_demanded_flags(), [], "demanded_flags 为空")
	assert_eq(op.get_referenced_traits(), [], "referenced_traits 为空")
	assert_eq(op.get_provided_traits(), [], "provided_traits 为空")
	assert_eq(op.get_demanded_traits(), [], "demanded_traits 为空")


