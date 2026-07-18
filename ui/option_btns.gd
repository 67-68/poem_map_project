class_name OptionBtns extends VBoxContainer
## 选项按钮容器 — 创建 EventBtn 并自注册 1-4 数字键到 InputManager
##
## 职责：
##   1. 根据 options 数组创建 EventBtn（原有）
##   2. apply_btns() 后自动注册 1-4 数字键回调
##   3. _exit_tree() 自动注销（确保离开场景时清理）

func apply_btns(options: Array, callback: Callable): # list[BaseOption]
	Logging.info("OptionBtns.apply_btns: 收到 %d 个选项" % options.size())
	for c in get_children():
		c.queue_free()

	# 4. 生成新按钮
	for i in range(options.size()):
		var option = options[i]
		Logging.info("OptionBtns.apply_btns:   [%d] option class=%s description='%s'" % [i, option.get_class() if option.has_method('get_class') else typeof(option), option.description if 'description' in option else 'NO_DESCRIPTION'])
		var btn = EventBtn.create(option) # 使用工厂方法实例化场景
		Logging.info("OptionBtns.apply_btns:   [%d] btn.text='%s'" % [i, btn.text])
		add_child(btn)
		# 只有点击有效选项才触发结束
		btn.option_made.connect(callback)

	# ── 自注册 1-4 数字键到 InputManager（延迟到下一帧，确保场景树完全就绪）──
	call_deferred("_register_number_keys")


func _exit_tree() -> void:
	_unregister_number_keys()


# ═══════════════════════════════════════════════
# InputManager 自注册 — 1-4 数字键映射
# ═══════════════════════════════════════════════

func _register_number_keys() -> void:
	""tr("CODE_OPTION_BTNS_12267A7A5D")""
	var btns := get_children()
	var callbacks: Array[Callable] = []
	for i in range(min(btns.size(), 4)):
		var btn = btns[i]
		var cb: Callable = func():
			Logging.info("OptionBtns: 数字键 %d 触发选项" % (i + 1))
			if "option_made" in btn:
				btn.option_made.emit(btn._option if "_option" in btn else null)
			elif btn.has_signal("pressed"):
				btn.pressed.emit()
		callbacks.append(cb)

	var im := _get_input_manager()
	if not im:
		Logging.warn("OptionBtns: 无法获取 InputManager，跳过数字键注册")
		return

	if callbacks.size() > 0:
		im.register_number_key_callbacks(callbacks, "OptionBtns")
		Logging.info("OptionBtns: 已注册 %d 个数字键回调" % callbacks.size())


func _unregister_number_keys() -> void:
	var im := _get_input_manager()
	if im:
		im.unregister_number_key_callbacks("OptionBtns")


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
