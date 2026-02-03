class_name SizeService extends Node

enum LabelSizeFlag{
	SINGLE_LINE, MULTI_LINE # 开启/不开启line wrap
}

var enlarge_widgets: Dictionary = {}
var minimize_widgets := {}
var label_size_flag := LabelSizeFlag.SINGLE_LINE

func enlarge_label(label: Label):
	if label_size_flag == LabelSizeFlag.MULTI_LINE:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = -1
	
	label.autowrap_trim_flags = 0 # trim nothing
	label.clip_text = false
	

func minimize_label(label: Label):
	if label_size_flag == LabelSizeFlag.MULTI_LINE:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.max_lines_visible = 0
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	label.clip_text = true
	label.custom_minimum_size = Vector2.ZERO

func enlarge_rich_text(label: RichTextLabel):
	label.fit_content = true

func minimize_rich_text(label: RichTextLabel):
	label.fit_content = false
	label.custom_minimum_size = Vector2.ZERO

func _ready():
	enlarge_widgets['Label'] = enlarge_label
	minimize_widgets['Label'] = minimize_label
	enlarge_widgets['RichTextLabel'] = enlarge_rich_text
	minimize_widgets['RichTextLabel'] = minimize_rich_text
func get_size(...widgets):
	"""
	only support orginal class for now
	"""
	var size_map := {}

	for widget in widgets:
		var cls_str = widget.get_class()
		Logging.info('try to get proper size for %s' % cls_str)
		var enlarge = enlarge_widgets.get(cls_str)
		if not enlarge:
			Logging.warn('do not found enlarge size function for %s' % cls_str)
			continue
		enlarge.call(widget)
		
	await get_tree().process_frame
	
	for widget in widgets:
		var cls_str = widget.get_class()
		var minimize = minimize_widgets.get(cls_str)
		var size = widget.size
		size_map[widget] = size
		if not minimize:
			Logging.warn('do not found minimize size function for %s' % cls_str)
			continue
		minimize.call(widget)
	return size_map
	
