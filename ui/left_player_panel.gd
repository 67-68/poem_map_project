extends PanelContainer

## 左侧玩家信息面板
## 显示玩家名字、属性、特质、野心按钮（hover 弹出 AmbitionHUD）
## 保留侧滑动画（EventBus.request_change_left_panel_visibility）

# 优先由 main.tscn 连线；若解析失败则回退到按路径查找
var ambition_hud: Control

# ── 节点引用 ─────────────────────────────────────────────
@onready var _name_label: Label = $"Panel/VBox/ScrollContainer/V/NameLabel"
@onready var _ambition_btn: LinkButton = $"Panel/VBox/ScrollContainer/V/Ambition"
@onready var _prop_grid: GridContainer = $"Panel/VBox/ScrollContainer/V/PropGrid"
@onready var _trait_grid: GridContainer = $"Panel/VBox/ScrollContainer/V/TraitGrid"

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
	
	# 订阅逐旬刷新
	TimeService.on_xun_tick.connect(_on_stat_changed)
	Logging.info("LeftPlayerPanel: connected to TimeService.on_xun_tick")
	
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

func _update_ambition_text() -> void:
	if PlayerState.ambition:
		_ambition_btn.text = "【野心】" + PlayerState.ambition.name
		Logging.info("LeftPlayerPanel: ambition text updated to '%s'" % _ambition_btn.text)
	else:
		_ambition_btn.text = "【野心】暂无"
		Logging.info("LeftPlayerPanel: no ambition data")

# ── PropGrid 构建 ────────────────────────────────────────

func _rebuild_prop_grid() -> void:
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
