extends Control
class_name IdeaPage

## IdeaPage — 理念总览页
##
## 全屏覆盖页面，三栏布局：
##   左栏：5 个槽位（已解锁理念名称列表）+ InfoContainer（令牌状态）
##   中栏：选中理念的详情（名称 + 效果描述 + 升级按钮）
##   右栏：候选理念池（IdeaBtn，含冲突检测）
##
## 动画逻辑 1:1 镜像 SocialConnectionPage。
##
## 令牌系统（替代旧的 idea_cost_name/idea_cost_amount 直接扣属性）：
##   势 (momentum) 累积 ≥ 阈值 [10, 40, 90, 180] → 势令牌池
##   望 (prestige)  累积 ≥ 阈值 [10, 40, 90, 180] → 望令牌池
##   可用令牌 = 属性达标阈值数 - GameSave.data.used_*_tokens
##   解锁/升级时消耗对应池的 1 令牌，idea_cost_name 决定归属池。

const _IdeaBtn := preload("res://ui/idea_btn.tscn")

# ── 令牌阈值（势和望共用）──
const TOKEN_THRESHOLDS: Array[int] = [10, 40, 90, 180]

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

# 左栏：InfoContainer 令牌状态标签
@onready var _label_shi_left: Label = $PanelContainer/HBoxContainer/VBoxContainer/InfoContainer/ShiLeft
@onready var _label_shi_target: Label = $PanelContainer/HBoxContainer/VBoxContainer/InfoContainer/ShiTarget
@onready var _label_wang_left: Label = $PanelContainer/HBoxContainer/VBoxContainer/InfoContainer/WangLeft
@onready var _label_wang_target: Label = $PanelContainer/HBoxContainer/VBoxContainer/InfoContainer/WangTarget

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
# 令牌池计算（静态工具方法）
# ═══════════════════════════════════════════════════════════

## 计算势令牌池：当前可用令牌数
static func get_available_momentum_tokens() -> int:
	var val: int = PlayerState.get_stat_val("momentum") if PlayerState else 0
	var crossed := 0
	for th in TOKEN_THRESHOLDS:
		if val >= th:
			crossed += 1
		else:
			break
	var used: int = GameSave.data.used_momentum_tokens if GameSave and GameSave.data else 0
	return max(0, crossed - used)

## 计算望令牌池：当前可用令牌数
static func get_available_prestige_tokens() -> int:
	var val: int = PlayerState.get_stat_val("prestige") if PlayerState else 0
	var crossed := 0
	for th in TOKEN_THRESHOLDS:
		if val >= th:
			crossed += 1
		else:
			break
	var used: int = GameSave.data.used_prestige_tokens if GameSave and GameSave.data else 0
	return max(0, crossed - used)

## 根据 idea_cost_name 获取对应池的可用令牌
static func get_available_tokens_for_idea(idea: Idea) -> int:
	if not idea:
		return 0
	match idea.idea_cost_name:
		"momentum":
			return get_available_momentum_tokens()
		"prestige":
			return get_available_prestige_tokens()
		_:
			Logging.warn("[IdeaPage] 未知令牌池: idea_cost_name='%s' (idea=%s)" % [idea.idea_cost_name, idea.uuid])
			return 0

## 获取下一未达阈值（用于显示"下一里程碑"）
static func get_next_threshold(val: int) -> int:
	for th in TOKEN_THRESHOLDS:
		if val < th:
			return th
	return -1

## 消耗令牌：根据 idea_cost_name 决定消耗哪个池
static func consume_token(idea: Idea) -> bool:
	if not idea:
		Logging.err("[IdeaPage] consume_token: idea 为 null")
		return false
	match idea.idea_cost_name:
		"momentum":
			if get_available_momentum_tokens() <= 0:
				Logging.warn("[IdeaPage] consume_token: 势令牌不足")
				return false
			GameSave.data.used_momentum_tokens += 1
			Logging.info("[IdeaPage] consume_token: 消耗势令牌, used_momentum_tokens=%d" % GameSave.data.used_momentum_tokens)
			return true
		"prestige":
			if get_available_prestige_tokens() <= 0:
				Logging.warn("[IdeaPage] consume_token: 望令牌不足")
				return false
			GameSave.data.used_prestige_tokens += 1
			Logging.info("[IdeaPage] consume_token: 消耗望令牌, used_prestige_tokens=%d" % GameSave.data.used_prestige_tokens)
			return true
		_:
			Logging.err("[IdeaPage] consume_token: 未知令牌池 idea_cost_name='%s'" % idea.idea_cost_name)
			return false


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

	# 连接 stat change 信号 → 势/望变化时刷新 InfoContainer
	if not PlayerState.player_stat_changed.is_connected(_on_stat_changed):
		PlayerState.player_stat_changed.connect(_on_stat_changed)
		Logging.info("[IdeaPage] 已连接 PlayerState.player_stat_changed")

	# 令牌消耗后刷新 InfoContainer
	if not EventBus.idea_upgraded.is_connected(_on_idea_upgraded_refresh):
		EventBus.idea_upgraded.connect(_on_idea_upgraded_refresh)
		Logging.info("[IdeaPage] 已连接 EventBus.idea_upgraded")

	Logging.info("[IdeaPage] _ready 完成")


# ═══════════════════════════════════════════════════════════
# 信号回调
# ═══════════════════════════════════════════════════════════

func _on_stat_changed(prop_name: String) -> void:
	if prop_name == "momentum" or prop_name == "prestige":
		Logging.info("[IdeaPage] _on_stat_changed: prop=%s, 刷新 InfoContainer" % prop_name)
		_refresh_info_labels()

func _on_idea_upgraded_refresh() -> void:
	Logging.info("[IdeaPage] _on_idea_upgraded_refresh: 令牌消耗后刷新")
	_refresh_info_labels()


# ═══════════════════════════════════════════════════════════
# InfoContainer 动态刷新
# ═══════════════════════════════════════════════════════════

func _refresh_info_labels() -> void:
	var momentum_val: int = PlayerState.get_stat_val("momentum")
	var prestige_val: int = PlayerState.get_stat_val("prestige")

	var shi_avail: int = get_available_momentum_tokens()
	var wang_avail: int = get_available_prestige_tokens()

	# ── 势行 ──
	_label_shi_left.text = "势: %d ｜ 可用令牌: %d" % [momentum_val, shi_avail]
	_label_shi_target.text = _format_threshold_bar(momentum_val)

	# ── 望行 ──
	_label_wang_left.text = "望: %d ｜ 可用令牌: %d" % [prestige_val, wang_avail]
	_label_wang_target.text = _format_threshold_bar(prestige_val)

	Logging.info("[IdeaPage] _refresh_info_labels: 势=%d(令牌%d) 望=%d(令牌%d)" % [momentum_val, shi_avail, prestige_val, wang_avail])


func _format_threshold_bar(val: int) -> String:
	var parts: Array[String] = []
	for th in TOKEN_THRESHOLDS:
		if val >= th:
			parts.append("%d✅" % th)
		else:
			parts.append("%d🔒" % th)
	return "  ".join(parts)


# ═══════════════════════════════════════════════════════════
# 数据刷新（每次 show_page 或获得新理念时调用）
# ═══════════════════════════════════════════════════════════

func refresh_all() -> void:
	Logging.info("[IdeaPage] refresh_all")

	_refresh_info_labels()
	_refresh_slot_buttons()
	_refresh_candidate_pool()

	# 如果当前选中的理念不再有效（如被移除），清空选择
	if _selected_idea_uuid.is_empty() or not _is_idea_available(_selected_idea_uuid):
		_selected_idea_uuid = ""
	_show_detail_for_selected()


func _refresh_slot_buttons() -> void:
	var unlocked: Array[String] = GameSave.data.current_unlock_ideas

	for i in range(_slot_btns.size()):
		var btn := _slot_btns[i]
		if i < unlocked.size():
			var idea = Database.get_idea(unlocked[i])
			if idea:
				btn.text = tr(idea.name) if not idea.name.is_empty() else idea.uuid
				btn.disabled = false
			else:
				btn.text = tr("CODE_IDEA_PAGE_90A49E5099")
				btn.disabled = true
		else:
			btn.text = tr("UI_IDEA_PAGE_TEXT_5")
			btn.disabled = true


func _refresh_candidate_pool() -> void:
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
		_candidate_hint.text = tr("CODE_IDEA_PAGE_0127C5A788")
	else:
		_candidate_hint.text = tr("UI_IDEA_PAGE_TEXT_8")


func _describe_counter(idea: Idea) -> String:
	if idea.counter_idea.is_empty():
		return ""
	var counter = Database.get_idea(idea.counter_idea)
	if counter:
		return tr("CODE_IDEA_PAGE_A440FE94DB") % (tr(counter.name) if not counter.name.is_empty() else counter.uuid)
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
			return tr("CODE_IDEA_PAGE_811A80B78E") % [tr(unlocked_idea.name) if not unlocked_idea.name.is_empty() else unlocked_idea.uuid, tr(idea.name) if not idea.name.is_empty() else idea.uuid]
		# 反向：已解锁理念的 counter_idea == 候选理念的 uuid
		if not unlocked_idea.counter_idea.is_empty() and unlocked_idea.counter_idea == idea.uuid:
			return tr("CODE_IDEA_PAGE_811A80B78E") % [tr(unlocked_idea.name) if not unlocked_idea.name.is_empty() else unlocked_idea.uuid, tr(idea.name) if not idea.name.is_empty() else idea.uuid]

	return ""


func _on_slot_pressed(index: int) -> void:
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
	if _selected_idea_uuid.is_empty():
		_detail_title.text = tr("UI_IDEA_PAGE_TEXT_7")
		_clear_effect_lines()
		_upgrade_btn.text = ""
		_upgrade_btn.disabled = true
		return

	var idea = Database.get_idea(_selected_idea_uuid)
	if not idea:
		_detail_title.text = tr("CODE_IDEA_PAGE_7705E3690F")
		_clear_effect_lines()
		_upgrade_btn.text = ""
		_upgrade_btn.disabled = true
		return

	# 标题：理念名称
	var owner_text := tr(idea.name) if not idea.name.is_empty() else tr("CODE_IDEA_PAGE_099E3CCA8A")
	_detail_title.text = owner_text

	# 效果描述：遍历 idea_demonstrations 显示已解锁/未解锁的条
	_clear_effect_lines()
	for i in range(idea.idea_demonstrations.size()):
		var is_unlocked = i <= idea.current_idea_level
		var line := Label.new()
		line.theme_type_variation = &"DefaultText"
		if is_unlocked:
			line.text = "✅ " + tr(idea.idea_demonstrations[i])
		else:
			line.text = "🔒 " + tr(idea.idea_demonstrations[i])
		_detail_effects_container.add_child(line)

	# ── 升级/获取按钮（令牌驱动） ──
	_upgrade_btn.disabled = false
	var is_owned := GameSave.data.current_unlock_ideas.has(idea.uuid)
	var token_pool_name := _get_pool_display_name(idea)
	var available := get_available_tokens_for_idea(idea)

	if not is_owned:
		# 未拥有：获取入口（加入槽位 → level -1 → 自动升到 0）
		_upgrade_btn.text = "获取「%s」（消耗 1 %s令牌）" % [tr(idea.name) if not idea.name.is_empty() else idea.uuid, token_pool_name]
		if available <= 0:
			_upgrade_btn.text += " — %s令牌不足" % token_pool_name
			_upgrade_btn.disabled = true
	else:
		var next_level = idea.current_idea_level + 1
		if next_level >= idea.idea_buffs.size():
			# 已满级
			_upgrade_btn.text = "已满级"
			_upgrade_btn.disabled = true
		else:
			_upgrade_btn.text = "升级至 Lv.%d（消耗 1 %s令牌）" % [next_level + 1, token_pool_name]
			if available <= 0:
				_upgrade_btn.text += " — %s令牌不足" % token_pool_name
				_upgrade_btn.disabled = true


func _on_upgrade_pressed() -> void:
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

	# 校验令牌
	var available := get_available_tokens_for_idea(idea)
	if available <= 0:
		Logging.warn("[IdeaPage] 令牌不足：%s 池无可用令牌" % idea.idea_cost_name)
		_show_detail_for_selected()
		return

	# 消耗令牌
	if not consume_token(idea):
		Logging.err("[IdeaPage] consume_token 失败，取消升级")
		return

	if not is_owned:
		# 获取：加入槽位
		if GameSave.data.current_unlock_ideas.size() >= 5:
			Logging.warn("[IdeaPage] 槽位已满（5/5），无法获取新理念")
			# 退还令牌
			_undo_token_consume(idea)
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
	
	EventBus.idea_upgraded.emit()


## 退还令牌（槽位满等异常情况）
func _undo_token_consume(idea: Idea) -> void:
	if not idea:
		return
	match idea.idea_cost_name:
		"momentum":
			GameSave.data.used_momentum_tokens = max(0, GameSave.data.used_momentum_tokens - 1)
			Logging.info("[IdeaPage] _undo_token_consume: 退还势令牌, used_momentum_tokens=%d" % GameSave.data.used_momentum_tokens)
		"prestige":
			GameSave.data.used_prestige_tokens = max(0, GameSave.data.used_prestige_tokens - 1)
			Logging.info("[IdeaPage] _undo_token_consume: 退还望令牌, used_prestige_tokens=%d" % GameSave.data.used_prestige_tokens)


## 返回令牌池的界面展示名称
func _get_pool_display_name(idea: Idea) -> String:
	match idea.idea_cost_name:
		"momentum":
			return "势"
		"prestige":
			return "望"
		_:
			Logging.warn("[IdeaPage] _get_pool_display_name: 未知 cost_name='%s'" % idea.idea_cost_name)
			return "?"


func _clear_effect_lines() -> void:
	for child in _detail_effects_container.get_children():
		child.queue_free()


func _is_idea_available(uuid: String) -> bool:
	if GameSave.data.current_unlock_ideas.has(uuid):
		return true
	if Database.ideas.has(uuid):
		return true
	return false


func _on_idea_data_changed() -> void:
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
	EventBus.idea_page_close.emit()
