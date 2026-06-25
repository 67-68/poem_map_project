class_name DecisionScroll extends SmoothScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	PlayerState.location_changed.connect(func(): refresh_current_decisions())
	EventBus.year_changed.connect(func(_year: float): refresh_current_decisions())
	EventBus.decision_clicked.connect(func(): refresh_current_decisions())
	refresh_current_decisions()
	
func refresh_current_decisions():
	#breakpoint
	var location = PlayerState.get_location()
	if not location:
		Logging.err('do not find location %s' % PlayerState.current_location)
		return
	
	var current_year: float = GameState.year
	
	# ── 第一遍：收集所有符合条件的 decisions（不创建 UI）──
	var decisions: Array = []
	for d_uuid in Database.get_decisions_all():
		var d = Database.get_decision(d_uuid)
		
		# 1. 检查是否已被禁用
		if d.disabled:
			continue
		
		# 1.5. 检查点击次数上限（仅当前会话生效）
		if d.allowed_count >= 0 and d._times_clicked > d.allowed_count:
			continue
		
		# 2. 检查时间窗口
		if d.available_from >= 0 and current_year < d.available_from:
			continue
		if d.available_until >= 0 and current_year > d.available_until:
			continue
		
		# 3. 检查前置需求（aciton_requirements）
		var req_passed = true
		if d.aciton_requirements:
			for req in d.aciton_requirements:
				if not req.compare(PlayerState):
					req_passed = false
					break
		if not req_passed:
			continue
		
		# 4. 检查地区标签
		if not d.area_tags:
			decisions.append(d)
			continue
		for t in d.area_tags:
			if t in location.area_tags:
				decisions.append(d)
				break
	
	# ── 第二遍：差分更新 UI ──
	var children = $V.get_children()
	
	# 空状态：显示占位文本
	if decisions.is_empty():
		# 清空所有已有的 action_button
		for child in children:
			child.queue_free()
		# 如果还没有 placeholder label，创建一个
		var placeholder := _get_or_create_placeholder()
		if placeholder.get_parent() == null:
			$V.add_child(placeholder)
		EventBus.avaialble_decision_change.emit([])
		return
	
	# 确保移除 placeholder
	_remove_placeholder()
	
	var target_count = decisions.size()
	var current_count = children.size()
	
	# 1. 更新已有按钮
	for i in range(min(current_count, target_count)):
		children[i].update_action(decisions[i])
	
	# 2. 多余的销毁
	for i in range(target_count, current_count):
		children[i].queue_free()
	
	# 3. 不足的新建
	for i in range(current_count, target_count):
		var panel = preload("res://ui/action_button.tscn").instantiate()
		panel.initialize(decisions[i])
		$V.add_child(panel)
	
	EventBus.avaialble_decision_change.emit(decisions)

# ── 空状态占位 Label 管理 ──

const PLACEHOLDER_NAME := &"__decision_placeholder__"
const PLACEHOLDER_TEXT := "江湖风平浪静，此处暂且无事。"

func _get_or_create_placeholder() -> Label:
	var path := NodePath(PLACEHOLDER_NAME)
	var label := $V.get_node_or_null(path) as Label
	if label:
		return label
	label = Label.new()
	label.name = PLACEHOLDER_NAME
	label.text = PLACEHOLDER_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", Color(0.4, 0.4, 0.4, 0.7))
	return label

func _remove_placeholder() -> void:
	var path := NodePath(PLACEHOLDER_NAME)
	var label := $V.get_node_or_null(path)
	if label:
		label.reparent(self, false)
		label.queue_free()
