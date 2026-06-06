# ----------------------------------------------------------------
# DSL Parser parse_context 逗号分割测试
# ----------------------------------------------------------------
# 验证 context DSL 中 "poem_taste: urn:..., taste_owner_relation_flag:..." 
# 这种逗号分隔的 key:value 是否能正确拆分为两个独立的 custom_params
# ----------------------------------------------------------------
extends GutTest

func test_parse_context_splits_comma_separated_kv():
	"""
	核心测试：验证带逗号的 context 字符串能否正确拆分为两个独立 key
	原始 CSV: "poem_taste: urn:poem_taste:libai_taste, taste_owner_relation_flag:flag_relation_with_libai"
	期望结果:
	  custom_params["poem_taste"] = "urn:poem_taste:libai_taste"
	  custom_params["taste_owner_relation_flag"] = "flag_relation_with_libai"
	"""
	var context_str = "poem_taste: urn:poem_taste:libai_taste| taste_owner_relation_flag:flag_relation_with_libai"
	var result = DSLParser.parse_context(context_str)
	
	assert_has(result, "custom_params", "parse_context 应返回 custom_params 字典")
	assert_has(result.custom_params, "poem_taste", "custom_params 应包含 poem_taste 键")
	assert_has(result.custom_params, "taste_owner_relation_flag", "custom_params 应包含 taste_owner_relation_flag 键")
	
	assert_eq(result.custom_params["poem_taste"], "urn:poem_taste:libai_taste", 
		"poem_taste 的值应为纯 URN，不应包含逗号后面的内容")
	assert_eq(result.custom_params["taste_owner_relation_flag"], "flag_relation_with_libai",
		"taste_owner_relation_flag 应被正确提取")
	
	# 🚨 关键断言：poem_taste 的值不能包含逗号！
	assert_false(result.custom_params["poem_taste"].contains(","),
		"poem_taste 的值不应包含逗号——如果失败说明逗号分割逻辑有问题")


func test_parse_context_single_kv_no_comma():
	"""
	无逗号的简单 case：确保没 regression
	"""
	var context_str = "poem_taste: urn:poem_taste:zhuoliu_basic_taste"
	var result = DSLParser.parse_context(context_str)
	
	assert_has(result.custom_params, "poem_taste", "应包含 poem_taste")
	assert_eq(result.custom_params["poem_taste"], "urn:poem_taste:zhuoliu_basic_taste",
		"无逗号时值应完整保留")


func test_parse_context_multiple_fields():
	"""
	管道符分隔的多字段 + 逗号分割：验证组合场景
	"""
	var context_str = "poem_taste: urn:poem_taste:libai_taste| taste_owner_relation_flag:flag_relation_with_libai | weight=15"
	var result = DSLParser.parse_context(context_str)
	
	assert_has(result.custom_params, "poem_taste")
	assert_has(result.custom_params, "taste_owner_relation_flag")
	assert_eq(result.custom_params["poem_taste"], "urn:poem_taste:libai_taste")
	assert_eq(result.custom_params["taste_owner_relation_flag"], "flag_relation_with_libai")
	assert_eq(result.weight, 15.0, "weight 应正常解析")


func test_parse_context_value_with_internal_colons():
	"""
	值本身包含冒号的情况（如 URN），确保正确找到 key:value 的分隔冒号
	"""
	var context_str = "urn_key: urn:prefix:some:value| extra_key:extra_val"
	var result = DSLParser.parse_context(context_str)
	
	assert_has(result.custom_params, "urn_key")
	assert_has(result.custom_params, "extra_key")
	assert_eq(result.custom_params["urn_key"], "urn:prefix:some:value",
		"URN 值包含冒号时不应被错误截断")
	assert_eq(result.custom_params["extra_key"], "extra_val")
