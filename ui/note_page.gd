extends Control
class_name NotePage

## NotePage — 笔记/便签总览页
##
## 全屏覆盖页面，左侧显示已触发的笔记列表（按钮），右侧展示选中笔记的详情。
## 打开时自动选中第一个已触发笔记；若无笔记则右侧显示「待触发」占位。

# ═══════════════════════════════════════════════════════════
# Onready 节点引用
# ═══════════════════════════════════════════════════════════

@onready var _btn_close: Button = $PanelContainer/Button

# 左侧
@onready var _note_list_container: VBoxContainer = $PanelContainer/H/V/NoteListScroll/NoteListContainer
@onready var _note_amount_label: Label = $PanelContainer/H/V/NoteAmount

# 右侧 — 详情面板（直接映射 Note 字段）
@onready var _demon_title: Label = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/DemonTitle
@onready var _demon_poem: Label = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/DemonPoem
@onready var _demon_description: Label = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/DemonDescription
@onready var _note_title: Label = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/NoteTitle
@onready var _note_narrative: RichTextLabel = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/NoteNarrative
@onready var _note_logical: RichTextLabel = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/NoteLogical
@onready var _placeholder: Label = $PanelContainer/H/Info/HBoxContainer/VBoxContainer/Placeholder
## 演示场景容器 — note_related_demonstration 实例化后挂载于此
@onready var _play_test_container: PanelContainer = $PanelContainer/H/Info/HBoxContainer/PlayTestContainer


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
# 数据刷新
# ═══════════════════════════════════════════════════════════

func refresh_list() -> void:
	var triggered: Array[Note] = NoteManager.get_triggered_notes()

	# 更新数量标签
	var total: int = NoteManager.get_total_count()
	var triggered_count: int = triggered.size()
	_note_amount_label.text = tr("CODE_NOTE_PAGE_4B713DD25B") % [triggered_count, total]

	# 清空旧的按钮列表
	for child in _note_list_container.get_children():
		child.queue_free()

	if triggered.is_empty():
		# 无已触发笔记 → 右侧显示待触发占位
		_show_placeholder()
		return

	# 为每个已触发 Note 创建按钮
	for i in range(triggered.size()):
		var note: Note = triggered[i]
		var btn := Button.new()
		btn.theme_type_variation = &"ButtonTheme"
		btn.text = note.name if not note.name.is_empty() else note.uuid
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# 存储 uuid 到 metadata
		btn.set_meta("note_uuid", note.uuid)
		btn.pressed.connect(_on_note_btn_pressed.bind(note.uuid))
		_note_list_container.add_child(btn)

	# 自动选中第一个
	_show_note_detail(triggered[0])


# ═══════════════════════════════════════════════════════════
# 笔记选中
# ═══════════════════════════════════════════════════════════

func _on_note_btn_pressed(note_uuid: String) -> void:
	var note: Note = NoteManager.get_note(note_uuid)
	if note == null:
		Logging.warn("[NotePage] 选中笔记但未找到: uuid=%s" % note_uuid)
		return
	_show_note_detail(note)


func _show_note_detail(note: Note) -> void:
	# 隐藏占位，显示详情
	_placeholder.visible = false
	_demon_title.visible = true
	_demon_poem.visible = true
	_demon_description.visible = true
	_note_title.visible = true
	_note_narrative.visible = true
	_note_logical.visible = true

	# Note.name → DemonTitle
	_demon_title.text = note.name if not note.name.is_empty() else tr("CODE_NOTE_PAGE_BAC59007BF")

	# Note.description → DemonPoem（诗词片段）
	_demon_poem.text = note.description if not note.description.is_empty() else ""

	# Note.description_explanation → DemonDescription（白话解释）
	_demon_description.text = note.description_explanation if not note.description_explanation.is_empty() else ""

	# Note.note_narrative → NoteNarrative（叙事文本）
	_note_narrative.text = note.note_narrative if not note.note_narrative.is_empty() else ""

	# Note.note_explanation → NoteLogical（机制解释）
	_note_logical.text = note.note_explanation if not note.note_explanation.is_empty() else ""

	# 🆕 演示场景实例化 — note_related_demonstration
	_clear_play_test_container()
	if not note.note_related_demonstration.is_empty():
		var tscn_path: String = note.get_demonstration_address()
		if not tscn_path.is_empty() and ResourceLoader.exists(tscn_path):
			Logging.info("[NotePage] 加载演示场景: %s" % tscn_path)
			var demo_scene: PackedScene = load(tscn_path)
			var demo_instance := demo_scene.instantiate()
			_play_test_container.add_child(demo_instance)
			Logging.info("[NotePage] 演示场景已实例化到 PlayTestContainer")
		else:
			Logging.warn("[NotePage] 演示地址无效或资源不存在: '%s' (raw: '%s')" % [tscn_path, note.note_related_demonstration])

	Logging.info("[NotePage] 展示笔记: uuid=%s, name='%s'" % [note.uuid, note.name])


func _show_placeholder() -> void:
	_demon_title.visible = false
	_demon_poem.visible = false
	_demon_description.visible = false
	_note_title.visible = false
	_note_narrative.visible = false
	_note_logical.visible = false
	_placeholder.visible = true
	_placeholder.text = tr("UI_NOTE_PAGE_TEXT_7")
	_clear_play_test_container()
	Logging.info("[NotePage] 无已触发笔记，显示待触发占位")


## 清空 PlayTestContainer 中的所有演示场景子节点
func _clear_play_test_container() -> void:
	for child in _play_test_container.get_children():
		child.queue_free()


# ═══════════════════════════════════════════════════════════
# 页面动画 — show / hide（镜像 SocialConnectionPage / IdeaPage）
# ═══════════════════════════════════════════════════════════

func show_page() -> void:
	if expand:
		return
	expand = true
	Logging.info("NotePage: show_page 开始 — 全屏模糊 → 面板滑出 → 展示")

	# 打开时刷新数据
	refresh_list()

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
