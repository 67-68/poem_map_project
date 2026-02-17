class_name OptionBtns extends VBoxContainer

func apply_btns(options: Array, callback: Callable): # list[EventOption]
	# 4. 生成新按钮
	for option in options:
		var btn = EventBtn.new(option) # 假设你封装好了这个
		add_child(btn)
		# 只有点击有效选项才触发结束
		btn.option_made.connect(callback)