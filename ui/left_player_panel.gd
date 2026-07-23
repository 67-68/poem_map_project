extends PanelContainer

## 左侧玩家信息面板
## 显示玩家名字、属性、特质
## 保留侧滑动画（EventBus.request_change_left_panel_visibility）
##
## 属性展示使用 tscn 中固定的 prefab 实例（prop_label.tscn / smaller_prop_label.tscn），
## 不再动态生成。颜色管理 API 兼容 MonthEndSettlement 的旬初染色逻辑。

# ── 节点引用 ─────────────────────────────────────────────
@onready var _name_label: Label = $"Panel/VBox/NameLabel"
@onready var _place_label: Label = $"Panel/VBox/ScrollContainer/V/PlaceLabel"
@onready var _trait_grid: GridContainer = $"Panel/VBox/ScrollContainer/V/TraitGrid"
@onready var _ambition_deadline_label: Label = $"Panel/VBox/ScrollContainer/V/AmbitionProgressBar/AmbitionDeadline"
@onready var _ambition_progress_bar: ProgressBar = $"Panel/VBox/ScrollContainer/V/AmbitionProgressBar"
@onready var _identity_label: Label = $"Panel/VBox/ScrollContainer/V/Label"
@onready var _trait_title_label: Label = $"Panel/VBox/ScrollContainer/V/Prop2"
@onready var _trait_sep: HSeparator = $"Panel/VBox/ScrollContainer/V/HSep2"
@onready var _ambition_sep: HSeparator = $"Panel/VBox/ScrollContainer/V/HSep5"
@onready var _ambition_title_label: Label = $"Panel/VBox/ScrollContainer/V/Prop"
@onready var _ambition_hbox: VBoxContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer"
@onready var _decoration_sep: HSeparator = $"Panel/VBox/ScrollContainer/V/HSep3"
@onready var _decoration_title_label: Label = $"Panel/VBox/ScrollContainer/V/Label2"
@onready var _decoration_hbox: VBoxContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer2"

const _ActionHintFormatter = preload("res://core/hints/action_hint_formatter.gd")

# ── 固定属性 Label 节点（对应 tscn 预制体实例）─────────
# 🆕 tscn 根节点为 PanelContainer（内嵌 HBoxContainer），适配解包到内层
@onready var _prop_health: PanelContainer = $"Panel/VBox/HBoxContainer/PropLabel"
@onready var _prop_money: PanelContainer = $"Panel/VBox/HBoxContainer/PropLabel2"
@onready var _prop_inspiration: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel"
@onready var _prop_momentum: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel2"
@onready var _prop_prestige: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel3"
@onready var _prop_talent: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer2/SmallerPropLabel"
@onready var _prop_astuteness: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer2/SmallerPropLabel2"
@onready var _prop_composure: PanelContainer = $"Panel/VBox/ScrollContainer/V/HBoxContainer2/SmallerPropLabel3"

# prop_key → PanelContainer 的映射（用于 hover 注册）
var _prop_panel_map: Dictionary = {}

# ── 属性显示格式配置 ────────────────────────────────────
# 三元组 {name, value, perception} 统一收敛属性 label 的三路文本输出：
#   name:       属性短名，通过 tr("LEFT_PANEL_PROP_NAME_*") 走 i18n
#   value:      纯数值格式 "%d/%d"，两个 %d  = 当前值 / 上限
#   perception: 感知描述包装格式，健康/钱财用「」，其他用()
var _PROP_FORMAT: Dictionary = {
	"health":      { "name": tr("LEFT_PANEL_PROP_NAME_HEALTH"),      "value": "%d/%d", "perception": "「%s」" },
	"money":       { "name": tr("LEFT_PANEL_PROP_NAME_MONEY"),       "value": "%d/%d", "perception": "「%s」" },
	"inspiration": { "name": tr("LEFT_PANEL_PROP_NAME_INSPIRATION"), "value": "%d/%d", "perception": "「%s」" },
	"momentum":    { "name": tr("LEFT_PANEL_PROP_NAME_MOMENTUM"),    "value": "%d/%d", "perception": "「%s」" },
	"prestige":    { "name": tr("LEFT_PANEL_PROP_NAME_PRESTIGE"),    "value": "%d/%d", "perception": "「%s」" },
	"talent":      { "name": tr("LEFT_PANEL_PROP_NAME_TALENT"),      "value": "%d/%d", "perception": "「%s」" },
	"astuteness":  { "name": tr("LEFT_PANEL_PROP_NAME_ASTUTENESS"),  "value": "%d/%d", "perception": "「%s」" },
	"composure":   { "name": tr("LEFT_PANEL_PROP_NAME_COMPOSURE"),   "value": "%d/%d", "perception": "「%s」" },
}

# prop_key → { name: Label, value: Label, perception: Label }
var _prop_label_map: Dictionary = {}
# 当前活跃的颜色覆盖，用于重新应用。{ prop_key → { name_color, value_color, perception_color } }
var _prop_color_overrides: Dictionary = {}

# ── 侧滑动画 ─────────────────────────────────────────────
var _original_pos_x: float
var _is_animating: bool = false
var _is_visible_state: bool = true
const SLIDE_OFFSET: float = 50.0
const ANIM_DURATION: float = 0.3

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	# ── Tutorial 可见性控制 ──
	if PlayerState.has_flag("tutorial_completed"):
		# 非 tutorial 模式，所有属性默认可见
		call_deferred("_show_all_properties")
	else:
		# Tutorial 未完成：默认全部隐藏，由 AnimationController 逐步揭示
		call_deferred("_hide_all_properties_tutorial")
	Logging.info("LeftPlayerPanel: _ready start")

	# 静态数据
	_name_label.text = tr(PlayerState.player_name)
	Logging.info("LeftPlayerPanel: player_name=%s" % PlayerState.player_name)

	# ── 驻留地点 PlaceLabel ──
	_refresh_place_label()
	if not PlayerState.stay_place_changed.is_connected(_refresh_place_label):
		PlayerState.stay_place_changed.connect(_refresh_place_label)
		Logging.info("LeftPlayerPanel: connected to stay_place_changed")
	# 独立探针 — 验证信号是否到达
	if not PlayerState.stay_place_changed.is_connected(_place_changed_probe):
		PlayerState.stay_place_changed.connect(_place_changed_probe)
		Logging.info("LeftPlayerPanel: connected _place_changed_probe to stay_place_changed")
	Logging.info("[PLACE_PROBE] stay_place_changed has %d connections" % PlayerState.stay_place_changed.get_connections().size())

	# 构建 prop label 映射表 + 首次填充
	_build_prop_label_map()
	_refresh_all_props()

	# 🆕 为属性标签注册 hover（SLIDE_FROM_LEFT 流）
	_register_prop_hovers()

	# 动态重建 TraitGrid
	_rebuild_trait_grid()

	# ── 信号连接：旬 tick + 属性实时变化 ──
	TimeService.on_xun_tick.connect(_on_stat_changed)
	Logging.info("LeftPlayerPanel: connected to TimeService.on_xun_tick")
	if not PlayerState.player_stat_changed.is_connected(_on_any_stat_changed):
		PlayerState.player_stat_changed.connect(_on_any_stat_changed)
		Logging.info("LeftPlayerPanel: connected to PlayerState.player_stat_changed")

	# ── 信号连接：trait 增减时重建 TraitGrid ──
	if not EventBus.on_trait_change.is_connected(_rebuild_trait_grid):
		EventBus.on_trait_change.connect(_rebuild_trait_grid)
		Logging.info("LeftPlayerPanel: connected to EventBus.on_trait_change")

	if not EventBus.imaginary_changed.is_connected(_rebuild_trait_grid):
		EventBus.imaginary_changed.connect(_rebuild_trait_grid)
		Logging.info("LeftPlayerPanel: connected to EventBus.imaginary_changed")

	# 野心进度 Label + 倒计时进度条
	_update_ambition_deadline_bar()

	# 监听属性变动 → 刷新野心进度
	if not PlayerState.player_stat_changed.is_connected(_on_ambition_stat_changed):
		PlayerState.player_stat_changed.connect(_on_ambition_stat_changed)

	# 监听野心变更 → 重建进度 Label
	if not PlayerState.ambition_changed.is_connected(_on_ambition_changed):
		PlayerState.ambition_changed.connect(_on_ambition_changed)

	# 侧滑动画
	_original_pos_x = position.x

	EventBus.request_change_left_panel_visibility.connect(func():
		if _is_visible_state:
			hide_panel()
		else:
			show_panel()
	)
	Logging.info("LeftPlayerPanel: _ready complete")

# ── 属性 Label 映射表构建 ───────────────────────────────

## tscn 内部结构（prop_label.tscn / smaller_prop_label.tscn 通用）：
## PanelContainer → HBoxContainer → [PropertyLabel(0), Control(1), NumberLabel(2), Description(3)]
##   child 0: PropertyLabel — 属性名称（动态："健康" / "兴"）
##   child 1: Control       — 布局 spacer
##   child 2: NumberLabel   — 属性数值（动态："50/100"）
##   child 3: Description   — 感知描述文本（动态："奄奄一息"）
static func _extract_labels(panel: PanelContainer) -> Dictionary:
	var inner_box := panel.get_child(0) as HBoxContainer
	if not inner_box:
		Logging.err("LeftPlayerPanel._extract_labels: panel '%s' 的第一个子节点不是 HBoxContainer，返回空 dict" % panel.name)
		return {}
	if inner_box.get_child_count() < 4:
		Logging.err("LeftPlayerPanel._extract_labels: panel '%s' 内层 HBoxContainer 子节点数=%d (期望≥4)，返回空 dict" % [panel.name, inner_box.get_child_count()])
		return {}
	var name_label := inner_box.get_child(0) as Label
	var spacer_label := inner_box.get_child(1) as Label  # Control(Label) — 用于填充 "." 对齐
	var value_label := inner_box.get_child(2) as Label
	var perception_label := inner_box.get_child(3) as Label
	if not name_label or not value_label or not perception_label:
		Logging.err("LeftPlayerPanel._extract_labels: panel '%s' 内层 HBoxContainer — PropertyLabel(child0)=%s, NumberLabel(child2)=%s, Description(child3)=%s" % [panel.name, "ok" if name_label else "NULL", "ok" if value_label else "NULL", "ok" if perception_label else "NULL"])
	Logging.debug("LeftPlayerPanel._extract_labels: panel '%s' OK — name_label='%s', spacer='%s', value_label='%s', perception_label='%s'" % [panel.name, name_label.name if name_label else "NULL", spacer_label.name if spacer_label else "NULL", value_label.name if value_label else "NULL", perception_label.name if perception_label else "NULL"])
	return {
		"name": name_label,
		"control": spacer_label,
		"value": value_label,
		"perception": perception_label,
	}

# ── Control Label 点填充对齐 ─────────────────────────────
# 为 spacer Label 设一大串 "."（100 个），HBoxContainer 自动收缩裁剪超出部分，
# 靠 NAME_DOTS 宏控制占位宽度。
const NAME_DOTS: int = 100

## 为所有属性的 Control(Label) 填充一大串 "."，靠 HBox 自裁剪实现占位。
func _fill_control_dots() -> void:
	var dots := ".".repeat(NAME_DOTS)
	for prop_key in _prop_label_map:
		var labels: Dictionary = _prop_label_map[prop_key]
		var spacer: Label = labels.get("control") as Label
		if not spacer:
			continue
		spacer.text = dots
		spacer.clip_text = true
	Logging.debug("LeftPlayerPanel._fill_control_dots: set %d dots with clip_text=true for %d props" % [NAME_DOTS, _prop_label_map.size()])

func _build_prop_label_map() -> void:
	_prop_panel_map = {
		"health":      _prop_health,
		"money":       _prop_money,
		"inspiration": _prop_inspiration,
		"momentum":    _prop_momentum,
		"prestige":    _prop_prestige,
		"talent":      _prop_talent,
		"astuteness":  _prop_astuteness,
		"composure":   _prop_composure,
	}
	_prop_label_map = {
		"health":      _extract_labels(_prop_health),
		"money":       _extract_labels(_prop_money),
		"inspiration": _extract_labels(_prop_inspiration),
		"momentum":    _extract_labels(_prop_momentum),
		"prestige":    _extract_labels(_prop_prestige),
		"talent":      _extract_labels(_prop_talent),
		"astuteness":  _extract_labels(_prop_astuteness),
		"composure":   _extract_labels(_prop_composure),
	}
	Logging.info("LeftPlayerPanel: prop label map built with %d entries" % _prop_label_map.size())

## 🆕 为所有属性标签 PanelContainer 注册 hover（SLIDE_FROM_LEFT 流）
func _register_prop_hovers() -> void:
	Logging.info("LeftPlayerPanel._register_prop_hovers: start — %d props to register" % _prop_panel_map.size())
	for prop_key in _prop_panel_map:
		var panel := _prop_panel_map[prop_key] as PanelContainer
		if not panel:
			Logging.err("LeftPlayerPanel._register_prop_hovers: panel '%s' 为 null，跳过" % prop_key)
			continue

		HoverPopupManager.unregister(panel)
		var hint = _ActionHintFormatter.new().build_prop_hint(prop_key)
		if not hint:
			Logging.warn("LeftPlayerPanel._register_prop_hovers: build_prop_hint('%s') 返回 null，跳过" % prop_key)
			continue

		var narrative: String = hint.narrative
		var vector: String = hint.vector

		if narrative.is_empty() and vector.is_empty():
			Logging.info("LeftPlayerPanel._register_prop_hovers: '%s' narrative + vector 均为空，跳过注册" % prop_key)
			continue

		HoverPopupManager.register(panel, {"narrative": narrative, "vector": vector}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_LEFT)
		Logging.info("LeftPlayerPanel._register_prop_hovers: '%s' hover registered (SLIDE_FROM_LEFT, narrative=%d chars, vector=%d chars)" % [prop_key, narrative.length(), vector.length()])

# ── 驻留地点 PlaceLabel ─────────────────────────────────

func _place_changed_probe(_place_str: String) -> void:
	Logging.info("[PLACE_PROBE] SIGNAL RECEIVED! place='%s', stay_place='%s', _place_label=%s, is_inside_tree=%s" % [_place_str, PlayerState.stay_place, "valid" if _place_label else "NULL", str(is_inside_tree())])
	_refresh_place_label()

func _refresh_place_label() -> void:
	if not _place_label:
		Logging.info("[PLACE_PROBE] _refresh_place_label: _place_label is NULL, aborting")
		return
	var cn := ENUMS.place_to_cn(PlayerState.stay_place)
	var place_str: String = PlayerState.stay_place
	Logging.info("LeftPlayerPanel._refresh_place_label: [地点DEBUG] ENTER — PlayerState.stay_place='%s' 「%s」, GameSave.data.stay_place='%s'" % [place_str, cn, GameSave.data.stay_place])

	# 收集当前地点已认识的 NPC（person_state > uncharted）
	var known_npcs: Array[String] = []
	var all_docs: Dictionary = Database.get_npc_document_all()
	for target_tag: String in all_docs:
		var doc = all_docs[target_tag]
		if doc == null:
			continue
		if place_str in doc.preferred_places:
			var state = RelationFlagManager.get_person_state(target_tag)
			if state != RelationFlagManager.PERSON_STATE.UNCHARTED:
				known_npcs.append(tr(doc.name) if not doc.name.is_empty() else target_tag)

	if known_npcs.is_empty():
		_place_label.text = tr("CODE_LEFT_PLAYER_PANEL_E6142E8810") % cn
		Logging.info("LeftPlayerPanel._refresh_place_label: [地点DEBUG] PlaceLabel set → '驻留 · %s' (无已知 NPC)" % cn)
	else:
		var npc_str := "、".join(known_npcs)
		_place_label.text = tr("CODE_LEFT_PLAYER_PANEL_7CB079ED6A") % [cn, npc_str]
		Logging.info("LeftPlayerPanel._refresh_place_label: [地点DEBUG] PlaceLabel set → '驻留 · %s — %s在此' (%d NPC)" % [cn, npc_str, known_npcs.size()])

# ── 上限计算 ────────────────────────────────────────────

## 计算属性的有效上限 = min(soft_max, hard_max)，
## 忽略 -1（无限制）。若两者均为 -1 则返回 -1 表示无上限。
static func _get_effective_cap(prop: Property) -> int:
	var soft := prop.soft_max
	var hard := prop.hard_max
	if soft < 0 and hard < 0:
		return -1
	elif soft < 0:
		return hard
	elif hard < 0:
		return soft
	else:
		return mini(soft, hard)

# ── 属性刷新 ────────────────────────────────────────────

func _on_stat_changed() -> void:
	Logging.info("LeftPlayerPanel: stat changed, refreshing")
	_refresh_place_label()
	_refresh_all_props()
	_refresh_trait_grid()
	_update_ambition_deadline_bar()

## 属性实时变动 → 增量刷新属性显示 + 野心进度
## 由 PlayerState.player_stat_changed 触发，每次属性变化立即刷新
func _on_any_stat_changed(_prop_name: String = "") -> void:
	_refresh_all_props()

## 刷新所有固定属性的名称、数值和感知文本
## 显示格式：当前值 / 上限（soft_max 与 hard_max 中较低者）
func _refresh_all_props() -> void:
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in _refresh_all_props, skipping")
		return
	for prop_key in _prop_label_map:
		var labels: Dictionary = _prop_label_map[prop_key]
		var val: int = PlayerState.get_stat_val(prop_key)
		var prop: Property = Database.get_property(prop_key)
		var perception: String = prop.get_staged_perception_text() if prop else ""

		var fmt: Dictionary = _PROP_FORMAT.get(prop_key, { "name": prop_key, "value": "%d/%d", "perception": "「%s」" })
		labels.name.text = fmt.name
		Logging.debug("LeftPlayerPanel._refresh_all_props: prop_key='%s' fmt.name='%s'" % [prop_key, fmt.name])

		var cap := _get_effective_cap(prop) if prop else -1
		if cap >= 0:
			labels.value.text = fmt.value % [val, cap]
		else:
			# 无上限：仅显示值，隐藏 "/上限" 部分
			labels.value.text = fmt.value.replace("/%d", "") % val
		labels.perception.text = fmt.perception % perception if not perception.is_empty() else ""

		Logging.info("LeftPlayerPanel: refresh prop '%s': name='%s' val=%d, cap=%d, perception='%s'" % [prop_key, fmt.name, val, cap, perception])

	# 属性文本刷新后，为所有 Control(Label) 填充 "." + clip_text 实现占位对齐
	_fill_control_dots()

# ── Prop Label 颜色管理 API ─────────────────────────────
# MonthEndSettlement 等外部模块通过以下 API 控制旬初染色。
# 数值标签使用鲜艳色，感知标签使用去饱和的灰色调。

## 返回左侧面板当前显示的属性 key 列表
func get_displayed_prop_keys() -> Array[String]:
	return ["health", "money", "inspiration", "momentum", "prestige", "talent", "astuteness", "composure"]

## 为指定属性的 label 设置字体颜色覆盖。
## 数值标签用传入的原色，感知标签自动去饱和为灰色调。
func set_prop_label_color(prop_key: String, color: Color) -> void:
	if not _prop_label_map.has(prop_key):
		Logging.info("LeftPlayerPanel: set_prop_label_color: label not found for key '%s'" % prop_key)
		return
	var labels: Dictionary = _prop_label_map[prop_key]
	var name_label: Label = labels.name
	var value_label: Label = labels.value
	var perception_label: Label = labels.perception

	# 名称 + 数值 → 传入的原色（鲜艳红/绿）
	name_label.add_theme_color_override("font_color", color)
	value_label.add_theme_color_override("font_color", color)

	# 感知文本 → 去饱和的灰色版本（60% 灰度 + 40% 原色）
	var grayed := _desaturate_for_perception(color)
	perception_label.add_theme_color_override("font_color", grayed)

	_prop_color_overrides[prop_key] = { "name_color": color, "value_color": color, "perception_color": grayed }

## 将颜色去饱和为灰色调（保持亮度，移除饱和度）
static func _desaturate_for_perception(c: Color) -> Color:
	var gray := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color(gray, gray, gray, c.a).lerp(c, 0.3)

## 重置指定属性的 label 颜色为默认
func reset_prop_label_color(prop_key: String) -> void:
	if not _prop_label_map.has(prop_key):
		return
	var labels: Dictionary = _prop_label_map[prop_key]
	labels.name.remove_theme_color_override("font_color")
	labels.value.remove_theme_color_override("font_color")
	labels.perception.remove_theme_color_override("font_color")
	_prop_color_overrides.erase(prop_key)

## 重置所有属性 label 的颜色为默认
func reset_all_prop_colors() -> void:
	for prop_key in _prop_label_map:
		var labels: Dictionary = _prop_label_map[prop_key]
		labels.name.remove_theme_color_override("font_color")
		labels.value.remove_theme_color_override("font_color")
		labels.perception.remove_theme_color_override("font_color")
	_prop_color_overrides.clear()


func _on_ambition_stat_changed(prop_name: String) -> void:
	var ambition = PlayerState.ambition
	if not ambition or ambition.tracked_property.is_empty():
		return
	if prop_name == ambition.tracked_property:
		if _is_frost_panel_active():
			_update_frost_distance_bar()
			Logging.debug("LeftPlayerPanel._on_ambition_stat_changed: 冻土模式 — 里程条已刷新 (prop=%s)" % prop_name)

func _on_ambition_changed(_new_ambition) -> void:
	_update_ambition_deadline_bar()

# ── 冻土面板模式 ────────────────────────────────────────

## 奉先距长安约 243 唐里，进度条百分比换算为实际里程
const FROST_TOTAL_DISTANCE: float = 243.0

## 冻土模式激活时保存的原始身份文本（用于退出冻土时还原）
var _original_identity_text: String = ""

func _is_frost_panel_active() -> bool:
	return PlayerState.has_flag("flag_frost_panel_active")

## 应用冻土面板模式：身份切换 + 进度条转里程 + 考试门控
func _apply_frost_panel_mode() -> void:
	if not _identity_label:
		return
	# 首次激活时保存原始身份文本
	#breakpoint
	if _original_identity_text.is_empty():
		_original_identity_text = _identity_label.text
	_identity_label.text = "从八品府库看守"
	Logging.info("LeftPlayerPanel: 冻土面板模式已激活 — 身份=%s" % _identity_label.text)

## 退出冻土面板模式：还原身份 + 还原进度条
func _restore_normal_panel_mode() -> void:
	if not _original_identity_text.is_empty() and _identity_label:
		_identity_label.text = _original_identity_text
		Logging.info("LeftPlayerPanel: 冻土面板模式已退出 — 身份还原为 '%s'" % _original_identity_text)

## 冻土里程进度条：剩余旬数 → 已行里程（百分比 × 243 里）
func _update_frost_distance_bar() -> void:
	_apply_frost_panel_mode()
	if not _ambition_progress_bar or not _ambition_deadline_label:
		return

	var remaining := PlayerState.get_ambition_remaining_xun()
	if remaining < 0:
		_ambition_deadline_label.hide()
		_ambition_progress_bar.hide()
		return

	var total := PlayerState.ambition.deadline_xun
	if total <= 0:
		Logging.warn("LeftPlayerPanel._update_frost_distance_bar: deadline_xun=%d 无效" % total)
		_ambition_deadline_label.hide()
		_ambition_progress_bar.hide()
		return

	var traveled_xun := total - remaining
	var ratio := float(traveled_xun) / float(total)
	var distance := ratio * FROST_TOTAL_DISTANCE

	_ambition_deadline_label.show()
	_ambition_progress_bar.show()

	_ambition_deadline_label.text = tr("CODE_LEFT_PLAYER_PANEL_FROST_DISTANCE") % [int(distance), int(FROST_TOTAL_DISTANCE)]

	_ambition_progress_bar.max_value = FROST_TOTAL_DISTANCE
	_ambition_progress_bar.value = distance
	_ambition_progress_bar.show_percentage = false

	# 冻土色系进度条：冰蓝 → 雪白渐变
	var bar_color := Color(0.3, 0.45, 0.6).lerp(Color(0.75, 0.85, 0.95), ratio)
	var fg_style := StyleBoxFlat.new()
	fg_style.bg_color = bar_color
	fg_style.border_width_left = 1
	fg_style.border_width_top = 1
	fg_style.border_width_right = 1
	fg_style.border_width_bottom = 1
	fg_style.border_color = bar_color.darkened(0.3)
	fg_style.corner_radius_top_left = 2
	fg_style.corner_radius_top_right = 2
	fg_style.corner_radius_bottom_left = 2
	fg_style.corner_radius_bottom_right = 2
	_ambition_progress_bar.add_theme_stylebox_override("fg", fg_style)

	Logging.debug("LeftPlayerPanel._update_frost_distance_bar: 已行 %.0f/%.0f 里 (ratio=%.3f)" % [distance, FROST_TOTAL_DISTANCE, ratio])


# ── 野心倒计时进度条 ────────────────────────────────────

func _update_ambition_deadline_bar() -> void:
	# ★ 冻土模式接管：里程进度条 + 考试门控
	if _is_frost_panel_active():
		_apply_frost_panel_mode()
		return

	# 退出冻土模式 → 还原身份文本
	if not _original_identity_text.is_empty():
		_restore_normal_panel_mode()

	var remaining := PlayerState.get_ambition_remaining_xun()
	if remaining < 0:
		_ambition_deadline_label.hide()
		_ambition_progress_bar.hide()
		return

	var total := PlayerState.ambition.deadline_xun

	# 🆕 大考触发：野心倒计时归零 → 推入考试事件链
	if remaining == 0:
		Logging.info("[LeftPlayerPanel] _update_ambition_deadline_bar: remaining==0, 触发大考事件链")
		if not PlayerState.has_flag("flag_exam_triggered"):
			PlayerState.set_flag("flag_exam_triggered", true)
			Logging.info("[LeftPlayerPanel] 设置防重复标记 flag_exam_triggered")
			EventBus.push_event.emit("event_exam_30", {})
			Logging.info("[LeftPlayerPanel] 已推入 event_exam_30")
		else:
			Logging.info("[LeftPlayerPanel] flag_exam_triggered 已存在，跳过重复触发")
		# 进度条归零后隐藏
		_ambition_deadline_label.hide()
		_ambition_progress_bar.hide()
		return

	_ambition_deadline_label.show()
	_ambition_progress_bar.show()

	_ambition_deadline_label.text = tr("CODE_LEFT_PLAYER_PANEL_134E5C5565") % [remaining, total]

	_ambition_progress_bar.max_value = float(total)
	_ambition_progress_bar.value = float(remaining)
	_ambition_progress_bar.show_percentage = false

	var ratio := float(remaining) / float(total) if total > 0 else 0.0
	var bar_color: Color
	if ratio > 0.5:
		var t := (ratio - 0.5) / 0.5
		bar_color = Color(0.42, 0.56, 0.14).lerp(Color(0.55, 0.55, 0.18), t)
	else:
		var t := ratio / 0.5
		bar_color = Color(0.75, 0.15, 0.05).lerp(Color(0.42, 0.56, 0.14), t)

	var fg_style := StyleBoxFlat.new()
	fg_style.bg_color = bar_color
	fg_style.border_width_left = 1
	fg_style.border_width_top = 1
	fg_style.border_width_right = 1
	fg_style.border_width_bottom = 1
	fg_style.border_color = bar_color.darkened(0.3)
	fg_style.corner_radius_top_left = 2
	fg_style.corner_radius_top_right = 2
	fg_style.corner_radius_bottom_left = 2
	fg_style.corner_radius_bottom_right = 2
	_ambition_progress_bar.add_theme_stylebox_override("fg", fg_style)

# ── TraitGrid 构建 ───────────────────────────────────────

func _rebuild_trait_grid() -> void:
	for child in _trait_grid.get_children():
		_trait_grid.remove_child(child)
		child.queue_free()
	Logging.info("LeftPlayerPanel: TraitGrid cleared")

	var trait_keys: Array = PlayerState.traits
	var filtered_keys: Array[String] = []
	for tk in trait_keys:
		if tk.begins_with("main_"):
			Logging.info("LeftPlayerPanel: 跳过已弃用的主线等级 trait '%s'" % tk)
			continue
		filtered_keys.append(tk)
	Logging.info("LeftPlayerPanel: building TraitGrid with %d traits (filtered from %d)" % [filtered_keys.size(), trait_keys.size()])

	for trait_key in filtered_keys:
		var trait_data: Trait = Database.get_trait(trait_key)

		var demonstrator = preload("res://ui/trait_demonstrator.tscn").instantiate()
		_trait_grid.add_child(demonstrator)

		if not trait_data:
			var resolved = Database.resolve(trait_key)
			var display_name: String = trait_key
			if resolved and "name" in resolved:
				display_name = tr(resolved.name)
			Logging.info("LeftPlayerPanel: trait key '%s' not in Database.traits, fallback display as '%s'" % [trait_key, display_name])
			demonstrator.set_trait_fallback(trait_key, display_name)
		else:
			demonstrator.set_trait(trait_data)
			Logging.info("LeftPlayerPanel: added trait demonstrator: %s" % trait_data.name)

	var imag_count := 0
	for imag_uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[imag_uuid]
		if not imag is Imaginary:
			continue
		var demonstrator = preload("res://ui/trait_demonstrator.tscn").instantiate()
		_trait_grid.add_child(demonstrator)
		demonstrator.set_trait(imag as Trait)
		imag_count += 1
		Logging.info("LeftPlayerPanel: added Imaginary demonstrator: %s (Lv%d)" % [imag.name, imag.level])
	Logging.info("LeftPlayerPanel: TraitGrid complete — %d traits + %d imaginaries" % [trait_keys.size(), imag_count])

func _refresh_trait_grid() -> void:
	var trait_keys: Array = PlayerState.traits
	var children := _trait_grid.get_children()

	var filtered_count := 0
	for tk in trait_keys:
		if not tk.begins_with("main_"):
			filtered_count += 1

	var imag_count := Database.imaginaries_detail.size()
	var expected_total := filtered_count + imag_count

	if children.size() != expected_total:
		Logging.info("LeftPlayerPanel: TraitGrid count changed (children=%d, traits=%d(filtered), imaginaries=%d), rebuilding" % [children.size(), filtered_count, imag_count])
		_rebuild_trait_grid()

# ── Tutorial 可见性控制 API ──────────────────────────────

## 设置单个属性行的可见性
## prop_key: "health"/"money"/"inspiration"/"momentum"/"prestige"/"talent"/"astuteness"/"composure"
func set_property_visible(prop_key: String, v: bool) -> void:
	if prop_key == 'prestige':
		$Panel/VBox/ScrollContainer/V/HBoxContainer.visible = true
		$Panel/VBox/ScrollContainer/V/Prop.visible = true
		$Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel.visible = true
		$Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel2.visible = true
		$Panel/VBox/ScrollContainer/V/HBoxContainer/SmallerPropLabel3.visible = true

	var labels: Dictionary = _prop_label_map.get(prop_key)
	if labels:
		# 每个 labels 包含 name / value / perception 三个 Label
		var name_label: Label = labels.get("name")
		if name_label:
			name_label.visible = v
		var value_label: Label = labels.get("value")
		if value_label:
			value_label.visible = v
		var perception_label: Label = labels.get("perception")
		if perception_label:
			perception_label.visible = v
		Logging.info("LeftPlayerPanel.set_property_visible: prop_key='%s' visible=%s" % [prop_key, v])

## 设置 TraitGrid 区域的可见性
func set_trait_grid_visible(v: bool) -> void:
	_trait_grid.visible = v
	Logging.info("LeftPlayerPanel.set_trait_grid_visible: visible=%s" % [v])

## 非 tutorial 模式：显示所有属性 + TraitGrid + 所有区域
func _show_all_properties() -> void:
	for prop_key in _prop_label_map:
		var labels: Dictionary = _prop_label_map[prop_key]
		var name_label: Label = labels.get("name")
		if name_label:
			name_label.visible = true
		var value_label: Label = labels.get("value")
		if value_label:
			value_label.visible = true
		var perception_label: Label = labels.get("perception")
		if perception_label:
			perception_label.visible = true
	_trait_grid.visible = true
	# 名字、地点、身份
	_name_label.visible = true
	_place_label.visible = true
	_identity_label.visible = true
	# 特质区域
	_trait_title_label.visible = true
	_trait_sep.visible = true
	# 政略主权区域
	_ambition_sep.visible = true
	_ambition_title_label.visible = true
	_ambition_hbox.visible = true
	# 底层修饰区域
	_decoration_sep.visible = true
	_decoration_title_label.visible = true
	_decoration_hbox.visible = true
	Logging.info("LeftPlayerPanel: 全部属性已设为可见（非 tutorial 模式）")

## Tutorial 模式：默认隐藏所有属性 + TraitGrid
func _hide_all_properties_tutorial() -> void:
	for prop_key in _prop_label_map:
		var labels: Dictionary = _prop_label_map[prop_key]
		var name_label: Label = labels.get("name")
		if name_label:
			name_label.visible = false
		var value_label: Label = labels.get("value")
		if value_label:
			value_label.visible = false
		var perception_label: Label = labels.get("perception")
		if perception_label:
			perception_label.visible = false
	_trait_grid.visible = false
	# 🆕 隐藏名字、地点、身份
	_name_label.visible = false
	_place_label.visible = false
	_identity_label.visible = false
	# 🆕 隐藏特质区域
	_trait_title_label.visible = false
	_trait_sep.visible = false
	# 🆕 隐藏政略主权区域
	_ambition_sep.visible = false
	_ambition_title_label.visible = false
	_ambition_hbox.visible = false
	# 🆕 隐藏底层修饰区域
	_decoration_sep.visible = false
	_decoration_title_label.visible = false
	_decoration_hbox.visible = false
	Logging.info("LeftPlayerPanel: 全部属性已设为隐藏（tutorial 模式，待逐步揭示）")

## 设置名字 Label 可见性
func set_name_visible(v: bool) -> void:
	_name_label.visible = v
	Logging.info("LeftPlayerPanel.set_name_visible: %s" % v)

## 设置地点 Label 可见性
func set_place_visible(v: bool) -> void:
	_place_label.visible = v
	Logging.info("LeftPlayerPanel.set_place_visible: %s" % v)

## 设置身份 Label 可见性（"京兆府·举子"）
func set_identity_visible(v: bool) -> void:
	_identity_label.visible = v
	Logging.info("LeftPlayerPanel.set_identity_visible: %s" % v)

## 设置政略主权区域可见性（HSep5 + Label"政略主权" + HBoxContainer(兴/势/望)）
func set_ambition_section_visible(v: bool) -> void:
	_ambition_sep.visible = v
	_ambition_title_label.visible = v
	_ambition_hbox.visible = v
	Logging.info("LeftPlayerPanel.set_ambition_section_visible: %s" % v)

## 设置底层修饰区域可见性（HSep3 + Label2"底层修饰" + HBoxContainer2(才/府/定)）
func set_bottom_decoration_visible(v: bool) -> void:
	_decoration_sep.visible = v
	_decoration_title_label.visible = v
	_decoration_hbox.visible = v
	Logging.info("LeftPlayerPanel.set_bottom_decoration_visible: %s" % v)


# ── 侧滑动画 ────────────────────────────────────────────

func _record_original_position():
	_original_pos_x = position.x

func hide_panel():
	if _is_animating or not _is_visible_state: return
	_is_animating = true
	_is_visible_state = false

	var tween = create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", _original_pos_x - SLIDE_OFFSET, ANIM_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(func():
		visible = false
		_is_animating = false
	)

func show_panel():
	if _is_animating or _is_visible_state: return
	_is_animating = true
	_is_visible_state = true
	visible = true

	var tween = create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", _original_pos_x, ANIM_DURATION).from(_original_pos_x - SLIDE_OFFSET)
	tween.tween_property(self, "modulate:a", 1.0, ANIM_DURATION).from(0.0)
	tween.chain().tween_callback(func(): _is_animating = false)
