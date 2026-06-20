class_name DecisionScroll extends ScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerState.location_changed.connect(func(): refresh_current_decisions())
	refresh_current_decisions()
	
func refresh_current_decisions():
	#breakpoint
	var location = PlayerState.get_location()
	if not location:
		Logging.err('do not find location %s' % PlayerState.current_location)
		return
	
	for child in $V.get_children():
		child.queue_free()	
	
	var decisions = []
	for d_uuid in Database.get_decisions_all():
		var d = Database.get_decision(d_uuid)
		
		# 1. 检查是否已被禁用
		if d.disabled:
			continue
		
		# 2. 检查前置需求（aciton_requirements）
		var req_passed = true
		if d.aciton_requirements:
			for req in d.aciton_requirements:
				if not req.compare(PlayerState):
					req_passed = false
					break
		if not req_passed:
			continue
		
		# 3. 检查地区标签
		if not d.area_tags:
			var panel = preload("res://ui/decision_panel.tscn").instantiate()
			panel.inititalization(d)
			$V.add_child(panel)
			decisions.append(d)
			continue
		for t in d.area_tags:
			if t in location.area_tags:
				var panel = preload("res://ui/decision_panel.tscn").instantiate()
				panel.inititalization(d)
				$V.add_child(panel)
				decisions.append(d)
				break
	EventBus.avaialble_decision_change.emit(decisions)

	# ── 注册 1-4 数字键 → DecisionPanel._on_button_pressed ──
	_register_decision_number_keys()


## 收集 DecisionScroll 中的 DecisionPanel 子节点，映射到 1-4 数字键
func _register_decision_number_keys() -> void:
	var children := $V.get_children()
	var callbacks: Array[Callable] = []
	for i in range(min(children.size(), 4)):
		var panel = children[i]
		if panel.has_method("_on_button_pressed"):
			var cb: Callable = func():
				Logging.info("DecisionScroll: 数字键 %d 触发决策" % (i + 1))
				panel._on_button_pressed()
			callbacks.append(cb)

	var im := _get_input_manager()
	if not im:
		Logging.warn("DecisionScroll: 无法获取 InputManager")
		return

	if callbacks.size() > 0:
		im.register_number_key_callbacks(callbacks, "DecisionScroll")
		Logging.info("DecisionScroll: 已注册 %d 个决策数字键回调" % callbacks.size())
	else:
		im.unregister_number_key_callbacks("DecisionScroll")


func _get_input_manager() -> InputManager:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return null
	var core_systems := main_node.get_node_or_null("CoreSystems")
	if not core_systems:
		return null
	return core_systems.get_node_or_null("InputManager") as InputManager
