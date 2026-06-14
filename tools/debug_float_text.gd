#!/usr/bin/env -S godot --headless --script
# ================================================================
# 飘字调试工具：直接测试 Property 和 PropertyOperator 的飘字文本
# ================================================================
# 用法: godot --headless --script tools/debug_float_text.gd
# ================================================================
@tool
extends SceneTree


func _init():
	Logging.info("\n=== 飘字系统调试工具 ===\n")
	
	# ── 1. 创建测试 Property ──
	var prop = Property.new()
	prop.uuid = "test_prop"
	prop.name = "测试属性"
	prop.val = 50
	prop.hard_max = 100
	
	# 注入 change_perceptions（模仿 fatigue.tres 的配置）
	var cp1 = PropChangePerceptionData.new()
	cp1.min_delta = 1; cp1.max_delta = 15
	cp1.gain_text = "稍感疲惫"; cp1.loss_text = "歇了一口气"
	prop.change_perceptions.append(cp1)
	
	var cp2 = PropChangePerceptionData.new()
	cp2.min_delta = 16; cp2.max_delta = 40
	cp2.gain_text = "疲态渐显"; cp2.loss_text = "恢复了些气力"
	prop.change_perceptions.append(cp2)
	
	var cp3 = PropChangePerceptionData.new()
	cp3.min_delta = 41; cp3.max_delta = 70
	cp3.gain_text = "身心俱疲"; cp3.loss_text = "神清气爽"
	prop.change_perceptions.append(cp3)
	
	# 注入 staged_perceptions
	var sp1 = PropStagedPerceptionData.new()
	sp1.stage_val = 0; sp1.perception_text = "精力充沛"
	prop.staged_perceptions.append(sp1)
	
	var sp2 = PropStagedPerceptionData.new()
	sp2.stage_val = 25; sp2.perception_text = "略感疲惫"
	prop.staged_perceptions.append(sp2)
	
	var sp3 = PropStagedPerceptionData.new()
	sp3.stage_val = 50; sp3.perception_text = "身心俱疲"
	prop.staged_perceptions.append(sp3)
	
	Logging.info("[OK] 测试 Property 创建完成")
	Logging.info("  uuid: %s" % prop.uuid)
	Logging.info("  val: %d" % prop.val)
	Logging.info("  change_perceptions: %d 条" % prop.change_perceptions.size())
	Logging.info("  staged_perceptions: %d 条" % prop.staged_perceptions.size())
	
	# ── 2. 测试 get_change_perception_text ──
	Logging.info("\n--- get_change_perception_text 测试 ---")
	
	var tests = [
		[10,  "增加 10（小量）"],
		[-10, "减少 10（小量）"],
		[30,  "增加 30（中量）"],
		[-30, "减少 30（中量）"],
		[50,  "增加 50（大量）"],
		[-50, "减少 50（大量）"],
	]
	
	var all_pass = true
	for test in tests:
		var delta = test[0] as int
		var label = test[1] as String
		var result = prop.get_change_perception_text(delta)
		if result.is_empty():
			Logging.info("  ❌ delta=%+d (%s): 返回空字符串！" % [delta, label])
			all_pass = false
		else:
			Logging.info("  ✅ delta=%+d (%s): '%s'" % [delta, label, result])
	
	# ── 3. 测试 staged_perception fallback ──
	Logging.info("\n--- get_staged_perception_text 测试 ---")
	var stage_tests = [
		[0,   "val=0"],
		[10,  "val=10"],
		[30,  "val=30"],
		[50,  "val=50"],
		[80,  "val=80"],
		[100, "val=100"],
	]
	
	for test in stage_tests:
		prop.val = test[0] as int
		var label = test[1] as String
		var result = prop.get_staged_perception_text()
		Logging.info("  %s → '%s'" % [label, result])
	
	# ── 4. 模拟 PropertyOperator 调用 ──
	Logging.info("\n--- PropertyOperator 模拟 ---")
	
	var op = PropertyOperator.new()
	op.str_props = "test_prop"
	
	for delta in [15, -15, 40, -40]:
		op.value = delta
		var perception_text = prop.get_change_perception_text(delta)
		Logging.info("  PropertyOperator(property=%s, value=%+d) → '%s'" % [op.str_props, op.value, perception_text])
	
	# ── 总结 ──
	Logging.info("\n=== 测试完成 ===")
	if all_pass:
		Logging.info("✅ 所有飘字文本测试通过")
	else:
		Logging.info("❌ 存在失败项，请检查配置")
	
	quit(0 if all_pass else 1)
