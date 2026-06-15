#!/usr/bin/env -S godot --headless --script
# ================================================================
# 语义数据导出工具
# ================================================================
# 从 Property/Trait .tres 文件和 EMOTION 枚举注释导出 JSON 快照，
# 供 OperatorSemanticTranslator（Python 端）加载。
# ================================================================
# 运行: godot --headless --script tools/export_semantic_data.gd
# 输出: tools/data/semantic_properties.json
#       tools/data/semantic_traits.json
#       tools/data/semantic_emotions.json
# ================================================================
# 设计原则：
# - 不依赖任何 autoload（可在 --script 模式下独立运行）
# - 通过 DirAccess 遍历 .tres 文件直接 load()
# - 不修改任何现有文件
# ================================================================
@tool
extends SceneTree


const PROPERTIES_DIR: String = "res://data/1_core_rules/properties/"
const TRAITS_DIR: String = "res://data/1_core_rules/traits/"
const OUTPUT_DIR: String = "res://tools/data/"


func _init() -> void:
	print("=== 语义数据导出工具 ===")
	print("")

	# 确保输出目录存在
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	# ── 1. 导出 semantic_properties.json ──
	var props_data: Dictionary = _export_properties()
	_write_json(OUTPUT_DIR.path_join("semantic_properties.json"), props_data)
	print("✅ semantic_properties.json: %d 个属性" % props_data.size())

	# ── 2. 导出 semantic_traits.json ──
	var traits_data: Dictionary = _export_traits()
	_write_json(OUTPUT_DIR.path_join("semantic_traits.json"), traits_data)
	print("✅ semantic_traits.json: %d 个特质" % traits_data.size())

	# ── 3. 导出 semantic_emotions.json ──
	var emotions_data: Dictionary = _export_emotions()
	_write_json(OUTPUT_DIR.path_join("semantic_emotions.json"), emotions_data)
	print("✅ semantic_emotions.json: %d 个情绪" % emotions_data.size())

	print("")
	print("=== 导出完成 ===")
	quit(0)


# ────────────────────────────────────────────────────────────────
# Property 导出
# ────────────────────────────────────────────────────────────────
func _export_properties() -> Dictionary:
	"""遍历 PROPERTIES_DIR 下所有 .tres → 解析为 Property → 按 uuid 索引输出"""
	var result: Dictionary = {}
	var dir: DirAccess = DirAccess.open(PROPERTIES_DIR)
	if dir == null:
		printerr("❌ 无法打开目录: %s" % PROPERTIES_DIR)
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = PROPERTIES_DIR.path_join(file_name)
			var prop: Resource = load(full_path)
			if prop is Property:
				# 提取 change_perceptions
				var perceptions: Array[Dictionary] = []
				for cp: PropChangePerceptionData in prop.change_perceptions:
					perceptions.append({
						"min_delta": cp.min_delta,
						"max_delta": cp.max_delta,
						"gain": cp.gain_text,
						"loss": cp.loss_text,
					})

				result[prop.uuid] = {
					"name": prop.name,
					"change_perceptions": perceptions,
				}
				print("  📦 Property[%s] → %s  (%d 条 change_perceptions)" % [prop.uuid, prop.name, perceptions.size()])
			else:
				printerr("  ⚠️  跳过非 Property 资源: %s (类型: %s)" % [file_name, typeof(prop)])
		file_name = dir.get_next()

	dir.list_dir_end()
	return result


# ────────────────────────────────────────────────────────────────
# Trait 导出
# ────────────────────────────────────────────────────────────────
func _export_traits() -> Dictionary:
	"""遍历 TRAITS_DIR 下所有 .tres → 解析为 Trait → 按 uuid 索引输出"""
	var result: Dictionary = {}
	var dir: DirAccess = DirAccess.open(TRAITS_DIR)
	if dir == null:
		printerr("❌ 无法打开目录: %s" % TRAITS_DIR)
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = TRAITS_DIR.path_join(file_name)
			var trait_res: Resource = load(full_path)
			if trait_res is Trait:
				result[trait_res.uuid] = {
					"name": trait_res.name,
				}
				print("  🏷️  Trait[%s] → %s" % [trait_res.uuid, trait_res.name])
			else:
				printerr("  ⚠️  跳过非 Trait 资源: %s (类型: %s)" % [file_name, typeof(trait_res)])
		file_name = dir.get_next()

	dir.list_dir_end()
	return result


# ────────────────────────────────────────────────────────────────
# Emotion 导出（硬编码自 model/enumerates.gd 第 81-88 行）
# ────────────────────────────────────────────────────────────────
func _export_emotions() -> Dictionary:
	"""
	硬编码 EMOTION 枚举注释映射。
	
	数据源: model/enumerates.gd:81-88
	enum EMOTION {
	    SORROW,      # 愁苦/悲凉 (替代 DESPAIR，更具诗意，涵盖送别与怀古)
	    ARROGANCE,   # 狂傲/得意 (涵盖饮酒作乐、金榜题名、无视权贵)
	    ANGER,       # 愤懑 (涵盖被贬、目睹不公)
	    TRANQUILITY, # 旷达/空灵 (涵盖山水田园、修道、释怀)
	    AMBITION,    # 世俗的野心（想做官、想入世），用于区分李白和杜甫的路线
	}
	"""
	return {
		"SORROW": {
			"cn_name": "悲悯",
			"description": "愁苦/悲凉，涵盖送别与怀古",
		},
		"ARROGANCE": {
			"cn_name": "狂傲",
			"description": "狂傲/得意，涵盖饮酒作乐、金榜题名、无视权贵",
		},
		"ANGER": {
			"cn_name": "愤懑",
			"description": "愤懑，涵盖被贬、目睹不公",
		},
		"TRANQUILITY": {
			"cn_name": "旷达",
			"description": "旷达/空灵，涵盖山水田园、修道、释怀",
		},
		"AMBITION": {
			"cn_name": "野心",
			"description": "世俗的野心（想做官、想入世）",
		},
	}


# ────────────────────────────────────────────────────────────────
# JSON 写入工具
# ────────────────────────────────────────────────────────────────
func _write_json(path: String, data: Dictionary) -> void:
	"""以格式化 JSON 写入文件"""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("❌ 无法写入文件: %s (错误码: %d)" % [path, FileAccess.get_open_error()])
		return
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
