extends MarginContainer

func apply_prop_key(prop_key: String):
	var prop = Database.properties.get(prop_key)
	if not prop:
		Logging.err("Property not found: " + prop_key)
		return
	$HBoxContainer/TextureRect.texture = prop.icon if prop.get("icon") else TextureResLoader.get_icon(GameConfig.DEFAULT_ICON_PATH)
	$HBoxContainer/Label.text = prop.name + ": " + str(prop.val)
