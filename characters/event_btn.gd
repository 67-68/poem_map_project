class_name  EventBtn extends Button

signal option_made(data: ChoiceResult) # 外部连接这个; 不要连接pressed
var option: BaseOption
var click_count := 0

# ── 枯墨下划线动画 ──────────────────────────────────
const UNDERLINE_COLOR: Color = Color(0.55, 0.12, 0.08, 0.7)
const UNDERLINE_HEIGHT: float = 2.0
const HOVER_EXPAND_DURATION: float = 0.25
const HOVER_SHRINK_DURATION: float = 0.15
var _underline: ColorRect = null
var _hover_tween: Tween = null

# 自定义工具提示缓存（由 _make_custom_tooltip 创建）
var _cached_tooltip: Control = null

static func create(data: BaseOption) -> EventBtn:
	var scene = load("res://characters/event_btn.tscn")
	var btn = scene.instantiate()
	btn._init_option(data)
	# 必须设为容器布局模式(1)，否则父 VBoxContainer 无法管理其尺寸（场景默认 layout_mode=2 固定定位）
	btn.layout_mode = 1
	
	# ── 音效挂件注入 ──
	var SfxCls := preload("res://features/ui_sound_component.gd")
	var sfx := SfxCls.new()
	sfx.name = "UISoundComponent"
	sfx.click_category = "book_impact"
	sfx.hover_category = "book_flip"
	btn.add_child(sfx)
	
	return btn

func _ready() -> void:
	_suppress_default_button_states()
	_setup_underline()

## 压制 Godot Button 默认 hover/pressed/focus 样式
## ButtonTheme 只定义了 normal，hover 时回退到默认主题会带阴影+异字体
func _suppress_default_button_states() -> void:
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	# 字体颜色在所有状态下保持一致
	add_theme_color_override("font_hover_color", get_theme_color("font_color", "ButtonTheme"))
	add_theme_color_override("font_pressed_color", get_theme_color("font_color", "ButtonTheme"))
	add_theme_color_override("font_focus_color", get_theme_color("font_color", "ButtonTheme"))

## 创建枯墨下划线 ColorRect，置于按钮底部
func _setup_underline() -> void:
	_underline = ColorRect.new()
	_underline.name = "UnderlineRect"
	_underline.color = UNDERLINE_COLOR
	# 使用 scale 实现左右展开：初始 scale.x=0（不可见）
	_underline.scale = Vector2(0.0, 1.0)
	# 手动锚定：底部铺满左右，高度固定
	_underline.anchor_left = 0.0
	_underline.anchor_right = 1.0
	_underline.anchor_bottom = 1.0
	_underline.anchor_top = 1.0
	_underline.offset_top = -UNDERLINE_HEIGHT
	_underline.offset_bottom = 0.0
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_underline)
	
	# 信号绑定
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	Logging.info("EventBtn._setup_underline: underline created for btn '%s'" % text)

func _on_hover_enter() -> void:
	if not _underline:
		return
	# 清除旧 tween
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.tween_property(_underline, "scale", Vector2(1.0, 1.0), HOVER_EXPAND_DURATION)

func _on_hover_exit() -> void:
	if not _underline:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_IN)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.tween_property(_underline, "scale", Vector2(0.0, 1.0), HOVER_SHRINK_DURATION)

## 构建 hover 数据并注册到 HoverPopupManager（BELOW_OVERLAY 流）
## 替代旧 Godot 原生 _make_custom_tooltip。
func _register_event_btn_hover() -> void:
	if not option:
		Logging.info("EventBtn._register_event_btn_hover: option 为空，跳过")
		return

	# 叙事层：按钮文本即选项描述
	var narrative: String = text if not text.is_empty() else tr("CODE_EVENT_BTN_BB7486F441")

	# 向量层
	var vector_lines: Array[String] = []
	
	# (A) Requirement 摘要（前提条件）
	if 'requirement' in option and option.requirement \
		and option.requirement.has_method('describe_requirement'):
		var req_text = option.requirement.describe_requirement()
		if not req_text.is_empty():
			vector_lines.append(tr("CODE_EVENT_BTN_057AE9C4A2"))
			vector_lines.append(req_text)
	
	# (B) Operator 预览
	var operator_lines: Array[String] = []
	if 'choice_result' in option and option.choice_result:
		operator_lines = option.choice_result.format_preview()
	
	if operator_lines.is_empty():
		if not vector_lines.is_empty():
			vector_lines.append("")
			vector_lines.append(tr("CODE_EVENT_BTN_CDAC366955"))
		vector_lines.append(tr("CODE_EVENT_BTN_29178BE430"))
	else:
		if not vector_lines.is_empty():
			vector_lines.append("")
		vector_lines.append(tr("CODE_EVENT_BTN_CDAC366955"))
		vector_lines.append_array(operator_lines)
	
	var vector_text := "\n".join(vector_lines)
	if vector_text.is_empty():
		Logging.info("EventBtn._register_event_btn_hover: vector_text 为空，跳过注册")
		return

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("EventBtn._register_event_btn_hover: 注册完成 (BELOW_OVERLAY), text='%s'" % text)

func _init_option(data: BaseOption):
	option = data
	# 🔒 优先读取 _resolved_description（动态模板解析后的值，不污染原始 description）
	#     fallback 到 description（静态文本）
	if '_resolved_description' in data and data._resolved_description:
		text = data._resolved_description
		Logging.info("EventBtn._init_option: 使用 _resolved_description='%s'" % text)
	else:
		text = data.description if 'description' in data else tr("CODE_EVENT_BTN_BB7486F441")
		Logging.info("EventBtn._init_option: 使用 description='%s' (has description=%s)" % [text, 'description' in data])
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable text wrapping
	# custom_minimum_size 已经在场景中设置了，不需要重复设置
	
	# ── 统一验证管线 ──
	var req = data.requirement if 'requirement' in data else null
	if req:
		var pass_prop = req.compare(PlayerState)
		if pass_prop == null:
			Logging.err('some property can not be found in state')
			return
		if not pass_prop:
			# 禁用按钮但允许点击查看原因（点击后变灰 + Toast 提示）
			tooltip_text = req.get_failed_hint()
			pressed.connect(disable_btn)
			return
	
	# 通过验证 → 正常触发
	_register_to_manager(data)
	_register_event_btn_hover()  # 🆕 BELOW_OVERLAY hover 注册
	pressed.connect(confirmed)

## 生成注册 key 并注册到 AncientOptionBtnManager
func _register_to_manager(data: BaseOption) -> void:
	var btn_id := ""
	if '_resolved_description' in data and data._resolved_description:
		btn_id = data._resolved_description
	else:
		btn_id = data.description if 'description' in data else ""
	if btn_id.is_empty():
		Logging.warn("EventBtn._register_to_manager: 无法生成 btn_id，跳过注册")
		return
	AncientOptionBtnManager.register(btn_id, self)

func confirmed():
	if not double_check():
		return
	option_made.emit(option.choice_result if 'choice_result' in option else null)

func disable_btn():
	if not double_check():
		return
	self.modulate = Color.GRAY
	disabled = true
	var reason = option.requirement.get_failed_hint() if option.requirement else tr("CODE_EVENT_BTN_1F4CD3AC79")
	EventBus.request_toast.emit(reason, 1)

func double_check() -> bool:
	if 'double_check' not in option or not option.double_check: return true
	click_count += 1
	if not click_count >= 2:
		EventBus.request_toast.emit(option.double_check_reason, 1)
		return false
	else: return true

# ── 自定义工具提示（已废弃，改用 BELOW_OVERLAY）──

## 🚫 禁用 Godot 原生 tooltip，防止与 BELOW_OVERLAY hover 同时出现。
func _make_custom_tooltip(_for_text: String) -> Object:
	return Control.new()
