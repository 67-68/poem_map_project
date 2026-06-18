# ================================================================
# RelationFlagManager 测试
# ================================================================
# 覆盖：leverage (add/get_keys/has/consume/try_use)、help (add/get/has/clear)、
#       cross-target 隔离、event_id 约定推导、NPC + IDENTITY 双目标
#
# Leverage 存储变更: v2 — list[str] JSON 编码 (str flag)
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	PlayerState.flags.clear()
	# 清理测试残留的虚拟 flag
	var residuals = []
	for f_id in Database.flags:
		if f_id.begins_with("flag_gen_leverage_") or f_id.begins_with("flag_gen_help_"):
			residuals.append(f_id)
	for f_id in residuals:
		Database.flags.erase(f_id)


# ════════════════════════════════════════════════════════════
# Leverage v2 — list[str] JSON 编码存储
# ════════════════════════════════════════════════════════════

func test_leverage_add_and_get():
	"""add_leverage 后 get_leverage_keys 应包含对应 key"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.add_leverage(tag, "libai_secret")
	var keys = RelationFlagManager.get_leverage_keys(tag)
	assert_eq(keys.size(), 1)
	assert_true(keys.has("libai_secret"))


func test_leverage_additive():
	"""多次 add 不同 key，list 应包含所有 key"""
	var tag = "TARGET_NPC_WANGWEI"
	RelationFlagManager.add_leverage(tag, "wangwei_secret")
	RelationFlagManager.add_leverage(tag, "wangwei_poem")
	assert_eq(RelationFlagManager.get_leverage_keys(tag).size(), 2)
	assert_true(RelationFlagManager.get_leverage_keys(tag).has("wangwei_secret"))
	assert_true(RelationFlagManager.get_leverage_keys(tag).has("wangwei_poem"))


func test_leverage_has_true():
	"""有把柄时 has_leverage 返回 true"""
	var tag = "TARGET_IDENTITY_QUANGUI"
	RelationFlagManager.add_leverage(tag, "quangui_corruption")
	assert_true(RelationFlagManager.has_leverage(tag))


func test_leverage_has_false():
	"""无把柄时 has_leverage 返回 false"""
	assert_false(RelationFlagManager.has_leverage("TARGET_NPC_LIBAI"))


func test_leverage_has_false_after_clear():
	"""clear_leverage 后 has_leverage 返回 false"""
	var tag = "TARGET_NPC_DUFU"
	RelationFlagManager.add_leverage(tag, "dufu_secret")
	assert_true(RelationFlagManager.has_leverage(tag))
	RelationFlagManager.clear_leverage(tag)
	assert_false(RelationFlagManager.has_leverage(tag))
	assert_eq(RelationFlagManager.get_leverage_keys(tag).size(), 0)


func test_consume_leverage():
	"""consume_leverage 按 key 精确匹配并移除"""
	var tag = "TARGET_IDENTITY_QUANGUI"
	RelationFlagManager.add_leverage(tag, "quangui_corruption")
	RelationFlagManager.add_leverage(tag, "quangui_treason")

	var consumed = RelationFlagManager.consume_leverage(tag, "quangui_corruption")
	assert_true(consumed)
	assert_false(RelationFlagManager.get_leverage_keys(tag).has("quangui_corruption"))
	assert_true(RelationFlagManager.get_leverage_keys(tag).has("quangui_treason"))


func test_consume_leverage_not_found():
	"""consume_leverage 不存在的 key 返回 false"""
	var tag = "TARGET_IDENTITY_QUANGUI"
	RelationFlagManager.add_leverage(tag, "quangui_corruption")
	assert_false(RelationFlagManager.consume_leverage(tag, "quangui_bribe"))


func test_consume_leverage_empty_target():
	"""没有把柄的 target consume 返回 false"""
	assert_false(RelationFlagManager.consume_leverage("TARGET_NPC_GAOSHI", "any_key"))


func test_try_use_leverage_lifo():
	"""后添加的 key 先被使用 (LIFO)"""
	var tag = "TARGET_IDENTITY_QUANGUI"
	RelationFlagManager.add_leverage(tag, "quangui_corruption")
	RelationFlagManager.add_leverage(tag, "quangui_treason")

	var result = RelationFlagManager.try_use_leverage(tag)
	assert_true(result.consumed)
	assert_eq(result.leverage_key, "quangui_treason")  # 后添加，先弹出
	assert_false(RelationFlagManager.get_leverage_keys(tag).has("quangui_treason"))
	assert_true(RelationFlagManager.get_leverage_keys(tag).has("quangui_corruption"))


func test_try_use_leverage_empty():
	"""无把柄时 try_use_leverage 返回 consumed=false"""
	var result = RelationFlagManager.try_use_leverage("TARGET_NPC_GAOSHI")
	assert_false(result.consumed)
	assert_eq(result.leverage_key, "")
	assert_eq(result.event_id, "")


func test_try_use_leverage_event_id_fallback():
	"""try_use_leverage 返回的 event_id 应为降级通用事件（具体事件不存在时）"""
	var tag = "TARGET_IDENTITY_QUANGUI"
	RelationFlagManager.add_leverage(tag, "quangui_corruption")

	var result = RelationFlagManager.try_use_leverage(tag)
	assert_true(result.consumed)
	assert_eq(result.leverage_key, "quangui_corruption")
	# 具体事件 event_threaten_quangui_corruption 大概率不存在，应降级
	assert_eq(result.event_id, "event_threaten_TARGET_IDENTITY_QUANGUI")


func test_cross_target_isolation():
	"""不同 target 的 leverage 互不影响"""
	RelationFlagManager.add_leverage("TARGET_NPC_LIBAI", "libai_secret")
	RelationFlagManager.add_leverage("TARGET_IDENTITY_QUANGUI", "quangui_corruption")
	assert_eq(RelationFlagManager.get_leverage_keys("TARGET_NPC_LIBAI").size(), 1)
	assert_eq(RelationFlagManager.get_leverage_keys("TARGET_IDENTITY_QUANGUI").size(), 1)


func test_get_leverage_keys_returns_empty_for_unknown_target():
	"""从未添加过的 target 应返回空数组"""
	var keys = RelationFlagManager.get_leverage_keys("TARGET_NPC_ZHENGQIAN")
	assert_eq(keys.size(), 0)


func test_clear_on_empty_target_does_not_error():
	"""对没有数据的 target 做 clear_leverage 不应报错"""
	RelationFlagManager.clear_leverage("TARGET_NPC_HUSHANG")


# ════════════════════════════════════════════════════════════
# Help — 帮助/交好 (int 计数器，未改)
# ════════════════════════════════════════════════════════════

func test_help_add_and_get():
	"""add_help 后 get_help 应返回对应数量"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.add_help(tag, 2)
	assert_eq(RelationFlagManager.get_help(tag), 2)
	assert_true(RelationFlagManager.has_help(tag))


func test_help_default_amount_is_one():
	"""不传 amount 时默认 +1"""
	var tag = "TARGET_IDENTITY_QINGLIU_OWNER"
	RelationFlagManager.add_help(tag)
	assert_eq(RelationFlagManager.get_help(tag), 1)


func test_help_additive():
	"""多次 add 应累加"""
	var tag = "TARGET_IDENTITY_MENZI"
	RelationFlagManager.add_help(tag, 1)
	RelationFlagManager.add_help(tag, 4)
	assert_eq(RelationFlagManager.get_help(tag), 5)


func test_help_has_returns_false_when_none():
	"""没有帮助记录时 has_help 返回 false"""
	assert_false(RelationFlagManager.has_help("TARGET_NPC_WANGWEI"))


func test_help_has_returns_false_after_clear():
	"""clear_help 后 has_help 返回 false"""
	var tag = "TARGET_NPC_GAOSHI"
	RelationFlagManager.add_help(tag, 1)
	assert_true(RelationFlagManager.has_help(tag))
	RelationFlagManager.clear_help(tag)
	assert_false(RelationFlagManager.has_help(tag))
	assert_eq(RelationFlagManager.get_help(tag), 0)


func test_help_cross_target_isolation():
	"""不同目标的 help 互不影响"""
	RelationFlagManager.add_help("TARGET_NPC_LIBAI", 2)
	RelationFlagManager.add_help("TARGET_IDENTITY_QUANGUI", 3)
	assert_eq(RelationFlagManager.get_help("TARGET_NPC_LIBAI"), 2)
	assert_eq(RelationFlagManager.get_help("TARGET_IDENTITY_QUANGUI"), 3)


func test_leverage_and_help_independent():
	"""leverage 和 help 是两组独立的 flag，互不影响"""
	RelationFlagManager.add_leverage("TARGET_NPC_LIBAI", "libai_secret")
	RelationFlagManager.add_help("TARGET_NPC_LIBAI", 3)
	assert_true(RelationFlagManager.has_leverage("TARGET_NPC_LIBAI"))
	assert_eq(RelationFlagManager.get_help("TARGET_NPC_LIBAI"), 3)


func test_get_help_returns_zero_for_unknown_target():
	"""从未添加过的 target 应返回 0"""
	assert_eq(RelationFlagManager.get_help("TARGET_NPC_LILINFU"), 0)


# ════════════════════════════════════════════════════════════
# Event ID 约定推导
# ════════════════════════════════════════════════════════════

func test_get_threaten_event_id_npc():
	"""NPC target 的威胁事件 ID 符合约定"""
	var eid = RelationFlagManager.get_threaten_event_id("TARGET_NPC_LIBAI")
	assert_eq(eid, "event_threaten_TARGET_NPC_LIBAI")


func test_get_threaten_event_id_identity():
	"""身份 target 的威胁事件 ID 符合约定"""
	var eid = RelationFlagManager.get_threaten_event_id("TARGET_IDENTITY_MENZI")
	assert_eq(eid, "event_threaten_TARGET_IDENTITY_MENZI")


func test_get_help_event_id_npc():
	"""NPC target 的帮助事件 ID 符合约定"""
	var eid = RelationFlagManager.get_help_event_id("TARGET_NPC_GAOSHI")
	assert_eq(eid, "event_help_TARGET_NPC_GAOSHI")


func test_get_help_event_id_identity():
	"""身份 target 的帮助事件 ID 符合约定"""
	var eid = RelationFlagManager.get_help_event_id("TARGET_IDENTITY_QINGLIU_OWNER")
	assert_eq(eid, "event_help_TARGET_IDENTITY_QINGLIU_OWNER")
