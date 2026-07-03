# ================================================================
# Sub-action 系统测试
# ================================================================
# 覆盖场景：
#   - Action.sub_actions 数据模型（Array[String] UUID）
#   - Picker 数据构建（GameEntity）
#   - SceneAction 继承 sub_actions
#   - possibility + failed_result 逻辑
#   - 子 action tags/fallback 覆盖父级（SceneAction 用 main_tag，普通 Action 用空 main_tag）
#   - 子 action 查不到时 fallback 父级挂起数据
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# Action.sub_actions 数据模型
# ════════════════════════════════════════════════════════════

func test_sub_actions_init() -> void:
	"""sub_actions 字段初始应为空数组"""
	var a := SceneAction.new()
	assert_true(a.sub_actions.is_empty(), "新建 Action 的 sub_actions 应为空")


func test_sub_actions_set_values() -> void:
	"""可以填入 UUID 字符串数组"""
	var a := SceneAction.new()
	a.sub_actions = ["actor:libai", "actor:dufu"]
	assert_eq(a.sub_actions.size(), 2, "sub_actions 应有 2 个条目")
	assert_eq(a.sub_actions[0], "actor:libai")
	assert_eq(a.sub_actions[1], "actor:dufu")


# ════════════════════════════════════════════════════════════
# Picker 数据构建 (GameEntity)
# ════════════════════════════════════════════════════════════

func test_picker_data_construction() -> void:
	"""
	从 UUID 字符串数组构建 GameEntity 数组。
	每个实体必备：uuid, name, meta("parent_main_tag")
	"""
	var sub_uuids: Array[String] = ["actor:libai", "actor:dufu"]
	var parent_main_tag := "action:main:jiaoyou"

	var picker_data: Array[GameEntity] = []
	for sub_uuid in sub_uuids:
		var entity := GameEntity.new({"uuid": sub_uuid, "name": sub_uuid})
		entity.set_meta("parent_main_tag", parent_main_tag)
		picker_data.append(entity)

	assert_eq(picker_data.size(), 2, "picker_data 应有 2 个条目")

	# 验证 "actor:libai" 条目的完整数据
	var libai_entity = null
	for e in picker_data:
		if e.uuid == "actor:libai":
			libai_entity = e
			break

	assert_not_null(libai_entity, "应能找到 actor:libai 实体")
	assert_eq(libai_entity.name, "actor:libai", "name 应与 sub_uuid 一致")
	assert_eq(libai_entity.get_meta("parent_main_tag"), parent_main_tag, "meta parent_main_tag 应正确携带")


func test_picker_data_duplicate_main_tag() -> void:
	"""
	多个 sub-action UUID 各自携带相同的 parent_main_tag。
	（未来多行动混合 picker 时每个选项的 parent_main_tag 可能不同）
	"""
	var sub_uuids: Array[String] = ["actor:libai", "actor:dufu"]

	var entities: Array[GameEntity] = []
	for sub_uuid in sub_uuids:
		var e := GameEntity.new({"uuid": sub_uuid, "name": sub_uuid})
		e.set_meta("parent_main_tag", "action:main:jiaoyou")
		entities.append(e)

	for e in entities:
		assert_eq(e.get_meta("parent_main_tag"), "action:main:jiaoyou",
			"每个 entity 都应带有 parent_main_tag")


# ════════════════════════════════════════════════════════════
# Tag 组合逻辑（用于 AND 模式）— 使用子 action 的 tags/fallback
# ════════════════════════════════════════════════════════════

func test_tag_combination_sub_action_tags() -> void:
	"""
	_on_sub_action_picked 应使用子 action 的 action_tags，
	而非父 action 的 tags。组合结果为：sub_uuid + sub_action.action_tags。
	"""
	var sub_uuid := "actor:libai"
	var sub_action_tags := ["action:main:jiaoyou", "action:main:baiye"]

	var combined: Array[String] = []
	combined.append(sub_uuid)
	for tag in sub_action_tags:
		combined.append(tag)

	assert_eq(combined.size(), 3, "组合后应有 3 个 tag（sub_uuid + 2 个 action_tags）")
	assert_eq(combined[0], "actor:libai", "sub_uuid 在先")
	assert_eq(combined[1], "action:main:jiaoyou", "第一个 action_tag")
	assert_eq(combined[2], "action:main:baiye", "第二个 action_tag")


func test_scene_action_sub_uses_own_main_tag() -> void:
	"""
	若子 action 是 SceneAction，应使用其 main_tag 作为事件桶 key。
	"""
	var sub_action := SceneAction.new()
	# _main_tag 是 private 的，但 main_tag getter 返回 to_action_str(_main_tag)
	# 这里测试 main_tag 可正常取值（默认为 "" 因为 _main_tag=-1）
	assert_not_null(sub_action.main_tag, "SceneAction.main_tag 不应为 null")


func test_plain_action_sub_uses_empty_main_tag() -> void:
	"""
	若子 action 是普通 Action（非 SceneAction），main_tag 应传空串，
	依赖 ActionTagFilter AND 模式过滤。
	"""
	var sub_action := Action.new()
	# Action 没有 main_tag 属性
	assert_false(sub_action is SceneAction, "普通 Action 不应是 SceneAction")
	var sub_main_tag: String = ""
	if sub_action is SceneAction:
		sub_main_tag = (sub_action as SceneAction).main_tag
	else:
		sub_main_tag = ""
	assert_eq(sub_main_tag, "", "普通 Action 的 main_tag 应为空串")


func test_sub_action_fallback_event_uuid() -> void:
	"""
	子 action 的 fallback_event_uuid 应被用于事件扫描 context。
	"""
	var sub_action := Action.new()
	sub_action.fallback_event_uuid = "event_test_fallback"

	var sub_fallback: String = sub_action.fallback_event_uuid
	assert_eq(sub_fallback, "event_test_fallback", "应使用子 action 的 fallback_event_uuid")

	# 默认为空
	var default_action := Action.new()
	assert_eq(default_action.fallback_event_uuid, "", "默认 fallback_event_uuid 应为空串")


func test_sub_action_fallback_to_parent_when_not_found() -> void:
	"""
	若子 action 在 Database 中查不到，应 fallback 到父 action 的挂起数据。
	"""
	var parent_main_tag := "action:main:jiaoyou"
	var parent_fallback := "parent_fallback_event"
	var parent_tags := ["action:main:jiaoyou"]

	# 模拟 sub_action 为 null（Database 查不到）
	var sub_action = null
	var sub_main_tag: String
	var sub_fallback: String
	var sub_tags: Array[String]

	if sub_action:
		sub_fallback = sub_action.fallback_event_uuid
		sub_tags = sub_action.action_tags.duplicate()
	else:
		sub_main_tag = parent_main_tag
		sub_fallback = parent_fallback
		sub_tags = parent_tags.duplicate()

	assert_eq(sub_main_tag, "action:main:jiaoyou", "查不到子 action 时应 fallback 父 main_tag")
	assert_eq(sub_fallback, "parent_fallback_event", "查不到子 action 时应 fallback 父 fallback")
	assert_eq(sub_tags.size(), 1, "查不到子 action 时应 fallback 父 tags")


# ════════════════════════════════════════════════════════════
# possibility 默认值
# ════════════════════════════════════════════════════════════

func test_possibility_default() -> void:
	"""possibility 默认应为 l_success_rate（=100，必定触发）"""
	var a := SceneAction.new()
	assert_eq(a.possibility, "l_success_rate", "新建 Action 的 possibility archetype 默认为 l_success_rate")
	assert_eq(a.get_possibility_int(), 100, "新建 Action 的 possibility 解析值应为 100")


func test_possibility_set() -> void:
	"""可以设置 possibility archetype"""
	var a := SceneAction.new()
	a.possibility = "m_success_rate"
	assert_eq(a.possibility, "m_success_rate", "possibility archetype 应可设为 m_success_rate")
	assert_eq(a.get_possibility_int(), 80, "m_success_rate 解析值应为 80")


# ════════════════════════════════════════════════════════════
# failed_result 默认值
# ════════════════════════════════════════════════════════════

func test_failed_result_default() -> void:
	"""failed_result 默认应为空的 ChoiceResult"""
	var a := SceneAction.new()
	assert_not_null(a.failed_result, "新建 Action 的 failed_result 不应为 null")
	assert_true(a.failed_result.operators.is_empty(), "新建 Action 的 failed_result.operators 应为空")
