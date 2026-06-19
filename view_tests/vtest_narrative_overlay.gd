class_name DebugNarrativeOverlay extends RefCounted

var view: Control

const SCENE_PATH = "res://characters/narrative_overlay.tscn"

func create_debug_view(idx: int):
	"""
	每次被调用都会创建对应的 view，用于 ViewTest 插件显示
	"""
	var view_scene := preload(SCENE_PATH)
	view = view_scene.instantiate()

	match idx:
		0:
			# 标准尺寸
			view.custom_minimum_size = Vector2(800, 600)
		1:
			# 宽屏/平板模式
			view.custom_minimum_size = Vector2(1024, 600)
		2:
			# 竖屏/移动端模式
			view.custom_minimum_size = Vector2(500, 800)
		3:
			# 紧凑模式
			view.custom_minimum_size = Vector2(600, 400)
		_:
			return null

	view.size = view.custom_minimum_size

	# 纸带模式：NarrativeOverlay 默认隐藏（全空时 hide）。
	# apply_narrative 内部会调用 _show_tape() 首次展示 dimmer 淡入。
	# ViewTest 中不需要手动 show()。
	return view


# ═══════════════════════════════════════════════
# 测试场景：纸带追加模式
# ═══════════════════════════════════════════════
# 每个 idx (0-3) 对应一个独立的 NarrativeOverlay 实例，
# 各自展示独立的纸带。因此每个实例只推送一个事件，
# 用于验证单条目纸带的显示效果。
#
# 纸带核心行为验证点（需在运行中交互验证）：
#   - 标题 + 正文 + example 是否正确渲染
#   - 选项按钮是否出现
#   - 点击选项后按钮是否变为文本烙印（choice_label）
#   - queue 事件 dim_previous_entries / stack 事件不 dim
#   - 回归路径 revive_entry 恢复选项

func test_narrative_scenarios(map):
	# -------------------------------------------------------------------------
	# Case 0: 单选项事件 — 石壕吏
	# -------------------------------------------------------------------------
	var v0 = map.get('0')
	if is_instance_valid(v0) and v0.has_method("apply_narrative"):
		var ev := BaseEvent.new()
		ev.name = "石壕吏"
		ev.description = "暮投石壕村，有吏夜捉人。老翁逾墙走，老妇出门看。"
		ev.example = "758年 陕州"

		var opt := EventOption.new()
		opt.description = "在墙角默默记录"
		ev.options = [opt]

		v0.apply_narrative(ev, {})

	# -------------------------------------------------------------------------
	# Case 1: 单选项事件 — 安史之乱
	# -------------------------------------------------------------------------
	var v1 = map.get('1')
	if is_instance_valid(v1) and v1.has_method("apply_narrative"):
		var ev := BaseEvent.new()
		ev.name = "安史之乱"
		ev.description = "渔阳鼙鼓动地来，惊破霓裳羽衣曲。安禄山在范阳起兵，直指洛阳。"
		ev.example = "755年 范阳"

		var opt := EventOption.new()
		opt.description = "我知道了"
		ev.options = [opt]

		v1.apply_narrative(ev, {})

	# -------------------------------------------------------------------------
	# Case 2: 多选项事件 — 马嵬坡之变
	# -------------------------------------------------------------------------
	var v2 = map.get('2')
	if is_instance_valid(v2) and v2.has_method("apply_narrative"):
		var ev := BaseEvent.new()
		ev.name = "马嵬坡之变"
		ev.description = "六军不发无奈何，宛转蛾眉马前死。禁军要求处死杨贵妃，否则拒绝开拔。"
		ev.example = "756年 马嵬驿"

		var opt1 := EventOption.new()
		opt1.description = "赐死杨玉环"

		var opt2 := EventOption.new()
		opt2.description = "坚决保住她"

		ev.options = [opt1, opt2]

		v2.apply_narrative(ev, {})

	# -------------------------------------------------------------------------
	# Case 3: 单选项事件 — 收复长安
	# -------------------------------------------------------------------------
	var v3 = map.get('3')
	if is_instance_valid(v3) and v3.has_method("apply_narrative"):
		var ev := BaseEvent.new()
		ev.name = "收复长安"
		ev.description = "剑外忽传收蓟北，初闻涕泪满衣裳。官军已收复京师！"
		ev.example = "757年 长安"

		var opt := EventOption.new()
		opt.description = "漫卷诗书喜欲狂"
		ev.options = [opt]

		v3.apply_narrative(ev, {})


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('测试纸带模式 (石壕/安史/马嵬/收复)', test_narrative_scenarios)
	]
