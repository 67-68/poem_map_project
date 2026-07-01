extends PanelContainer

## 左侧玩家信息面板
## 显示玩家名字、属性、特质、野心按钮（hover 弹出 AmbitionHUD）
## 保留侧滑动画（EventBus.request_change_left_panel_visibility）
## 情绪展示方案A："字即是心" — RichTextLabel BBCode 异化流

# 优先由 main.tscn 连线；若解析失败则回退到按路径查找
var ambition_hud: Control

# ── 情绪配置：key → { label, 零值描述, 低压描述, 中压描述, 高压描述, 极值描述 }
const _EMOTION_CFG := {
	"sorrow":      { "label": "愁苦", "zero": "心如止水", "low": "黯然神伤", "mid": "郁郁寡欢", "high": "悲从中来", "max": "肝肠寸断" },
	"arrogance":   { "label": "狂傲", "zero": "心如止水", "low": "恃才傲物", "mid": "目中无人", "high": "睥睨天下", "max": "天低吴楚" },
	"anger":       { "label": "愤懑", "zero": "心如止水", "low": "意难平",   "mid": "愤世嫉俗", "high": "拍案而起", "max": "怒发冲冠" },
	"tranquility": { "label": "旷达", "zero": "心如止水", "low": "清风徐来", "mid": "心旷神怡", "high": "宠辱不惊", "max": "天地一沙鸥" },
	"ambition":    { "label": "野心", "zero": "心如止水", "low": "跃跃欲试", "mid": "志在千里", "high": "舍我其谁", "max": "致君尧舜上" }
}
const MAX_EMOTION_VALUE: int = 100

# ── 节点引用 ─────────────────────────────────────────────
@onready var _name_label: Label = $"Panel/VBox/ScrollContainer/V/NameLabel"
@onready var _ambition_btn: LinkButton = $"Panel/VBox/ScrollContainer/V/Ambition"
@onready var _prop_grid: GridContainer = $"Panel/VBox/ScrollContainer/V/PropGrid"
@onready var _trait_grid: GridContainer = $"Panel/VBox/ScrollContainer/V/TraitGrid"
@onready var _emotion_header: Label = $"Panel/VBox/ScrollContainer/V/EmotionHeader"
@onready var _emotion_sorrow: RichTextLabel = $"Panel/VBox/ScrollContainer/V/EmotionSorrow"
@onready var _emotion_arrogance: RichTextLabel = $"Panel/VBox/ScrollContainer/V/EmotionArrogance"
@onready var _emotion_anger: RichTextLabel = $"Panel/VBox/ScrollContainer/V/EmotionAnger"
@onready var _emotion_tranquility: RichTextLabel = $"Panel/VBox/ScrollContainer/V/EmotionTranquility"
@onready var _emotion_ambition: RichTextLabel = $"Panel/VBox/ScrollContainer/V/EmotionAmbition"

# emotion_key → RichTextLabel 查找表
var _emotion_labels: Dictionary = {}
# prop_key(String) → Label 映射
var _prop_label_map: Dictionary = {}
# 当前活跃的颜色覆盖（prop_key → Color），用于 rebuild 后重染色
var _prop_color_overrides: Dictionary = {}
# 野心追踪属性进度 Label（动态创建在 Ambition 按钮下方）
var _ambition_progress_label: Label = null

# 侧滑动画
var _original_pos_x: float
var _is_animating: bool = false
var _is_visible_state: bool = true
const SLIDE_OFFSET: float = 50.0
const ANIM_DURATION: float = 0.3

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	Logging.info("LeftPlayerPanel: _ready start")
	
	# 静态数据
	_name_label.text = PlayerState.player_name
	Logging.info("LeftPlayerPanel: player_name=%s" % PlayerState.player_name)
	
	# 动态填充 PropGrid / TraitGrid
	_rebuild_prop_grid()
	_rebuild_trait_grid()
	
	# ── 情绪 label 查找表 ──
	_emotion_labels = {
		"sorrow":      _emotion_sorrow,
		"arrogance":   _emotion_arrogance,
		"anger":       _emotion_anger,
		"tranquility": _emotion_tranquility,
		"ambition":    _emotion_ambition,
	}
	for emo_key in _emotion_labels:
		if not _emotion_labels[emo_key]:
			Logging.err("LeftPlayerPanel: emotion label '%s' is null!" % emo_key)
		else:
			Logging.info("LeftPlayerPanel: emotion label '%s' ready, visible=%s" % [emo_key, str(_emotion_labels[emo_key].visible)])
	
	# ── 信号连接：旬 tick + 情绪实时变化 ──
	TimeService.on_xun_tick.connect(_on_stat_changed)
	Logging.info("LeftPlayerPanel: connected to TimeService.on_xun_tick")
	if not PlayerState.emotion_changed.is_connected(_refresh_emotions):
		PlayerState.emotion_changed.connect(_refresh_emotions)
		Logging.info("LeftPlayerPanel: connected to PlayerState.emotion_changed")
	
	# ── 信号连接：trait 增减时重建 TraitGrid ──
	if not EventBus.on_trait_change.is_connected(_rebuild_trait_grid):
		EventBus.on_trait_change.connect(_rebuild_trait_grid)
		Logging.info("LeftPlayerPanel: connected to EventBus.on_trait_change")
	
	# 初始化情绪显示
	_refresh_emotions()
	
	# ── 野心 LinkButton → HoverPopupManager ──
	# 优先信任 @export（main.tscn 手动连线），回退按绝对路径查找
	if not ambition_hud:
		ambition_hud = get_tree().root.get_node("Main/UI/AmbitionHUD") as Control
		if ambition_hud:
			Logging.info("LeftPlayerPanel: resolved ambition_hud by path fallback")
	if ambition_hud:
		HoverPopupManager.register(_ambition_btn, ambition_hud, 0.2, 0.15)
		Logging.info("LeftPlayerPanel: registered ambition_hud with HoverPopupManager")
	else:
		Logging.warn("LeftPlayerPanel: ambition_hud is null, hover popup disabled")
	
	# 野心按钮文本 + 动态创建进度 Label
	_update_ambition_text()
	_create_ambition_progress_label()
	
	# 监听属性变动 → 刷新野心进度
	if not PlayerState.player_stat_changed.is_connected(_on_ambition_stat_changed):
		PlayerState.player_stat_changed.connect(_on_ambition_stat_changed)
	
	# 监听野心变更 → 重建进度 Label（tracked_property 可能变化）
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

# ── 动态数据刷新 ────────────────────────────────────────

func _on_stat_changed() -> void:
	Logging.info("LeftPlayerPanel: stat changed, refreshing")
	_refresh_prop_grid()
	_refresh_trait_grid()
	_update_ambition_text()
	_refresh_emotions()

func _update_ambition_text() -> void:
	if PlayerState.ambition:
		_ambition_btn.text = "【野心】" + PlayerState.ambition.name
		Logging.info("LeftPlayerPanel: ambition text updated to '%s'" % _ambition_btn.text)
	else:
		_ambition_btn.text = "【野心】暂无"
		Logging.info("LeftPlayerPanel: no ambition data")
	_refresh_ambition_progress_label()

func _create_ambition_progress_label() -> void:
	if _ambition_progress_label:
		return
	_ambition_progress_label = Label.new()
	_ambition_progress_label.name = "AmbitionProgressLabel"
	_ambition_progress_label.theme_type_variation = &"DefaultText"
	_ambition_progress_label.add_theme_font_size_override(&"font_size", 12)
	_ambition_progress_label.add_theme_color_override(&"font_color", Color(0.5, 0.45, 0.35))
	var parent_vbox := _ambition_btn.get_parent()
	if parent_vbox:
		parent_vbox.add_child(_ambition_progress_label)
		parent_vbox.move_child(_ambition_progress_label, _ambition_btn.get_index() + 1)
		Logging.info("LeftPlayerPanel: ambition progress label created")
	_refresh_ambition_progress_label()

func _refresh_ambition_progress_label() -> void:
	if not _ambition_progress_label:
		return
	var ambition = PlayerState.ambition
	if not ambition or ambition.tracked_property.is_empty():
		_ambition_progress_label.hide()
		return
	var tracked_prop = Database.get_property(ambition.tracked_property)
	if not tracked_prop:
		_ambition_progress_label.hide()
		Logging.warn("LeftPlayerPanel: tracked property '%s' not found" % ambition.tracked_property)
		return
	var cn_name = tracked_prop.get_display_name()
	var val = tracked_prop.val
	var perception = tracked_prop.get_staged_perception_text()
	_ambition_progress_label.text = "进度「%s」：%d(%s)" % [cn_name, val, perception]
	_ambition_progress_label.show()

func _on_ambition_stat_changed(prop_name: String) -> void:
	var ambition = PlayerState.ambition
	if not ambition or ambition.tracked_property.is_empty():
		return
	if prop_name == ambition.tracked_property:
		_refresh_ambition_progress_label()

func _on_ambition_changed(_new_ambition) -> void:
	# tracked_property 可能变化，重建 label
	if _ambition_progress_label:
		_ambition_progress_label.queue_free()
		_ambition_progress_label = null
	_create_ambition_progress_label()

# ── 情绪刷新（字即是心 BBCode 方案）────────────────────

func _refresh_emotions(_unused: String = "") -> void:
	Logging.info("LeftPlayerPanel: _refresh_emotions() called")
	
	for emo_key in _emotion_labels:
		var label: RichTextLabel = _emotion_labels[emo_key]
		if not label:
			Logging.err("LeftPlayerPanel: _refresh_emotions: label is null for key '%s'" % emo_key)
			continue
		
		var value: int = PlayerState.get_emotion(emo_key)
		var cfg: Dictionary = _EMOTION_CFG.get(emo_key, {})
		var cn_name: String = cfg.get("label", emo_key)
		var desc: String
		var color_str: String
		var font_size: int
		var has_shake: bool = false
		
		if value <= 0:
			desc = cfg.get("zero", "心如止水")
			color_str = "#8b8173"
			font_size = 12
		elif value <= 33:
			desc = cfg.get("low", "")
			color_str = "#6b6153"
			font_size = 14
		elif value <= 66:
			desc = cfg.get("mid", "")
			color_str = "#5a5045"
			font_size = 18
		elif value <= 99:
			desc = cfg.get("high", "")
			color_str = "#a03020"
			font_size = 24
		else:
			desc = cfg.get("max", "")
			color_str = "#8b0000"
			font_size = 28
			has_shake = true
		
		if has_shake:
			label.text = "[color=%s][font_size=%d][shake rate=20.0 level=5 connected=1]%s：%d(%s)[/shake][/font_size][/color]" % [color_str, font_size, cn_name, value, desc]
		else:
			label.text = "[color=%s][font_size=%d]%s：%d(%s)[/font_size][/color]" % [color_str, font_size, cn_name, value, desc]
		
		Logging.info("LeftPlayerPanel: _refresh_emotions: %s value=%d -> '%s'" % [cn_name, value, desc])

# ── PropGrid 构建 ────────────────────────────────────────

func _rebuild_prop_grid() -> void:
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in _rebuild_prop_grid, skipping")
		return
	# 清空映射表（子节点即将被清空）
	_prop_label_map.clear()
	# 清空占位子节点
	for child in _prop_grid.get_children():
		child.queue_free()
	Logging.info("LeftPlayerPanel: PropGrid cleared")
	
	var props: Dictionary = Database.get_properties_all()
	Logging.info("LeftPlayerPanel: building PropGrid with %d properties" % props.size())
	
	for prop_key in props:
		var prop: Property = props[prop_key]
		if prop.not_show_on_left:
			Logging.info("LeftPlayerPanel: skip prop '%s' (not_show_on_left)" % prop_key)
			continue
		var label := Label.new()
		label.theme_type_variation = &"DefaultText"
		label.text = "「%s」：%d(%s)" % [prop.get_display_name(), prop.val, prop.get_staged_perception_text()]
		_prop_grid.add_child(label)
		_prop_label_map[prop_key] = label
		Logging.info("LeftPlayerPanel: added prop label: %s" % label.text)
	
	# 重建后恢复已设置的颜色覆盖
	_reapply_color_overrides()

func _refresh_prop_grid() -> void:
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in _refresh_prop_grid, skipping")
		return
	var props: Dictionary = Database.get_properties_all()
	var children := _prop_grid.get_children()
	
	# 计算可见属性数量（排除 not_show_on_left）
	var visible_count := 0
	for prop_key in props:
		var prop: Property = props[prop_key]
		if not prop.not_show_on_left:
			visible_count += 1
	
	# 如果子节点数量变了，重建
	if children.size() != visible_count:
		Logging.info("LeftPlayerPanel: PropGrid count changed (%d→%d), rebuilding" % [children.size(), visible_count])
		_rebuild_prop_grid()
		return
	
	var idx := 0
	for prop_key in props:
		var prop: Property = props[prop_key]
		if prop.not_show_on_left:
			continue
		var label: Label = children[idx]
		var new_text := "「%s」：%d(%s)" % [prop.get_display_name(), prop.val, prop.get_staged_perception_text()]
		if label.text != new_text:
			label.text = new_text
			Logging.info("LeftPlayerPanel: updated prop label: %s" % new_text)
		idx += 1

# ── Prop Label 颜色管理 API ─────────────────────────────

## 返回左侧面板当前显示的属性 key 列表（排除 not_show_on_left）
func get_displayed_prop_keys() -> Array[String]:
	var keys: Array[String] = []
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in get_displayed_prop_keys")
		return keys
	var props: Dictionary = Database.get_properties_all()
	for prop_key in props:
		var prop: Property = props[prop_key]
		if not prop.not_show_on_left:
			keys.append(prop_key)
	return keys

## 为指定属性的 label 设置字体颜色覆盖
func set_prop_label_color(prop_key: String, color: Color) -> void:
	if _prop_label_map.has(prop_key):
		var label: Label = _prop_label_map[prop_key]
		label.add_theme_color_override("font_color", color)
		_prop_color_overrides[prop_key] = color
	else:
		Logging.info("LeftPlayerPanel: set_prop_label_color: label not found for key '%s'" % prop_key)

## 重置指定属性的 label 颜色为默认
func reset_prop_label_color(prop_key: String) -> void:
	if _prop_label_map.has(prop_key):
		var label: Label = _prop_label_map[prop_key]
		label.remove_theme_color_override("font_color")
	_prop_color_overrides.erase(prop_key)

## 重置所有属性 label 的颜色为默认
func reset_all_prop_colors() -> void:
	for prop_key in _prop_label_map:
		var label: Label = _prop_label_map[prop_key]
		label.remove_theme_color_override("font_color")
	_prop_color_overrides.clear()

## 私有方法：rebuild 后重新应用已存储的颜色覆盖
func _reapply_color_overrides() -> void:
	for prop_key in _prop_color_overrides:
		if _prop_label_map.has(prop_key):
			var label: Label = _prop_label_map[prop_key]
			var color: Color = _prop_color_overrides[prop_key]
			label.add_theme_color_override("font_color", color)

# ── TraitGrid 构建 ───────────────────────────────────────

func _rebuild_trait_grid() -> void:
	# 清空旧子节点：先 remove_child（立即解绑）再 queue_free（异步释放）
	for child in _trait_grid.get_children():
		_trait_grid.remove_child(child)
		child.queue_free()
	Logging.info("LeftPlayerPanel: TraitGrid cleared")
	
	var trait_keys: Array = PlayerState.traits
	Logging.info("LeftPlayerPanel: building TraitGrid with %d traits" % trait_keys.size())
	
	for trait_key in trait_keys:
		var trait_data: Trait = Database.get_trait(trait_key)
		
		# 使用 TraitDemonstrator（阳刻印章 + 名称）
		var demonstrator = preload("res://ui/trait_demonstrator.tscn").instantiate()
		_trait_grid.add_child(demonstrator)
		
		if not trait_data:
			# 未在 Database.traits 注册的软 trait（如 poem_recipe_*），
			# 尝试通过 Database.resolve() 查找对应资源获取展示名
			var resolved = Database.resolve(trait_key)
			var display_name: String = trait_key
			if resolved and "name" in resolved:
				display_name = resolved.name
			Logging.info("LeftPlayerPanel: trait key '%s' not in Database.traits, fallback display as '%s'" % [trait_key, display_name])
			demonstrator.set_trait_fallback(trait_key, display_name)
		else:
			demonstrator.set_trait(trait_data)
			Logging.info("LeftPlayerPanel: added trait demonstrator: %s" % trait_data.name)

func _refresh_trait_grid() -> void:
	var trait_keys: Array = PlayerState.traits
	var children := _trait_grid.get_children()
	
	# 不依赖 children.size() 比较（queue_free 异步导致不准），直接重建
	if children.size() != trait_keys.size():
		Logging.info("LeftPlayerPanel: TraitGrid count changed (%d→%d), rebuilding" % [children.size(), trait_keys.size()])
		_rebuild_trait_grid()
		return
	# 暂时不做逐字刷新（trait 变更更常见的触发路径是 add/remove，届时重建即可）
	# 如果未来需要逐字刷新，可以在这里实现

# ── 侧滑动画（保留不动）─────────────────────────────────

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
