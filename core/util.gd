class_name Util extends RefCounted

static func get_highest_val_from_dict_vec2(dict: Dictionary, axis: int) -> float:
	var max_val: float = 0.0
	for val in dict.values():
		if val is Vector2:
			# axis 传入 0 代表 x, 1 代表 y
			max_val = maxf(max_val, val[axis])
	return max_val

static func get_margin_left_right(obj):
	return obj.get_theme_constant('margin_left') + obj.get_theme_constant('margin_right')

static func colorize(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(), text]

static func underline(text: String) -> String:
	return "[u]%s[/u]" % text

static func link(text: String, key: String) -> String:
	return "[url=%s]%s[/url]" % [key, text]

static func colorize_underlined_link(text: String,color: Color,key: String):
	return colorize(underline(link(text,key)),color)