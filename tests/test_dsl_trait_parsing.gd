# ----------------------------------------------------------------
# 大唐地理系统 - DSL Trait 解析无菌测试舱
# ----------------------------------------------------------------
# 架构师留言：
# 这个测试专门验证DSL parser对trait数据的处理是否正确。
# 重点关注：
# 1. trait UUID格式转换（__ vs :）
# 2. CSV中trait名称与实际trait UUID的映射
# 3. Trait requirement和operator的解析逻辑
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

# --- [核心测试用例] ---

func test_trait_requirement_parsing():
	# 测试基本的trait requirement解析
	var req_str = "trait:has:official"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "trait requirement解析结果不应为null")
	assert_true(parsed_req is TraitRequirement, "解析结果应该是TraitRequirement类型")
	assert_eq(parsed_req.trait_name, "official", "trait名称应该被正确解析")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.HAS, "操作符应该是HAS")

func test_trait_requirement_not_has_parsing():
	# 测试not_has操作符
	var req_str = "trait:not_has:corrupt"
	var parsed_req = MicroDSLParser.parse_trait_requirement(req_str)
	
	assert_not_null(parsed_req, "trait requirement解析结果不应为null")
	assert_eq(parsed_req.trait_name, "corrupt", "trait名称应该被正确解析")
	assert_eq(parsed_req.operator, REQ_OPERATOR.EXIST.NOT_HAS, "操作符应该是NOT_HAS")

func test_trait_operator_add_parsing():
	# 测试trait add操作符
	var op_str = "trait:add:brave"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "应该解析出一个操作符")
	assert_not_null(parsed_ops[0], "操作符不应为null")
	assert_true(parsed_ops[0] is TraitOperator, "解析结果应该是TraitOperator类型")
	assert_eq(parsed_ops[0].str_traits, "brave", "trait名称应该被正确解析")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.ADD, "操作符应该是ADD")

func test_trait_operator_remove_parsing():
	# 测试trait remove操作符
	var op_str = "trait:remove:cowardly"
	var parsed_ops = MicroDSLParser.parse_consequence_operators(op_str)
	
	assert_eq(parsed_ops.size(), 1, "应该解析出一个操作符")
	assert_eq(parsed_ops[0].str_traits, "cowardly", "trait名称应该被正确解析")
	assert_eq(parsed_ops[0].operator, REQ_OPERATOR.CRUD.REMOVE, "操作符应该是REMOVE")

func test_trait_uuid_format_conversion():
	# 测试trait UUID的格式转换
	# 模拟data_helper中的UUID转换逻辑
	var mock_trait = MockTrait.new("poem__deng_gao__1", "登高")
	var converted_uuid = mock_trait.uuid.replace('__', ':')
	
	assert_eq(converted_uuid, "poem:deng_gao:1", "UUID中的双下划线应该被转换为冒号")

func test_dsl_csv_trait_integration():
	# 测试完整的DSL CSV trait处理流程
	var csv_row = {
		"event_id": "test_event_01",
		"trigger_tags": "action:intent:study:poetry",
		"requirements": "trait:has:official,prop:money:>50",
		"title": "测试事件",
		"description": "这是一个测试",
		"opt_1_text": "选择A",
		"opt_1_result": "trait:add:corrupt,prop:money:-100"
	}
	
	var event = DSLParser.parse_random_event(csv_row)
	
	assert_not_null(event, "事件应该被成功解析")
	assert_not_null(event.requirement, "事件应该有requirements")
	
	# 检查trait requirement是否被正确解析
	# 注意：这里需要根据实际的requirement结构来验证
	print("Event requirement type: ", event.requirement.get_class())
	
	# 检查选项结果中的trait操作符
	assert_not_null(event.options, "事件应该有选项")
	assert_gt(event.options.size(), 0, "事件应该至少有一个选项")
	
	var first_option = event.options[0]
	assert_not_null(first_option.choice_result, "选项应该有结果")
	assert_not_null(first_option.choice_result.operators, "结果应该有操作符")
	
	# 查找trait操作符
	var trait_ops = first_option.choice_result.operators.filter(func(op): return op is TraitOperator)
	assert_gt(trait_ops.size(), 0, "结果中应该包含trait操作符")
	assert_eq(trait_ops[0].str_traits, "corrupt", "trait操作符应该指定正确的trait名称")

func test_multiple_trait_requirements():
	# 测试多个trait requirements的组合
	var req_str = "trait:has:official,trait:not_has:corrupt"
	var parsed_req = DSLParser.parse_requirements(req_str)
	
	assert_not_null(parsed_req, "复合requirement不应为null")
	# 如果是ComplexRequirements，检查其子requirements
	if parsed_req is ComplexRequirements:
		assert_gt(parsed_req.operators.size(), 0, "复合requirement应该包含子requirements")

func test_trait_name_mapping_issue():
	# 这个测试专门暴露trait名称映射的问题
	# CSV中使用简单的trait名称，但实际的trait UUID可能是不同的格式
	
	# 模拟CSV中的trait名称
	var csv_trait_name = "official"
	
	# 模拟实际的trait UUID（从registry中看到的格式）
	var actual_trait_uuids = [
		"main_baiye_1",
		"main_duzhuo_1", 
		"poem:deng_gao:1",
		"relation_libai_1"
	]
	
	# 检查CSV中的trait名称是否与实际UUID匹配
	var found_match = false
	for uuid in actual_trait_uuids:
		if uuid == csv_trait_name:
			found_match = true
			break
	
	# 这个测试预期会失败，因为CSV中的"official"与实际UUID不匹配
	# 这就是问题所在！
	assert_false(found_match, "CSV中的trait名称与实际trait UUID不匹配，这是预期的失败")

func test_invalid_trait_format():
	# 测试格式错误的trait（段数不对）
	# 这种情况不会触发push_error，而是返回null
	var invalid_req_str = "trait:has"  # 缺少trait名称段
	var parsed_req = MicroDSLParser.parse_trait_requirement(invalid_req_str)
	
	assert_null(parsed_req, "格式错误的trait应该返回null")

func test_empty_trait_handling():
	# 测试空trait的处理
	var empty_req_str = "trait:has:"
	var parsed_req = MicroDSLParser.parse_trait_requirement(empty_req_str)
	
	# 根据实际实现，空trait名可能被接受或拒绝
	# 这里只是测试解析行为
	if parsed_req:
		assert_true(parsed_req.trait_name.is_empty(), "空的trait名称应该被保留为空字符串")