# ================================================================
# ActionHintBuilder 行动提示构建器测试
# ================================================================
# GUT 限制：build_action_hint(action != null) 内部无条件调用
# SurvivalManager.get_active_ap_hint() → ENUMS.to_prop_str(int)，
# 该 ENUMS 转换在 GUT 沙箱中不可用。因此仅测独立于该路径的接口。
# ================================================================
extends GutTest


func _make_scene_action(id: String) -> SceneAction:
	var a := SceneAction.new()
	a.uuid = id
	return a


func _make_prop_op(prop_name: String, val: int) -> PropertyOperator:
	var op := PropertyOperator.new()
	op.property = prop_name
	op.value = val
	return op


func before_each():
	PlayerState._is_repeated_action = false
	PlayerState.last_action_tags.clear()
	Database.actions.clear()
	Database.properties.clear()
	Database.action_archetypes.clear()
	GameSave.data.properties.clear()
	for key in ["health", "money", "literary_fame"]:
		if not Database.properties.has(key):
			var p := Property.new(); p.uuid = key; p.name = key; p.lowest = 0; p.val = 50
			Database.properties[key] = p


func after_each():
	PlayerState._is_repeated_action = false
	PlayerState.last_action_tags.clear()
	Database.actions.clear()
	Database.properties.clear()
	Database.action_archetypes.clear()
	GameSave.data.properties.clear()


# ════════════════════════════════════════════════════════════
# build_action_hint — null action（唯一安全的调用路径）
# ════════════════════════════════════════════════════════════

func test_hint_null_action():
	var result := ActionHintBuilder.build_action_hint(null, false)
	assert_eq(result.narrative, "（无数据）")
	assert_eq(result.vector, "")


# ════════════════════════════════════════════════════════════
# build_operator_preview
# ════════════════════════════════════════════════════════════

func test_operator_preview_empty():
	assert_eq(ActionHintBuilder.build_operator_preview([]).size(), 0)


func test_operator_preview_property_operator():
	var op := _make_prop_op("health", 30)
	var lines := ActionHintBuilder.build_operator_preview([op])
	assert_gt(lines.size(), 0)
	assert_true(lines[0].begins_with("• "))


func test_operator_preview_multiple():
	var o1 := _make_prop_op("health", 30)
	var o2 := _make_prop_op("money", -20)
	assert_eq(ActionHintBuilder.build_operator_preview([o1, o2]).size(), 2)


func test_operator_preview_invalid_skipped():
	var dummy := BaseOperator.new()
	var valid := _make_prop_op("money", -20)
	assert_eq(ActionHintBuilder.build_operator_preview([dummy, valid]).size(), 1)


func test_operator_preview_null_skipped():
	var valid := _make_prop_op("health", 10)
	assert_eq(ActionHintBuilder.build_operator_preview([null, valid]).size(), 1)


func test_operator_preview_zero_value_skipped():
	assert_eq(ActionHintBuilder.build_operator_preview([_make_prop_op("health", 0)]).size(), 0)


# ════════════════════════════════════════════════════════════
# build_choice_result_preview
# ════════════════════════════════════════════════════════════

func test_choice_result_preview_null():
	assert_eq(ActionHintBuilder.build_choice_result_preview(null).size(), 0)


func test_choice_result_preview_empty():
	var cr := ChoiceResult.new()
	assert_eq(ActionHintBuilder.build_choice_result_preview(cr).size(), 0)


func test_choice_result_preview_with_ops():
	var cr := ChoiceResult.new(); cr.operators = [_make_prop_op("health", -15)]
	assert_gt(ActionHintBuilder.build_choice_result_preview(cr).size(), 0)


# ════════════════════════════════════════════════════════════
# build_sub_action_preview（parent_day_consumed=0 路径，不触发 format_time_detail）
# ════════════════════════════════════════════════════════════

func test_sub_preview_null():
	assert_eq(ActionHintBuilder.build_sub_action_preview(null, [], [], 0.0), "")


func test_sub_preview_basic():
	var sub := _make_scene_action("test_sub"); sub.possibility = "l_success_rate"
	var r := ActionHintBuilder.build_sub_action_preview(sub, [], [], 0.0)
	assert_true(r.contains("[预览]"))
	assert_true(r.contains("概率"))


func test_sub_preview_success_ops():
	var sub := _make_scene_action("test_sub"); sub.possibility = "l_success_rate"
	var r := ActionHintBuilder.build_sub_action_preview(sub, [_make_prop_op("literary_fame", 20)], [], 0.0)
	assert_true(r.contains("[成功效果]"))


func test_sub_preview_fail_ops():
	var sub := _make_scene_action("test_sub"); sub.possibility = "m_success_rate"
	var r := ActionHintBuilder.build_sub_action_preview(sub, [], [_make_prop_op("health", -10)], 0.0)
	assert_true(r.contains("[失败效果]"))


func test_sub_preview_fallback():
	var sub := _make_scene_action("test_sub"); sub.possibility = "l_success_rate"
	var r := ActionHintBuilder.build_sub_action_preview(sub, [], [], 0.0)
	assert_true(r.contains("成败未卜"))
	assert_true(r.contains("后果难料"))


func test_instance_creation():
	assert_not_null(ActionHintBuilder.new())
