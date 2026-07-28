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

	# 🆕 全锁定 fallback: 如果所有按钮都被锁定（requirement / affordability），
	#    追加一个「仓皇逃跑」选项（-3 天），确保玩家不会卡死。
	_append_fallback_if_all_locked(callback)

	# ── 自注册 1-4 数字键到 InputManager（延迟到下一帧，确保场景树完全就绪）──
	call_deferred("_register_number_keys")


func _exit_tree() -> void:
	_unregister_number_keys()


# ════════════════════════════════════════════════════════════════
# 🆕 全锁定 fallback: "仓皇逃跑"
# ════════════════════════════════════════════════════════════════

## 检查所有已创建的 EventBtn 是否全部 disabled。
## 若是，追加一个合成 EventOption（"仓皇逃跑"，消耗 3 天），始终可选。
func _append_fallback_if_all_locked(callback: Callable) -> void:
	var btns := get_children()
	if btns.is_empty():
		Logging.info("OptionBtns._append_fallback_if_all_locked: 无按钮，跳过")
		return

	# 检查是否全部被锁定
	for btn in btns:
		if not btn is EventBtn:
			continue
		if not btn.disabled:
			Logging.info("OptionBtns._append_fallback_if_all_locked: 至少有一个可用按钮 (text='%s')，跳过" % btn.text)
			return

	Logging.info("OptionBtns._append_fallback_if_all_locked: 所有 %d 个按钮均被锁定，追加「仓皇逃跑」fallback" % btns.size())

	# 合成 fallback EventOption
	var fallback := EventOption.new()
	fallback.description = tr("CODE_OPTION_BTNS_FALLBACK_DESCRIPTION")  # "仓皇逃跑"

	var cr := ChoiceResult.new()
	var time_op := TimeOperator.new()
	time_op.day = 3.0
	cr.operators.append(time_op)
	fallback.choice_result = cr

	var fb_btn := EventBtn.create(fallback)
	# fallback 按钮不需要 hover 注册（EventBtn._init_option 中无 requirement/choice_result 检查，
	# 会直接走 _register_event_btn_hover() + confirmed()）
	add_child(fb_btn)
	fb_btn.option_made.connect(callback)
	Logging.info("OptionBtns._append_fallback_if_all_locked: fallback 按钮已追加 (text='%s')" % fb_btn.text)


# ═══════════════════════════════════════════════
# InputManager 自注册 — 1-4 数字键映射
# ═══════════════════════════════════════════════

func _register_number_keys() -> void:
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
