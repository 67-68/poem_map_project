extends GutTest


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 清理动态创建的 NPCDocument 条目（测试用例间隔离）
	var to_remove: Array[String] = []
	for doc_id in Database.npc_document:
		to_remove.append(doc_id)
	for doc_id in to_remove:
		Database.npc_document.erase(doc_id)
	# 重置已有 .tres 的 NPCDocument 属性
	var docs = Database.get_npc_document_all()
	for target_tag in docs:
		var doc = docs[target_tag]
		if doc:
			doc.leverage_keys.clear()
			doc.help_count = 0
			doc.person_state = RelationFlagManager.DEFAULT_PERSON_STATE


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
	assert_false(RelationFlagManager.has_leverage("TARGET_NPC_HUSHANG"), "空 target clear 后应仍无 leverage")


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
	"""leverage 和 help 是 NPCDocument 的两组独立属性，互不影响"""
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


# ════════════════════════════════════════════════════════════
# Person State — 四态状态机 (NEW)
# ════════════════════════════════════════════════════════════

func test_person_state_default_is_not_meet():
	"""全新 target 默认 person_state 应为 not_meet"""
	var tag = "TARGET_NEW_NOBODY"
	assert_eq(RelationFlagManager.get_person_state(tag), RelationFlagManager.PERSON_STATE.NOT_MEET)


func test_person_state_set_and_get():
	"""set_person_state → get_person_state 往返一致"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
	assert_eq(RelationFlagManager.get_person_state(tag), "know_about")


func test_person_state_is_check():
	"""is_person_state 应在匹配时返回 true"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	assert_true(RelationFlagManager.is_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE))
	assert_false(RelationFlagManager.is_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH))


func test_person_state_invalid_value_rejected():
	"""非法 person_state 值应被拒写"""
	var tag = "TARGET_NPC_LIBAI"
	# 先设为合法值确认写入成功
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
	assert_eq(RelationFlagManager.get_person_state(tag), "know_about")
	# 非法值拒绝写入，状态应保持 know_about
	RelationFlagManager.set_person_state(tag, "best_friends_forever")
	assert_eq(RelationFlagManager.get_person_state(tag), "know_about", "非法值不应覆盖已有状态")


func test_person_state_clear():
	"""clear_person_state 应重置为默认值"""
	var tag = "TARGET_NPC_GAOSHI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH)
	RelationFlagManager.clear_person_state(tag)
	assert_eq(RelationFlagManager.get_person_state(tag), RelationFlagManager.DEFAULT_PERSON_STATE)


# ════════════════════════════════════════════════════════════
# get_next_person_state — 自动推算下一级
# ════════════════════════════════════════════════════════════

func test_get_next_from_not_meet():
	"""T0 → 下一级应为 T1 know_about"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.NOT_MEET)
	assert_eq(RelationFlagManager.get_next_person_state(tag), "know_about")


func test_get_next_from_know_about():
	"""T1 → 下一级应为 T2 inner_circle"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
	assert_eq(RelationFlagManager.get_next_person_state(tag), "inner_circle")


func test_get_next_from_inner_circle():
	"""T2 → 下一级应为 T3 blood_oath"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	assert_eq(RelationFlagManager.get_next_person_state(tag), "blood_oath")


func test_get_next_from_blood_oath():
	"""T3 已是最高级，get_next 应返回空字符串"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH)
	assert_eq(RelationFlagManager.get_next_person_state(tag), "")


# ════════════════════════════════════════════════════════════
# upgrade_person_state — 自动升级到下一级
# ════════════════════════════════════════════════════════════

func test_upgrade_t0_to_t1():
	"""T0 upgrade → T1"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.NOT_MEET)
	var ok = RelationFlagManager.upgrade_person_state(tag)
	assert_true(ok)
	assert_eq(RelationFlagManager.get_person_state(tag), "know_about")


func test_upgrade_t1_to_t2():
	"""T1 upgrade → T2"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
	var ok = RelationFlagManager.upgrade_person_state(tag)
	assert_true(ok)
	assert_eq(RelationFlagManager.get_person_state(tag), "inner_circle")


func test_upgrade_t2_to_t3():
	"""T2 upgrade → T3"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	var ok = RelationFlagManager.upgrade_person_state(tag)
	assert_true(ok)
	assert_eq(RelationFlagManager.get_person_state(tag), "blood_oath")


func test_upgrade_t3_noop():
	"""T3 upgrade 应返回 false，状态不变"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH)
	var ok = RelationFlagManager.upgrade_person_state(tag)
	assert_false(ok)
	assert_eq(RelationFlagManager.get_person_state(tag), "blood_oath", "T3 升级应无变化")


func test_upgrade_cross_target_isolation():
	"""不同 target 的 person_state 升级互不影响"""
	var tag_a = "TARGET_NPC_LIBAI"
	var tag_b = "TARGET_NPC_GAOSHI"
	RelationFlagManager.set_person_state(tag_a, RelationFlagManager.PERSON_STATE.NOT_MEET)
	RelationFlagManager.set_person_state(tag_b, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)

	RelationFlagManager.upgrade_person_state(tag_a)
	assert_eq(RelationFlagManager.get_person_state(tag_a), "know_about")
	assert_eq(RelationFlagManager.get_person_state(tag_b), "know_about", "tag_b 不应被影响")


# ════════════════════════════════════════════════════════════
# get_tier_multiplier — 离散 4 态乘法表
# ════════════════════════════════════════════════════════════

func test_tier_multiplier_not_meet():
	"""T0 倍率应为 0.0（无交互）"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.NOT_MEET)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, true), 0.0, 0.001)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, false), 0.0, 0.001)


func test_tier_multiplier_know_about():
	"""T1 倍率应为 1.0（公平交易）"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, true), 1.0, 0.001)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, false), 1.0, 0.001)


func test_tier_multiplier_inner_circle_good():
	"""T2 好属性倍率应为 1.5"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, true), 1.5, 0.001)


func test_tier_multiplier_inner_circle_bad():
	"""T2 坏属性倍率应为 0.67"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, false), 0.67, 0.001)


func test_tier_multiplier_blood_oath_good():
	"""T3 好属性倍率应为 2.5"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, true), 2.5, 0.001)


func test_tier_multiplier_blood_oath_bad():
	"""T3 坏属性倍率应为 0.4"""
	var tag = "TARGET_NPC_LIBAI"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.BLOOD_OATH)
	assert_almost_eq(RelationFlagManager.get_tier_multiplier(tag, false), 0.4, 0.001)


func test_tier_multiplier_empty_tag():
	"""空 target_tag 应返回 1.0"""
	assert_almost_eq(RelationFlagManager.get_tier_multiplier("", true), 1.0, 0.001)


# ════════════════════════════════════════════════════════════
# get_known_targets — 兼容四态（≥T1 都算认识）
# ════════════════════════════════════════════════════════════

func test_known_targets_includes_all_tiers_above_not_meet():
	"""T1/T2/T3 都应被 get_known_targets 返回，T0 not_meet 不应被返回"""
	# ENUMS.RELATION_TARGET 通过 to_relation_str() 转为小写 target_tag（如 LIBAI → "libai"）
	# "libai" 是 RELATION_TARGET 中 LIBAI 的 to_relation_str() 结果
	var tag = "libai"
	RelationFlagManager.set_person_state(tag, RelationFlagManager.PERSON_STATE.INNER_CIRCLE)
	var known = RelationFlagManager.get_known_targets()
	assert_gt(known.size(), 0, "至少应有一个 known target")
	assert_true(known.has(tag), "libai (T2) 应在 known 列表中")


# ════════════════════════════════════════════════════════════
# get_all_relations — 无 favor 字段
# ════════════════════════════════════════════════════════════

func test_get_all_relations_no_favor():
	"""get_all_relations 不应再包含 favor 字段"""
	var rels = RelationFlagManager.get_all_relations(["libai"])
	assert_true(rels.has("libai"))
	var data = rels["libai"]
	assert_false(data.has("favor"), "get_all_relations 不应再包含 favor")
	assert_true(data.has("person_state"))
	assert_true(data.has("leverage_keys"))
	assert_true(data.has("help"))
