extends MarginContainer

func apply_prop_key(prop_key: String):
	var prop = Database.get_property(prop_key)
	if not prop:
		Logging.err("Property not found: " + prop_key)
		return
	$VBoxContainer/HBoxContainer/TextureRect.texture = prop.icon if prop.get("icon") else TextureResLoader.get_icon(GameConfig.DEFAULT_ICON_PATH)
	
	# 从 GameSave.data 读取运行时值（而非 prop.val 模板默认值）
	var runtime_val: int = PlayerState.get_stat_val(prop_key)
	$VBoxContainer/HBoxContainer/Label.text = "%s: %d(%s)" % [prop.get_display_name(), runtime_val, prop.get_staged_perception_text()]
	
	# 更新进度条
	var progress_bar = $VBoxContainer/ProgressBar
	progress_bar.value = runtime_val
	
	# 根据数值设置颜色
	if runtime_val > 80:
		progress_bar.modulate = Color.RED
	elif runtime_val > 50:
		progress_bar.modulate = Color.PURPLE
	elif runtime_val > 30:
		progress_bar.modulate = Color.GREEN
	else:
		progress_bar.modulate = Color.WHITE
