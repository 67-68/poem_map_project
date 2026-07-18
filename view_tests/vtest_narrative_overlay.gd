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
	if is_instance_valid(v0):
		var ev := BaseEvent.new()
		ev.name = tr("CODE_VTEST_NARRATIVE_OVERLAY_646CD3FFE7")
		ev.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_D2EFB8D7EF")
		ev.ui_decl = UIDecl.new()
		ev.ui_decl.example = tr("CODE_VTEST_NARRATIVE_OVERLAY_B727926D45")

		var opt := EventOption.new()
		opt.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_65F2DF86F1")
		ev.options = [opt]

		EventBus.request_event.emit(ev, {})

	# -------------------------------------------------------------------------
	# Case 1: 单选项事件 — 安史之乱
	# -------------------------------------------------------------------------
	var v1 = map.get('1')
	if is_instance_valid(v1):
		var ev := BaseEvent.new()
		ev.name = tr("CODE_VTEST_NARRATIVE_OVERLAY_83D5BE2253")
		ev.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_AE6DF29F62")
		ev.ui_decl = UIDecl.new()
		ev.ui_decl.example = tr("CODE_VTEST_NARRATIVE_OVERLAY_A0E36E4083")

		var opt := EventOption.new()
		opt.description = tr("TRES_TEST_INTERRUPT_TARGET_DESCRIPTION_0")
		ev.options = [opt]

		EventBus.request_event.emit(ev, {})

	# -------------------------------------------------------------------------
	# Case 2: 多选项事件 — 马嵬坡之变
	# -------------------------------------------------------------------------
	var v2 = map.get('2')
	if is_instance_valid(v2):
		var ev := BaseEvent.new()
		ev.name = tr("CODE_VTEST_NARRATIVE_OVERLAY_DCAFE4963D")
		ev.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_D090BECA34")
		ev.ui_decl = UIDecl.new()
		ev.ui_decl.example = tr("CODE_VTEST_NARRATIVE_OVERLAY_DB1CE346AF")

		var opt1 := EventOption.new()
		opt1.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_77CD91DEDE")

		var opt2 := EventOption.new()
		opt2.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_1A7BACE0E6")

		ev.options = [opt1, opt2]

		EventBus.request_event.emit(ev, {})

	# -------------------------------------------------------------------------
	# Case 3: 单选项事件 — 收复长安
	# -------------------------------------------------------------------------
	var v3 = map.get('3')
	if is_instance_valid(v3):
		var ev := BaseEvent.new()
		ev.name = tr("CODE_VTEST_NARRATIVE_OVERLAY_4EE29B8406")
		ev.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_45323DA6A8")
		ev.ui_decl = UIDecl.new()
		ev.ui_decl.example = tr("CODE_VTEST_NARRATIVE_OVERLAY_1C015818A6")

		var opt := EventOption.new()
		opt.description = tr("CODE_VTEST_NARRATIVE_OVERLAY_7369422DC5")
		ev.options = [opt]

		EventBus.request_event.emit(ev, {})


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('测试纸带模式 (石壕/安史/马嵬/收复)', test_narrative_scenarios)
	]
