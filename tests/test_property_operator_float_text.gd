# ================================================================
# PropertyOperator 飘字链路测试
# ================================================================
# 用途：不依赖游戏场景，直接验证 PropertyOperator 的
#       _emit_float_text() 是否产生正确的飘字信号
# ================================================================
extends GutTest

var _test_property: Property
var _operator: PropertyOperator


func before_each():
	# ── 清理 Database ──
	Database.properties.clear()
	
	# ── 创建测试属性：fatigue（疲劳值）─
	_test_property = Property.new()
	_test_property.uuid = "fatigue"
	_test_property.name = "fatigue"
	_test_property.val = 50
	_test_property.hard_max = 100
	
	# 注入 change_perceptions（跟 .tres 一样的配置）
	var cp1 = PropChangePerceptionData.new()
	cp1.min_delta = 1; cp1.max_delta = 15
	cp1.gain_text = "稍感疲惫"; cp1.loss_text = "歇了一口气"
	_test_property.change_perceptions.append(cp1)
	
	var cp2 = PropChangePerceptionData.new()
	cp2.min_delta = 16; cp2.max_delta = 40
	cp2.gain_text = "疲态渐显"; cp2.loss_text = "恢复了些气力"
	_test_property.change_perceptions.append(cp2)
	
	var cp3 = PropChangePerceptionData.new()
	cp3.min_delta = 41; cp3.max_delta = 70
	cp3.gain_text = "身心俱疲"; cp3.loss_text = "神清气爽"
	_test_property.change_perceptions.append(cp3)
	
	Database.properties["fatigue"] = _test_property
	
	# ── 创建 PropertyOperator ──
	_operator = PropertyOperator.new()
	_operator.str_props = "fatigue"
	_operator.value = 10  # +10 fatigue


# ════════════════════════════════════════════════════════════
# 测试 get_change_perception_text
# ════════════════════════════════════════════════════════════

func test_get_change_perception_text_gain():
	"""增加时返回 gain_text"""
	var text = _test_property.get_change_perception_text(10)
	assert_eq(text, "稍感疲惫", "delta=+10 → gain_text='稍感疲惫'")


func test_get_change_perception_text_loss():
	"""减少时返回 loss_text"""
	var text = _test_property.get_change_perception_text(-10)
	assert_eq(text, "歇了一口气", "delta=-10 → loss_text='歇了一口气'")


func test_get_change_perception_text_large_gain():
	"""大增加量匹配正确区间"""
	var text = _test_property.get_change_perception_text(50)
	assert_eq(text, "身心俱疲", "delta=+50 → gain_text='身心俱疲'")


func test_get_change_perception_text_large_loss():
	"""大减少量匹配正确区间"""
	var text = _test_property.get_change_perception_text(-50)
	assert_eq(text, "神清气爽", "delta=-50 → loss_text='神清气爽'")


func test_get_change_perception_text_zero():
	"""delta=0 → 无文本"""
	var text = _test_property.get_change_perception_text(0)
	assert_eq(text, "精力充沛", "delta=0 → fallback 到 staged_perception 的 '精力充沛'")


# ════════════════════════════════════════════════════════════
# 测试 PropertyOperator 飘字文本
# ════════════════════════════════════════════════════════════

func test_operator_get_change_perception_text():
	"""PropertyOperator._emit_float_text 内部调用的 get_change_perception_text"""
	var prop = Database.properties.get("fatigue")
	assert_not_null(prop, "fatigue 应该存在于 Database")
	
	var text = prop.get_change_perception_text(_operator.value)
	assert_eq(text, "稍感疲惫", "value=+10 → gain_text='稍感疲惫'")


func test_operator_negative_value():
	"""负值（prop_sub）对应的文本"""
	var op = PropertyOperator.new()
	op.str_props = "fatigue"
	op.value = -30
	
	var prop = Database.properties.get("fatigue")
	var text = prop.get_change_perception_text(op.value)
	assert_eq(text, "恢复了些气力", "value=-30 → loss_text='恢复了些气力'")
