extends PanelContainer

# ═══════════════════════════════════════════════════════════
# 目标中文名映射（ENUMS.RELATION_TARGET → 游戏内显示名）
# ═══════════════════════════════════════════════════════════
var CN_NAME_MAP: Dictionary = {
	"libai": tr("TRES_POET_LIBAI_001_NAME_0"),
	"hushang": tr("CODE_RIGHT_INFO_PANEL_C5E7068A59"),
	"lilinfu": tr("TRES_LILINFU_PROMISE_NAME_5"),
	"jiwen": tr("CODE_RIGHT_INFO_PANEL_C3C019A3D2"),
	"youxiangfu": tr("CODE_RIGHT_INFO_PANEL_D261840111"),
	"qingliu": tr("CODE_RIGHT_INFO_PANEL_92C54C878B"),
	"gaoshi": tr("CODE_RIGHT_INFO_PANEL_5692EF6E24"),
	"wangwei": tr("TRES_NPC_DOC_WANGWEI_NAME_0"),
	"zhengqian": tr("TRES_NPC_DOC_ZHENGQIAN_NAME_0"),
	"waiqi": tr("CODE_RIGHT_INFO_PANEL_2C01ABE772"),
	"yangguozhong": tr("CODE_RIGHT_INFO_PANEL_1BA44F209A"),
	"guoguofuren": tr("CODE_RIGHT_INFO_PANEL_96BE00E055"),
}

@onready var _info_grid: VBoxContainer = $Panel/V/InfoGrid
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
@onready var _time_panel: Control = $Panel/V/TimeControlPanel
@onready var _rumors_title_label: Label = $"Panel/V/Label"
@onready var _rumors_sep: HSeparator = $Panel/V/HSeparator
@onready var _decisions_title_label: Label = $"Panel/V/Label3"
@onready var _decisions_sep: HSeparator = $Panel/V/HSeparator2
@onready var _decisions_scroll: Control = $Panel/V/DecisioinScr
@onready var _bottom_btn_bar: PanelContainer = $Panel/V/PanelContainer2

func _ready() -> void:
	# ── 风闻刷新 ──
	_refresh_rumors()
	TimeService.on_month_tick.connect(_refresh_rumors)
	EventBus.request_refresh_action_panel.connect(_refresh_rumors)

	# ── 社交人脉按钮 ──
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
	# 点击对应按钮后清除提示
	if not EventBus.social_connection_toggled.is_connected(_clear_special_hint):
		EventBus.social_connection_toggled.connect(_clear_special_hint)
	if not EventBus.poem_start_clicked.is_connected(_clear_special_hint):
		EventBus.poem_start_clicked.connect(_clear_special_hint)
	if not EventBus.idea_page_toggled.is_connected(_clear_special_hint):
		EventBus.idea_page_toggled.connect(_clear_special_hint)
	# 🆕 笔记页面打开 → 清除提示
	if not EventBus.note_page_toggled.is_connected(_clear_special_hint):
		EventBus.note_page_toggled.connect(_clear_special_hint)
	# 🆕 诗词图鉴页面打开 → 清除提示
	if not EventBus.poem_page_toggled.is_connected(_clear_special_hint):
		EventBus.poem_page_toggled.connect(_clear_special_hint)

	# ── 🆕 Tutorial 模式：默认隐藏非时间面板区域 ──
	if not PlayerState.has_flag("tutorial_completed"):
		call_deferred("_hide_for_tutorial")

## 刷新风闻面板：遍历所有 RELATION_TARGET，查询 RelationFlagManager，
## 只显示有死穴（leverage）或恩义（help）的目标。
##
## 渲染协议：
##   有具体 key → 「死穴：key1」「死穴：key2」
##   leverage_keys.size() > 1 → 末尾追加 死穴：N
##   help > 0 → 「恩义」×N
##   help > 1 → 末尾追加 恩义：N
##   两者都为空 → 该目标不渲染
func _refresh_rumors() -> void:
	# 构建 target 列表（RELATION_TARGET 枚举 → to_lower 字符串）
	var targets: Array[String] = []
	for target_enum in ENUMS.RELATION_TARGET.values():
		var target_tag: String = ENUMS.to_relation_str(target_enum)
		if not target_tag.is_empty():
			targets.append(target_tag)

	if targets.is_empty():
		Logging.warn("RightInfoPanel: RELATION_TARGET 枚举为空，跳过风闻刷新")
		return

	# 批量查询所有关系数据
	var all_relations: Dictionary = RelationFlagManager.get_all_relations(targets)

	# ── 第一遍：收集所有要渲染的 label 文本 ──
	var label_texts: Array[String] = []
	for target_tag in targets:
		var data: Dictionary = all_relations.get(target_tag, {})
		var leverage_keys: Array = data.get("leverage_keys", [])
		var help_count: int = data.get("help", 0)

		if leverage_keys.is_empty() and help_count <= 0:
			continue

		var parts: Array[String] = []
		var cn_name: String = CN_NAME_MAP.get(target_tag, target_tag)

		# ── 死穴 ──
		if not leverage_keys.is_empty():
			for key in leverage_keys:
				parts.append(tr("CODE_RIGHT_INFO_PANEL_489B840597") % key)
			if leverage_keys.size() > 1:
				parts.append(tr("CODE_RIGHT_INFO_PANEL_422551FD0B") % leverage_keys.size())

		# ── 恩义 ──
		if help_count > 0:
			parts.append(tr("CODE_RIGHT_INFO_PANEL_74592EF709") % help_count)
			if help_count > 1:
				parts.append(tr("CODE_RIGHT_INFO_PANEL_7FB471BC60") % help_count)

		label_texts.append("%s：%s" % [cn_name, "  ".join(parts)])

	# ── 第二遍：差分更新 UI ──
	var children = _info_grid.get_children()
	var target_count = label_texts.size()
	var current_count = children.size()

	# 1. 更新已有 Label
	for i in range(min(current_count, target_count)):
		children[i].text = label_texts[i]

	# 2. 多余的销毁
	for i in range(target_count, current_count):
		children[i].queue_free()

	# 3. 不足的新建
	for i in range(current_count, target_count):
		var label := Label.new()
		label.theme_type_variation = "DefaultText"
		label.text = label_texts[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_grid.add_child(label)

	Logging.info("RightInfoPanel: 风闻刷新完成，已渲染 %d 条" % _info_grid.get_child_count())


# ═══════════════════════════════════════════════════════════
# 社交人脉按钮 — 点击弹出 SocialConnectionPage
# ═══════════════════════════════════════════════════════════

func _on_social_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: SocialConnectionBtn 点击 → 发射 social_connection_toggled")
		EventBus.social_connection_toggled.emit()


# ═══════════════════════════════════════════════════════════
# 理念按钮 — 点击弹出 IdeaPage
# ═══════════════════════════════════════════════════════════

func _on_idea_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: LinianBtn 点击 → 发射 idea_page_toggled")
		EventBus.idea_page_toggled.emit()


# ═══════════════════════════════════════════════════════════
# 写诗按钮 — 点击发射 poem_start_clicked 信号
# ═══════════════════════════════════════════════════════════

func _on_poem_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: Poembtn 点击 → 发射 poem_start_clicked")
		EventBus.poem_start_clicked.emit()


# ═══════════════════════════════════════════════════════════
# 🆕 笔记按钮 — 点击弹出 NotePage
# ═══════════════════════════════════════════════════════════

func _on_note_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: NoteBtn 点击 → 发射 note_page_toggled")
		EventBus.note_page_toggled.emit()


# ═══════════════════════════════════════════════════════════
# 🆕 诗词图鉴按钮 — 点击弹出 PoemPage
# ═══════════════════════════════════════════════════════════

func _on_poem_info_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Logging.info("RightInfoPanel: PoemInfoBtn 点击 → 发射 poem_page_toggled")
		EventBus.poem_page_toggled.emit()


# ═══════════════════════════════════════════════════════════
# Focus session 显隐 — 聚焦时隐藏写诗按钮
# ═══════════════════════════════════════════════════════════

func _on_focus_changed(active: bool) -> void:
	_poem_btn.visible = not active
	Logging.info("RightInfoPanel: Focus session %s → Poembtn visible=%s" % ["active" if active else "inactive", not active])


# ═══════════════════════════════════════════════════════════
# SpecialLabel 动态提示 — 根据游戏状态提示用户点击对应按钮
# ═══════════════════════════════════════════════════════════

## 社交关系状态改变 → 提示点击人脉按钮
func _on_person_state_changed(_target_tag: String, _new_state: String) -> void:
	_special_label.text = tr("UI_RIGHT_INFO_PANEL_TEXT_0")
	Logging.info("RightInfoPanel: person_state changed → 显示社交提示")

## 意象获得 → 提示点击诗词按钮
func _on_imaginary_changed() -> void:
	_special_label.text = tr("CODE_RIGHT_INFO_PANEL_441BE330DE")
	Logging.info("RightInfoPanel: imaginary changed → 显示诗词提示")

## 特殊属性（望/兴/势）变化 → 提示点击理念按钮
const SPECIAL_PROPS: Array[String] = ["prestige", "inspiration", "momentum"]

func _on_special_prop_changed(prop_name: String) -> void:
	if prop_name in SPECIAL_PROPS:
		_special_label.text = tr("CODE_RIGHT_INFO_PANEL_B593A0EA10")
		Logging.info("RightInfoPanel: 特殊属性 '%s' 变化 → 显示理念提示" % prop_name)

## 🆕 笔记触发 → 提示点击注解按钮
var _note_hint_timer: SceneTreeTimer = null

func _on_note_triggered(note_uuid: String) -> void:
	var note: Note = NoteManager.get_note(note_uuid)
	if note == null:
		Logging.warn("RightInfoPanel: note_triggered 但 Note '%s' 未找到" % note_uuid)
		return
	_special_label.text = tr("CODE_RIGHT_INFO_PANEL_3732C36978") % note.name
	Logging.info("RightInfoPanel: note_triggered '%s' → 显示注解提示" % note_uuid)

	# 5s 后自动清除（重置已有定时器）
	if _note_hint_timer != null:
		_note_hint_timer.timeout.disconnect(_clear_special_hint)
	_note_hint_timer = get_tree().create_timer(5.0)
	_note_hint_timer.timeout.connect(_clear_special_hint)

## 点击任一对应按钮后清除提示
func _clear_special_hint() -> void:
	_special_label.text = ""
	if _note_hint_timer != null:
		_note_hint_timer.timeout.disconnect(_clear_special_hint)
		_note_hint_timer = null
	Logging.info("RightInfoPanel: 按钮已点击 → 清除 SpecialLabel 提示")


# ═══════════════════════════════════════════════════════════
# 🆕 Tutorial 可见性控制 API
# ═══════════════════════════════════════════════════════════

## Tutorial 模式：默认隐藏时间面板以外的所有区域
func _hide_for_tutorial() -> void:
	# 隐藏风闻区域
	_rumors_title_label.visible = false
	_info_grid.visible = false
	_rumors_sep.visible = false
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

## 设置风闻区域可见性（"风闻" Label + InfoGrid + HSeparator）
func set_rumors_section_visible(v: bool) -> void:
	_rumors_title_label.visible = v
	_info_grid.visible = v
	_rumors_sep.visible = v
	Logging.info("RightInfoPanel.set_rumors_section_visible: %s" % v)

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

## 🆕 设置 SpecialLabel 文本（tutorial 提示用）
func set_special_label_text(p_text: String) -> void:
	#breakpoint
	_special_label.text = p_text
	_special_label.visible = true
	Logging.info("RightInfoPanel.set_special_label_text: '%s'" % p_text)
	
