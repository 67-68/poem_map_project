class_name SceneActionPanel extends Button
## 纯 UI 渲染基类 — 行动/决议按钮的通用展示层
##
## 保留：展示（title / outcome / icon）、hover popup、锁定/灰化/deferring 视觉、闪光动画
## 删除：所有 pending_* 字段、sub-action picker 管线、cost / possibility / scan_events 执行逻辑
## 新增：_on_clicked() 虚方法 — 子类覆写实现具体点击行为
##
## 子类：
##   MainActionButton  — 父行动完整执行管线
##   SubActionButton   — Toggle Mode 选择器
##   NpcActionButton   — 确认执行按钮
##   基类直接使用       — Decision（通过 action_button.tscn）

signal clicked_with_action(action: Action)  ## 通用点击信号（子类可用）

@export var action: Action

## 锁定闪光 Tween 引用（用于清除旧闪光）
var _flash_tween: Tween = null

## 当前是否处于灰化锁定状态（硬锁：不可点击）
var _is_locked: bool = false

## 当前是否处于软锁定状态（灰化但可点击，如所有子行动 GRAY）
var _is_soft_locked: bool = false

## 当前是否处于 deferring 状态（淡蓝或淡红）
var _is_deferring: bool = false

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

# ── Defer 视觉颜色 ──
const DEFERRING_COLOR: Color = Color(0.5, 0.6, 1.0, 0.85)      # 淡蓝 — defer 进行中
const DEFER_FAILING_COLOR: Color = Color(1.0, 0.5, 0.5, 0.85)  # 淡红 — 资源不足

func _init() -> void:
	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = HOVER_BG_COLOR
	_normal_style = StyleBoxEmpty.new()


func initialize(action_: Action = null):
	if action_:
		action = action_
		# 使用 $ 内联访问而非 @onready，因为 initialize 可能在 _ready 之前调用
		$Panel/HBoxContainer/VBoxContainer/Title.text = tr(action.name)
		$Panel/HBoxContainer/VBoxContainer/Outcome.text = tr(action.description)
		
		# ── 图标：有数据则显示，无数据则隐藏 ──
		if action.icon:
			$Panel/HBoxContainer/TextureRect.texture = action.icon
			$Panel/HBoxContainer/TextureRect.visible = true
		else:
			$Panel/HBoxContainer/TextureRect.visible = false
	else:
		Logging.err('there\'s no action input in the init of scene action panel!!!')
		return
	
	# ── 点击：委托虚方法 _on_clicked ──
	pressed.connect(_on_button_pressed)
	
	# ── 锁定闪光（仅 SceneAction 有 main_tag 可匹配）──
	if action is SceneAction:
		EventBus.locked_actions_selected.connect(_on_locked_actions_selected)
	
	# ── Hover 底色绑定 ──
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# ── Hover Popup（Alt 双层揭示）──
	if not action.description.is_empty() or not action.action_results.is_empty() or not action.aciton_requirements.is_empty() or action.get_possibility_int() < 100 or (action.failed_result and not action.failed_result.operators.is_empty()):
		_register_hover_popup()
	
	Logging.info("SceneActionPanel.initialize: action='%s' type=%s" % [action.name, action.get_class()])


## 差分更新：只刷 UI 文本/图标，不重建信号 & HoverPopup（已注册的 popup 绑定不变）
func update_action(new_action: Action) -> void:
	action = new_action
	$Panel/HBoxContainer/VBoxContainer/Title.text = tr(new_action.name)
	$Panel/HBoxContainer/VBoxContainer/Outcome.text = tr(new_action.description)
	
	# ── 图标：有数据则显示，无数据则隐藏 ──
	if new_action.icon:
		$Panel/HBoxContainer/TextureRect.texture = new_action.icon
		$Panel/HBoxContainer/TextureRect.visible = true
	else:
		$Panel/HBoxContainer/TextureRect.visible = false


## 设置为灰化锁定态（硬锁：不可点击）
func set_locked(reason: String) -> void:
	_is_locked = true
	_is_soft_locked = false
	_is_deferring = false
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()
	Logging.info("SceneActionPanel.set_locked: action='%s' reason='%s'" % [action.name if action else "null", reason])


## 设置为软锁定态（灰化但可点击，如所有子行动 GRAY）
func set_soft_locked(reason: String) -> void:
	_is_soft_locked = true
	_is_locked = false
	_is_deferring = false
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()
	Logging.info("SceneActionPanel.set_soft_locked: action='%s' reason='%s'" % [action.name if action else "null", reason])


## 解除灰化锁定态（包括硬锁和软锁）
func set_unlocked() -> void:
	_is_locked = false
	_is_soft_locked = false
	_is_deferring = false
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()
	Logging.info("SceneActionPanel.set_unlocked: action='%s'" % (action.name if action else "null"))


## 设置为 deferring 状态（淡蓝色 — 进行中，可点击取消）
func set_deferring() -> void:
	_is_deferring = true
	# 视觉优先级：红 > 灰 > 蓝 > 白
	# 如果已经被灰化锁定（硬锁或软锁），不覆盖
	if _is_locked or _is_soft_locked:
		return
	modulate = DEFERRING_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()
	Logging.info("SceneActionPanel.set_deferring: action='%s'" % (action.name if action else "null"))


## 设置为 defer 资源不足状态（淡红色 — 点击取消或等待自灭）
func set_defer_failing() -> void:
	_is_deferring = true
	# 红色是最高优先级，即使灰化也能覆盖
	modulate = DEFER_FAILING_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()
	Logging.info("SceneActionPanel.set_defer_failing: action='%s'" % (action.name if action else "null"))


## 监听锁定行动信号，匹配当前 action 时触发呼吸闪光
func _on_locked_actions_selected(locked_actions: Array) -> void:
	if not action:
		return
	for locked_action in locked_actions:
		if not locked_action is SceneAction:
			continue
		# 通过 main_tag 前缀匹配
		if locked_action.main_tag == action.main_tag:
			_start_flash()
			return


## 呼吸闪光：亮黄 ↔ 白，循环 4 次，每步 0.4s
func _start_flash() -> void:
	# 清除已有闪光 tween
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_loops(4)
	_flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 0.6), 0.4)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.4)


## 创建/重建 hover 数据，注入叙事文本 + 向量文本，注册到 HoverPopupManager（SLIDE_FROM_RIGHT 流）
## 硬锁和软锁都传 is_locked=true，让 hover 展示锁定原因。
func _register_hover_popup() -> void:
	if not action:
		Logging.warn("SceneActionPanel._register_hover_popup: action is null, skip")
		return
	
	var hint = ActionHintBuilder.new().build_action_hint(action, _is_locked or _is_soft_locked)
	
	HoverPopupManager.register(self, {"narrative": hint.narrative, "vector": hint.vector}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_RIGHT)
	Logging.info("SceneActionPanel._register_hover_popup: done for '%s' (SLIDE_FROM_RIGHT)" % action.name)


## 注销旧 popup 并重建（用于 set_locked / set_unlocked 后刷新 hover 内容）
func _refresh_hover_popup() -> void:
	if not action:
		Logging.warn("SceneActionPanel._refresh_hover_popup: action is null, skip")
		return
	HoverPopupManager.unregister(self)
	_register_hover_popup()
	Logging.info("SceneActionPanel._refresh_hover_popup: refreshed for '%s'" % action.name)


func _on_mouse_entered() -> void:
	if _hover_style and not _hover_style.bg_color == Color.TRANSPARENT:
		self.add_theme_stylebox_override("normal", _hover_style)


func _on_mouse_exited() -> void:
	self.add_theme_stylebox_override("normal", _normal_style)


## 统一按钮点击入口 — 处理 defer/lock/Decision 计数，委托 _on_clicked() 虚方法
func _on_button_pressed() -> void:
	# 行动开始时 dismiss 所有 hover
	HoverPopupManager.dismiss_all()
	
	# ── deferring 态 → 取消所有相关 defer，不继续执行 ──
	if _is_deferring and action:
		var defer_ids: Array[String] = []
		if ActionManager.is_deferring(action.uuid):
			defer_ids.append(action.uuid)
		for sub_uuid in action.sub_actions:
			if ActionManager.is_deferring(sub_uuid):
				defer_ids.append(sub_uuid)
		if not defer_ids.is_empty():
			for d_id in defer_ids:
				ActionManager.cancel_defer(d_id)
				Logging.info("SceneActionPanel: deferring 态点击 → 取消 defer id=%s" % d_id)
			EventBus.request_toast.emit(tr("CODE_ACTION_BUTTON_A3ED1BB61F"), 1)
			return
	
	# ── 软锁态 → 灰化但允许点击进入 picker（子行动 GRAY 在 picker 中显示）──
	if _is_soft_locked:
		Logging.info("SceneActionPanel: 软锁态点击透传进入 picker action=%s" % (action.uuid if action else "NULL"))
		# 不 return — 继续执行下方逻辑
	
	# ── 硬锁定态 → 弹出 toast，不执行 ──
	if _is_locked:
		var reason := action.dynamic_failed_hint if not action.dynamic_failed_hint.is_empty() else tr("CODE_NPC_ACTION_BUTTON_60ABF5AC4F")
		EventBus.request_toast.emit(reason, 1)
		Logging.info("SceneActionPanel: 锁定态点击被拦截 action=%s reason=%s" % [action.uuid if action else "NULL", reason])
		return
	
	# ── Decision 点击计数前置检查 ──
	if action is Decision and action.allowed_count >= 0:
		if action._times_clicked >= action.allowed_count:
			Logging.info("SceneActionPanel: Decision '%s' already at limit (clicked=%d, allowed=%d), skip execution" % [
				action.name, action._times_clicked, action.allowed_count
			])
			EventBus.decision_clicked.emit()
			return
		action.record_click()
		Logging.info("SceneActionPanel: Decision '%s' click %d/%d" % [action.name, action._times_clicked, action.allowed_count])
	
	# ── 委托子类实现 ──
	clicked_with_action.emit(action)
	_on_clicked()


## 虚方法 — 子类覆写以注入具体点击行为
func _on_clicked() -> void:
	Logging.info("SceneActionPanel._on_clicked: base class no-op for action='%s'" % (action.name if action else "null"))
	pass


## 从 current_action_tags 中提取 NPC 中文名（供 fallback 事件插值使用）
func _extract_npc_name_from_tags(tags: Array) -> String:
	for tag in tags:
		if tag.begins_with("actor:npc:"):
			var npc_tag = tag.trim_prefix("actor:npc:")
			if npc_tag.is_empty():
				continue
			var doc = Database.get_npc_document(npc_tag)
			if doc != null and not doc.name.is_empty():
				Logging.info("SceneActionPanel._extract_npc_name_from_tags: '%s' → '%s'" % [npc_tag, doc.name])
				return doc.name
			else:
				Logging.debug("SceneActionPanel._extract_npc_name_from_tags: '%s' 无中文名，回退到 tag" % npc_tag)
				return npc_tag
	return ""
