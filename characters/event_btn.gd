class_name  EventBtn extends Button

signal option_made(data: ChoiceResult) # 外部连接这个; 不要连接pressed
var option: BaseOption
var click_count := 0

# 自定义工具提示缓存（由 _make_custom_tooltip 创建）
var _cached_tooltip: Control = null

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

# ── 自定义工具提示（Alt Reveal 双层 Tooltip）──

func _make_custom_tooltip(for_text: String) -> Object:
	"""
	重写 Godot 的 _make_custom_tooltip 方法。
	返回自定义 CustomTooltip 控件，支持 Alt 键切换叙事层/向量层。
	"""
	var tooltip = preload("res://ui/custom_tooltip.gd").new()
	
	# 先构建向量层文本，判断是否有向量数据
	var has_vector_data := false
	var vector_lines: Array[String] = []
	
	# (A) Requirement 摘要（Alt 下显示简略前提）
	if option and 'requirement' in option and option.requirement \
		and option.requirement.has_method('describe_requirement'):
		var req_text = option.requirement.describe_requirement()
		if not req_text.is_empty():
			has_vector_data = true
			vector_lines.append("[前提]")
			vector_lines.append(req_text)
	
	# (B) Operator 预览（向量变化）
	var operator_lines: Array[String] = []
	if option and 'choice_result' in option and option.choice_result:
		operator_lines = option.choice_result.format_preview()
		if not operator_lines.is_empty():
			has_vector_data = true
	
	if operator_lines.is_empty():
		# 无 operator 的选项显示这句话
		if has_vector_data:
			vector_lines.append("")
			vector_lines.append("[影响]")
		vector_lines.append("你想知道什么发生了")
	else:
		if not vector_lines.is_empty():
			vector_lines.append("")  # 空行分隔前提和向量
		vector_lines.append("[影响]")
		vector_lines.append_array(operator_lines)
	
	tooltip.set_vector_text("\n".join(vector_lines))
	
	# 叙事层：如果有向量数据可看，在锁定原因尾部追加 Alt 提示
	var narrative_body = for_text
	if has_vector_data:
		narrative_body += "\n[color=gray][font_size=12]━━━ [按住 ALT 查看系统解析] ━━━[/font_size][/color]"
	tooltip.set_narrative_text(narrative_body)
	
	_cached_tooltip = tooltip
	return tooltip
