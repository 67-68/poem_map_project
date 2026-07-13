extends GutTest
## SimpleOperatorPreviewFormatter 直接测试 — 粗暴 assert 精确文本
##
## 注意：PropertyOperator._get_arrow_count() 依赖 NamedDSLParser._load_named_amounts()
## 在 GUT 测试环境中可能返回空字典 → arrows 始终为 1（fallback 逻辑）。
## 因此箭头数量测试只验证 "有箭头" 和 "无数字"，不依赖精确箭头个数。

const _SimpleFormatter = preload("res://core/hints/simple_operator_preview_formatter.gd")


func before_each():
	Database.properties.clear()
	Database.traits.clear()


func after_each():
	Database.properties.clear()
	Database.traits.clear()


# Helper: 创建一个 PropertyOperator，附带 Database 注册
func _make_prop(name: String, val: int) -> PropertyOperator:
	var op = PropertyOperator.new()
	op.property = name
	op.value = val
	if not Database.properties.has(name):
		var p = Property.new()
		p.uuid = name
		p.name = name
		Database.properties[name] = p
	return op


# ═══════════════════════════════════════════════
#  PropertyOperator — 结构验证（箭头存在 + 无数字）
# ═══════════════════════════════════════════════

func test_prop_positive_has_arrows():
	var op = _make_prop("test_prop", 30)
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_true(lines[0].begins_with("• test_prop"), "Should start with bullet + name")
	assert_true(lines[0].contains("↑"), "Positive should have up arrows")
	assert_false(lines[0].contains("+30"), "Should NOT contain raw number")


func test_prop_negative_has_arrows():
	var op = _make_prop("test_prop", -50)
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_true(lines[0].begins_with("• test_prop"), "Should start with bullet + name")
	assert_true(lines[0].contains("↓"), "Negative should have down arrows")
	assert_false(lines[0].contains("-50"), "Should NOT contain raw number")


func test_prop_zero_skip():
	var op = _make_prop("test_prop", 0)
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 0)


# ═══════════════════════════════════════════════
#  TimeOperator — 精确文本匹配
# ═══════════════════════════════════════════════

func test_time_5():
	var op = TimeOperator.new()
	op.day = 5
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• ⏱5天")


func test_time_1():
	var op = TimeOperator.new()
	op.day = 1
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• ⏱1天")


func test_time_zero_skip():
	var op = TimeOperator.new()
	op.day = 0
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 0)


func test_time_refresh_skip():
	var op = TimeOperator.new()
	op.refresh_time = true
	op.day = 5
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 0)


# ═══════════════════════════════════════════════
#  TraitOperator — 精确文本匹配
# ═══════════════════════════════════════════════

func test_trait_add():
	var op = TraitOperator.new()
	op.str_traits = "test_trait"
	op.operator = REQ_OPERATOR.CRUD.ADD
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 获 test_trait")


func test_trait_remove():
	var op = TraitOperator.new()
	op.str_traits = "test_trait"
	op.operator = REQ_OPERATOR.CRUD.REMOVE
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 失 test_trait")


func test_trait_add_with_db():
	var t = Trait.new()
	t.uuid = "test_trait"
	t.name = "测试特质"
	Database.traits["test_trait"] = t

	var op = TraitOperator.new()
	op.str_traits = "test_trait"
	op.operator = REQ_OPERATOR.CRUD.ADD
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 获 测试特质")


func test_trait_remove_with_db():
	var t = Trait.new()
	t.uuid = "test_trait"
	t.name = "测试特质"
	Database.traits["test_trait"] = t

	var op = TraitOperator.new()
	op.str_traits = "test_trait"
	op.operator = REQ_OPERATOR.CRUD.REMOVE
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 失 测试特质")


# ═══════════════════════════════════════════════
#  PoemRewardOperator — 精确文本匹配
# ═══════════════════════════════════════════════

func test_poem_reward_money():
	var op = PoemRewardOperator.new()
	op.mode = "money"
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 卖诗")


func test_poem_reward_fame():
	var op = PoemRewardOperator.new()
	op.mode = "fame"
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 以诗换名")


func test_poem_reward_baiye():
	var op = PoemRewardOperator.new()
	op.mode = "baiye"
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 携诗拜谒")


func test_poem_reward_unknown_mode_fallback():
	var op = PoemRewardOperator.new()
	op.mode = "something_weird"
	var lines = _SimpleFormatter.build_simple_preview([op])
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "• 卖诗")


# ═══════════════════════════════════════════════
#  边缘情况
# ═══════════════════════════════════════════════

func test_empty_list():
	assert_eq(_SimpleFormatter.build_simple_preview([]).size(), 0)


func test_null_operator():
	assert_eq(_SimpleFormatter.build_simple_preview([null]).size(), 0)


func test_base_operator_skip():
	var op = BaseOperator.new()
	assert_eq(_SimpleFormatter.build_simple_preview([op]).size(), 0)


func test_mixed_operators():
	var prop = _make_prop("test_prop", 50)
	var time = TimeOperator.new()
	time.day = 3

	var lines = _SimpleFormatter.build_simple_preview([prop, time])
	assert_eq(lines.size(), 2)
	assert_true(lines[0].begins_with("• test_prop"), "First line: property name")
	assert_true(lines[0].contains("↑"), "First line: up arrow")
	assert_eq(lines[1], "• ⏱3天", "Second line: time")


func test_mixed_with_skipped():
	var valid1 = _make_prop("test_prop", 10)
	var invalid = _make_prop("test_prop", 0)
	var valid2 = _make_prop("test_prop", 50)

	var lines = _SimpleFormatter.build_simple_preview([valid1, invalid, valid2])
	assert_eq(lines.size(), 2, "Should skip 0-value operator")
	assert_true(lines[0].begins_with("• test_prop"), "First valid line")
	assert_true(lines[1].begins_with("• test_prop"), "Second valid line")
