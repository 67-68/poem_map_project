extends Node
## 全量 dump：所有 trait .tres + 所有 Database.imaginaries_detail 中的 Imaginary。
## 运行: /Applications/Godot.app/Contents/MacOS/Godot --headless res://view_tests/vtest_trait_hints.tscn

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout

	var output := PackedStringArray()
	output.append(tr("CODE_DUMP_TRAIT_HINTS_EF92583DCC"))

	# Database.properties 塞基本数据
	for key in ["health", "money", "prestige", "talent"]:
		if not Database.properties.has(key):
			var p := Property.new()
			p.uuid = key; p.name = key; p.lowest = 0; p.val = 50
			Database.properties[key] = p

	# ═══════════════════════════════════════════════════
	# Part 1: 所有 Trait .tres 文件
	# ═══════════════════════════════════════════════════
	output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	output.append(tr("CODE_DUMP_TRAIT_HINTS_E58116E336"))
	output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	var dirs := [
		"res://data/1_core_rules/traits/",
		"res://data/1_core_rules/disease/",
	]

	for d in dirs:
		var dir := DirAccess.open(d)
		if not dir:
			output.append("ERROR: 目录不可达 " + d)
			continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.ends_with(".tres"):
				var res = load(d + f)
				if res and res is Trait:
					_dump_one(output, res)
			f = dir.get_next()
		dir.list_dir_end()

	# ═══════════════════════════════════════════════════
	# Part 2: Database.imaginaries_detail 中的 Imaginary
	# ═══════════════════════════════════════════════════
	output.append("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	output.append(tr("CODE_DUMP_TRAIT_HINTS_F4013C8605"))
	output.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# 初始化开局 Imaginary（布衣、孤松等）
	PlayerState.init_imaginaries()

	var imag_count := 0
	for uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[uuid]
		if imag is Imaginary:
			_dump_one(output, imag)
			imag_count += 1

	if imag_count == 0:
		output.append(tr("CODE_DUMP_TRAIT_HINTS_D14370FE66"))
	else:
		output.append(tr("CODE_DUMP_TRAIT_HINTS_399888A2E0") % imag_count)

	output.append("\n=== DUMP COMPLETE ===")
	var result := "\n".join(output)
	var file := FileAccess.open("user://trait_hint_dump.txt", FileAccess.WRITE)
	if file:
		file.store_string(result)
		file.close()
		print("✅ Dump 完成: " + ProjectSettings.globalize_path("user://trait_hint_dump.txt"))
	else:
		print(tr("CODE_DUMP_TRAIT_HINTS_980FA0FD3E"))

	get_tree().quit(0)


func _dump_one(output: PackedStringArray, t: Trait) -> void:
	var hint := ActionHintBuilder.new().build_trait_hint(t)
	var cls := "Imaginary" if t is Imaginary else ("Disease" if t is Disease else "Trait")
	output.append("─".repeat(70))
	output.append("[%s] %-14s | uuid: %-38s | dur:%2d  exp:%s  Lv:%s" % [cls, t.name, t.uuid, t.duration_xun, t.expiry_trait, str(t.get("level")) if t is Imaginary else "-"])
	output.append("  tp:%d | ap:%+d | ctp:%d | ops:%d | bp:%s | br:%s | ho:%dch" % [t.time_penalty, t.ap_penalty, t.conditional_time_penalties.size(), t.trait_effect_operations.size(), str(t.buffer_to_prop != null), str(t.buffer_to_region != null), t.hover_narrative.length()])
	output.append("─".repeat(70))
	output.append(str(hint))
	output.append("")
