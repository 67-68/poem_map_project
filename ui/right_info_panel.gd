extends PanelContainer

# ═══════════════════════════════════════════════════════════
# 底部按钮 ID 枚举 — show_hint / _try_clear_on_click 用
# ═══════════════════════════════════════════════════════════
enum BtnID {
	SOCIAL,      ## 社交人脉按钮
	IDEA,        ## 理念按钮
	POEM,        ## 写诗按钮
	NOTE,        ## 笔记按钮
	POEM_INFO,   ## 诗词图鉴按钮
}

# ── 高亮 Tween 管理（每个按钮一个进出 tween）──
var _active_tweens: Dictionary = {}  ## BtnID → Tween

## 当前活跃提示的目标按钮 ID（-1 = 无活动提示）
var _active_hint_btn: int = -1

## 统一的 7s 自动消失定时器
var _hint_timer: SceneTreeTimer = null

# ── 高亮动画参数 ──
const HIGHLIGHT_SCALE: float = 1.06
const HIGHLIGHT_MODULATE: Color = Color(1.15, 1.15, 1.15, 1.0)
const NORMAL_SCALE: float = 1.0
const NORMAL_MODULATE: Color = Color.WHITE
const HIGHLIGHT_TWEEN_DURATION: float = 0.5  ## 进出 tween 统一时长（秒）
const HINT_AUTO_CLEAR_SECONDS: float = 7.0

@onready var _task_container: VBoxContainer = $Panel/V/TaskContainer
@onready var _social_btn: PanelContainer = $Panel/V/PanelContainer2/HBoxContainer/SocialConnectionBtn
@onready var _idea_btn: PanelContainer = $Panel/V/PanelContainer2/HBoxContainer/LinianBtn
## 写诗按钮 — 从 ActionPanelManager 迁移至此
@onready var _poem_btn: PanelContainer = $Panel/V/PanelContainer2/HBoxContainer/Poembtn
## 🆕 笔记按钮
@onready var _note_btn: PanelContainer = $Panel/V/PanelContainer2/HBoxContainer/NoteBtn
## 🆕 诗词图鉴按钮
@onready var _poem_info_btn: PanelContainer = $Panel/V/PanelContainer2/HBoxContainer/PoemInfoBtn
## 特殊提示标签（SpecialLabel）
@onready var _special_label: Label = $Control/SpecialLabel
## 🆕 Tutorial 可见性控制用节点引用
@onready var _task_title_label: Label = $"Panel/V/Label2"
@onready var _time_panel: Control = $Panel/V/TimeControlPanel
@onready var _decisions_title_label: Label = $"Panel/V/Label3"
@onready var _decisions_sep: HSeparator = $Panel/V/HSeparator2
@onready var _decisions_scroll: Control = $Panel/V/DecisioinScr
@onready var _bottom_btn_bar: PanelContainer = $Panel/V/PanelContainer2


# ═══════════════════════════════════════════════════════════
# BtnID → PanelContainer 映射
# ═══════════════════════════════════════════════════════════

func _get_btn_by_id(btn_id: BtnID) -> PanelContainer:
	match btn_id:
		BtnID.SOCIAL:
			return _social_btn
		BtnID.IDEA:
			return _idea_btn
		BtnID.POEM:
			return _poem_btn
		BtnID.NOTE:
			return _note_btn
		BtnID.POEM_INFO:
			return _poem_info_btn
		_:
			Logging.err("RightInfoPanel._get_btn_by_id: 未知 btn_id=%d" % btn_id)
			return null


func _ready() -> void:
	# ── 社交人脉按钮 gui_input ──
	_social_btn.gui_input.connect(_on_social_btn_gui_input)

	# ── 理念按钮（右下角）──
	_idea_btn.gui_input.connect(_on_idea_btn_gui_input)

	# ── 写诗按钮 ──
	_poem_btn.gui_input.connect(_on_poem_btn_gui_input)

	# ── 🆕 笔记按钮 ──
	_note_btn.gui_input.connect(_on_note_btn_gui_input)

	# ── 🆕 诗词图鉴按钮 ──
	_poem_info_btn.gui_input.connect(_on_poem_info_btn_gui_input)

	# ── Focus session 显隐 ──
	if EventBus.focus_session_changed.is_connected(_on_focus_changed):
		EventBus.focus_session_changed.disconnect(_on_focus_changed)
	EventBus.focus_session_changed.connect(_on_focus_changed)

	# ── SpecialLabel 动态提示 ──
	_special_label.text = ""


	# ── Pivot Offset 延迟预设（按钮已布局后设置到中心）──
	call_deferred("_preset_all_pivot_offsets")

	# 注册一次性提示虚拟 flag（提醒一次就不再显示）
	PlayerState.register_virtual_flag("hint_social_shown", "bool")
	PlayerState.register_virtual_flag("hint_poem_shown", "bool")
	PlayerState.register_virtual_flag("hint_idea_shown", "bool")
	PlayerState.register_virtual_flag("hint_note_shown", "bool")
	Logging.info("RightInfoPanel: 已注册 4 个一次性提示虚拟 flag")

	if not EventBus.on_person_state_changed.is_connected(_on_person_state_changed):
		EventBus.on_person_state_changed.connect(_on_person_state_changed)
	if not EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.connect(_on_imaginary_changed)
	# 监听特殊属性（望/兴/势）变化
	if not PlayerState.player_stat_changed.is_connected(_on_special_prop_changed):
		PlayerState.player_stat_changed.connect(_on_special_prop_changed)
	# 🆕 笔记触发提示
	if not EventBus.note_triggered.is_connected(_on_note_triggered):
		EventBus.note_triggered.connect(_on_note_triggered)

	# ── 🆕 Tutorial 模式：默认隐藏非时间面板区域 ──
	if not PlayerState.has_flag("tutorial_completed"):
		call_deferred("_hide_for_tutorial")


# ═══════════════════════════════════════════════════════════
# Pivot Offset 预设
# ═══════════════════════════════════════════════════════════

func _preset_all_pivot_offsets() -> void:
	for btn_id in BtnID.values():
		var btn: PanelContainer = _get_btn_by_id(btn_id)
		if btn and btn.size.x > 0 and btn.size.y > 0:
			btn.pivot_offset = btn.size / 2.0
			Logging.info("RightInfoPanel._preset_all_pivot_offsets: btn_id=%d pivot_offset=%s" % [btn_id, btn.pivot_offset])
		elif btn:
			Logging.warn("RightInfoPanel._preset_all_pivot_offsets: btn_id=%d size=%s（尚未布局）" % [btn_id, btn.size])


# ═══════════════════════════════════════════════════════════
# 高亮动画核心（单次进出，不循环）
# ═══════════════════════════════════════════════════════════

## 对指定按钮执行单次进入高亮 Tween（scale→1.06 + modulate→BRIGHT，TRANS_SINE，0.5s）
func _tween_to_highlight(btn_id: BtnID) -> void:
	var btn: PanelContainer = _get_btn_by_id(btn_id)
	if btn == null:
		Logging.err("RightInfoPanel._tween_to_highlight: btn_id=%d 无效，跳过" % btn_id)
		return

	btn.pivot_offset = btn.size / 2.0

	# 💀 防呆：杀死旧 Tween
	_kill_active_tween(btn_id)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(HIGHLIGHT_SCALE, HIGHLIGHT_SCALE), HIGHLIGHT_TWEEN_DURATION)
	tween.tween_property(btn, "modulate", HIGHLIGHT_MODULATE, HIGHLIGHT_TWEEN_DURATION)

	_active_tweens[btn_id] = tween
	Logging.info("RightInfoPanel._tween_to_highlight: btn_id=%d 高亮进入 tween 已启动（pivot_offset=%s）" % [btn_id, btn.pivot_offset])


## 对指定按钮执行单次退出高亮 Tween（scale→1.0 + modulate→WHITE，TRANS_SINE，0.5s）
func _tween_to_normal(btn_id: BtnID) -> void:
	var btn: PanelContainer = _get_btn_by_id(btn_id)
	if btn == null:
		Logging.err("RightInfoPanel._tween_to_normal: btn_id=%d 无效，跳过" % btn_id)
		return

	# 💀 防呆：杀死旧 Tween
	_kill_active_tween(btn_id)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(NORMAL_SCALE, NORMAL_SCALE), HIGHLIGHT_TWEEN_DURATION)
	tween.tween_property(btn, "modulate", NORMAL_MODULATE, HIGHLIGHT_TWEEN_DURATION)

	_active_tweens[btn_id] = tween
	Logging.info("RightInfoPanel._tween_to_normal: btn_id=%d 退出高亮 tween 已启动" % btn_id)


## 杀死指定按钮的活跃 tween 并清理字典记录
func _kill_active_tween(btn_id: BtnID) -> void:
	if not _active_tweens.has(btn_id):
		return
	var tween: Tween = _active_tweens[btn_id]
	if tween and tween.is_valid():
		tween.kill()
		Logging.info("RightInfoPanel._kill_active_tween: btn_id=%d 旧 Tween 已 kill" % btn_id)
	_active_tweens.erase(btn_id)


# ═══════════════════════════════════════════════════════════
# SpecialLabel 统一提示管线
# ═══════════════════════════════════════════════════════════

## 统一入口：设置 SpecialLabel 文本 + 启动目标按钮呼吸 + 7s 自动消失
func show_hint(btn_id: BtnID, p_text: String) -> void:
	# 先清除旧 hint（如有）
	_clear_hint()

	_active_hint_btn = btn_id
	_special_label.text = p_text
	_special_label.visible = true

	# 启动高亮进入 tween
	_tween_to_highlight(btn_id)

	# 启动 7s 自动消失定时器
	_hint_timer = get_tree().create_timer(HINT_AUTO_CLEAR_SECONDS)
	_hint_timer.timeout.connect(_on_hint_timeout)

	Logging.info("RightInfoPanel.show_hint: btn_id=%d text='%s' 呼吸已启动 %.1fs 定时器已启动" % [btn_id, p_text, HINT_AUTO_CLEAR_SECONDS])


## 清除当前所有提示（停止呼吸 + 清文本 + 取消定时器 + 重置状态）
func _clear_hint() -> void:
	if _active_hint_btn != -1:
		_tween_to_normal(_active_hint_btn)
	_active_hint_btn = -1
	_special_label.text = ""

	if _hint_timer != null:
		_hint_timer.timeout.disconnect(_on_hint_timeout)
		_hint_timer = null

	Logging.info("RightInfoPanel._clear_hint: 提示已清除")


## 目标按钮点击时调用 — 仅当 btn_id 匹配活跃 hint 时才清除
func _try_clear_on_click(btn_id: BtnID) -> void:
	if btn_id == _active_hint_btn and _active_hint_btn != -1:
		Logging.info("RightInfoPanel._try_clear_on_click: btn_id=%d 匹配活跃提示，清除" % btn_id)
		_clear_hint()
	else:
		Logging.info("RightInfoPanel._try_clear_on_click: btn_id=%d 不匹配活跃提示 %d，跳过" % [btn_id, _active_hint_btn])


## 7s 定时器超时回调
func _on_hint_timeout() -> void:
	Logging.info("RightInfoPanel._on_hint_timeout: %.1fs 超时，清除提示" % HINT_AUTO_CLEAR_SECONDS)
	_hint_timer = null  # 已自动 fire + 断开，防止 _clear_hint 重复 disconnect
	_clear_hint()


# ═══════════════════════════════════════════════════════════
# 触发源 → show_hint 适配
# ═══════════════════════════════════════════════════════════

## 社交关系状态改变 → 提示点击人脉按钮
func _on_person_state_changed(_target_tag: String, _new_state: String) -> void:
	if PlayerState.has_flag("hint_social_shown"):
		return
	show_hint(BtnID.SOCIAL, tr("UI_RIGHT_INFO_PANEL_TEXT_0"))
	PlayerState.set_flag("hint_social_shown", true)
	Logging.info("RightInfoPanel: person_state changed → 显示社交提示（仅此一次）")

## 意象获得 → 提示点击诗词按钮
func _on_imaginary_changed() -> void:
	if PlayerState.has_flag("hint_poem_shown"):
		return
	show_hint(BtnID.POEM, tr("CODE_RIGHT_INFO_PANEL_441BE330DE"))
	PlayerState.set_flag("hint_poem_shown", true)
	Logging.info("RightInfoPanel: imaginary changed → 显示诗词提示（仅此一次）")

## 特殊属性（望/兴/势）变化 → 提示点击理念按钮
const SPECIAL_PROPS: Array[String] = ["prestige", "inspiration", "momentum"]

func _on_special_prop_changed(prop_name: String) -> void:
	if prop_name in SPECIAL_PROPS:
		if PlayerState.has_flag("hint_idea_shown"):
			return
		show_hint(BtnID.IDEA, tr("CODE_RIGHT_INFO_PANEL_B593A0EA10"))
		PlayerState.set_flag("hint_idea_shown", true)
		Logging.info("RightInfoPanel: 特殊属性 '%s' 变化 → 显示理念提示（仅此一次）" % prop_name)

## 🆕 笔记触发 → 提示点击注解按钮
func _on_note_triggered(note_uuid: String) -> void:
	if PlayerState.has_flag("hint_note_shown"):
		return
	var note: Note = NoteManager.get_note(note_uuid)
	if note == null:
		Logging.warn("RightInfoPanel: note_triggered 但 Note '%s' 未找到" % note_uuid)
		return
	show_hint(BtnID.NOTE, tr("CODE_RIGHT_INFO_PANEL_3732C36978") % note.name)
	PlayerState.set_flag("hint_note_shown", true)
	Logging.info("RightInfoPanel: note_triggered '%s' → 显示注解提示（仅此一次）" % note_uuid)


# ═══════════════════════════════════════════════════════════
# 社交人脉按钮 — 点击弹出 SocialConnectionPage
# ═══════════════════════════════════════════════════════════

func _on_social_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: SocialConnectionBtn 点击 → 发射 social_connection_toggled")
		EventBus.social_connection_toggled.emit()
		_try_clear_on_click(BtnID.SOCIAL)


# ═══════════════════════════════════════════════════════════
# 理念按钮 — 点击弹出 IdeaPage
# ═══════════════════════════════════════════════════════════

func _on_idea_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: LinianBtn 点击 → 发射 idea_page_toggled")
		EventBus.idea_page_toggled.emit()
		_try_clear_on_click(BtnID.IDEA)


# ═══════════════════════════════════════════════════════════
# 写诗按钮 — 点击发射 poem_start_clicked 信号
# ═══════════════════════════════════════════════════════════

func _on_poem_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: Poembtn 点击 → 发射 poem_start_clicked")
		EventBus.poem_start_clicked.emit()
		_try_clear_on_click(BtnID.POEM)


# ═══════════════════════════════════════════════════════════
# 🆕 笔记按钮 — 点击弹出 NotePage
# ═══════════════════════════════════════════════════════════

func _on_note_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: NoteBtn 点击 → 发射 note_page_toggled")
		EventBus.note_page_toggled.emit()
		_try_clear_on_click(BtnID.NOTE)


# ═══════════════════════════════════════════════════════════
# 🆕 诗词图鉴按钮 — 点击弹出 PoemPage
# ═══════════════════════════════════════════════════════════

func _on_poem_info_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: PoemInfoBtn 点击 → 发射 poem_page_toggled")
		EventBus.poem_page_toggled.emit()
		_try_clear_on_click(BtnID.POEM_INFO)


# ═══════════════════════════════════════════════════════════
# Focus session 显隐 — 聚焦时隐藏写诗按钮
# ═══════════════════════════════════════════════════════════

func _on_focus_changed(active: bool) -> void:
	_poem_btn.visible = not active
	Logging.info("RightInfoPanel: Focus session %s → Poembtn visible=%s" % ["active" if active else "inactive", not active])


# ═══════════════════════════════════════════════════════════
# 🆕 Tutorial 可见性控制 API
# ═══════════════════════════════════════════════════════════

## Tutorial 模式：默认隐藏时间面板以外的所有区域
func _hide_for_tutorial() -> void:
	# 隐藏任务面板标题 + 内容
	_task_title_label.visible = false
	_task_container.visible = false
	# 隐藏决议区域
	_decisions_title_label.visible = false
	_decisions_sep.visible = false
	_decisions_scroll.visible = false
	# 隐藏底部按钮栏（social/idea/poem/note）
	_bottom_btn_bar.visible = false
	# 隐藏时间面板（将由 AnimationController 在合适时机展示）
	_time_panel.visible = false
	# 🆕 隐藏 SpecialLabel（将在 tut_final_reveal 时和 social_btn 一起显示）
	_special_label.visible = false
	Logging.info("RightInfoPanel: tutorial 模式，非时间区域已隐藏")

## 设置时间面板可见性
func set_time_panel_visible(v: bool) -> void:
	_time_panel.visible = v
	Logging.info("RightInfoPanel.set_time_panel_visible: %s" % v)

## 🆕 刷新时间面板显示（确保年份/日期等实时数据更新）
func refresh_time_panel() -> void:
	if _time_panel and _time_panel.has_method("refresh"):
		_time_panel.refresh()
		Logging.info("RightInfoPanel.refresh_time_panel: 已刷新时间面板")
	else:
		Logging.info("RightInfoPanel.refresh_time_panel: _time_panel 无 refresh 方法，跳过")

## 设置决议区域可见性（"决议" Label + DecisionScroll + HSeparator）
func set_decisions_section_visible(v: bool) -> void:
	_decisions_title_label.visible = v
	_decisions_sep.visible = v
	_decisions_scroll.visible = v
	Logging.info("RightInfoPanel.set_decisions_section_visible: %s" % v)

## 设置底部按钮栏可见性（social/idea/poem/note 四个按钮容器）
func set_bottom_btn_bar_visible(v: bool) -> void:
	_bottom_btn_bar.visible = v
	Logging.info("RightInfoPanel.set_bottom_btn_bar_visible: %s" % v)

## 🆕 设置 SpecialLabel 可见性（独立于 right_panel 的显示/隐藏）
func set_special_label_visible(v: bool) -> void:
	_special_label.visible = v
	Logging.info("RightInfoPanel.set_special_label_visible: %s" % v)

## 🆕 设置 SpecialLabel 文本（tutorial 提示用，不走呼吸管线）
func set_special_label_text(p_text: String) -> void:
	#breakpoint
	_special_label.text = p_text
	_special_label.visible = true
	Logging.info("RightInfoPanel.set_special_label_text: '%s'" % p_text)
