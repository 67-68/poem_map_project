# ----------------------------------------------------------------
# 正交事件 CSV 输出解析测试
# ----------------------------------------------------------------
# 验证 generate_orthogonal_events.py 产出的 CSV 格式能被
# DSLParser.parse_csv_data() 正确解析。
#
# 测试数据模拟了 bai_ye_honeymoon 管线产出的 CSV 输出，
# 包含正确的 DSL 格式（Layer 0: |, Layer 1: ;）。
# ----------------------------------------------------------------
extends GutTest

const REQUIREMENTS_DSL = "prop_gt(name=ambition;val=0)|prop_lt(name=ambition;val=70)"

# L0+TypeA+M0 (combined=1.0): money(10) | money(20)
var _csv_l0_typea_m0: Array[Dictionary] = [
	{
		"row_type": "random_event",
		"uuid": "bai_ye_honeymoon_l0_typea_m0",
		"context": "trigger_tags=bai_ye|weight=10",
		"requirements": REQUIREMENTS_DSL,
		"title": "门钱",
		"description": "尚书省门口被门子拦住索要门敬",
	},
	{
		"row_type": ">option",
		"description": "（确认）",
		"results": "prop_sub(name=money; val=10) | prop_sub(name=money; val=20)",
	},
]

# L0+TypeC+M1 (combined=1.5): money(15) | fatigue(15)
var _csv_l0_typec_m1: Array[Dictionary] = [
	{
		"row_type": "random_event",
		"uuid": "bai_ye_honeymoon_l0_typec_m1",
		"context": "trigger_tags=bai_ye|weight=10",
		"title": "候见室",
		"description": "枯坐候见室两个时辰",
	},
	{
		"row_type": ">option",
		"description": "（确认）",
		"results": "prop_sub(name=money; val=15) | prop_sub(name=fatigue; val=15)",
	},
]

# L2+TypeA+M2 (combined=2.0): money(20) | money(40)
var _csv_l2_typea_m2: Array[Dictionary] = [
	{
		"row_type": "random_event",
		"uuid": "bai_ye_honeymoon_l2_typea_m2",
		"context": "trigger_tags=bai_ye|weight=10",
		"requirements": REQUIREMENTS_DSL,
		"title": "相府门槛",
		"description": "李林甫府邸前等待接见",
	},
	{
		"row_type": ">option",
		"description": "（确认）",
		"results": "prop_sub(name=money; val=20) | prop_sub(name=money; val=40)",
	},
]


func _parse_events(data: Array[Dictionary]) -> Array:
	"""便捷方法：用 DSLParser 解析数据集"""
	return DSLParser.parse_csv_data(data, "random_event")


# ── 基本解析测试 ──

func test_basic_parse_count() -> void:
	"""验证单个事件数据集解析出 1 个事件"""
	var events = _parse_events(_csv_l0_typea_m0)
	assert_eq(events.size(), 1, "应解析出 1 个事件")


func test_basic_uuid() -> void:
	"""验证 uuid 正确"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_eq(evt.uuid, "bai_ye_honeymoon_l0_typea_m0")


func test_basic_title() -> void:
	"""验证 title 映射到 name 字段"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_eq(evt.name, "门钱")


func test_basic_description() -> void:
	"""验证 description 正确"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_eq(evt.description, "尚书省门口被门子拦住索要门敬")


# ── Requirements 解析测试 ──

func test_requirements_parsed() -> void:
	"""验证 requirements DSL 被解析为 requirement 对象"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_not_null(evt.requirement, "requirement 不应为 null")


func test_event_without_requirement() -> void:
	"""验证没有 requirement 的事件也能正常解析"""
	var events = _parse_events(_csv_l0_typec_m1)
	var evt = events[0] as RandomEvent
	assert_not_null(evt, "无 requirement 的事件应正常解析")


# ── Option 解析测试 ──

func test_event_option_count() -> void:
	"""验证每个事件有 1 个选项"""
	for data in [_csv_l0_typea_m0, _csv_l0_typec_m1, _csv_l2_typea_m2]:
		var events = _parse_events(data)
		var evt = events[0] as RandomEvent
		assert_eq(evt.options.size(), 1, "每个事件应有 1 个选项 (uuid=%s)" % evt.uuid)


func test_option_description() -> void:
	"""验证选项的描述文本正确"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_eq(option.description, "（确认）", "选项描述应为（确认）")


func test_option_has_choice_result() -> void:
	"""验证选项有 choice_result"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_not_null(option.choice_result, "选项应有 choice_result")


func test_option_choice_result_type() -> void:
	"""验证 choice_result 类型为 ChoiceResult"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_true(option.choice_result is ChoiceResult,
		"choice_result 应为 ChoiceResult 实例")


# ── DSL Operator 解析测试 ──

func test_operator_count_in_l0_typea_m0() -> void:
	"""L0+TypeA+M0: prop_sub(money;10) | prop_sub(money;20) → 2 个 operator"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_eq(option.choice_result.operators.size(), 2,
		"应有 2 个 operator")


func test_operator_count_in_l0_typec_m1() -> void:
	"""L0+TypeC+M1: prop_sub(money;15) | prop_sub(fatigue;15) → 2 个 operator"""
	var events = _parse_events(_csv_l0_typec_m1)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_eq(option.choice_result.operators.size(), 2,
		"应有 2 个 operator")


func test_operator_count_in_l2_typea_m2() -> void:
	"""L2+TypeA+M2: prop_sub(money;20) | prop_sub(money;40) → 2 个 operator"""
	var events = _parse_events(_csv_l2_typea_m2)
	var evt = events[0] as RandomEvent
	var option = evt.options[0]
	assert_eq(option.choice_result.operators.size(), 2,
		"应有 2 个 operator")


# ── Context 解析测试 ──

func test_context_trigger_tags() -> void:
	"""验证 trigger_tags 从 context 正确解析"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_gt(evt.target_tags.size(), 0, "trigger_tags 不应为空")
	assert_true("bai_ye" in evt.target_tags, "应包含 bai_ye")


func test_context_weight() -> void:
	"""验证 weight 从 context 正确解析为浮点数"""
	var events = _parse_events(_csv_l0_typea_m0)
	var evt = events[0] as RandomEvent
	assert_eq(evt.weight, 10.0, "weight 应为 10.0")


# ── 批量解析测试 ──

func test_batch_parse_count() -> void:
	"""验证合并数据集解析出 3 个事件"""
	var combined: Array[Dictionary] = []
	combined.append_array(_csv_l0_typea_m0)
	combined.append_array(_csv_l0_typec_m1)
	combined.append_array(_csv_l2_typea_m2)

	var events = DSLParser.parse_csv_data(combined, "random_event")
	assert_eq(events.size(), 3, "应解析出 3 个事件")


func test_batch_parse_uuids() -> void:
	"""验证批量解析的 uuid 顺序正确"""
	var combined: Array[Dictionary] = []
	combined.append_array(_csv_l0_typea_m0)
	combined.append_array(_csv_l0_typec_m1)
	combined.append_array(_csv_l2_typea_m2)

	var events = DSLParser.parse_csv_data(combined, "random_event")
	assert_eq(events[0].uuid, "bai_ye_honeymoon_l0_typea_m0")
	assert_eq(events[1].uuid, "bai_ye_honeymoon_l0_typec_m1")
	assert_eq(events[2].uuid, "bai_ye_honeymoon_l2_typea_m2")
