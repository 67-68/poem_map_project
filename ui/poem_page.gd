class_name PoemPage
extends Control

## PoemPage — 诗词图鉴页面
##
## 全屏覆盖页面，左侧显示诗词类型列表（PoemType）和历史诗词列表（lore=true 的 Poem），
## 右侧根据选中项切换 TypeDescriptor / PoemDescriptor 详情面板。
## 打开时自动选中第一个 PoemType 显示其详情。

# ═══════════════════════════════════════════════════════════
# Onready 节点引用
# ═══════════════════════════════════════════════════════════

@onready var _btn_close: Button = $PanelContainer/Button

# 左侧
@onready var _type_count_label: Label = $PanelContainer/H/V/TypeCount
@onready var _poem_type_container: VBoxContainer = $PanelContainer/H/V/PoemTypeScroll/NoteListContainer
@onready var _poem_count_label: Label = $PanelContainer/H/V/PoemCount
@onready var _history_poem_container: VBoxContainer = $PanelContainer/H/V/HistoryPoemScroll/NoteListContainer

# 右侧 — TypeDescriptor
@onready var _type_descriptor: HBoxContainer = $PanelContainer/H/Info/TypeDescriptor
@onready var _type_title: Label = $PanelContainer/H/Info/TypeDescriptor/VBoxContainer/TypeTitle
@onready var _type_composition: Label = $PanelContainer/H/Info/TypeDescriptor/VBoxContainer/Composition
@onready var _type_effect: Label = $PanelContainer/H/Info/TypeDescriptor/VBoxContainer/Effect

# 右侧 — PoemDescriptor
@onready var _poem_descriptor: HBoxContainer = $PanelContainer/H/Info/PoemDescriptor
@onready var _poem_title: Label = $PanelContainer/H/Info/PoemDescriptor/VBoxContainer/PoemTitle
@onready var _poem_composition: Label = $PanelContainer/H/Info/PoemDescriptor/VBoxContainer/Composition
@onready var _poem_level: Label = $PanelContainer/H/Info/PoemDescriptor/VBoxContainer/Level
@onready var _poem_content: Label = $PanelContainer/H/Info/PoemDescriptor/VBoxContainer/PoemContent


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
	Logging.info("[PoemPage] _ready 开始")

	# 保存原始 offset 供 hide 后恢复
	_original_offsets = {
		"left": offset_left,
		"top": offset_top,
		"right": offset_right,
		"bottom": offset_bottom,
	}

	hide()
	EventBus.poem_page_toggled.connect(func():
		if not expand:
			show_page()
		else:
			hide_page()
	)

	# 右上角 X 按钮 → 关闭页面
	_btn_close.pressed.connect(hide_page)

	Logging.info("[PoemPage] _ready 完成")


# ═══════════════════════════════════════════════════════════
# 数据刷新
# ═══════════════════════════════════════════════════════════

func refresh_page() -> void:
	Logging.info("[PoemPage] refresh_page 开始")

	# 清空旧列表
	for child in _poem_type_container.get_children():
		child.queue_free()
	for child in _history_poem_container.get_children():
		child.queue_free()

	# ── 构建 PoemType 列表 ──
	var all_types: Array = []
	for uuid in Database.poem_types:
		all_types.append(Database.poem_types[uuid])

	var lore_poems: Array[Poem] = []
	for entry in PlayerState.created_poems:
		if entry is Poem and entry.lore:
			lore_poems.append(entry as Poem)

	# ── 更新 TypeCount：玩家诗词覆盖的种类数 ──
	var covered_type_count := 0
	for pt in all_types:
		if not pt is PoemType:
			continue
		for poem in lore_poems:
			if _poem_matches_type(poem, pt as PoemType):
				covered_type_count += 1
				break

	_type_count_label.text = tr("CODE_POEM_PAGE_TYPE_COUNT") % covered_type_count
	Logging.info("[PoemPage] TypeCount=%d (covered %d of %d types)" % [covered_type_count, covered_type_count, all_types.size()])

	# ── 为每个 PoemType 创建按钮 ──
	for i in range(all_types.size()):
		var pt: PoemType = all_types[i] as PoemType
		var btn := LinkButton.new()
		btn.theme_type_variation = &"DefaultText"
		btn.text = tr(pt.name) if not pt.name.is_empty() else pt.uuid
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.set_meta("poem_type_uuid", pt.uuid)
		btn.pressed.connect(_on_type_btn_pressed.bind(pt.uuid))
		_poem_type_container.add_child(btn)

	# ── 更新 PoemCount：lore 诗词数 ──
	_poem_count_label.text = tr("CODE_POEM_PAGE_POEM_COUNT") % lore_poems.size()
	Logging.info("[PoemPage] PoemCount=%d" % lore_poems.size())

	# ── 为每个 lore 诗词创建按钮 ──
	for i in range(lore_poems.size()):
		var poem: Poem = lore_poems[i]
		var btn := LinkButton.new()
		btn.theme_type_variation = &"DefaultText"
		btn.text = tr(poem.name) if not poem.name.is_empty() else poem.uuid
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.set_meta("poem_uuid", poem.uuid)
		btn.pressed.connect(_on_poem_btn_pressed.bind(poem.uuid))
		_history_poem_container.add_child(btn)

	# ── 默认选中第一个 PoemType ──
	if all_types.size() > 0:
		_show_type_detail(all_types[0] as PoemType)
	else:
		Logging.warn("[PoemPage] 没有 PoemType 数据，无法显示默认详情")

	Logging.info("[PoemPage] refresh_page 完成")


# ═══════════════════════════════════════════════════════════
# 选中回调
# ═══════════════════════════════════════════════════════════

func _on_type_btn_pressed(type_uuid: String) -> void:
	var pt = Database.poem_types.get(type_uuid)
	if pt == null:
		Logging.warn("[PoemPage] 选中 PoemType 但未找到: uuid=%s" % type_uuid)
		return
	_show_type_detail(pt as PoemType)


func _on_poem_btn_pressed(poem_uuid: String) -> void:
	# 从 PlayerState.created_poems 中查找
	for entry in PlayerState.created_poems:
		if entry is Poem and entry.uuid == poem_uuid:
			_show_poem_detail(entry as Poem)
			return
	Logging.warn("[PoemPage] 选中 Poem 但未找到: uuid=%s" % poem_uuid)


# ═══════════════════════════════════════════════════════════
# 详情面板填充
# ═══════════════════════════════════════════════════════════

func _show_type_detail(poem_type: PoemType) -> void:
	Logging.info("[PoemPage] _show_type_detail: uuid=%s name=%s" % [poem_type.uuid, poem_type.name])

	_type_descriptor.show()
	_poem_descriptor.hide()

	_type_title.text = tr(poem_type.name) if not poem_type.name.is_empty() else poem_type.uuid

	# Composition: 三项用 tr() 翻译后用 " + " 连接
	var comp_parts: Array[String] = []
	for c in poem_type.composition:
		comp_parts.append(tr(c))
	_type_composition.text = " + ".join(comp_parts)

	# Effect: 遍历 publication_effects
	var effect_text := poem_type.get_effects_text()
	if effect_text.is_empty():
		_type_effect.text = tr("CODE_POEM_PAGE_NO_EFFECT")
	else:
		_type_effect.text = effect_text


func _show_poem_detail(poem: Poem) -> void:
	Logging.info("[PoemPage] _show_poem_detail: uuid=%s name=%s" % [poem.uuid, poem.name])

	_type_descriptor.hide()
	_poem_descriptor.show()

	_poem_title.text = tr(poem.name) if not poem.name.is_empty() else poem.uuid

	# Composition: 展平 used_imaginary_types → ["功名","功名","隐逸"] → tr + " + "
	var flat_types := _flatten_imaginary_types(poem.used_imaginary_types)
	var comp_parts: Array[String] = []
	for t in flat_types:
		comp_parts.append(tr(t))
	_poem_composition.text = " + ".join(comp_parts)

	_poem_level.text = "Lv%d" % poem.level

	_poem_content.text = poem.description if not poem.description.is_empty() else ""


# ═══════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════

func _flatten_imaginary_types(types: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for type_name in types:
		var count: int = types[type_name] as int
		for i in range(count):
			result.append(type_name)
	result.sort()
	return result


func _poem_matches_type(poem: Poem, poem_type: PoemType) -> bool:
	var flat := _flatten_imaginary_types(poem.used_imaginary_types)
	var comp := poem_type.composition.duplicate()
	comp.sort()
	return flat == comp


# ═══════════════════════════════════════════════════════════
# 页面动画 — show / hide（镜像 NotePage）
# ═══════════════════════════════════════════════════════════

func show_page() -> void:
	if expand:
		return
	expand = true
	Logging.info("[PoemPage] show_page 开始 — 全屏模糊 → 面板滑出 → 展示")

	# 打开时刷新数据
	refresh_page()

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
		Logging.warn("[PoemPage] Main.slide_panels_out 不可用")
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
		Logging.info("[PoemPage] restored original offsets: %s" % _original_offsets)
	show()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished

	Logging.info("[PoemPage] show_page 完成")


func hide_page() -> void:
	if not expand:
		return
	expand = false
	Logging.info("[PoemPage] hide_page 开始")

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

	Logging.info("[PoemPage] hide_page 完成")
