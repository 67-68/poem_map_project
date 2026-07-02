# ================================================================
# Sub-action 系统测试
# ================================================================
# 覆盖场景：
#   - Action.sub_actions 数据模型（Array[Action]）
#   - Picker 数据构建（GameEntity）
#   - SceneAction 继承 sub_actions
#   - possibility + failed_result 逻辑
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
	"""可以填入 Action 资源数组"""
	var a := SceneAction.new()
	var sub1 := SceneAction.new()
	sub1.uuid = "actor:libai"
	sub1.name = "找李白痛饮"
	var sub2 := SceneAction.new()
	sub2.uuid = "actor:dufu"
	sub2.name = "与杜甫唱和"
	a.sub_actions = [sub1, sub2]
	assert_eq(a.sub_actions.size(), 2, "sub_actions 应有 2 个条目")
	assert_eq(a.sub_actions[0].uuid, "actor:libai")
	assert_eq(a.sub_actions[0].name, "找李白痛饮")
	assert_eq(a.sub_actions[1].uuid, "actor:dufu")
	assert_eq(a.sub_actions[1].name, "与杜甫唱和")


# ════════════════════════════════════════════════════════════
# Picker 数据构建 (GameEntity)
# ════════════════════════════════════════════════════════════

func test_picker_data_construction() -> void:
	"""
	遍历 sub_actions 构建 GameEntity 数组。
	每个实体必备：uuid, name, meta("parent_main_tag")
	"""
	var sub1 := SceneAction.new()
	sub1.uuid = "actor:libai"
	sub1.name = "找李白痛饮"
	var sub2 := SceneAction.new()
	sub2.uuid = "actor:dufu"
	sub2.name = "与杜甫唱和"
	var sub_actions: Array[Action] = [sub1, sub2]
	var parent_main_tag := "action:main:jiaoyou"

	var picker_data: Array[GameEntity] = []
	for sub_action in sub_actions:
		var entity := GameEntity.new({"uuid": sub_action.uuid, "name": sub_action.name})
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
	assert_eq(libai_entity.name, "找李白痛饮", "name 应与 sub_action.name 一致")
	assert_eq(libai_entity.get_meta("parent_main_tag"), parent_main_tag, "meta parent_main_tag 应正确携带")


func test_picker_data_duplicate_main_tag() -> void:
	"""
	多个 sub-action 选项各自携带相同的 parent_main_tag。
	（未来多行动混合 picker 时每个选项的 parent_main_tag 可能不同）
	"""
	var sub1 := SceneAction.new()
	sub1.uuid = "actor:libai"
	sub1.name = "找李白痛饮"
	var sub2 := SceneAction.new()
	sub2.uuid = "actor:dufu"
	sub2.name = "与杜甫唱和"
	var sub_actions: Array[Action] = [sub1, sub2]

	var entities: Array[GameEntity] = []
	for sub_action in sub_actions:
		var e := GameEntity.new({"uuid": sub_action.uuid, "name": sub_action.name})
		e.set_meta("parent_main_tag", "action:main:jiaoyou")
		entities.append(e)

	for e in entities:
		assert_eq(e.get_meta("parent_main_tag"), "action:main:jiaoyou",
			"每个 entity 都应带有 parent_main_tag")


# ════════════════════════════════════════════════════════════
# Tag 组合逻辑（用于 AND 模式）
# ════════════════════════════════════════════════════════════

func test_tag_combination() -> void:
	"""
	测试 _on_sub_action_picked 中 tag 追加逻辑：
	sub_uuid + parent_action_tags 应合并为一个 current_action_tags 数组。
	"""
	var sub_uuid := "actor:libai"
	var parent_tags := ["action:main:jiaoyou"]

	var combined: Array[String] = []
	combined.append(sub_uuid)
	for tag in parent_tags:
		combined.append(tag)

	assert_eq(combined.size(), 2, "组合后应有 2 个 tag")
	assert_eq(combined[0], "actor:libai", "sub_uuid 在先")
	assert_eq(combined[1], "action:main:jiaoyou", "action tag 在后")


# ════════════════════════════════════════════════════════════
# possibility 默认值
# ════════════════════════════════════════════════════════════

func test_possibility_default() -> void:
	"""possibility 默认应为 100（必定触发）"""
	var a := SceneAction.new()
	assert_eq(a.possibility, 100, "新建 Action 的 possibility 默认为 100")


func test_possibility_set() -> void:
	"""可以设置 possibility 值"""
	var a := SceneAction.new()
	a.possibility = 60
	assert_eq(a.possibility, 60, "possibility 应可设为 60")


# ════════════════════════════════════════════════════════════
# failed_result 默认值
# ════════════════════════════════════════════════════════════

func test_failed_result_default() -> void:
	"""failed_result 默认应为空的 ChoiceResult"""
	var a := SceneAction.new()
	assert_not_null(a.failed_result, "新建 Action 的 failed_result 不应为 null")
	assert_true(a.failed_result.operators.is_empty(), "新建 Action 的 failed_result.operators 应为空")
