@tool
extends Node

## 诗词创作测试事件生成器
## 在 Godot 编辑器中运行此脚本，生成测试用 .tres 事件文件到 tests/data/poem_events/
##
## 用法: 将此脚本附加到任意场景 Node，在编辑器中运行场景。

const OUTPUT_DIR := "res://data/tests/poem_events/"

const SEP = "============================================================"

func _ready() -> void:
	Logging.info(SEP)
	Logging.info("诗词创作测试事件生成器 启动")
	Logging.info(SEP)

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	_generate_scenario_1()
	_generate_scenario_2()
	_generate_scenario_3()
	_generate_scenario_4()
	_generate_scenario_5()
	_generate_scenario_6()

	Logging.info("全部测试事件生成完毕，输出目录: %s" % OUTPUT_DIR)


func _save_event(event: Resource, filename: String) -> void:
	var path = OUTPUT_DIR + filename
	var err = ResourceSaver.save(event, path)
	if err == OK:
		Logging.info("  ✓ 已保存: %s" % path)
	else:
		Logging.err("  ✗ 保存失败: %s (err=%d)" % [path, err])


func _make_imagery_op(tag: String) -> ImageryAcquisitionOperator:
	var op = ImageryAcquisitionOperator.new()
	op.imagery_name = tag
	return op


func _make_chained_event(event_uuid: String, archetype: String, desc: String,
		imagery_tags: Array[String]) -> Resource:
	"""创建一个事件，每选一个选项就获得一个意象"""
	var event = RandomEvent.new()
	event.uuid = event_uuid
	event.name = event_uuid
	event.archetype_id = archetype
	event.weight = 100.0

	var options: Array = []
	for i in range(imagery_tags.size()):
		var tag = imagery_tags[i]
		var choice_result = ChoiceResult.new()
		choice_result.operators = [_make_imagery_op(tag)] as Array[BaseOperator]

		var option = EventOption.new()
		option.description = "获得意象: %s" % tag
		option.choice_result = choice_result
		options.append(option)

	options as Array[BaseOption]
	event.options = options
	return event


func _make_poem_trait(uuid: String, specific_topic: String, level: int,
		secular: float, literary: float, required_frags: Array[String]) -> Poem:
	var poem = Poem.new("POEM", specific_topic, level, secular, literary)
	poem.uuid = uuid
	poem.name = uuid
	poem.required_fragments = required_frags
	return poem


# ════════════════════════════════════════════════════════════
# 场景 1: Imaginary 重叠 → merge 验证
# Imaginary A: ACTOR:FINANCE:BROKE:imag_a + ACTOR:HEALTH:EXHAUSTED:imag_a
# Imaginary B: ACTOR:FINANCE:BROKE:imag_b + VIBE:AESTHETIC:ELEGANT:imag_b
# → finance:broke 有 2 个 Imaginary → 可合并
# ════════════════════════════════════════════════════════════

func _generate_scenario_1() -> void:
	Logging.info("[场景1] 生成 Imaginary 重叠 → merge 验证事件")

	var event = _make_chained_event(
		"test_s1_imaginary_overlap",
		"jiaoyou",
		"[测试] 场景1: 获取两个重叠 Imaginary",
		[
			"buyi",
			"qianli",
		]
	)
	_save_event(event, "test_s1_overlap.tres")


# ════════════════════════════════════════════════════════════
# 场景 2: 3 个 partial match → 恰好 30 权重
# 诗词要求 ENV:NATURE:AUTUMN:changanleaf
# 3 个概念各给 partial ENV:NATURE:AUTUMN:* → 10+10+10=30 刚好过线
# ════════════════════════════════════════════════════════════

func _generate_scenario_2() -> void:
	Logging.info("[场景2] 生成 partial match → 30 权重事件")

	var event = _make_chained_event(
		"test_s2_partial_threshold",
		"denggao",
		"[测试] 场景2: 获取 environment 相关概念的 Imaginary",
		[
			"cold_moon",
			"lone_snow",
			"falling_leaf",
		]
	)
	_save_event(event, "test_s2_partial.tres")


# ════════════════════════════════════════════════════════════
# 场景 3: 无法匹配 → 拒绝创作
# 诗词要求 ENV:NATURE:AUTUMN:changanleaf
# 所有意象都不相关
# ════════════════════════════════════════════════════════════

func _generate_scenario_3() -> void:
	Logging.info("[场景3] 生成无匹配 → 拒绝创作事件")

	var event = _make_chained_event(
		"test_s3_no_match",
		"baiye",
		"[测试] 场景3: 获取各种不相干的 Imaginary",
		[
			"drunk",
			"ink_stone",
			"qianli",
			"empty_cup",
			"cold_blade",
			"starving_bone",
		]
	)
	_save_event(event, "test_s3_no_match.tres")


# ════════════════════════════════════════════════════════════
# 场景 4: 2 partial + 1 无匹配 → 拒绝
# 诗词要求 ENV:NATURE:AUTUMN:changanleaf
# 2 个 partial (10+10=20) + 1 无匹配 → 20 < 30 → 拒绝
# ════════════════════════════════════════════════════════════

func _generate_scenario_4() -> void:
	Logging.info("[场景4] 生成 2 partial + 1 无匹配 → 拒绝事件")

	var event = _make_chained_event(
		"test_s4_partial_fail",
		"fangshi",
		"[测试] 场景4: 获取部分匹配 + 无关 Imaginary",
		[
			"cold_moon",
			"lone_snow",
			"drunk",
		]
	)
	_save_event(event, "test_s4_partial_fail.tres")


# ════════════════════════════════════════════════════════════
# 场景 5: PoemTypeChooseOperator → 诗词使用后删除
# 需要先给玩家一个 Poem trait，然后用 PoemTypeChooseOperator
# ════════════════════════════════════════════════════════════

func _generate_scenario_5() -> void:
	Logging.info("[场景5] 生成 PoemTypeChooseOperator 删除测试事件")

	var event = RandomEvent.new()
	event.uuid = "test_s5_poem_choose"
	event.name = "test_s5_poem_choose"
	event.archetype_id = "jiaoyou"
	event.weight = 100.0

	# 选项 1: 先给玩家一首真实配方诗词（poem_recipe_tian_cheng）
	var give_poem_result = ChoiceResult.new()
	var give_poem_op = OperatorFactory.create_trait_operator("poem_recipe_tian_cheng")
	give_poem_result.operators = [give_poem_op] as Array[BaseOperator]

	var give_poem_opt = EventOption.new()
	give_poem_opt.description = "获得诗词: 干谒诗 Lv1"
	give_poem_opt.choice_result = give_poem_result

	# 选项 2: 使用 PoemTypeChooseOperator 选择诗词
	var choose_poem_result = ChoiceResult.new()
	var choose_op = PoemTypeChooseOperator.new()
	choose_op.key_to_get_poem_taste = "poem_taste"
	choose_op.property_multiplication = 1.0
	# 配置 PoemTaste：接受所有诗词类型
	choose_op.poem_taste = PoemTaste.new()
	choose_op.poem_taste.lowest_poem_level = 0
	choose_op.poem_taste.accepted_poem_types = ["GAN_YE", "DENG_GAO", "SHAN_SHUI", "YING_ZHI", "HUAI_GU", "JI_LV"]
	choose_poem_result.operators = [choose_op] as Array[BaseOperator]

	var choose_poem_opt = EventOption.new()
	choose_poem_opt.description = "使用 PoemTypeChooseOperator 选择诗词"
	choose_poem_opt.choice_result = choose_poem_result

	event.options = [give_poem_opt, choose_poem_opt]
	_save_event(event, "test_s5_poem_choose.tres")


# ════════════════════════════════════════════════════════════
# 场景 6: Tier 1/2/3 + SECULAR/BROADCAST 管道乘数
# 通过不同的 ImaginaryOperator 设置不同 tier 的概念
# 然后通过 PoemTypeChooseOperator 选择不同诗词类型观察收益差异
# ════════════════════════════════════════════════════════════

func _generate_scenario_6() -> void:
	Logging.info("[场景6] 生成 Tier 1/2/3 管道乘数测试事件")
	# 注: 此场景主要靠单元测试验证，事件仅在玩家试图创作时看到收益差异
	# 提供完整的意象池，让玩家能创作不同 tier 的诗词

	var event = _make_chained_event(
		"test_s6_tier_pipeline",
		"denggao",
		"[测试] 场景6: 获取不同 Tier 的 Imaginary 素材",
		[
			# Tier 1 意象素材 (世俗: 红袖/空盏/折柳)
			"ink_stone",
			"empty_cup",
			"willow_branch",
			# Tier 2 意象素材 (沉重: 烽火/饿殍/残垣)
			"starving_bone",
			"ruined_wall",
			"ghost_fire",
			# Tier 3 意象素材 (高洁: 寒月/孤雪/晨钟)
			"cold_moon",
			"lone_snow",
			"temple_bell",
		]
	)
	_save_event(event, "test_s6_tiers.tres")
