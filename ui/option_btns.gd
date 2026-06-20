class_name OptionBtns extends VBoxContainer

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
