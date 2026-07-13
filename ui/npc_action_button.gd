class_name NpcActionButton extends Button
## NPC 确认执行按钮 — Picker 右侧的确认按钮
##
## 点击时读取 VolatileState.action_state，若 selected_sub_action_uuid 非空 → SubActionExecutor.execute()
## 否则 toast 提示"请先选择一个行动"
##
## 不继承 SceneActionPanel 因为 npc_action_button.tscn 的内部结构不同（MarginContainer/VBoxContainer/...）
## 直接用 Button.text 展示标签

signal execution_completed(entity: GameEntity)  ## 执行完成后发射（Picker 用此信号关闭自身）


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	Logging.info("NpcActionButton._ready: 已连接 pressed 信号")


func _on_pressed() -> void:
	HoverPopupManager.dismiss_all()
	
	var selected_uuid := VolatileState.action_state.selected_sub_action_uuid
	Logging.info("NpcActionButton._on_pressed: selected_uuid='%s'" % selected_uuid)
	
	if selected_uuid.is_empty():
		EventBus.request_toast.emit("请先选择一个行动", 1)
		Logging.info("NpcActionButton: 未选择任何行动，toast 提示")
		return
	
	# ── 委托 SubActionExecutor 执行 ──
	SubActionExecutor.execute(selected_uuid, VolatileState.action_state)
	Logging.info("NpcActionButton: 已委托 SubActionExecutor.execute('%s')" % selected_uuid)
	
	# ── 发射执行完成信号（Picker 用此信号关闭自身）──
	var sub_action: Action = Database.get_action(selected_uuid) as Action
	var result_entity := GameEntity.new({"uuid": selected_uuid, "name": sub_action.name if sub_action else selected_uuid})
	execution_completed.emit(result_entity)


## 设置占位标签文本
func set_placeholder(label_text: String = "") -> void:
	text = label_text
	Logging.info("NpcActionButton.set_placeholder: label='%s'" % label_text)
