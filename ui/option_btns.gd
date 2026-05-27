class_name OptionBtns extends VBoxContainer

func apply_btns(options: Array, callback: Callable): # list[BaseOption]
	for c in get_children():
		c.queue_free()

	# 4. 生成新按钮
	for option in options:
		var btn = EventBtn.create(option) # 使用工厂方法实例化场景
		add_child(btn)
		# 只有点击有效选项才触发结束
		btn.option_made.connect(callback)