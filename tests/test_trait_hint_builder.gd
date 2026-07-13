# ================================================================
# ActionHintBuilder.build_trait_hint() 全面测试
# ================================================================
# 架构：before_all 加载所有 traits .tres 文件，遍历调用 build_trait_hint，
# 断言结构性不变量 + 富数据 trait 内容级断言。
# ================================================================
extends GutTest

# ── 类级别缓存 ──
var _all_traits: Array[Trait] = []
var _all_results: Array[Dictionary] = []  # [{trait, hint}]
var _trait_by_name: Dictionary = {}        # name → Trait
var _hint_by_name: Dictionary = {}         # name → hint string


# ──────────────────────────────────────────────────────────────
# before_all: 加载所有 .tres trait 文件，搭建最小 Database 假数据
# ──────────────────────────────────────────────────────────────

func before_all():
	Logging.info("=== test_trait_hint_builder before_all: 开始加载所有 trait .tres ===")
	
	# 1. 搭建 Database.properties（PropertyOperator.describe_preview 依赖）
	#    health 是最常用的 prop key，几乎所有负面 trait 的 trait_effect_operations 都操作它
	for key in ["health", "money", "prestige"]:
		if not Database.properties.has(key):
			var p := Property.new()
			p.uuid = key
			p.name = key
			p.lowest = 0
			p.val = 50
			Database.properties[key] = p
	Logging.info("test_trait_hint_builder: Database.properties populated with %d keys" % Database.properties.size())
	
	# 2. 扫描 data/1_core_rules/traits/ 下所有 .tres 文件
	var dir := DirAccess.open("res://data/1_core_rules/traits/")
	if not dir:
		Logging.err("test_trait_hint_builder: 无法打开 traits 目录")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := "res://data/1_core_rules/traits/" + file_name
			var loaded := load(full_path)
			if loaded and loaded is Trait:
				_all_traits.append(loaded)
				Logging.info("test_trait_hint_builder: loaded trait '%s' uuid='%s'" % [loaded.name, loaded.uuid])
			else:
				Logging.warn("test_trait_hint_builder: 跳过 %s → 非 Trait 类型或 load 失败" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	Logging.info("test_trait_hint_builder: 总共加载 %d 个 Trait 资源" % _all_traits.size())
	
	# 3. 预计算所有 hint 并建索引
	for t in _all_traits:
		var hint := ActionHintBuilder.build_trait_hint(t)
		_all_results.append({"trait": t, "hint": hint})
		_trait_by_name[t.name] = t
		_hint_by_name[t.name] = hint
		Logging.info("test_trait_hint_builder: hint for '%s' computed (%d chars)" % [t.name, hint.length()])


func after_all():
	_all_traits.clear()
	_all_results.clear()
	_trait_by_name.clear()
	_hint_by_name.clear()
	Logging.info("=== test_trait_hint_builder after_all: 清理完毕 ===")


# ════════════════════════════════════════════════════════════
# 结构性不变量（所有 trait 共享）
# ════════════════════════════════════════════════════════════

func test_all_traits_loaded():
	assert_gt(_all_traits.size(), 0, "至少应加载到 trait 文件")


func test_null_trait_returns_empty():
	var result := ActionHintBuilder.build_trait_hint(null)
	assert_eq(result, "", "null trait 应返回空字符串")


func test_every_trait_hint_non_empty():
	for entry in _all_results:
		var t: Trait = entry.trait
		var hint: String = entry.hint
		assert_ne(hint, "", "trait '%s' hint 不应为空" % t.name)


func test_every_trait_hint_has_name_header():
	for entry in _all_results:
		var t: Trait = entry.trait
		var hint: String = entry.hint
		var expected_header := "【%s】" % t.name
		assert_true(hint.contains(expected_header), "trait '%s' hint 应包含名称头 '%s'" % [t.name, expected_header])


func test_every_trait_hint_has_effect_section():
	for entry in _all_results:
		var t: Trait = entry.trait
		var hint: String = entry.hint
		assert_true(hint.contains("效果"), "trait '%s' hint 应包含「效果」section" % t.name)


func test_no_effect_traits_show_placeholder():
	# 筛选没有任何效果字段的 trait（如右相门生、狂客等）
	for entry in _all_results:
		var t: Trait = entry.trait
		# 判断是否"无效果"trait
		var has_effects := false
		if not t.trait_effect_operations.is_empty():
			has_effects = true
		if t.buffer_to_prop and not t.buffer_to_prop.operators.is_empty():
			has_effects = true
		if t.buffer_to_region and not t.buffer_to_region.operators.is_empty():
			has_effects = true
		if t.time_penalty > 0:
			has_effects = true
		if not t.conditional_time_penalties.is_empty():
			has_effects = true
		if t.ap_penalty != 0:
			has_effects = true
		
		if not has_effects:
			assert_true(entry.hint.contains("（无特殊效果）"), "无效果 trait '%s' 应显示无特殊效果占位" % t.name)
			Logging.info("test_no_effect_traits_show_placeholder: confirmed for '%s'" % t.name)


func test_traits_with_duration_have_duration_section():
	for entry in _all_results:
		var t: Trait = entry.trait
		if t.duration_xun > 0:
			assert_true(entry.hint.contains("持续"), "trait '%s' (duration_xun=%d) 应包含「持续」section" % [t.name, t.duration_xun])


func test_traits_without_duration_no_duration_section():
	for entry in _all_results:
		var t: Trait = entry.trait
		if t.duration_xun == 0:
			assert_false(entry.hint.contains("持续"), "trait '%s' (duration_xun=0) 不应包含「持续」section" % t.name)


# ════════════════════════════════════════════════════════════
# 富数据 trait 内容级断言
# ════════════════════════════════════════════════════════════

func test_poisoned_has_per_xun_effect():
	if not _hint_by_name.has("中毒"):
		gut.p("⚠ 跳过：未找到 '中毒' trait")
		return
	var hint: String = _hint_by_name["中毒"]
	assert_true(hint.contains("每旬"), "中毒 hint 应包含「每旬」效果行")


func test_sprained_ankle_has_time_penalty():
	if not _hint_by_name.has("崴脚"):
		gut.p("⚠ 跳过：未找到 '崴脚' trait")
		return
	var hint: String = _hint_by_name["崴脚"]
	assert_true(hint.contains("所有行动"), "崴脚 hint 应包含时间惩罚效果")


func test_severe_injury_has_time_penalty():
	if not _hint_by_name.has("重伤"):
		gut.p("⚠ 跳过：未找到 '重伤' trait")
		return
	var hint: String = _hint_by_name["重伤"]
	assert_true(hint.contains("每旬"), "重伤 hint 应包含每旬效果")
	assert_true(hint.contains("所有行动"), "重伤 hint 应包含时间惩罚")


func test_ouxinlixue_has_ap_penalty_and_description():
	if not _hint_by_name.has("呕心沥血"):
		gut.p("⚠ 跳过：未找到 '呕心沥血' trait")
		return
	var hint: String = _hint_by_name["呕心沥血"]
	assert_true(hint.contains("意象耗尽"), "呕心沥血 hint 应包含 description")
	assert_true(hint.contains("行动力上限"), "呕心沥血 hint 应包含 AP 惩罚行")


func test_fenghan_imaginary_has_buffer_to_prop():
	if not _hint_by_name.has("风寒"):
		gut.p("⚠ 跳过：未找到 '风寒' trait")
		return
	var hint: String = _hint_by_name["风寒"]
	# buffer_to_prop 有 health ×1.5
	assert_true(hint.contains("健康") or hint.contains("health"), "风寒 hint 应包含 buffer_to_prop 的 prop 名")


func test_hover_narrative_in_output():
	# 找一个已知含 hover_narrative 的 trait 验证（当前 .tres 中暂无该字段，用断言模板占位）
	# 如果未来有 trait 的 .tres 包含 hover_narrative，对应的 name 级断言会在这补上
	var found := false
	for entry in _all_results:
		var t: Trait = entry.trait
		if not t.hover_narrative.is_empty():
			found = true
			assert_true(entry.hint.contains(t.hover_narrative), "trait '%s' hint 末尾应包含 hover_narrative" % t.name)
			Logging.info("test_hover_narrative_in_output: verified for '%s'" % t.name)
	if not found:
		gut.p("ℹ 当前所有 trait 均无 hover_narrative 字段，跳过具体断言（字段已保留，数据待填）")


func test_hint_instance_creation():
	assert_not_null(ActionHintBuilder.new())
	assert_not_null(preload("res://core/hints/trait_hint_formatter.gd").new())
	assert_not_null(preload("res://core/hints/operator_preview_formatter.gd").new())
	assert_not_null(preload("res://core/hints/action_hint_formatter.gd").new())


# ════════════════════════════════════════════════════════════
# 辅助函数测试（已迁移至 TraitHintFormatter）
# ════════════════════════════════════════════════════════════

func test_mul_operator_mode_string():
	var _THF = preload("res://core/hints/trait_hint_formatter.gd")
	assert_eq(_THF._mul_operator_mode_string(MultiplyOperator.MUL_OPERATOR.POSITIVE_ONLY), "正面效果")
	assert_eq(_THF._mul_operator_mode_string(MultiplyOperator.MUL_OPERATOR.NEGATIVE_ONLY), "负面效果")
	assert_eq(_THF._mul_operator_mode_string(MultiplyOperator.MUL_OPERATOR.BOTH), "所有变动")
	assert_eq(_THF._mul_operator_mode_string(-1), "变动")


func test_get_prop_display_name():
	var _THF = preload("res://core/hints/trait_hint_formatter.gd")
	# health 已在 before_all 中注册到 Database.properties
	assert_eq(_THF._get_prop_display_name("health"), "health")
	# 不在数据库中的 key 原样返回
	assert_eq(_THF._get_prop_display_name("nonexistent_prop"), "nonexistent_prop")


func test_get_trait_display_name():
	var _THF = preload("res://core/hints/trait_hint_formatter.gd")
	# 不在 Database.traits 中时 fallback 返回原 uuid
	var display := _THF._get_trait_display_name("disease_dongshang_necrosis")
	assert_true(display == "disease_dongshang_necrosis" or display == "冻疮坏死",
		"应返回 uuid 或 display name，实际: '%s'" % display)
