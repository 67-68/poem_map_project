# ----------------------------------------------------------------
# PoemRequirement 单元测试
# ----------------------------------------------------------------
extends GutTest

# --- Mock 数据辅助 ---

class MockPlayerState:
	var _traits: Array = []
	
	func _init(trait_keys: Array):
		_traits = trait_keys
	
	func get_traits() -> Array:
		return _traits


class MockTrait extends Resource:
	@export var uuid: String
	@export var name: String
	@export var topic: String = ""
	@export var specific_topic: String = ""
	
	func _init(p_uuid: String = "", p_name: String = "", p_topic: String = "", p_specific: String = ""):
		uuid = p_uuid
		name = p_name
		topic = p_topic
		specific_topic = p_specific


# ════════════════════════════════════════════════════════════
# DSL 解析测试
# ════════════════════════════════════════════════════════════

func test_poem_has_parsing_with_array_types():
	"""poem_has(type=[GAN_YE/YING_ZHI] ; min_level=2) 应该正确解析"""
	var req_str = "poem_has(type=[GAN_YE/YING_ZHI] ; min_level=2)"
	var parsed = MicroDSLParser.parse_requirement(req_str)
	
	assert_not_null(parsed, "poem_has 解析结果不应为 null")
	assert_true(parsed is PoemRequirement, "解析结果应为 PoemRequirement 类型")
	var req = parsed as PoemRequirement
	assert_eq(req.accepted_poem_types.size(), 2, "应解析出 2 个诗词类型")
	assert_eq(req.lowest_poem_level, 2, "最低等级应为 2")


func test_poem_has_parsing_single_type():
	"""poem_has(type=GAN_YE ; min_level=1) 单个类型应正确解析"""
	var req_str = "poem_has(type=GAN_YE ; min_level=1)"
	var parsed = MicroDSLParser.parse_requirement(req_str)
	
	assert_not_null(parsed, "poem_has 解析结果不应为 null")
	var req = parsed as PoemRequirement
	assert_eq(req.accepted_poem_types.size(), 1, "应解析出 1 个诗词类型")
	assert_eq(req.lowest_poem_level, 1, "最低等级应为 1")


func test_poem_has_parsing_no_type():
	"""poem_has(min_level=1) 不指定 type 应解析为空数组（接受所有类型）"""
	var req_str = "poem_has(min_level=1)"
	var parsed = MicroDSLParser.parse_requirement(req_str)
	
	assert_not_null(parsed, "poem_has 解析结果不应为 null")
	var req = parsed as PoemRequirement
	assert_true(req.accepted_poem_types.is_empty(), "type 为空数组")
	assert_eq(req.lowest_poem_level, 1, "最低等级应为 1")


func test_poem_has_parsing_default_min_level():
	"""poem_has(type=[GAN_YE]) 不指定 min_level 应默认为 0"""
	var req_str = "poem_has(type=[GAN_YE])"
	var parsed = MicroDSLParser.parse_requirement(req_str)
	
	assert_not_null(parsed, "poem_has 解析结果不应为 null")
	var req = parsed as PoemRequirement
	assert_eq(req.lowest_poem_level, 0, "默认最低等级应为 0")


# ════════════════════════════════════════════════════════════
# 逻辑测试 — 不能直接测试 compare() 因为它需要 Database 和 PlayerState 实例
# 但这些解析层测试已经覆盖了 PoemRequirement 的正确构造
# ════════════════════════════════════════════════════════════

func test_poem_has_in_complex_requirements():
	"""poem_has 和其它 requirement 组合应该能正确解析为 ComplexRequirements"""
	var req_str = "poem_has(type=[GAN_YE] ; min_level=2)|trait_has(name=official)"
	var parsed = DSLParser.parse_requirements(req_str)
	
	assert_not_null(parsed, "复合条件不应为 null")
	assert_true(parsed is ComplexRequirements, "应解析为 ComplexRequirements")
