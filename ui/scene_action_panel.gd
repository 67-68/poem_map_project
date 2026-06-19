class_name SceneActionPanel extends VBoxContainer
# 这是更加小的那个直接的button，不是上层承载他们的scroll

@export var action: SceneAction

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

func _init() -> void:
	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = HOVER_BG_COLOR
	_normal_style = StyleBoxEmpty.new()

func initialize(action_: SceneAction = null): # 这里的info未来会用来做非对称信息
	#breakpoint
	if action_:
		action = action_
		$ActionTitleLabel.text = action.name
		$ActionOutcomeLabel.text = action.description
		$TextureRect.texture = action.icon
	else:
		Logging.err('there\'s no action input in the init of scene action panel!!!')
		return
	
	# ── Hover 底色绑定 ──
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# ── Hover Popup（Alt 双层揭示）──
	if not action.description.is_empty() or not action.action_results.is_empty() or not action.aciton_requirements.is_empty():
		_register_hover_popup()


## 创建 HoverInfoPopup，注入叙事文本 + 向量文本，注册到 HoverPopupManager
func _register_hover_popup() -> void:
	var popup := HoverInfoPopup.new()
	
	# 叙事层（默认可见）
	popup.set_narrative_text(action.description if not action.description.is_empty() else "（无叙述）")
	
	# 向量层（Alt 按下可见）
	var vector_lines: Array[String] = []
	if not action.aciton_requirements.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 前提 ━━━[/font_size][/color]")
		for req in action.aciton_requirements:
			var desc = req.describe_requirement()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	if not action.action_results.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
		for op in action.action_results:
			var desc = op.describe_preview()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	popup.set_vector_text("\n".join(vector_lines))
	
	HoverPopupManager.register(self, popup, 0.5, 0.15)


func _on_mouse_entered() -> void:
	if _hover_style and not _hover_style.bg_color == Color.TRANSPARENT:
		self.add_theme_stylebox_override("normal", _hover_style)


func _on_mouse_exited() -> void:
	self.add_theme_stylebox_override("normal", _normal_style)

func _on_button_pressed() -> void:
	#breakpoint
	if action.action_results:
		for r in action.action_results: r.operate()
	
	# ── Generator 消费（统一入口） ──
	var had_generator := action.generator != null
	ActionManager.consume_generator(action)
	
	# ⛔ generator 存在时 block 随机事件查找
	# generator 内部通过 PushEventOperator 自行推送事件
	if had_generator:
		return
	
	# 🚀 革新后：不再需要标准化，前缀匹配自动忽略第4级
	for tag in action.action_tags:
		PlayerState.current_action_tags.append(tag)
	var context = {
	    'main_tag': action.main_tag,
	    'fallback_event_uuid': action.fallback_event_uuid,
	}
	EventManager.scan_events(0, context)
