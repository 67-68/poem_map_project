extends MarginContainer

func apply_prop_key(prop_key: String):
	var prop = Database.properties.get(prop_key)
	if not prop:
		Logging.err("Property not found: " + prop_key)
		return
	$VBoxContainer/HBoxContainer/TextureRect.texture = prop.icon if prop.get("icon") else TextureResLoader.get_icon(GameConfig.DEFAULT_ICON_PATH)
	$VBoxContainer/HBoxContainer/Label.text = prop.name + ": " + str(prop.val)
	
	# 更新进度条
	var progress_bar = $VBoxContainer/ProgressBar
	progress_bar.value = prop.val
	
	# 根据数值设置颜色
	if prop.val > 80:
		progress_bar.modulate = Color.RED
	elif prop.val > 50:
		progress_bar.modulate = Color.PURPLE
	elif prop.val > 30:
		progress_bar.modulate = Color.GREEN
	else:
		progress_bar.modulate = Color.WHITE