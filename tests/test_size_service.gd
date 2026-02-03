class_name TestSizeService extends GutTest

var scene: Label

func before_each():
	scene = Label.new()
	add_child_autofree(scene)
	scene.text = "test_description"

func test_label_size():
	var size = await SizeService_.get_size(scene)
	assert_not_null(size, "应该返回一个 Dictionary")
	assert_true(size.has(scene), "结果应包含被测量的节点")
	assert_gt(size[scene].y, 20, "Label 测量出的高度应大于 20")
	
func test_label_size_precision():
	# 1. 准备数据
	var font = scene.get_theme_font("font")
	var font_size = scene.get_theme_font_size("font_size")
	
	# 获取单行文本的理论高度（不含间距）
	var single_line_height = font.get_height(font_size)
	
	# 2. 运行 Service
	var size_map = await SizeService_.get_size(scene)
	var measured_height = size_map[scene].y
	
	# 3. 精度断言
	# 假设你的文本在 200px 宽度下肯定会折成 2 行
	# 那么高度应该在 1.8倍 到 2.2倍 单行高度之间
	var expected_min = single_line_height * 1.8
	var expected_max = single_line_height * 2.5 # 算上行间距
	
	assert_between(measured_height, expected_min, expected_max, 
		"多行文本高度应当在预期行数倍数范围内")

func test_relative_precision():
	# 1. 测短的
	scene.text = "Hello"
	var size_short = await SizeService_.get_size(scene)
	
	# 2. 测长的
	scene.text = "这是一段非常非常非常非常非常非常非常非常非常长的文本..."
	var size_long = await SizeService_.get_size([scene])
	
	assert_gt(size_long[scene].y, size_short[scene].y, 
		"内容变多后，测量出的高度必须增加！")
