@tool
extends Control

## ⚠️ 共存警告：本页面与 Picker 几乎不会同时存在。
## 若将来出现共存场景，需解决 BlurManager.show_cinematic_blur() (layer=100)
## 与 Picker blur (layer=50) 或 cinematic_post_blur (layer=100) 的层级冲突。

@export var maximize := false:
	set(value):
		if value:
			maximize = false
			var main := get_tree().root.get_node("Main")
			main.slide_panels_out()
			show_page_internal()

@export var minimize := false:
	set(value):
		if value:
			minimize = false
			var main := get_tree().root.get_node("Main")
			main.slide_panels_in()
			hide_page_internal()

var expand := false
var _page_tween: Tween = null
var _original_offsets: Dictionary = {}


func _ready() -> void:
	## 保存原始 offset，防止 hide_page 动画污染永久属性后无法恢复
	_original_offsets = {
		"left": offset_left,
		"top": offset_top,
		"right": offset_right,
		"bottom": offset_bottom,
	}
	hide()
	EventBus.poem_start_clicked.connect(func():
		if not expand:
			show_page()
		else:
			hide_page()
	)
	EventBus.poem_cancel.connect(func():
		if expand:
			hide_page()
	)


func show_page() -> void:
	if expand:
		return
	expand = true
	Logging.info("PoemCreationPage: show_page 开始 — 全屏模糊 → 面板滑出 → 卷轴浮现")

	# 1. 全屏模糊（幕布）
	BlurManager.show_cinematic_blur()
	await get_tree().create_timer(0.5).timeout

	# 2. 左右面板滑出（复用 tab 动画）
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_out"):
		main.slide_panels_out()
	else:
		Logging.warn("PoemCreationPage: Main.slide_panels_out 不可用")
	await get_tree().create_timer(0.65).timeout

	# 3. 取消全屏模糊，切换为地图模糊
	BlurManager.hide_cinematic_blur()
	BlurManager.trigger_event_blur()

	# 4. 展示页面 — 先恢复原始 offset（防止上次 hide_page 的 size tween 污染）
	if not _original_offsets.is_empty():
		offset_left = _original_offsets.get("left", offset_left)
		offset_top = _original_offsets.get("top", offset_top)
		offset_right = _original_offsets.get("right", offset_right)
		offset_bottom = _original_offsets.get("bottom", offset_bottom)
		Logging.debug("PoemCreationPage: restored original offsets: %s" % _original_offsets)
	show()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished

	# 5. 卷轴浮现
	var crafter := %PoemCrafter
	if crafter and crafter.has_method(&"show_with_animation"):
		crafter.show_with_animation()
	else:
		Logging.warn("PoemCreationPage: PoemCrafter.show_with_animation 不可用")

	Logging.info("PoemCreationPage: show_page 完成")


func hide_page() -> void:
	if not expand:
		return
	expand = false
	Logging.info("PoemCreationPage: hide_page 开始")

	# 1. 卷轴退出
	var crafter := %PoemCrafter
	if crafter and crafter.has_method(&"hide_with_animation"):
		crafter.hide_with_animation()

	# 2. 取消地图模糊
	BlurManager.return_to_hub()

	# 3. 面板滑回
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_in"):
		main.slide_panels_in()

	# 4. 隐藏页面
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(self, "size", Vector2(103, 47), 0.5)
	_page_tween.tween_property(self, "position", Vector2(520, 565), 0.5)
	_page_tween.tween_callback(func():
		hide()
	)

	Logging.info("PoemCreationPage: hide_page 完成")


func show_page_internal() -> void:
	show()
	Logging.info("PoemCreationPage: show_page_internal（由 editor maximize 触发）")


func hide_page_internal() -> void:
	hide()
	Logging.info("PoemCreationPage: hide_page_internal（由 editor minimize 触发）")
