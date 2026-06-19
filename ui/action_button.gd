class_name SceneActionPanel extends Button
# 这是更加小的那个直接的button，不是上层承载他们的scroll

@export var action: SceneAction

## 锁定闪光 Tween 引用（用于清除旧闪光）
var _flash_tween: Tween = null

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

@onready var title = $Panel/HBoxContainer/VBoxContainer/Title
@onready var outcome = $Panel/HBoxContainer/VBoxContainer/Outcome
@onready var texture = $Panel/HBoxContainer/TextureRect

func _init() -> void:
	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = HOVER_BG_COLOR
	_normal_style = StyleBoxEmpty.new()

func initialize(action_: SceneAction = null): # 这里的info未来会用来做非对称信息
	#breakpoint
	if action_:
		action = action_
		$Panel/HBoxContainer/VBoxContainer/Title.text = action.name
		$Panel/HBoxContainer/VBoxContainer/Outcome.text = action.description
		$Panel/HBoxContainer/TextureRect.texture = action.icon
	else:
		Logging.err('there\'s no action input in the init of scene action panel!!!')
		return
	
	# ── 点击：执行 action ──
	pressed.connect(_on_button_pressed)
	
	# ── 锁定闪光（locked_actions_selected 迁移到右侧卡片）──
	EventBus.locked_actions_selected.connect(_on_locked_actions_selected)
	
	# ── Hover 底色绑定 ──
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# ── Hover Popup（Alt 双层揭示）──
	if not action.description.is_empty() or not action.action_results.is_empty() or not action.aciton_requirements.is_empty():
		_register_hover_popup()

## 监听锁定行动信号，匹配当前 action 时触发呼吸闪光
func _on_locked_actions_selected(locked_actions: Array) -> void:
	if not action:
		return
	for locked_action in locked_actions:
		if not locked_action is SceneAction:
			continue
		# 通过 main_tag 前缀匹配（与旧 action_map.gd 一致）
		if locked_action.main_tag == action.main_tag:
			_start_flash()
			return

## 呼吸闪光：亮黄 ↔ 白，循环 4 次，每步 0.4s
func _start_flash() -> void:
	# 清除已有闪光 tween
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_loops(4)
	_flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 0.6), 0.4)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.4)


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
