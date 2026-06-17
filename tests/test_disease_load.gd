#!/usr/bin/env godot --headless -s
# 测试 Disease 系统加载管线（--script 模式，无 autoload）
extends SceneTree

func _init() -> void:
	await create_timer(0.2).timeout

	# ── 1. 直接用 load() 加载 Disease .tres 文件 ──
	print("\n===== 1. 直接加载 Disease .tres =====")
	var disease_paths = [
		"res://data/1_core_rules/disease/disease_fenghan_acute.tres",
		"res://data/1_core_rules/disease/disease_feilao_chronic.tres",
		"res://data/1_core_rules/disease/disease_shiyi_depression.tres",
		"res://data/1_core_rules/disease/disease_zhanwang_mania.tres",
	]
	for p in disease_paths:
		var res = load(p)
		if res:
			print("  ✅ " + p + " → uuid=" + str(res.get("uuid")) + " name=" + str(res.get("name")) + " class=" + res.get_class())
			# 使用 'in' 操作符检查字段（GDScript Resource 不支持 has()）
			if "on_enter_event" in res:
				print("     on_enter_event=" + str(res.get("on_enter_event")))
			if "progression_target" in res:
				print("     progression_target=" + str(res.get("progression_target")) + " progression_xun=" + str(res.get("progression_xun")))
			if "hijack_provider" in res:
				print("     hijack_provider=" + str(res.get("hijack_provider")))
			if "buffer_to_prop" in res:
				print("     buffer_to_prop=" + str(res.get("buffer_to_prop")))
		else:
			print("  ❌ " + p + " → load() 失败")

	# ── 2. 加载诊断事件 .tres ──
	print("\n===== 2. 加载诊断事件 .tres =====")
	var event_paths = [
		"res://data/1_core_rules/disease/event_disease_fenghan_diagnosis.tres",
		"res://data/1_core_rules/disease/event_disease_shiyi_diagnosis.tres",
		"res://data/1_core_rules/disease/event_disease_zhanwang_crazy.tres",
	]
	for p in event_paths:
		var res = load(p)
		if res:
			print("  ✅ " + p + " → uuid=" + str(res.get("uuid")) + " name=" + str(res.get("name")) + " class=" + res.get_class())
		else:
			print("  ❌ " + p + " → load() 失败")

	# ── 3. 加载 ManiaProvider ──
	print("\n===== 3. 加载 ManiaProvider =====")
	var prov = load("res://data/1_core_rules/disease/provider_mania_example.tres")
	if prov:
		print("  ✅ provider_mania_example.tres → class=" + prov.get_class() + " crazy_option_text=" + str(prov.get("crazy_option_text")))
	else:
		print("  ❌ provider_mania_example.tres → load() 失败")

	# ── 4. 检查 Database（autoload）中的 Disease ──
	print("\n===== 4. Database 检查 =====")
	if Engine.has_singleton("Database"):
		var DB = Engine.get_singleton("Database")
		print("  ✅ Database singleton 存在")
		
		# 检查 traits 中的 Disease
		var disease_traits = []
		for key in DB.traits:
			var t = DB.traits[key]
			if "topic" in t and (t.get("topic") == "DISEASE" or t.get("topic") == "MENTAL_ILLNESS"):
				disease_traits.append(key)
				print("  ✅ trait[" + key + "] name=" + str(t.get("name")) + " topic=" + str(t.get("topic")))
		
		if disease_traits.size() == 0:
			print("  ⚠️ 未在 DB.traits 中找到 Disease（检查 database.gd 合并逻辑）")
			# 检查 raw_data_pool
			print("\n  --- 搜索 _raw_data_pool ---")
			for uuid in DB._raw_data_pool:
				if "disease" in uuid:
					var r = DB._raw_data_pool[uuid]
					print("  ✅ _raw_data_pool[" + uuid + "] class=" + r.get_class() + " name=" + str(r.get("name")))
		
		# 检查 resolve
		print("\n  --- 测试 Database.resolve() ---")
		var test_keys = ["disease_fenghan_acute", "disease_feilao_chronic", "disease_shiyi_depression", "disease_zhanwang_mania",
			"event_disease_fenghan_diagnosis", "event_disease_shiyi_diagnosis", "event_disease_zhanwang_crazy"]
		for k in test_keys:
			var r = DB.resolve(k)
			if r:
				print("  ✅ resolve(" + k + ") → " + str(r.get("name", "?")))
			else:
				print("  ⚠️ resolve(" + k + ") → null")
	else:
		print("  ⚠️ Database singleton 不可用（--script 模式可能不加载 autoload）")
		# 手动扫描
		print("\n  --- 手动 DataScanner 扫描 ---")
		var DataScanner = load("res://core/data_scanner.gd")
		if DataScanner:
			var result = DataScanner.scan("res://data/")
			if result:
				print("  ✅ scan() 成功: pool=" + str(result.pool.size()) + " bases=" + str(result.bases.size()))
				for bk in result.bases:
					if "disease" in bk.to_lower():
						print("  📁 base[" + bk + "]=" + str(result.bases[bk].size()))
				var dc = 0
				var ec = 0
				for key in result.pool:
					var item = result.pool[key]
					if "uuid" in item:
						var u = item.get("uuid", "")
						if u.begins_with("disease_"): dc += 1
						if u.begins_with("event_disease_"): ec += 1
				print("  📊 pool: disease=" + str(dc) + " event_disease=" + str(ec))

	print("\n===== 测试完成 =====")
	quit(0)
