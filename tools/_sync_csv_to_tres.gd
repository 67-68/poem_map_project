@tool
extends Node

func _ready() -> void:
	Logging.info("===== CSV -> TRES Sync Started =====")
	
	var csv_files = [
		# 747_kuangda 时代
		"res://data/4_eras/747_kuangda/_duotai_humiliation_events.csv",
		"res://data/4_eras/747_kuangda/_kuangke_qingliu_events.csv",
		"res://data/4_eras/747_kuangda/_kuangke_zhuoliu_events.csv",
		"res://data/4_eras/747_kuangda/_qingliu_daoxin_posui_events.csv",
		"res://data/4_eras/747_kuangda/_qingliu_fengying_events.csv",
		"res://data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv",
		"res://data/4_eras/747_kuangda/_qingliu_passive_benefits_events.csv",
		"res://data/4_eras/747_kuangda/_qingliu_zuanying_events.csv",
		"res://data/4_eras/747_kuangda/_zhuoliu_fengying_events.csv",
		"res://data/4_eras/747_kuangda/_zhuoliu_lieqi_events.csv",
		"res://data/4_eras/747_kuangda/_zhuoliu_zuanying_events.csv",
		"res://data/4_eras/747_kuangda/_zize_events.csv",
		"res://data/4_eras/747_kuangda/_drunken_oblivion_events.csv",
		"res://data/4_eras/747_kuangda/_political_purge_events.csv",
		"res://data/4_eras/747_kuangda/denggao/_747kuangda_denggao_events.csv",
		# 745_ambition 时代
		"res://data/4_eras/745_ambition/baiye/honey_moon/_bai_ye_honeymoon_events.csv",
		"res://data/4_eras/745_ambition/baiye/real_appearance/_bai_ye_real_appearance_events.csv",
		"res://data/4_eras/745_ambition/_scene_imagery_library_events.csv",
		# 755_backhome
		"res://data/4_eras/755_backhome/_ganlu_journey_events.csv",
	]
	
	for csv_path in csv_files:
		Logging.info("Processing: %s" % csv_path)
		if not FileAccess.file_exists(csv_path):
			Logging.err("CSV not found: %s" % csv_path)
			continue
		
		var file = FileAccess.open(csv_path, FileAccess.READ)
		if file == null:
			Logging.err("Cannot open: %s" % csv_path)
			continue
		
		var csv_content = file.get_as_text()
		file.close()
		
		Logging.info("  Read %d bytes from CSV" % csv_content.length())
		
		var loader_script = load("res://core/csv_cloud_loader.gd")
		if loader_script == null:
			Logging.err("Cannot load csv_cloud_loader.gd")
			continue
		
		var loader = loader_script.new()
		add_child(loader)
		loader._process_csv_data(csv_content, csv_path, "random_event", "")
	
	Logging.info("===== CSV -> TRES Sync Complete =====")
	get_tree().quit(0)
