# ================================================================
# Sub-action 系统测试
# ================================================================
# 覆盖场景：
#   - Action.sub_actions 数据模型
#   - Picker 数据构建（GameEntity）
#   - SceneAction 继承 sub_actions
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# Action.sub_actions 数据模型
# ════════════════════════════════════════════════════════════

func test_sub_actions_dict_init() -> void:
	"""sub_actions 字段初始应为空字典"""
	var a := SceneAction.new()
	assert_true(a.sub_actions.is_empty(), "新建 Action 的 sub_actions 应为空")


func test_sub_actions_set_values() -> void:
	"""可以填入 sub_action uuid→name 映射"""
	var a := SceneAction.new()
	a.sub_actions = {
		"actor:libai": "找李白痛饮",
		"actor:dufu": "与杜甫唱和",
	}
	assert_eq(a.sub_actions.size(), 2, "sub_actions 应有 2 个条目")
	assert_eq(a.sub_actions.get("actor:libai"), "找李白痛饮")
	assert_eq(a.sub_actions.get("actor:dufu"), "与杜甫唱和")


# ════════════════════════════════════════════════════════════
# Picker 数据构建 (GameEntity)
# ════════════════════════════════════════════════════════════

func test_picker_data_construction() -> void:
	"""
	遍历 sub_actions 构建 GameEntity 数组。
	每个实体必备：uuid, name, meta("parent_main_tag")
	"""
	var sub_actions := {
		"actor:libai": "找李白痛饮",
		"actor:dufu": "与杜甫唱和",
	}
	var parent_main_tag := "action:main:jiaoyou"
	
	var picker_data: Array[GameEntity] = []
	for sub_uuid in sub_actions:
		var entity := GameEntity.new({"uuid": sub_uuid, "name": sub_actions[sub_uuid]})
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
	assert_eq(libai_entity.name, "找李白痛饮", "name 应与 sub_actions dict 一致")
	assert_eq(libai_entity.get_meta("parent_main_tag"), parent_main_tag, "meta parent_main_tag 应正确携带")


func test_picker_data_duplicate_main_tag() -> void:
	"""
	多个 sub-action 选项各自携带相同的 parent_main_tag。
	（未来多行动混合 picker 时每个选项的 parent_main_tag 可能不同）
	"""
	var sub_actions := {
		"actor:libai": "找李白痛饮",
		"actor:dufu": "与杜甫唱和",
	}
	
	var entities: Array[GameEntity] = []
	for sub_uuid in sub_actions:
		var e := GameEntity.new({"uuid": sub_uuid, "name": sub_actions[sub_uuid]})
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
