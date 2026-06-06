# ----------------------------------------------------------------
# 大唐地理系统 - DSL Trait 解析无菌测试舱
# ----------------------------------------------------------------
# 架构师留言：
# 这个测试专门验证DSL parser对trait数据的处理是否正确。
# 重点测试新语法（命名参数函数调用）和旧语法（冒号分割）的解析。
# ----------------------------------------------------------------
extends GutTest

# --- [测试用数据模拟] ---

# 模拟一个简单的trait数据结构
class MockTrait extends Resource:
	@export var uuid: String
	@export var name: String
	
	func _init(p_uuid: String = "", p_name: String = ""):
		uuid = p_uuid
		name = p_name

# ════════════════════════════════════════════════════════════
# 新语法测试（命名参数函数调用）
# ════════════════════════════════════════════════════════════

# --- 新语法: Trait Requirement ---

func test_new_trait_requirement_parsing():
	var req_str = "trait_has(name=official)"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: trait requirement解析结果不应为null")
	assert_true(parsed_req is TraitRequirement, "新语法: 解析结果应该是TraitRequirement类型")
	assert_eq(parsed_req.trait_name, "official", "新语法: trait名称应该被正确解析")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.HAS, "新语法: 操作符应该是HAS")

func test_new_trait_requirement_not_has():
	var req_str = "trait_not_has(name=corrupt)"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: trait_not_has解析结果不应为null")
	assert_eq(parsed_req.trait_name, "corrupt", "新语法: trait_not_has名称正确")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.NOT_HAS, "新语法: 操作符应该是NOT_HAS")

# --- 新语法: Property Requirement ---

func test_new_property_requirement_gt():
	var req_str = "prop_gt(name=money; val=50)"
	var parsed_req = MicroDSLParser.parse_property_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: prop_gt解析结果不应为null")
	assert_eq(parsed_req.property, "money", "新语法: 属性名应为money")
	assert_eq(parsed_req.value, 50, "新语法: 值应为50")
	assert_eq(parsed_req.operator, REQ_OPERATOR.COMPARE.GREATER_THAN, "新语法: 操作符应为GREATER_THAN")

func test_new_property_requirement_lt():
	var req_str = "prop_lt(name=health; val=30)"
	var parsed_req = MicroDSLParser.parse_property_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: prop_lt解析结果不应为null")
	assert_eq(parsed_req.property, "health", "新语法: 属性名应为health")
	assert_eq(parsed_req.value, 30, "新语法: 值应为30")
	assert_eq(parsed_req.operator, REQ_OPERATOR.COMPARE.LESS_THAN, "新语法: 操作符应为LESS_THAN")

func test_new_property_requirement_param_order():
	# 测试参数顺序无关
	var req_str = "prop_gt(val=50; name=money)"
	var parsed_req = MicroDSLParser.parse_property_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: 参数顺序无关")
	assert_eq(parsed_req.property, "money", "新语法: 属性名应为money")
	assert_eq(parsed_req.value, 50, "新语法: 值应为50")

# --- 新语法: Flag Requirement ---

func test_new_flag_bool_has():
	var req_str = "flag_bool_has(name=visited_palace)"
	var parsed_req = MicroDSLParser.parse_flag_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: flag_bool_has解析结果不应为null")
	assert_eq(parsed_req.flag_id, "visited_palace", "新语法: flag_id正确")
	assert_eq(parsed_req.type, "bool", "新语法: 类型应为bool")
	assert_eq(parsed_req.value, true, "新语法: 期望值为true")

func test_new_flag_int_gt():
	var req_str = "flag_int_gt(name=flag_score; val=100)"
	var parsed_req = MicroDSLParser.parse_flag_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: flag_int_gt解析结果不应为null")
	assert_eq(parsed_req.flag_id, "flag_score", "新语法: flag_id正确")
	assert_eq(parsed_req.type, "int", "新语法: 类型应为int")
	assert_eq(parsed_req.value, 100, "新语法: 值应为100")

func test_new_flag_str_is():
	var req_str = 'flag_str_is(name=player_name; val=张三)'
	var parsed_req = MicroDSLParser.parse_flag_requirement(req_str)
	
	assert_not_null(parsed_req, "新语法: flag_str_is解析结果不应为null")
	assert_eq(parsed_req.flag_id, "player_name", "新语法: flag_id正确")
	assert_eq(parsed_req.type, "str", "新语法: 类型应为str")
	assert_eq(parsed_req.operator, REQ_OPERATOR.COMPARE.EQUAL, "新语法: 操作符应为EQUAL")

# --- 新语法: Consequence Operators ---

func test_new_trait_operator_add():
	var op_str = "trait_add(name=brave)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "新语法: 应该解析出一个操作符")
	assert_true(parsed_ops[0] is TraitOperator, "新语法: 应为TraitOperator")
	assert_eq(parsed_ops[0].str_traits, "brave", "新语法: trait名称正确")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.ADD, "新语法: 操作符应为ADD")

func test_new_trait_operator_remove():
	var op_str = "trait_remove(name=cowardly)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "新语法: 应该解析出一个操作符")
	assert_eq(parsed_ops[0].str_traits, "cowardly", "新语法: trait名称正确")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.REMOVE, "新语法: 操作符应为REMOVE")

func test_new_property_operators():
	var op_str = "prop_add(name=prestige; val=50)|prop_sub(name=money; val=100)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 2, "新语法: 应该解析出两个操作符")
	assert_true(parsed_ops[0] is PropertyOperator, "新语法: 第一个应为PropertyOperator")
	assert_eq(parsed_ops[0].str_props, "prestige", "新语法: 第一个操作符属性名正确")
	assert_eq(parsed_ops[0].value, 50, "新语法: 第一个操作符值应为50")
	assert_true(parsed_ops[1] is PropertyOperator, "新语法: 第二个应为PropertyOperator")
	assert_eq(parsed_ops[1].str_props, "money", "新语法: 第二个操作符属性名正确")
	assert_eq(parsed_ops[1].value, -100, "新语法: 第二个操作符值应为-100（prop_sub取负）")

func test_new_flag_operators():
	var op_str = "flag_bool_set(name=has_key; val=true)|flag_int_append(name=score; val=50)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 2, "新语法: 应该解析出两个操作符")
	assert_true(parsed_ops[0] is FlagOperator, "新语法: 第一个应为FlagOperator")
	assert_eq(parsed_ops[0].flag_id, "has_key", "新语法: 第一个flag_id正确")
	assert_eq(parsed_ops[0].value, true, "新语法: 第一个值应为true")
	assert_true(parsed_ops[1] is FlagOperator, "新语法: 第二个应为FlagOperator")
	assert_eq(parsed_ops[1].flag_id, "score", "新语法: 第二个flag_id正确")
	assert_eq(parsed_ops[1].value, 50, "新语法: 第二个值应为50")

func test_new_flag_int_reduce_if_above():
	var op_str = "flag_int_reduce_if_above(name=score; threshold=100; amount=50)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)

	assert_eq(parsed_ops.size(), 1, "新语法: 应该解析出一个操作符")
	assert_true(parsed_ops[0] is FlagOperator, "新语法: 应为FlagOperator")
	var op = parsed_ops[0] as FlagOperator
	assert_eq(op.flag_id, "score", "新语法: flag_id正确")
	assert_eq(op.type, "int", "新语法: 类型应为int")
	assert_eq(op.operation, "reduce_if_above", "新语法: operation应为reduce_if_above")
	assert_eq(op.threshold, 100, "新语法: threshold应为100")
	assert_eq(op.amount, 50, "新语法: amount应为50")

func test_new_flag_replace():
	var op_str = "flag_bool_replace(from=old_status; to=new_status)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "新语法: 应该解析出一个替换操作符")

# --- 新语法: 复合条件 ---

func test_new_complex_requirements():
	var req_str = "prop_gt(name=money; val=50)|trait_has(name=official)|flag_bool_has(name=flag_visited)"
	var parsed_req = DSLParser.parse_requirements(req_str)
	
	assert_not_null(parsed_req, "新语法: 复合条件不应为null")

func test_new_dsl_csv_integration():
	# 使用 parse_csv_data 走完整的 PDA 下推自动机流程
	# 🚨 必须显式声明 Array[Dictionary] 类型，避免 Godot 4 类型数组入参不匹配
	var csv_data: Array[Dictionary] = [
		{
			"row_type": "random_event",
			"uuid": "test_event_01",
			"trigger_tags": "action:intent:study:poetry",
			"requirements": "trait_has(name=official)|prop_gt(name=money; val=50)",
			"title": "测试事件",
			"description": "这是一个测试",
		},
		{
			"row_type": ">option",
			"title": "选择A",
			"results": "trait_add(name=corrupt)|prop_sub(name=money; val=100)"
		}
	]
	
	var events = DSLParser.parse_csv_data(csv_data, "random_event")
	
	assert_eq(events.size(), 1, "新语法: 应该解析出1个事件")
	var event = events[0] as RandomEvent
	assert_not_null(event, "新语法: 事件应该被成功解析")
	assert_not_null(event.requirement, "新语法: 事件应该有requirements")
	
	assert_gt(event.options.size(), 0, "新语法: 事件应该至少有一个选项")
	var first_option = event.options[0]
	assert_not_null(first_option.choice_result, "新语法: 选项应该有结果")
	
	var trait_ops = first_option.choice_result.operators.filter(func(op): return op is TraitOperator)
	assert_gt(trait_ops.size(), 0, "新语法: 结果中应该包含trait操作符")
	assert_eq(trait_ops[0].str_traits, "corrupt", "新语法: trait操作符名称正确")


# ════════════════════════════════════════════════════════════
# 新语法全覆盖测试（旧语法已移除，所有用例迁移至新语法）
# ════════════════════════════════════════════════════════════

func test_old_trait_requirement_parsing():
	var req_str = "trait_has(name=official)"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "trait requirement解析结果不应为null")
	assert_true(parsed_req is TraitRequirement, "解析结果应该是TraitRequirement类型")
	assert_eq(parsed_req.trait_name, "official", "trait名称应该被正确解析")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.HAS, "操作符应该是HAS")

func test_old_trait_requirement_not_has():
	var req_str = "trait_not_has(name=corrupt)"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "trait_not_has解析结果不应为null")
	assert_eq(parsed_req.trait_name, "corrupt", "trait_not_has名称正确")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.NOT_HAS, "操作符应该是NOT_HAS")

func test_old_trait_operator_add():
	var op_str = "trait_add(name=brave)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "应该解析出一个操作符")
	assert_not_null(parsed_ops[0], "操作符不应为null")
	assert_true(parsed_ops[0] is TraitOperator, "解析结果应该是TraitOperator类型")
	assert_eq(parsed_ops[0].str_traits, "brave", "trait名称应该被正确解析")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.ADD, "操作符应该是ADD")

func test_old_trait_operator_remove():
	var op_str = "trait_remove(name=cowardly)"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "应该解析出一个操作符")
	assert_eq(parsed_ops[0].str_traits, "cowardly", "trait名称应该被正确解析")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.REMOVE, "操作符应该是REMOVE")

func test_old_dsl_csv_integration():
	# 使用 parse_csv_data 走完整的 PDA 下推自动机流程
	# 🚨 必须显式声明 Array[Dictionary] 类型，避免 Godot 4 类型数组入参不匹配
	var csv_data: Array[Dictionary] = [
		{
			"row_type": "random_event",
			"uuid": "test_event_02",
			"trigger_tags": "action:intent:study:poetry",
			"requirements": "trait_has(name=official)|prop_gt(name=money; val=50)",
			"title": "测试事件",
			"description": "这是一个测试",
		},
		{
			"row_type": ">option",
			"title": "选择A",
			"results": "trait_add(name=corrupt)|prop_sub(name=money; val=100)"
		}
	]
	
	var events = DSLParser.parse_csv_data(csv_data, "random_event")
	
	assert_eq(events.size(), 1, "应该解析出1个事件")
	var event = events[0] as RandomEvent
	assert_not_null(event, "事件应该被成功解析")
	assert_not_null(event.requirement, "事件应该有requirements")
	
	assert_gt(event.options.size(), 0, "事件应该至少有一个选项")
	var first_option = event.options[0]
	assert_not_null(first_option.choice_result, "选项应该有结果")
	
	var trait_ops = first_option.choice_result.operators.filter(func(op): return op is TraitOperator)
	assert_gt(trait_ops.size(), 0, "结果中应该包含trait操作符")
	assert_eq(trait_ops[0].str_traits, "corrupt", "trait操作符应该指定正确的trait名称")

func test_old_multiple_trait_requirements():
	var req_str = "trait_has(name=official)|trait_not_has(name=corrupt)"
	var parsed_req = DSLParser.parse_requirements(req_str)
	
	assert_not_null(parsed_req, "复合requirement不应为null")
	if parsed_req is ComplexRequirements:
		assert_gt(parsed_req.operators.size(), 0, "复合requirement应该包含子requirements")

func test_old_invalid_trait_format():
	var invalid_req_str = "trait_has()"
	var parsed_req = MicroDSLParser.parse_trait_requirement(invalid_req_str)
	assert_null(parsed_req, "缺少name参数的trait应该返回null")

func test_old_empty_trait_handling():
	var empty_req_str = "trait_has(name=)"
	var parsed_req = MicroDSLParser.parse_trait_requirement(empty_req_str)
	assert_null(parsed_req, "name为空的trait应该返回null")
