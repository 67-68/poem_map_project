extends Node

## 古风选项按钮管理器（Autoload）
##
## 职责：
## - 轻量注册表：维护 btn_id → EventBtn 映射
## - 动态文本 API：运行时修改已创建的 EventBtn 文本
## - 自动收尸：tree_exiting 时自动 unregister
##
## 契约：
## - 绝不触碰视觉 / 动画逻辑（视觉动效由 EventBtn 自身管理）
## - btn_id 由调用方生成，建议使用 option.description hash 或 choice_result 唯一标识

var _registry: Dictionary = {}  # String → EventBtn


# ═══════════════════════════════════════════════
# 公开 API
# ═══════════════════════════════════════════════

## 注册一个 EventBtn
func register(btn_id: String, btn: EventBtn) -> void:
	if btn_id.is_empty():
		Logging.err("AncientOptionBtnManager.register: btn_id 为空，拒绝注册")
		return
	if _registry.has(btn_id):
		Logging.warn("AncientOptionBtnManager.register: btn_id='%s' 已存在，覆盖旧注册" % btn_id)
		_unregister_internal(btn_id)

	_registry[btn_id] = btn
	# 自动收尸：btn 被 free 时清理
	btn.tree_exiting.connect(_on_btn_dying.bind(btn_id), CONNECT_ONE_SHOT)
	Logging.info("AncientOptionBtnManager.register: btn_id='%s' registered" % btn_id)


## 取消注册
func unregister(btn_id: String) -> void:
	if not _registry.has(btn_id):
		Logging.warn("AncientOptionBtnManager.unregister: btn_id='%s' 未找到" % btn_id)
		return
	_unregister_internal(btn_id)
	Logging.info("AncientOptionBtnManager.unregister: btn_id='%s' unregistered" % btn_id)


## 动态修改按钮文本
func set_text(btn_id: String, new_text: String) -> void:
	var btn: EventBtn = _registry.get(btn_id, null)
	if not btn or not is_instance_valid(btn):
		Logging.err("AncientOptionBtnManager.set_text: btn_id='%s' 不存在或已销毁" % btn_id)
		return
	btn.text = new_text
	Logging.info("AncientOptionBtnManager.set_text: btn_id='%s' text='%s'" % [btn_id, new_text])


## 获取已注册的按钮（只读）
func get_button(btn_id: String) -> EventBtn:
	return _registry.get(btn_id, null)


## 检查 btn_id 是否已注册
func has(btn_id: String) -> bool:
	return _registry.has(btn_id)


# ═══════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════

func _unregister_internal(btn_id: String) -> void:
	var btn: EventBtn = _registry[btn_id]
	_registry.erase(btn_id)
	if btn and is_instance_valid(btn) and btn.tree_exiting.is_connected(_on_btn_dying):
		btn.tree_exiting.disconnect(_on_btn_dying)


## 按钮即将销毁时自动清理
func _on_btn_dying(btn_id: String) -> void:
	Logging.info("AncientOptionBtnManager: btn_id='%s' tree_exiting，自动 unregister" % btn_id)
	_registry.erase(btn_id)
