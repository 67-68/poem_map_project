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
	
	# 初始化情绪显示
	_refresh_emotions()
	
	# ── 野心 LinkButton → HoverPopupManager ──
	# 优先信任 @export（main.tscn 手动连线），回退按绝对路径查找
	if not ambition_hud:
		ambition_hud = get_tree().root.get_node("Main/UI/AmbitionHUD") as Control
		if ambition_hud:
			Logging.info("LeftPlayerPanel: resolved ambition_hud by path fallback")
	if ambition_hud:
		HoverPopupManager.register(_ambition_btn, ambition_hud, 0.5, 0.15)
		Logging.info("LeftPlayerPanel: registered ambition_hud with HoverPopupManager")
	else:
		Logging.warn("LeftPlayerPanel: ambition_hud is null, hover popup disabled")
	
	# 野心按钮文本
	_update_ambition_text()
	
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
			label.text = "[color=%s][font_size=%d][shake rate=20.0 level=5 connected=1]%s：%s[/shake][/font_size][/color]" % [color_str, font_size, cn_name, desc]
		else:
			label.text = "[color=%s][font_size=%d]%s：%s[/font_size][/color]" % [color_str, font_size, cn_name, desc]
		
		Logging.info("LeftPlayerPanel: _refresh_emotions: %s value=%d -> '%s'" % [cn_name, value, desc])

# ── PropGrid 构建 ────────────────────────────────────────

func _rebuild_prop_grid() -> void:
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in _rebuild_prop_grid, skipping")
		return
	# 清空占位子节点
	for child in _prop_grid.get_children():
		child.queue_free()
	Logging.info("LeftPlayerPanel: PropGrid cleared")
	
	var props: Dictionary = Database.get_properties_all()
	Logging.info("LeftPlayerPanel: building PropGrid with %d properties" % props.size())
	
	for prop_key in props:
		var prop: Property = props[prop_key]
		var label := Label.new()
		label.theme_type_variation = &"DefaultText"
		label.text = "「%s」：%s" % [prop.get_display_name(), prop.get_staged_perception_text()]
		_prop_grid.add_child(label)
		Logging.info("LeftPlayerPanel: added prop label: %s" % label.text)

func _refresh_prop_grid() -> void:
	if not Database:
		Logging.err("LeftPlayerPanel: Database autoload not ready in _refresh_prop_grid, skipping")
		return
	var props: Dictionary = Database.get_properties_all()
	var children := _prop_grid.get_children()
	
	# 如果子节点数量变了，重建
	if children.size() != props.size():
		Logging.info("LeftPlayerPanel: PropGrid count changed (%d→%d), rebuilding" % [children.size(), props.size()])
		_rebuild_prop_grid()
		return
	
	var idx := 0
	for prop_key in props:
		var prop: Property = props[prop_key]
		var label: Label = children[idx]
		var new_text := "「%s」：%s" % [prop.get_display_name(), prop.get_staged_perception_text()]
		if label.text != new_text:
			label.text = new_text
			Logging.info("LeftPlayerPanel: updated prop label: %s" % new_text)
		idx += 1

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
		if not trait_data:
			Logging.warn("LeftPlayerPanel: trait key '%s' not found in Database" % trait_key)
			continue
		
		# 使用 TraitDemonstrator（阳刻印章 + 名称）
		var demonstrator = preload("res://ui/trait_demonstrator.tscn").instantiate()
		_trait_grid.add_child(demonstrator)
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
