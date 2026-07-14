extends Control
class_name IdeaPage

## IdeaPage — 理念总览页
##
## 全屏覆盖页面，三栏布局：
##   左栏：5 个槽位（已解锁理念名称列表）
##   中栏：选中理念的详情（名称 + 效果描述 + 升级按钮）
##   右栏：候选理念池（IdeaBtn，含冲突检测）
##
## 动画逻辑 1:1 镜像 SocialConnectionPage。

const _IdeaBtn := preload("res://ui/idea_btn.tscn")

# ── 当前选中状态 ──
var _selected_idea_uuid: String = ""

# ── Onready 节点引用 ──
@onready var _btn_close: Button = $PanelContainer/Button

# 左栏：5 个槽位 LinkButton
@onready var _slot_btn_1: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer/LinkButton
@onready var _slot_btn_2: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer/LinkButton2
@onready var _slot_btn_3: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer/LinkButton3
@onready var _slot_btn_4: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer/LinkButton4
@onready var _slot_btn_5: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer/LinkButton5
var _slot_btns: Array[LinkButton] = []

# 中栏：详情面板
@onready var _detail_title: Label = $PanelContainer/HBoxContainer/VBoxContainer2/Label
@onready var _detail_effects_container: VBoxContainer = $PanelContainer/HBoxContainer/VBoxContainer2/EffectsContainer
@onready var _upgrade_btn: LinkButton = $PanelContainer/HBoxContainer/VBoxContainer2/LinkButton4

# 右栏：候选容器（动态填充 IdeaBtn）
@onready var _candidate_container: VBoxContainer = $PanelContainer/HBoxContainer/VBoxContainer3/CandidateContainer
@onready var _candidate_hint: Label = $PanelContainer/HBoxContainer/VBoxContainer3/Label2


# ═══════════════════════════════════════════════════════════
# 页面开关状态 + 动画
# ═══════════════════════════════════════════════════════════

var expand := false
var _page_tween: Tween = null
var _original_offsets: Dictionary = {}


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	Logging.info("[IdeaPage] _ready 开始")

	_slot_btns = [_slot_btn_1, _slot_btn_2, _slot_btn_3, _slot_btn_4, _slot_btn_5]

	# 保存原始 offset 供 hide 后恢复
	_original_offsets = {
		"left": offset_left,
		"top": offset_top,
		"right": offset_right,
		"bottom": offset_bottom,
	}

	hide()
	EventBus.idea_page_toggled.connect(func():
		if not expand:
			show_page()
		else:
			hide_page()
	)

	# 右上角 X 按钮 → 关闭页面
	_btn_close.pressed.connect(hide_page)

	# 槽位按钮点击 → 选中对应理念
	for i in range(_slot_btns.size()):
		_slot_btns[i].pressed.connect(_on_slot_pressed.bind(i))

	# 升级按钮点击
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)

	Logging.info("[IdeaPage] _ready 完成")


# ═══════════════════════════════════════════════════════════
# 数据刷新（每次 show_page 或获得新理念时调用）
# ═══════════════════════════════════════════════════════════

func refresh_all() -> void:
	"""刷新所有栏位的数据"""
	Logging.info("[IdeaPage] refresh_all")

	_refresh_slot_buttons()
	_refresh_candidate_pool()

	# 如果当前选中的理念不再有效（如被移除），清空选择
	if _selected_idea_uuid.is_empty() or not _is_idea_available(_selected_idea_uuid):
		_selected_idea_uuid = ""
	_show_detail_for_selected()


func _refresh_slot_buttons() -> void:
	"""刷新左栏 5 个槽位（已解锁理念）"""
	var unlocked: Array[String] = GameSave.data.current_unlock_ideas

	for i in range(_slot_btns.size()):
		var btn := _slot_btns[i]
		if i < unlocked.size():
			var idea = Database.get_idea(unlocked[i])
			if idea:
				btn.text = idea.name if not idea.name.is_empty() else idea.uuid
				btn.disabled = false
			else:
				btn.text = "（未知）"
				btn.disabled = true
		else:
			btn.text = "空槽位"
			btn.disabled = true


func _refresh_candidate_pool() -> void:
	"""刷新右栏候选理念池（Database.ideas - 已解锁 - 冲突检测）"""
	Logging.info("[IdeaPage] _refresh_candidate_pool: Database.ideas=%s" % str(Database.ideas.keys()))
	# 清除旧的 IdeaBtn
	for child in _candidate_container.get_children():
		child.queue_free()

	var unlocked: Array[String] = GameSave.data.current_unlock_ideas
	var all_ideas: Dictionary = Database.ideas
	Logging.info("[IdeaPage] _refresh_candidate_pool: Database.ideas 共 %d 个条目, unlocked=%s" % [all_ideas.size(), str(unlocked)])
	var any_available := false

	for uuid in all_ideas:
		var idea := all_ideas[uuid] as Idea
		Logging.info("[IdeaPage] _refresh_candidate_pool: 检查理念 uuid=%s, idea=%s" % [uuid, str(idea)])
		if not idea:
			Logging.info("[IdeaPage] _refresh_candidate_pool: 跳过 null idea uuid=%s" % uuid)
			continue

		# 如果已解锁，跳过
		if uuid in unlocked:
			continue

		# 冲突检测
		var conflict_reason := _check_conflict(idea, unlocked)

		# 即使无冲突，也显示潜在互斥关系（counter_idea 指向谁）
		var display_reason := conflict_reason
		if display_reason.is_empty():
			display_reason = _describe_counter(idea)

		var btn_instance := _IdeaBtn.instantiate() as IdeaBtn
		_candidate_container.add_child(btn_instance)

		var is_locked := not conflict_reason.is_empty()
		btn_instance.set_idea(idea, is_locked, display_reason)

		if not is_locked:
			any_available = true
			btn_instance.pressed.connect(_on_candidate_pressed.bind(uuid))

	if not any_available:
		_candidate_hint.text = "暂无可用理念"
	else:
		_candidate_hint.text = "点击选择理念"


func _describe_counter(idea: Idea) -> String:
	"""描述理念的 counter_idea 关系（无冲突时显示潜在互斥）"""
	if idea.counter_idea.is_empty():
		return ""
	var counter = Database.get_idea(idea.counter_idea)
	if counter:
		return "与「%s」互斥" % (counter.name if not counter.name.is_empty() else counter.uuid)
	return ""


func _check_conflict(idea: Idea, unlocked: Array[String]) -> String:
	"""检查 idea 是否与已解锁理念冲突，返回冲突原因字符串（空=无冲突）
	
	双向检测：
	  1. 候选理念的 counter_idea 指向已解锁理念（正向）
	  2. 已解锁理念的 counter_idea 指向候选理念（反向）
	"""
	for unlocked_uuid in unlocked:
		var unlocked_idea = Database.get_idea(unlocked_uuid)
		if not unlocked_idea:
			continue
		# 正向：候选的 counter_idea == 已解锁理念的 uuid
		if not idea.counter_idea.is_empty() and unlocked_idea.uuid == idea.counter_idea:
			return "%s：与「%s」冲突" % [unlocked_idea.name if not unlocked_idea.name.is_empty() else unlocked_idea.uuid, idea.name if not idea.name.is_empty() else idea.uuid]
		# 反向：已解锁理念的 counter_idea == 候选理念的 uuid
		if not unlocked_idea.counter_idea.is_empty() and unlocked_idea.counter_idea == idea.uuid:
			return "%s：与「%s」冲突" % [unlocked_idea.name if not unlocked_idea.name.is_empty() else unlocked_idea.uuid, idea.name if not idea.name.is_empty() else idea.uuid]

	return ""


func _on_slot_pressed(index: int) -> void:
	"""左栏槽位点击：选中已解锁理念"""
	var unlocked: Array[String] = GameSave.data.current_unlock_ideas
	if index < unlocked.size():
		_selected_idea_uuid = unlocked[index]
		_show_detail_for_selected()


func _on_candidate_pressed(uuid: String) -> void:
	"""右栏候选理念点击：选中候选理念（会自动解锁？还是单纯展示？）
	   此处仅为选中展示，解锁逻辑由中栏升级按钮处理"""
	_selected_idea_uuid = uuid
	_show_detail_for_selected()


func _show_detail_for_selected() -> void:
	"""根据 _selected_idea_uuid 填充中栏详情"""
	if _selected_idea_uuid.is_empty():
		_detail_title.text = "选择一个理念"
		_clear_effect_lines()
		_upgrade_btn.text = ""
		_upgrade_btn.disabled = true
		return

	var idea = Database.get_idea(_selected_idea_uuid)
	if not idea:
		_detail_title.text = "（理念未找到）"
		_clear_effect_lines()
		_upgrade_btn.text = ""
		_upgrade_btn.disabled = true
		return

	# 标题：理念名称
	var owner_text := ""
	if GameSave.data.current_unlock_ideas.has(idea.uuid):
		owner_text = idea.name if not idea.name.is_empty() else "未知理念"
	else:
		owner_text = idea.name if not idea.name.is_empty() else "未知理念"
	_detail_title.text = owner_text

	# 效果描述：遍历 idea_demonstrations 显示已解锁/未解锁的条
	_clear_effect_lines()
	for i in range(idea.idea_demonstrations.size()):
		var is_unlocked = i <= idea.current_idea_level
		var line := Label.new()
		line.theme_type_variation = &"DefaultText"
		if is_unlocked:
			line.text = "✅ " + idea.idea_demonstrations[i]
		else:
			line.text = "🔒 " + idea.idea_demonstrations[i]
		_detail_effects_container.add_child(line)

	# 升级/获取按钮
	_upgrade_btn.disabled = false
	var cost_name = idea.idea_cost_name
	var cost_amount = idea.idea_cost_amount
	var current_val = PlayerState.get_stat_val(cost_name)

	# 是否已拥有此理念
	var is_owned := GameSave.data.current_unlock_ideas.has(idea.uuid)

	if not is_owned:
		# 未拥有：获取入口（加入槽位 → level -1 → 自动升到 0）
		_upgrade_btn.text = "获取「%s」？消耗 %d点%s" % [idea.name if not idea.name.is_empty() else idea.uuid, cost_amount, cost_name]
		if current_val < cost_amount:
			_upgrade_btn.text += "（不足）"
			_upgrade_btn.disabled = true
	else:
		var next_level = idea.current_idea_level + 1
		if next_level >= idea.idea_buffs.size():
			# 已满级
			_upgrade_btn.text = "已满级"
			_upgrade_btn.disabled = true
		else:
			_upgrade_btn.text = "解锁效果%d？消耗 %d点%s" % [next_level + 1, cost_amount, cost_name]
			if current_val < cost_amount:
				_upgrade_btn.text += "（不足）"
				_upgrade_btn.disabled = true


func _on_upgrade_pressed() -> void:
	"""升级/获取按钮点击：消耗资源 + 加入槽位/提升理念等级"""
	if _selected_idea_uuid.is_empty():
		return

	var idea = Database.get_idea(_selected_idea_uuid)
	if not idea:
		return

	var is_owned := GameSave.data.current_unlock_ideas.has(idea.uuid)

	# 校验冲突（获取时）：候选与已解锁互斥则拒绝
	if not is_owned:
		var conflict := _check_conflict(idea, GameSave.data.current_unlock_ideas)
		if not conflict.is_empty():
			Logging.warn("[IdeaPage] 冲突，无法获取理念 '%s'：%s" % [idea.name, conflict])
			return

	# 校验资源
	var cost_name = idea.idea_cost_name
	var cost_amount = idea.idea_cost_amount
	var current_val = PlayerState.get_stat_val(cost_name)
	if current_val < cost_amount:
		Logging.warn("[IdeaPage] 资源不足：%s=%d < %d" % [cost_name, current_val, cost_amount])
		_show_detail_for_selected()
		return

	# 扣资源
	PlayerState.append_stat(cost_name, -cost_amount)

	if not is_owned:
		# 获取：加入槽位
		if GameSave.data.current_unlock_ideas.size() >= 5:
			Logging.warn("[IdeaPage] 槽位已满（5/5），无法获取新理念")
			# 退还资源
			PlayerState.append_stat(cost_name, cost_amount)
			return
		GameSave.data.current_unlock_ideas.append(idea.uuid)
		Logging.info("[IdeaPage] 获取理念 '%s'，加入槽位" % idea.name)
		# 自动升到 level 0
		idea.increase_idea_level()
		# 刷新全部
		refresh_all()
	else:
		# 升级
		idea.increase_idea_level()
		Logging.info("[IdeaPage] 理念 '%s' 升级至等级 %d" % [idea.name, idea.current_idea_level])
		_show_detail_for_selected()


func _clear_effect_lines() -> void:
	"""清除效果列所有 Label（保留 EffectsContainer 自身）"""
	for child in _detail_effects_container.get_children():
		child.queue_free()


func _is_idea_available(uuid: String) -> bool:
	"""检查理念是否仍然可访问（在已解锁或 Database 中）"""
	if GameSave.data.current_unlock_ideas.has(uuid):
		return true
	if Database.ideas.has(uuid):
		return true
	return false


func _on_idea_data_changed() -> void:
	"""外部调用：当获得新理念或理念数据变化时刷新页面"""
	refresh_all()


# ═══════════════════════════════════════════════════════════
# 页面动画 — show / hide（镜像 SocialConnectionPage）
# ═══════════════════════════════════════════════════════════

func show_page() -> void:
	if expand:
		return
	expand = true

	Logging.info("IdeaPage: show_page 开始 — 全屏模糊 → 面板滑出 → 展示")

	# 打开时刷新数据
	refresh_all()

	# 隐藏纸带（引用计数递增）
	EventBus.narrative_tape_hide_requested.emit()

	# 1. 全屏模糊（幕布）
	BlurManager.show_cinematic_blur()
	await get_tree().create_timer(0.5).timeout

	# 2. 左右面板滑出
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_out"):
		main.slide_panels_out()
	else:
		Logging.warn("IdeaPage: Main.slide_panels_out 不可用")
	await get_tree().create_timer(0.65).timeout

	# 3. 取消全屏模糊，切换为地图模糊
	BlurManager.hide_cinematic_blur()
	BlurManager.trigger_event_blur()

	# 4. 展示页面 — 先恢复原始 offset（防止 hide 动画污染）
	if not _original_offsets.is_empty():
		offset_left = _original_offsets.get("left", offset_left)
		offset_top = _original_offsets.get("top", offset_top)
		offset_right = _original_offsets.get("right", offset_right)
		offset_bottom = _original_offsets.get("bottom", offset_bottom)
		Logging.info("IdeaPage: restored original offsets: %s" % _original_offsets)
	show()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished

	Logging.info("IdeaPage: show_page 完成")


func hide_page() -> void:
	if not expand:
		return
	expand = false
	Logging.info("IdeaPage: hide_page 开始")

	# 恢复纸带（引用计数递减）
	EventBus.narrative_tape_show_requested.emit()

	# 1. 取消地图模糊
	BlurManager.return_to_hub()

	# 2. 面板滑回
	var main := get_tree().root.get_node("Main") as Node
	if main and main.has_method("slide_panels_in"):
		main.slide_panels_in()

	# 3. 隐藏页面
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(self, "size", Vector2(103, 47), 0.5)
	_page_tween.tween_property(self, "position", Vector2(520, 565), 0.5)
	_page_tween.tween_callback(func():
		hide()
	)

	Logging.info("IdeaPage: hide_page 完成")
