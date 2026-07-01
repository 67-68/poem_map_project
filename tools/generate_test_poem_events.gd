@tool
extends Node

## 诗词创作测试事件生成器 V5
## 在 Godot 编辑器中运行此脚本，生成测试用 .tres 事件文件到 tests/data/poem_events/

const OUTPUT_DIR := "res://data/tests/poem_events/"
const SEP = "============================================================"


func _ready() -> void:
	Logging.info(SEP)
	Logging.info("诗词创作测试事件生成器 V5 启动")
	Logging.info(SEP)

	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	_generate_scenario_1()
	_generate_scenario_2()
	_generate_scenario_3()
	_generate_scenario_4()
	_generate_scenario_5()
	_generate_scenario_6()
	_generate_scenario_7()

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


# ════════════════════════════════════════════════════════════
# 场景 1: Imaginary 重叠 → merge 验证 (V5 不变)
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
# 场景 2: 精确 Set 匹配 → 命中「风雪夜归人」食谱（V5）
# 食谱 required_fragments: {environment:moon, environment:snow, environment:wind}
# cold_moon→environment:moon, lone_snow→environment:snow, falling_leaf→environment:wind
# ════════════════════════════════════════════════════════════

func _generate_scenario_2() -> void:
	Logging.info("[场景2] 生成精确 Set 匹配事件 (V5: 风雪夜归人)")

	var event = _make_chained_event(
		"test_s2_exact_match",
		"denggao",
		"[测试] 场景2: 获取「风雪夜归人」食谱的 Imaginary",
		[
			"cold_moon",
			"lone_snow",
			"falling_leaf",
		]
	)
	_save_event(event, "test_s2_exact_match.tres")


# ════════════════════════════════════════════════════════════
# 场景 3: 无法匹配 → 消耗意象无产出（V5: <2 概念命中任何食谱）
# ════════════════════════════════════════════════════════════

func _generate_scenario_3() -> void:
	Logging.info("[场景3] 生成无匹配 → 消耗并失败事件 (V5)")

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
# 场景 4: 精确 Set 匹配 — 也命中「风雪夜归人」食谱（V5: 原 partial_fail 改为精确匹配）
# 三个 concept {environment:moon, environment:snow, environment:wind} → 风雪夜归人
# ════════════════════════════════════════════════════════════

func _generate_scenario_4() -> void:
	Logging.info("[场景4] 生成精确匹配事件 (V5: 风雪夜归人 — 原 partial_fail 迁移)")

	var event = _make_chained_event(
		"test_s4_exact_match",
		"fangshi",
		"[测试] 场景4: 获取「风雪夜归人」食谱的 Imaginary",
		[
			"cold_moon",
			"lone_snow",
			"falling_leaf",
		]
	)
	_save_event(event, "test_s4_exact_match.tres")


# ════════════════════════════════════════════════════════════
# 场景 5: PoemTypeChooseOperator — 诗词选择与消耗（V5 待 poem_refactor_detrait）
# ════════════════════════════════════════════════════════════

func _generate_scenario_5() -> void:
	Logging.info("[场景5] 生成 PoemTypeChooseOperator 选择测试事件 (V5)")

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
# 场景 6: Tier 1/2 管道乘数（V5: Tier 2/3 已合并）
# ════════════════════════════════════════════════════════════

func _generate_scenario_6() -> void:
	Logging.info("[场景6] 生成 Tier 1/2 管道乘数测试事件 (V5)")

	var event = _make_chained_event(
		"test_s6_tier_pipeline",
		"denggao",
		"[测试] 场景6: 获取 Tier 1/2 的 Imaginary 素材（V5: Tier 2/3 已合并）",
		[
			"ink_stone",
			"empty_cup",
			"willow_branch",
			"starving_bone",
			"ruined_wall",
			"ghost_fire",
			"cold_moon",
			"lone_snow",
			"temple_bell",
		]
	)
	_save_event(event, "test_s6_tiers.tres")


# ════════════════════════════════════════════════════════════
# 场景 7: 打油诗（V5 新增）
# 给 2 个命中「风雪夜归人」的 concept + 1 个无关 concept
# cold_moon→environment:moon（命中）, lone_snow→environment:snow（命中）
# drunk→health:drunk（无关）→ 2/3 → 打油诗
# ════════════════════════════════════════════════════════════

func _generate_scenario_7() -> void:
	Logging.info("[场景7] 生成打油诗事件 (V5)")

	var event = _make_chained_event(
		"test_s7_doggerel",
		"fangshi",
		"[测试] 场景7: 2/3 命中 → 打油诗",
		[
			"cold_moon",
			"lone_snow",
			"drunk",
		]
	)
	_save_event(event, "test_s7_doggerel.tres")
