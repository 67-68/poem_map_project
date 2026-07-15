extends Control
class_name NotePage

## NotePage — 笔记/便签总览页（骨架）
##
## 全屏覆盖页面，当前为骨架状态，内容后续填充。
## 动画逻辑 1:1 镜像 SocialConnectionPage / IdeaPage。

# ── Onready 节点引用 ──
@onready var _btn_close: Button = $PanelContainer/Button

# ═══════════════════════════════════════════════════════════
# 页面开关状态 + 动画
# ═══════════════════════════════════════════════════════════

var expand := false
var _page_tween: Tween = null
var _original_offsets: Dictionary = {}


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	Logging.info("[NotePage] _ready 开始")

	# 保存原始 offset 供 hide 后恢复
	_original_offsets = {
		"left": offset_left,
		"top": offset_top,
		"right": offset_right,
		"bottom": offset_bottom,
	}

	hide()
	EventBus.note_page_toggled.connect(func():
		if not expand:
			show_page()
		else:
			hide_page()
	)

	# 右上角 X 按钮 → 关闭页面
	_btn_close.pressed.connect(hide_page)

	Logging.info("[NotePage] _ready 完成")


# ═══════════════════════════════════════════════════════════
# 页面动画 — show / hide（镜像 SocialConnectionPage / IdeaPage）
# ═══════════════════════════════════════════════════════════

func show_page() -> void:
	if expand:
		return
	expand = true
	Logging.info("NotePage: show_page 开始 — 全屏模糊 → 面板滑出 → 展示")

	# 隐藏纸带（引用计数递增）
	EventBus.narrative_tape_hide_requested.emit()

	# 1. 全屏模糊（幕布）
	BlurManager.show_cinematic_blur()
	await get_tree().create_timer(0.5).timeout

	# 2. 左右面板滑出
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_out"):
		main.slide_panels_out()
	else:
		Logging.warn("NotePage: Main.slide_panels_out 不可用")
	await get_tree().create_timer(0.65).timeout

	# 3. 取消全屏模糊，切换为地图模糊
	BlurManager.hide_cinematic_blur()
	BlurManager.trigger_event_blur()

	# 4. 展示页面 — 先恢复原始 offset（防止 hide 动画污染）
	if not _original_offsets.is_empty():
		offset_left = _original_offsets.get("left", offset_left)
		offset_top = _original_offsets.get("top", offset_top)
		offset_right = _original_offsets.get("right", offset_right)
		offset_bottom = _original_offsets.get("bottom", offset_bottom)
		Logging.info("NotePage: restored original offsets: %s" % _original_offsets)
	show()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished

	Logging.info("NotePage: show_page 完成")


func hide_page() -> void:
	if not expand:
		return
	expand = false
	Logging.info("NotePage: hide_page 开始")

	# 恢复纸带（引用计数递减）
	EventBus.narrative_tape_show_requested.emit()

	# 1. 取消地图模糊
	BlurManager.return_to_hub()

	# 2. 面板滑回
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_in"):
		main.slide_panels_in()

	# 3. 隐藏页面
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(self, "size", Vector2(103, 47), 0.5)
	_page_tween.tween_property(self, "position", Vector2(520, 565), 0.5)
	_page_tween.tween_callback(func():
		hide()
	)

	Logging.info("NotePage: hide_page 完成")
