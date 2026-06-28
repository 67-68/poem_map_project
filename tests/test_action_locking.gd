# ================================================================
# ActionManager 锁定展示系统 (Locking Display) 测试
# ================================================================
# 覆盖场景：
#   - check_action_validity() 纯函数
#     - 无需求 → valid
#     - 需求满足 → valid
#     - 需求不满足 → invalid + reasons
#     - 时间不足 → invalid + time reason
#   - pick_top_actions() 中签/未中签追踪
#     - 中签标记到 _selected_action_ids
#     - 未中签合法 action 获得 B 类 lock_narrative
#     - dynamic_failed_hint 每轮重建
#   - reevaluate_all_locks() 属性变动重评估
#     - 中签 + 条件满足 → 解锁
#     - 中签 + 条件不满足 → A 类锁定
#     - 未中签 → B 类锁定（始终）
#   - Action 模型扩展
#     - append_failed_hint() / clear_failed_hint()
#     - lock_narrative 配置
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 辅助工厂
# ════════════════════════════════════════════════════════════

## 创建最基本的 SceneAction（无需求，无时间消耗）
func _make_action(id: String, name: String = "") -> SceneAction:
	var a := SceneAction.new()
	a.uuid = id
	a.name = name if name else id
	return a


## 创建带 PropertyRequirement 的 action
func _make_action_with_prop_req(id: String, prop: String, val: int, op: int) -> SceneAction:
	var a := _make_action(id)
	var req := PropertyRequirement.new()
	req.property = prop
	req.value = val
	req.operator = op  # REQ_OPERATOR.COMPARE.LESS_THAN=0, GREATER_THAN=1
	a.aciton_requirements = [req]
	return a


## 创建带时间消耗的 action（用 TimeOperator 模拟）
func _make_action_with_time_cost(id: String, day_cost: float) -> SceneAction:
	var a := _make_action(id)
	var time_op := TimeOperator.new()
	time_op.day = day_cost
	a.action_results = [time_op]
	return a


## 创建带 lock_narrative 的 action
func _make_action_with_narrative(id: String, narrative: String) -> SceneAction:
	var a := _make_action(id)
	a.lock_narrative = narrative
	return a


## 模拟 get_available_scene_actions 的返回值格式
func _make_action_pool(action_ids: Array) -> Dictionary:
	var pool = {}
	for id in action_ids:
		pool[id] = 1
	return pool


## 给 action 注入需求实例（按需设置 PlayerState 属性）
func _inject_health_requirement(a: Action, threshold: int, operator: int = REQ_OPERATOR.COMPARE.GREATER_THAN) -> void:
	var req := PropertyRequirement.new()
	req.property = "health"
	req.value = threshold
	req.operator = operator
	a.aciton_requirements = [req]


## 设置测试用的 Database.properties（PlayerState 依赖这些）
func _setup_mock_properties() -> void:
	# 创建 health property，默认值 50
	if not Database.properties.has("health"):
		var health_prop := Property.new()
		health_prop.uuid = "health"
		health_prop.name = "健康"
		health_prop.val = 50
		Database.properties["health"] = health_prop
	
	# 创建 time property，默认值 10
	if not Database.properties.has("time"):
		var time_prop := Property.new()
		time_prop.uuid = "time"
		time_prop.name = "时间"
		time_prop.val = 10
		Database.properties["time"] = time_prop


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 清理 ActionManager 状态
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	
	# 清理 Database.actions 和 properties
	Database.actions.clear()
	Database.properties.clear()
	
	# 注入 8 个基础 action
	for i in range(1, 9):
		var action_id := "test_action_%d" % i
		var action := _make_action(action_id, "测试行动 %d" % i)
		Database.actions[action_id] = action
	
	# 注入 mock properties（PlayerState 依赖）
	_setup_mock_properties()


func after_each():
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	Database.actions.clear()
	Database.properties.clear()
	
	# 清理所有 action 的 dynamic_failed_hint
	for a_id in Database.actions:
		var a = Database.actions[a_id]
		if a:
			a.clear_failed_hint()


# ════════════════════════════════════════════════════════════
# check_action_validity — 纯函数测试
# ════════════════════════════════════════════════════════════

func test_validity_no_requirements():
	"""无需求的 action → valid"""
	var a := _make_action("test_no_req")
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "无需求时应返回 valid")
	assert_eq(result.reasons.size(), 0, "无需求时 reasons 应为空")


func test_validity_requirements_met():
	"""需求满足（health > 50, 当前 health=80）→ valid"""
	# Arrange: 设 health=80
	Database.properties["health"].val = 80
	var a := _make_action_with_prop_req("test_req_met", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	
	# Act
	var result := ActionManager.check_action_validity(a)
	
	# Assert
	assert_true(result.valid, "health=80 > 50 时应返回 valid")
	assert_eq(result.reasons.size(), 0, "条件满足时 reasons 应为空")


func test_validity_requirements_not_met():
	"""需求不满足（health > 80, 当前 health=50）→ invalid + reasons"""
	# Arrange: health 默认 50
	var a := _make_action_with_prop_req("test_req_fail", "health", 80, REQ_OPERATOR.COMPARE.GREATER_THAN)
	
	# Act
	var result := ActionManager.check_action_validity(a)
	
	# Assert
	assert_false(result.valid, "health=50 < 80 时应返回 invalid")
	assert_gt(result.reasons.size(), 0, "应包含失败原因")


func test_validity_time_insufficient():
	"""时间不足（time=3, 需要 5 天）→ invalid + time reason"""
	# Arrange: 设 time=3
	Database.properties["time"].val = 3
	var a := _make_action_with_time_cost("test_time_short", 5.0)
	
	# Act
	var result := ActionManager.check_action_validity(a)
	
	# Assert
	assert_false(result.valid, "time=3 < 5 时应返回 invalid")
	assert_gt(result.reasons.size(), 0, "应包含时间不足原因")
	# 检查是否包含 "时间不足" 或类似文本
	var has_time_reason := false
	for r in result.reasons:
		if r.contains("时间不足") or r.contains("时间"):
			has_time_reason = true
			break
	assert_true(has_time_reason, "时间不足原因应包含'时间'相关文本")


func test_validity_time_sufficient():
	"""时间充足（time=10, 需要 5 天）→ valid"""
	Database.properties["time"].val = 10
	var a := _make_action_with_time_cost("test_time_enough", 5.0)
	
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "time=10 >= 5 时应返回 valid")


func test_validity_no_time_cost():
	"""无时间消耗 → valid（即使 time=0）"""
	Database.properties["time"].val = 0
	var a := _make_action("test_no_time_cost")
	
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "无时间消耗时始终 valid")


func test_validity_negative_time_cost():
	"""负数 day 被 clamp 为 0 → valid"""
	var a := _make_action_with_time_cost("test_neg_time", -3.0)
	
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "负数 day 被 clamp 为 0 → valid")


# ════════════════════════════════════════════════════════════
# pick_top_actions — 中签/未中签追踪
# ════════════════════════════════════════════════════════════

func test_pick_tracks_selected_ids():
	"""pick_top_actions 后，中签的 action 应在 _selected_action_ids 中"""
	var ids := ["test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"]
	var pool := _make_action_pool(ids)
	
	var selected := ActionManager.pick_top_actions(pool)
	
	assert_eq(ActionManager._selected_action_ids.size(), 6, "应记录 6 个中签 action")
	for sa in selected:
		assert_true(ActionManager._selected_action_ids.has(sa.uuid),
			"中签的 %s 应在 _selected_action_ids 中" % sa.uuid)


func test_pick_clears_old_selected():
	"""pick_top_actions 之前应清空旧的 _selected_action_ids"""
	# 先塞个旧数据
	ActionManager._selected_action_ids["stale_id"] = true
	
	var pool := _make_action_pool(["test_action_1", "test_action_2",
		"test_action_3", "test_action_4", "test_action_5", "test_action_6"])
	ActionManager.pick_top_actions(pool)
	
	assert_does_not_have(ActionManager._selected_action_ids, "stale_id",
		"过时的 selected_id 应被清空")


func test_pick_clears_failed_hints():
	"""pick_top_actions 应清空所有 action 的 dynamic_failed_hint"""
	# Arrange: 给一个不在池中的 action 预设 failed_hint
	var action_extra := _make_action("test_extra")
	action_extra.append_failed_hint("旧数据")
	Database.actions["test_extra"] = action_extra
	
	var pool := _make_action_pool(["test_action_1", "test_action_2",
		"test_action_3", "test_action_4", "test_action_5", "test_action_6"])
	ActionManager.pick_top_actions(pool)
	
	assert_true(action_extra.dynamic_failed_hint.is_empty(),
		"dynamic_failed_hint 应在抽取前被清空")


func test_pick_locks_unselected_with_narrative():
	"""未中签的合法 action 应获得 lock_narrative 文本"""
	# Arrange: 给一些 action 设置 lock_narrative
	Database.actions.clear()
	for i in range(1, 9):
		var a := _make_action_with_narrative("test_action_%d" % i,
			"未中签理由 %d" % i if i > 6 else "")
		Database.actions["test_action_%d" % i] = a
	
	var pool := _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6",
		"test_action_7", "test_action_8"
	])
	
	ActionManager.pick_top_actions(pool)
	
	# 未中签的 action（7 和 8 大概率未中签）应有 failed_hint
	var locked_count := 0
	for i in range(7, 9):
		var a = Database.actions["test_action_%d" % i]
		if not a.dynamic_failed_hint.is_empty():
			locked_count += 1
	
	assert_gt(locked_count, 0, "至少有一些未中签 action 获得 failed_hint")


# ════════════════════════════════════════════════════════════
# reevaluate_all_locks — 属性变动重评估
# ════════════════════════════════════════════════════════════

func test_reeval_selected_valid_unlocked():
	"""已中签 + 条件满足 → dynamic_failed_hint 为空"""
	# Arrange: 设置玩家 health=80
	Database.properties["health"].val = 80
	
	# 创建 action 带需求 health > 50
	var a := _make_action_with_prop_req("test_selected_ok", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_selected_ok"] = a
	
	# 标记为中签
	ActionManager._selected_action_ids["test_selected_ok"] = true
	
	# Act
	ActionManager.reevaluate_all_locks()
	
	# Assert
	assert_true(a.dynamic_failed_hint.is_empty(),
		"中签 + 条件满足 → failed_hint 应为空")


func test_reeval_selected_invalid_locked():
	"""已中签 + 条件不满足 → dynamic_failed_hint 有 A 类原因"""
	# Arrange: 玩家 health=20
	Database.properties["health"].val = 20
	
	var a := _make_action_with_prop_req("test_selected_fail", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_selected_fail"] = a
	ActionManager._selected_action_ids["test_selected_fail"] = true
	
	# Act
	ActionManager.reevaluate_all_locks()
	
	# Assert
	assert_false(a.dynamic_failed_hint.is_empty(),
		"中签 + 条件不满足 → failed_hint 应有内容")


func test_reeval_unselected_always_locked():
	"""未中签 → 始终有 B 类 failed_hint（即使条件满足）"""
	# Arrange: 玩家 health=80
	Database.properties["health"].val = 80
	
	var a := _make_action_with_narrative("test_unselected", "今日不宜出行")
	a = _make_action_with_prop_req("test_unselected", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	a.lock_narrative = "今日不宜出行"
	Database.actions["test_unselected"] = a
	# 不标记中签
	
	# Act
	ActionManager.reevaluate_all_locks()
	
	# Assert: 未中签 → 应有 lock_narrative 作为 B 类文本
	assert_false(a.dynamic_failed_hint.is_empty(),
		"未中签 → failed_hint 不应为空")
	assert_true(a.dynamic_failed_hint.contains("今日不宜出行"),
		"未中签 → failed_hint 应包含 lock_narrative")


func test_reeval_unselected_with_a_reason():
	"""未中签 + 条件不满足 → failed_hint 包含 B 类 + A 类原因"""
	# Arrange: 玩家 health=20（不满足 health > 50）
	Database.properties["health"].val = 20
	
	var a := _make_action_with_prop_req("test_unselected_a", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	a.lock_narrative = "未中签"
	Database.actions["test_unselected_a"] = a
	# 不标记中签
	
	# Act
	ActionManager.reevaluate_all_locks()
	
	# Assert: 应有内容
	assert_false(a.dynamic_failed_hint.is_empty(),
		"未中签 + 条件不满足 → failed_hint 应有内容")
	# 应包含 B 类文本
	assert_true(a.dynamic_failed_hint.contains("未中签"),
		"应包含 B 类锁叙事文本")


# ════════════════════════════════════════════════════════════
# Action 模型扩展测试
# ════════════════════════════════════════════════════════════

func test_action_append_failed_hint():
	"""append_failed_hint 应追加文本"""
	var a := _make_action("test_append")
	a.append_failed_hint("第一条原因")
	assert_eq(a.dynamic_failed_hint, "第一条原因",
		"首次追加应等于文本本身")


func test_action_append_multiple():
	"""多次 append 应用换行分隔"""
	var a := _make_action("test_append_multi")
	a.append_failed_hint("原因A")
	a.append_failed_hint("原因B")
	assert_eq(a.dynamic_failed_hint, "原因A\n原因B",
		"多次追加应用换行分隔")


func test_action_clear_failed_hint():
	"""clear_failed_hint 应清空文本"""
	var a := _make_action("test_clear")
	a.append_failed_hint("临时数据")
	a.clear_failed_hint()
	assert_true(a.dynamic_failed_hint.is_empty(),
		"清空后应为空")


func test_action_append_empty_ignored():
	"""append 空字符串应被忽略"""
	var a := _make_action("test_append_empty")
	a.append_failed_hint("")
	assert_true(a.dynamic_failed_hint.is_empty(),
		"追加空字符串应被忽略")
	
	a.append_failed_hint("实际内容")
	a.append_failed_hint("")
	assert_eq(a.dynamic_failed_hint, "实际内容",
		"空字符串不应影响已有文本")


func test_action_lock_narrative_export():
	"""lock_narrative @export 字段可读写"""
	var a := _make_action("test_lock_narrative")
	a.lock_narrative = "自定义叙事文本"
	assert_eq(a.lock_narrative, "自定义叙事文本",
		"lock_narrative 应可读写")


# ════════════════════════════════════════════════════════════
# _get_archetype_key — 类型映射测试
# ════════════════════════════════════════════════════════════

func test_archetype_key_for_scene_action():
	"""SceneAction 的 _main_tag 应正确映射到 archetype key"""
	# bai_ye: _main_tag=29(ACTION_MAIN_BAIYE) → action_type=0(BAI_YE) → "baiye"
	var a := SceneAction.new()
	a._main_tag = 29  # ACTION_MAIN_BAIYE
	
	var key := ActionManager._get_archetype_key(a)
	assert_eq(key, "baiye", "ACTION_MAIN_BAIYE(29) → archetype key='baiye'")


func test_archetype_key_for_non_scene_action():
	"""非 SceneAction → 空字符串"""
	var fake := Action.new()  # 直接用 Action 基类
	var key := ActionManager._get_archetype_key(fake)
	assert_true(key.is_empty(), "非 SceneAction → 空 key")


func test_archetype_key_for_unknown_tag():
	"""无法映射的 _main_tag → 空字符串"""
	var a := SceneAction.new()
	a._main_tag = -1  # 无对应 action_type
	
	var key := ActionManager._get_archetype_key(a)
	assert_true(key.is_empty(), "未知 _main_tag → 空 key")


# ════════════════════════════════════════════════════════════
# 信号发射测试
# ════════════════════════════════════════════════════════════

func test_reeval_emits_refresh_signal():
	"""reevaluate_all_locks 在状态变更时应发射 request_refresh_action_locks"""
	# Arrange: 创建一个条件不满足的已中签 action
	Database.properties["health"].val = 10
	var a := _make_action_with_prop_req("test_signal", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_signal"] = a
	ActionManager._selected_action_ids["test_signal"] = true
	
	# 使用 watch_signals 监控 EventBus
	watch_signals(EventBus)
	
	# Act
	ActionManager.reevaluate_all_locks()
	
	# Assert
	assert_signal_emitted(EventBus, "request_refresh_action_locks",
		"锁定状态变更时应发射 request_refresh_action_locks 信号")
