extends PanelContainer

## 大地图行动前缀 → Button 节点路径映射
## 前缀为 main_tag 中第三个 ":" 之前的部分
## 例如 "action:main:baiye:general" 的前缀为 "action:main:baiye"
const MAIN_ACTION_PREFIXES: Dictionary = {
	"action:main:baiye":   "ActionMap/Button",   # 权贵府（干晔）/ 拜谒
	"action:main:jiaoyou": "ActionMap/Button2",  # 山水园林(交游)
	"action:main:denggao": "ActionMap/Button3",  # 登高
	"action:main:fangshi": "ActionMap/Button4",  # 坊市
	"action:main:duzhuo":  "ActionMap/Button5",  # 独酌
	"action:main:fengzhao": "ActionMap/Button6", # 奉召
}

## 存储匹配上的 SceneAction 引用: prefix → SceneAction
var _action_map: Dictionary = {}

## 存储各按钮当前的 Tween 引用，用于清除闪光
var _flash_tweens: Dictionary = {}


func _ready() -> void:
	# 1. 监听 SceneActionScroll 输出的已选中行动
	EventBus.selected_actions_change.connect(_on_selected_actions_changed)

	# 2. 监听锁定行动信号（触发闪光效果）
	EventBus.locked_actions_selected.connect(_on_locked_actions_selected)

	# 3. 连接所有大地图按钮的 pressed 信号 + 初始全部 disabled
	for prefix in MAIN_ACTION_PREFIXES:
		var btn_path: String = MAIN_ACTION_PREFIXES[prefix]
		var btn: Button = get_node(btn_path)
		if not btn:
			Logging.err("[ActionMap] 找不到按钮节点: %s" % btn_path)
			continue
		btn.disabled = true
		# 用 bind 把前缀带进回调，以便查 _action_map
		btn.pressed.connect(_on_map_action_button_pressed.bind(prefix))


## 清除所有按钮的闪光效果（下次正常刷新时调用）
func _clear_all_flash_effects() -> void:
	for prefix in MAIN_ACTION_PREFIXES:
		var tween = _flash_tweens.get(prefix)
		if tween:
			tween.kill()
		_flash_tweens.erase(prefix)
		var btn = _get_btn(prefix)
		if btn:
			btn.modulate = Color.WHITE


func _get_btn(prefix: String) -> Button:
	var btn_path: String = MAIN_ACTION_PREFIXES.get(prefix, "")
	if btn_path.is_empty():
		return null
	return get_node(btn_path) as Button


func _flash_button(prefix: String) -> void:
	# 清除该按钮已有的闪光 tween
	var old_tween = _flash_tweens.get(prefix)
	if old_tween:
		old_tween.kill()

	var btn = _get_btn(prefix)
	if not btn:
		return

	# 缓慢呼吸闪光：亮黄 ↔ 白，循环 4 次，每步 0.4s
	var tween := create_tween().set_loops(4)
	tween.tween_property(btn, "modulate", Color(2.0, 2.0, 0.6), 0.4)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.4)
	_flash_tweens[prefix] = tween


func _on_locked_actions_selected(actions: Array) -> void:
	for action in actions:
		if not action is SceneAction:
			Logging.warn("[ActionMap] locked_actions_selected 中包含非 SceneAction 对象")
			continue

		var tag: String = action.main_tag
		for prefix in MAIN_ACTION_PREFIXES:
			if tag.begins_with(prefix):
				_flash_button(prefix)
				Logging.info("[ActionMap] 锁定行动闪光: %s (%s)" % [action.name, tag])
				break


func _on_selected_actions_changed(selected_actions: Array) -> void:
	# 清空上一轮的状态
	_action_map.clear()

	# 消除上一轮的锁定闪光效果
	_clear_all_flash_effects()

	# 将所有按钮重置为禁用
	for prefix in MAIN_ACTION_PREFIXES:
		var btn_path: String = MAIN_ACTION_PREFIXES[prefix]
		var btn: Button = get_node(btn_path)
		if btn:
			btn.disabled = true

	# 遍历选中的行动，匹配大地图前缀
	for action in selected_actions:
		if not action is SceneAction:
			Logging.warn("[ActionMap] selected_actions 中包含非 SceneAction 对象")
			continue

		var tag: String = action.main_tag
		for prefix in MAIN_ACTION_PREFIXES:
			if tag.begins_with(prefix):
				# 命中大地图行动 → 启用对应按钮 + 存引用
				_action_map[prefix] = action
				var btn_path: String = MAIN_ACTION_PREFIXES[prefix]
				var btn: Button = get_node(btn_path)
				if btn:
					btn.disabled = false
				Logging.info("[ActionMap] 激活大地图行动: %s (%s)" % [action.name, tag])
				break  # 一个 action 只匹配一个按钮


func _on_map_action_button_pressed(prefix: String) -> void:
	"""
	大地图按钮被点击时的行为。
	与 SceneActionPanel._on_button_pressed() 完全一致：
	1. 执行 action_results
	2. 追加 action_tags 到 PlayerState
	3. 扫描事件
	"""
	var action: SceneAction = _action_map.get(prefix) as SceneAction
	if not action:
		Logging.err("[ActionMap] 按钮被点击但找不到对应的 SceneAction: %s" % prefix)
		return

	# 1. 执行所有行动结果
	if action.action_results:
		for r in action.action_results:
			r.operate()

	# ── 1.5 Generator 消费（统一入口） ──
	var had_generator := action.generator != null
	ActionManager.consume_generator(action)

	# ⛔ generator 存在时 block 随机事件查找
	# generator 内部通过 PushEventOperator 自行推送事件
	if had_generator:
		return

	# 2. 追加 action_tags
	# 也就是说，这里提供的action:main:baiye:general会导致无法匹配action:main:baiye?
	for tag in action.action_tags:
		PlayerState.current_action_tags.append(tag)

	# 3. 扫描事件
	var context = {
	    'main_tag': action.main_tag,
	    'fallback_event_uuid': action.fallback_event_uuid,
	}
	EventManager.scan_events(0, context)
