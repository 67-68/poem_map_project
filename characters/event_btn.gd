class_name  EventBtn extends Button

signal option_made(data: ChoiceResult) # 外部连接这个; 不要连接pressed
var option: BaseOption
var click_count := 0

static func create(data: BaseOption) -> EventBtn:
	"""工厂方法：创建并初始化按钮"""
	var scene = load("res://characters/event_btn.tscn")
	var btn = scene.instantiate()
	btn._init_option(data)
	return btn

func _init_option(data: BaseOption):
	"""初始化选项数据"""
	option = data
	# 🔒 优先读取 _resolved_description（动态模板解析后的值，不污染原始 description）
	#     fallback 到 description（静态文本）
	if '_resolved_description' in data and data._resolved_description:
		text = data._resolved_description
	else:
		text = data.description if 'description' in data else "选项"
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable text wrapping
	# custom_minimum_size 已经在场景中设置了，不需要重复设置
	
	# ── 统一验证管线 ──
	# 无论是 Requirement（属性不够、flag 未设置）还是 NarrativeLock（叙事锁定），
	# 都通过 requirement.compare() 统一判断。不再单独处理 is_disabled 分支。
	if data.requirement:
		var pass_prop = data.requirement.compare(PlayerState)
		if pass_prop == null:
			Logging.err('some property can not be found in state')
			return
		if not pass_prop:
			# 禁用按钮但允许点击查看原因（点击后变灰 + Toast 提示）
			tooltip_text = data.requirement.get_failed_hint()
			pressed.connect(disable_btn)
			return
	
	# 通过验证 → 正常触发
	pressed.connect(confirmed)

func confirmed():
	if not double_check():
		return
	option_made.emit(option.choice_result if 'choice_result' in option else null)

func disable_btn():
	if not double_check():
		return
	self.modulate = Color.GRAY
	disabled = true
	var reason = option.requirement.get_failed_hint() if option.requirement else "选项已禁用"
	EventBus.request_toast.emit(reason, 1)

func double_check() -> bool:
	if 'double_check' not in option or not option.double_check: return true
	click_count += 1
	if not click_count >= 2:
		EventBus.request_toast.emit(option.double_check_reason, 1)
		return false
	else: return true
	
