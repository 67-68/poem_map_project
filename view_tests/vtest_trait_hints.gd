class_name DebugTraitHints extends RefCounted
## 批量 dump 所有 trait 的 build_trait_hint() 输出到控制台。
## 挂载方式：view_tests/view_test.tscn → debug_script 指向此文件

var _dump: Array[String] = []

func create_debug_view(_idx: int) -> Control:
	return Label.new()


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new(tr("CODE_VTEST_TRAIT_HINTS_CBAB3C0E87"), func(_map: Dictionary): _dump_all()),
		ViewTestAction.new(tr("CODE_VTEST_TRAIT_HINTS_D0C5FDDF75"), func(_map: Dictionary): _dump_timed()),
		ViewTestAction.new(tr("CODE_VTEST_TRAIT_HINTS_BE1E9C3C80"), func(_map: Dictionary): _dump_with_effects()),
	]


func _dump_all() -> void:
	_load_and_dump(true, true)


func _dump_timed() -> void:
	_load_and_dump(false, true)


func _dump_with_effects() -> void:
	_load_and_dump(true, false)


func _load_and_dump(include_no_effect: bool, include_timed_only: bool) -> void:
	var all_paths: Array[String] = []
	var dirs := [
		"res://data/1_core_rules/traits/",
		"res://data/1_core_rules/disease/",
	]
	for d in dirs:
		var dir := DirAccess.open(d)
		if not dir:
			continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.ends_with(".tres"):
				all_paths.append(d + f)
			f = dir.get_next()
		dir.list_dir_end()
	
	Logging.info("========================================")
	Logging.info("TraitHint Dump: 共扫描 %d 个 .tres 文件" % all_paths.size())
	Logging.info("========================================")
	
	all_paths.sort()
	var total := 0
	for path in all_paths:
		var res = load(path)
		if not res or not (res is Trait):
			continue
		
		var t := res as Trait
		var hint := ActionHintBuilder.build_trait_hint(t)
		
		if not include_no_effect and hint.contains(tr("CODE_VTEST_TRAIT_HINTS_508D363EA0")):
			continue
		if include_timed_only and t.duration_xun <= 0:
			continue
		
		total += 1
		Logging.info("\n─── [%s] uuid=%s ───\n%s" % [t.name, t.uuid, hint])
	
	Logging.info("\n========================================")
	Logging.info("TraitHint Dump 完成: 输出 %d 个 trait" % total)
	Logging.info("========================================")
