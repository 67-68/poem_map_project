extends Node
const _StyleData = preload("res://core/model/style_data.gd")
## 视觉风格管理器 (Autoload) — 属性驱动 shader + StyleBox 策略引擎
##
## 模式: 单容器 / 策略组（多容器同时切换）
##   • data.container = $P  → 旧式单容器。switch_strategy 只影响这一个
##   • data.containers = [$A, $B, $C] → 策略组模式。bind/switch 时同时生效
##   • switch_strategy(任意组内容器, "frost") → 全组批量切换
##
## 核心职责:
##   • bind(data) — 注册策略，自动应用 shader + stylebox + text theme
##   • switch_strategy(container, name) — 按策略组切换，空串回滚 default
##   • apply_event_background(container, tex) — 事件临时背景覆盖
##   • 监听 PlayerState.player_stat_changed，按活跃策略同步 progress
##
## 用法（策略组模式）:
##   var data = StyleData.new()
##   data.strategy_name = "frost"
##   data.containers = [$TapeContainer, $SidePanel]
##   data.shader_parameter_names = ["freeze_progress"]
##   StyleManager.bind(data)

const LOG_TAG := "StyleManager"

# ── 内部数据结构 ──────────────────────────────────────────

## { instance_id → { strategy_name: StyleData } }
var _strategies: Dictionary = {}

## { instance_id → { "material": ShaderMaterial|null, "stylebox": StyleBox|null } }
var _default_states: Dictionary = {}

## { instance_id → active_strategy_name }
var _active_strategy: Dictionary = {}

## 防重连标记
var _signal_connected := false

## { container_instance_id → { "narrative_text_theme": ..., "title_text_theme": ..., "inner_thought_theme": ..., "default_text_theme": ... } }
## 活跃文本主题缓存，用于 child_entered_tree 信号触发时懒应用
var _active_text_themes: Dictionary = {}

## { watched_node_instance_id → container_instance_id }
## 反向索引：记录哪些节点被连接了 child_entered_tree 信号，用于 cleanup
var _watched_text_nodes: Dictionary = {}

## ★ 容器同伴映射: { container_instance_id → Array[int] } — 同组所有容器 id
## bind() 时构建；switch_strategy() 据此批量切换组内所有容器
## 单容器注册时该项映射为 [自身id]，保证 switch_strategy 行为一致
var _container_peers: Dictionary = {}


# ============================================================
# _ready() — 初始化信号连接
# ============================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ensure_player_stat_signal_connected()
	Logging.info("%s: _ready — StyleManager 已就绪" % LOG_TAG)


# ============================================================
# 公共 API — 策略管理
# ============================================================

## 注册一个策略到目标 container(s)
##
## [param data] StyleData，包含完整的策略描述
##
## 容器解析: containers 非空 → 用 containers；否则退回到 container（向后兼容）
## 策略组模式: containers 中的全部控件共享同一策略组，switch_strategy 时同时切换
##
## 防御性:
##   • container 和 containers 均为空 → Logging.err + return
##   • strategy_name 重名 → Logging.warn，覆盖旧策略
##   • 首次 bind 此 container → 自动 capture_default()
func bind(data: StyleData) -> void:
	if Engine.is_editor_hint():
		return

	# ── 解析目标容器列表 ──────────────────────────────────
	var targets: Array[Control] = _resolve_target_containers(data)
	if targets.is_empty():
		Logging.err("%s: bind 失败 — container 和 containers 均为空" % LOG_TAG)
		return

	var strategy_name: String = data.strategy_name
	if strategy_name.is_empty():
		Logging.warn("%s: bind — strategy_name 为空，策略不会被自动激活" % LOG_TAG)

	# ── 构建同伴映射（每个容器记录同组所有容器的 id）─────
	var all_ids: Array[int] = []
	for c in targets:
		if c != null and is_instance_valid(c):
			all_ids.append(c.get_instance_id())

	for c in targets:
		if c != null and is_instance_valid(c):
			_container_peers[c.get_instance_id()] = all_ids

	# ── 遍历每个目标容器，执行注册 ────────────────────────
	for c in targets:
		if c == null:
			Logging.err("%s: bind — 跳过 null container (strategy='%s')" % [LOG_TAG, strategy_name])
			continue

		if not is_instance_valid(c):
			Logging.err("%s: bind — 跳过已销毁 container (name=%s)" % [LOG_TAG, c.name if c else "?"])
			continue

		var id := c.get_instance_id()

		# ── 首次 bind → 捕获 default 状态 ─────────────
		if not _default_states.has(id):
			_capture_default(c)

		# ── 注册策略 ─────────────────────────────────
		if not _strategies.has(id):
			_strategies[id] = {}

		if _strategies[id].has(strategy_name):
			Logging.warn("%s: bind — 策略 '%s' 已存在，覆盖旧策略 (container=%s)" % [LOG_TAG, strategy_name, c.name])

		_strategies[id][strategy_name] = data

		# ── 绑定 tree_exiting → 自动清理 ──────────────
		if not c.tree_exiting.is_connected(_on_container_tree_exiting.bind(c)):
			c.tree_exiting.connect(_on_container_tree_exiting.bind(c))


		Logging.info("%s: bind → strategy='%s' prop=%s container=%s params=%s start=%.1f target=%.1f" % [
			LOG_TAG,
			strategy_name,
			data.target_property,
			c.name,
			str(data.shader_parameter_names),
			data.start_property_value,
			data.target_property_value,
		])

		# ── stylebox_active_on_bind → 立即应用 ──────────
		if data.stylebox_active_on_bind and c is PanelContainer and data.stylebox != null:
			c.set("theme_override_styles/panel", data.stylebox)
			if _default_states.has(id):
				_default_states[id]["stylebox"] = data.stylebox.duplicate()
			Logging.info("%s: bind → stylebox 已立即应用 (container=%s)" % [LOG_TAG, c.name])


## 切换策略组内所有容器的活跃策略
##
## [param container] 组内任意一个容器（用于定位策略组），null → 报错
## [param name] 策略名，空串 → 全组回滚到 default
##
## 行为: 通过 _container_peers[container_id] 找到组内所有容器，
##       对每个容器执行 _apply_strategy 或 _restore_default
func switch_strategy(container: Control, name: String) -> void:
	if container == null:
		Logging.err("%s: switch_strategy — container 为 null" % LOG_TAG)
		return

	if not is_instance_valid(container):
		Logging.err("%s: switch_strategy — container 已销毁" % LOG_TAG)
		return

	# ── 通过同伴映射获取策略组内所有容器 ──────────────────
	var container_id := container.get_instance_id()
	var group_ids: Array = _container_peers.get(container_id, [container_id])  # 兜底：单容器
	if group_ids.is_empty():
		if name.is_empty():
			# 空策略名且无组 → 回滚单个 container
			_restore_default(container)
			Logging.info("%s: switch_strategy → 回滚 default (单容器=%s)" % [LOG_TAG, container.name])
		else:
			Logging.err("%s: switch_strategy — 策略 '%s' 未在反向索引中找到" % [LOG_TAG, name])
		return

	if name.is_empty():
		# 全组回滚 default
		for cid in group_ids:
			if not is_instance_id_valid(cid):
				continue
			var c := instance_from_id(cid) as Control
			if c == null or not is_instance_valid(c):
				continue
			_restore_default(c)
			Logging.info("%s: switch_strategy → 回滚 default (container=%s)" % [LOG_TAG, c.name])
		return

	# ── 全组激活策略 ──────────────────────────────────────
	# 从组内任意一个容器查出 StyleData（所有容器共享同一份 data 引用）
	var data: StyleData = null
	for cid in group_ids:
		if not is_instance_id_valid(cid):
			continue
		if _strategies.has(cid) and _strategies[cid].has(name):
			data = _strategies[cid][name]
			break

	if data == null:
		Logging.err("%s: switch_strategy — 策略 '%s' 的 StyleData 未找到" % [LOG_TAG, name])
		return

	var apply_count := 0
	for cid in group_ids:
		if not is_instance_id_valid(cid):
			continue
		var c := instance_from_id(cid) as Control
		if c == null or not is_instance_valid(c):
			continue
		_apply_strategy(c, data)
		apply_count += 1

	Logging.info("%s: switch_strategy → '%s' 组批量切换 (%d 容器)" % [LOG_TAG, name, apply_count])


# ============================================================
# 公共 API — 背景纹理管理
# ============================================================

## 事件临时背景覆盖
##
## [param container] 目标控件（需是 PanelContainer）
## [param texture] 临时纹理。null → 还原当前策略的默认背景。
func apply_event_background(container: Control, texture: Texture2D) -> void:
	if container == null:
		return

	if not (container is PanelContainer):
		Logging.warn("%s: apply_event_background — container '%s' 不是 PanelContainer，跳过" % [LOG_TAG, container.name])
		return

	if texture != null:
		# 临时覆盖：构建临时 StyleBoxTexture 整块替换
		var temp_stylebox := _make_temp_stylebox_texture(texture)
		if temp_stylebox:
			container.set("theme_override_styles/panel", temp_stylebox)
			Logging.info("%s: apply_event_background → 临时覆盖 tex='%s' (container=%s)" % [LOG_TAG, texture.resource_path, container.name])
		else:
			Logging.warn("%s: apply_event_background — 无法构建临时 StyleBoxTexture (container=%s)" % [LOG_TAG, container.name])
	else:
		# 还原优先级: 活跃策略的 stylebox > default_states
		var active_sb := _get_active_strategy_stylebox(container)
		if active_sb:
			container.set("theme_override_styles/panel", active_sb)
			Logging.info("%s: apply_event_background → 已还原活跃策略 StyleBox (container=%s)" % [LOG_TAG, container.name])
		else:
			_restore_stylebox_from_default(container)
			Logging.info("%s: apply_event_background → 已还原默认 StyleBox (container=%s)" % [LOG_TAG, container.name])


## 读取 container 当前的 StyleBoxTexture 背景纹理
func get_container_background(container: Control) -> Texture2D:
	if container == null or not (container is PanelContainer):
		return null

	var style: StyleBoxTexture = container.get("theme_override_styles/panel") as StyleBoxTexture
	if not style:
		return null

	return style.texture


## 读取 container 的 default 状态中的背景纹理
func get_default_background(container: Control) -> Texture2D:
	if container == null:
		return null

	var id := container.get_instance_id()
	if not _default_states.has(id):
		return null

	var def_state: Dictionary = _default_states[id]
	var saved_stylebox: StyleBox = def_state.get("stylebox", null)
	if saved_stylebox is StyleBoxTexture:
		return (saved_stylebox as StyleBoxTexture).texture
	return null


# ============================================================
# 公共 API — 手动解绑
# ============================================================

## 取消 container 的所有策略注册，还原 default 状态
func unbind(container: Control) -> void:
	if container == null:
		Logging.warn("%s: unbind — container 为 null，跳过" % LOG_TAG)
		return

	var id := container.get_instance_id()

	# 还原 default
	_restore_default(container)

	# 断开信号
	if is_instance_valid(container) and container.tree_exiting.is_connected(_on_container_tree_exiting):
		container.tree_exiting.disconnect(_on_container_tree_exiting)

	# ── 从同伴映射中清理 ──────────────────────────────────
	_container_peers.erase(id)

	_strategies.erase(id)
	_default_states.erase(id)
	_active_strategy.erase(id)

	Logging.info("%s: unbind → container=%s" % [LOG_TAG, container.name])


## 强制刷新所有活跃策略的进度（调试用）
func refresh_all() -> void:
	if Engine.is_editor_hint():
		return

	var count := 0
	for id in _active_strategy:
		var container := instance_from_id(id) as Control
		if container == null or not is_instance_valid(container):
			continue
		var strategy_name: String = _active_strategy[id]
		if _strategies.has(id) and _strategies[id].has(strategy_name):
			var data: StyleData = _strategies[id][strategy_name]
			_sync_progress(container, data)
			count += 1

	Logging.debug("%s: refresh_all — 刷新 %d 个活跃策略" % [LOG_TAG, count])


# ============================================================
# 信号处理
# ============================================================

func _on_player_stat_changed(prop_name: String) -> void:
	for id in _active_strategy:
		var container := instance_from_id(id) as Control
		if container == null or not is_instance_valid(container):
			continue

		var strategy_name: String = _active_strategy[id]
		if not _strategies.has(id) or not _strategies[id].has(strategy_name):
			continue

		var data: StyleData = _strategies[id][strategy_name]
		if data.target_property == prop_name:
			_sync_progress(container, data)


func _on_container_tree_exiting(container: Control) -> void:
	if container == null:
		return

	Logging.info("%s: container '%s' tree_exiting → 自动 unbind" % [LOG_TAG, container.name])
	unbind(container)


# ============================================================
# 内部方法 — 策略应用
# ============================================================

## 应用一个策略到 container
func _apply_strategy(container: Control, data: StyleData) -> void:
	var id := container.get_instance_id()

	# ── 确保信号已连接 ────────────────────────────────────
	_ensure_player_stat_signal_connected()

	# ── 处理 ShaderMaterial ───────────────────────────────
	var mat: ShaderMaterial = data.shader_material
	if mat == null and data.shader_resource != null:
		mat = ShaderMaterial.new()
		mat.shader = data.shader_resource

	if mat != null:
		container.material = mat
	else:
		# 无 shader → 不碰 material
		pass

	# ── 处理 StyleBox 背景 ────────────────────────────────
	if container is PanelContainer and data.stylebox != null:
		container.set("theme_override_styles/panel", data.stylebox)
		Logging.info("%s: _apply_strategy → StyleBox 已整块替换 (container=%s)" % [
			LOG_TAG, container.name,
		])

	# ── 标记活跃策略 ──────────────────────────────────────
	_active_strategy[id] = data.strategy_name

	# ── 应用文本 Theme Type Variation ──────────────────────
	_apply_text_theme_variations(container, data)

	# ── 首次进度同步 ──────────────────────────────────────
	_sync_progress(container, data)


## 还原 container 到 default 状态
func _restore_default(container: Control) -> void:
	var id := container.get_instance_id()

	# 清除活跃策略
	_active_strategy.erase(id)

	if not _default_states.has(id):
		return

	var def_state: Dictionary = _default_states[id]

	# 还原 material
	var saved_mat = def_state.get("material", null)
	if saved_mat == null:
		container.material = null
	elif saved_mat is Material:
		container.material = saved_mat
	# 否则保持原样

	# 还原 StyleBox（仅 PanelContainer）
	if container is PanelContainer:
		var saved_stylebox: StyleBox = def_state.get("stylebox", null)
		if saved_stylebox:
			container.set("theme_override_styles/panel", saved_stylebox)

	# 还原文本 Theme Type Variation
	_restore_text_theme_variations(container)

	Logging.info("%s: _restore_default → container=%s" % [LOG_TAG, container.name])


## 捕获 container 的当前状态为 default
func _capture_default(container: Control) -> void:
	var id := container.get_instance_id()

	var def_state := {
		"material": container.material if container.material is ShaderMaterial else null,
		"stylebox": null,
		"text_theme_variations": {},
	}

	# 捕获 StyleBox（仅 PanelContainer）
	if container is PanelContainer:
		var style: StyleBox = container.get("theme_override_styles/panel") as StyleBox
		if style:
			# 保存完整 StyleBox 副本（duplicate() 深拷贝）
			def_state["stylebox"] = style.duplicate()

	# 捕获子控件文本 theme_type_variation
	var text_variations := {}
	for child in _get_all_text_controls(container):
		text_variations[child.get_instance_id()] = child.theme_type_variation
	def_state["text_theme_variations"] = text_variations

	_default_states[id] = def_state
	Logging.info("%s: _capture_default → container=%s text_controls=%d" % [
		LOG_TAG,
		container.name,
		text_variations.size(),
	])


# ============================================================
# 内部方法 — 进度同步
# ============================================================

## 确保 PlayerState.player_stat_changed 已连接
func _ensure_player_stat_signal_connected() -> void:
	if _signal_connected:
		return

	if not PlayerState.has_signal("player_stat_changed"):
		Logging.err("%s: PlayerState 没有 player_stat_changed 信号 💀" % LOG_TAG)
		return

	if not PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
		PlayerState.player_stat_changed.connect(_on_player_stat_changed)
		Logging.info("%s: 已连接 PlayerState.player_stat_changed" % LOG_TAG)

	_signal_connected = true


## 同步单个策略的 progress
func _sync_progress(container: Control, data: StyleData) -> void:
	# ── 读取当前属性值 ────────────────────────────────────
	var current_val: float = float(PlayerState.get_stat_val(data.target_property))

	# ── 计算 progress（含 remap 到输出区间）───────────────
	var progress: float = data.compute_progress_remapped(current_val)

	# ── 写入 shader parameter ─────────────────────────────
	var mat: Material = container.material
	var shader_mat := mat as ShaderMaterial
	if shader_mat == null:
		# 无 ShaderMaterial → 只驱动 StyleBox 的场景
		return

	for param_name in data.shader_parameter_names:
		shader_mat.set_shader_parameter(param_name, progress)

	Logging.debug("%s: _sync_progress → prop=%s val=%.1f progress=%.3f params=%s container=%s" % [
		LOG_TAG,
		data.target_property,
		current_val,
		progress,
		str(data.shader_parameter_names),
		container.name,
	])


# ============================================================
# 内部方法 — 容器解析
# ============================================================

## 从 StyleData 解析目标容器列表
## containers 非空 → 返回 containers；否则退回 container 单元素数组
## 两者都为空 → 返回空数组，由调用方报错
func _resolve_target_containers(data: StyleData) -> Array[Control]:
	if not data.containers.is_empty():
		return data.containers
	if data.container != null:
		return [data.container]
	return []


# ============================================================
# 内部方法 — StyleBox 辅助
# ============================================================

## 用纹理构建一个最小临时 StyleBoxTexture
func _make_temp_stylebox_texture(tex: Texture2D) -> StyleBoxTexture:
	if tex == null:
		return null
	var sbt := StyleBoxTexture.new()
	sbt.texture = tex
	return sbt


## 从 default_states 还原完整 StyleBox 到 container
func _restore_stylebox_from_default(container: Control) -> void:
	if container == null:
		return
	var id := container.get_instance_id()
	if not _default_states.has(id):
		return
	var saved_stylebox: StyleBox = _default_states[id].get("stylebox", null)
	if saved_stylebox:
		container.set("theme_override_styles/panel", saved_stylebox)


## 获取当前活跃策略中注册的 stylebox（如有）
## 用于 apply_event_background(null) 时优先还原到活跃策略背景
func _get_active_strategy_stylebox(container: Control) -> StyleBox:
	if container == null:
		return null
	var id := container.get_instance_id()
	var active_name: String = _active_strategy.get(id, "")
	if active_name.is_empty():
		return null
	var strategies: Dictionary = _strategies.get(id, {})
	var data: StyleData = strategies.get(active_name, null)
	if data == null:
		return null
	return data.stylebox


## 递归扫描 container 下所有 Label / RichTextLabel
##
## 返回它们组成的数组（用于 capture / apply / restore text theme variation）
func _get_all_text_controls(root: Control) -> Array[Control]:
	var result: Array[Control] = []
	_collect_text_controls_recursive(root, result)
	return result


## 递归收集 Label / RichTextLabel 到 result 数组
func _collect_text_controls_recursive(node: Node, result: Array[Control]) -> void:
	if node is Label or node is RichTextLabel:
		result.append(node as Control)
	for child in node.get_children():
		_collect_text_controls_recursive(child, result)


## 将 StyleData 中的 text theme variation 应用到 container 下所有文本控件
##
## 规则:
##   • RichTextLabel:
##       - 若原 variation 为 "NarrativeText" 或空 → 替换为 narrative_text_theme
##       - 若原 variation 为 "InnerThought"           → 替换为 inner_thought_theme
##   • Label:
##       - 若原 variation 为 "DefaultText" 或空       → 替换为 default_text_theme
##       - 若原 variation 为 "TitleText"              → 替换为 title_text_theme
##
## 仅当 data 中对应的 theme 字段非空时才进行替换（空串 = 不修改）
func _apply_text_theme_variations(container: Control, data: StyleData) -> void:
	if data == null:
		return

	for child in _get_all_text_controls(container):
		if child is RichTextLabel:
			var old_variation: String = child.theme_type_variation
			if old_variation == "NarrativeText" or old_variation.is_empty():
				if not data.narrative_text_theme.is_empty():
					# 清除 add_theme_color_override 钉死的颜色，让 variation 生效
					if child.has_theme_color_override(&"default_color"):
						child.remove_theme_color_override(&"default_color")
					if child.has_theme_color_override(&"font_color"):
						child.remove_theme_color_override(&"font_color")
					child.theme_type_variation = data.narrative_text_theme
					Logging.debug("%s: RichTextLabel '%s' theme: '%s' → '%s' (narrative)" % [
						LOG_TAG, child.name, old_variation, data.narrative_text_theme,
					])
			elif old_variation == "InnerThought":
				if not data.inner_thought_theme.is_empty():
					if child.has_theme_color_override(&"default_color"):
						child.remove_theme_color_override(&"default_color")
					if child.has_theme_color_override(&"font_color"):
						child.remove_theme_color_override(&"font_color")
					child.theme_type_variation = data.inner_thought_theme
					Logging.debug("%s: RichTextLabel '%s' theme: '%s' → '%s' (inner_thought)" % [
						LOG_TAG, child.name, old_variation, data.inner_thought_theme,
					])
		elif child is Label:
			var old_variation: String = child.theme_type_variation
			if old_variation == "DefaultText" or old_variation.is_empty():
				if not data.default_text_theme.is_empty():
					if child.has_theme_color_override(&"font_color"):
						child.remove_theme_color_override(&"font_color")
					child.theme_type_variation = data.default_text_theme
					Logging.debug("%s: Label '%s' theme: '%s' → '%s' (default)" % [
						LOG_TAG, child.name, old_variation, data.default_text_theme,
					])
			elif old_variation == "TitleText":
				if not data.title_text_theme.is_empty():
					if child.has_theme_color_override(&"font_color"):
						child.remove_theme_color_override(&"font_color")
					child.theme_type_variation = data.title_text_theme
					Logging.debug("%s: Label '%s' theme: '%s' → '%s' (title)" % [
						LOG_TAG, child.name, old_variation, data.title_text_theme,
					])

	# ── 缓存活跃主题，供后续新增子控件懒应用 ──
	var container_id := container.get_instance_id()
	_active_text_themes[container_id] = {
		"narrative_text_theme": data.narrative_text_theme,
		"title_text_theme": data.title_text_theme,
		"inner_thought_theme": data.inner_thought_theme,
		"default_text_theme": data.default_text_theme,
	}

	# ── 递归监听容器子树中所有节点的 child_entered_tree ──
	# 后续新增事件卡片会自动扫描并应用冻土字体
	_watch_child_entered_tree_recursive(container, container_id)

	Logging.info("%s: _apply_text_theme_variations → 已启用 child_entered_tree 懒监听 (container=%s)" % [
		LOG_TAG, container.name,
	])


## 将 container 下的文本控件恢复到 default_states 中捕获的 theme_type_variation
##
## 同时清除 strategy 期间可能残留的 add_theme_color_override，
## 新事件进入时 _apply_ui_decl_colors 会重新设置需要的颜色覆盖
func _restore_text_theme_variations(container: Control) -> void:
	var id := container.get_instance_id()

	# ── 清理 child_entered_tree 信号监听 ──
	_unwatch_child_entered_tree_recursive(container)
	_active_text_themes.erase(id)

	if not _default_states.has(id):
		return

	var saved_variations: Dictionary = _default_states[id].get("text_theme_variations", {})
	if saved_variations.is_empty():
		return

	var count := 0
	for child in _get_all_text_controls(container):
		var child_id := child.get_instance_id()
		if saved_variations.has(child_id):
			# 清除 add_theme_color_override 残留，让原始 variation 颜色生效
			if child.has_theme_color_override(&"font_color"):
				child.remove_theme_color_override(&"font_color")
			if child.has_theme_color_override(&"default_color"):
				child.remove_theme_color_override(&"default_color")
			child.theme_type_variation = saved_variations[child_id]
			count += 1

	if count > 0:
		Logging.info("%s: _restore_text_theme_variations → 恢复 %d 个文本控件 (container=%s)" % [
			LOG_TAG, count, container.name,
		])


# ── child_entered_tree 懒监听 ────────────────────────────

## 递归为节点及其所有子孙连接 child_entered_tree 信号
## 后续新增到纸带的 Event block 会自动扫描并应用冻土字体
func _watch_child_entered_tree_recursive(node: Node, container_id: int) -> void:
	if not is_instance_valid(node):
		return

	var node_id := node.get_instance_id()
	if _watched_text_nodes.has(node_id):
		return  # 已监听，跳过

	if node.has_signal("child_entered_tree"):
		if not node.child_entered_tree.is_connected(_on_new_child_entered):
			node.child_entered_tree.connect(_on_new_child_entered)
			_watched_text_nodes[node_id] = container_id

	for child in node.get_children():
		_watch_child_entered_tree_recursive(child, container_id)


## 递归断开 child_entered_tree 信号
func _unwatch_child_entered_tree_recursive(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var node_id := node.get_instance_id()
	if _watched_text_nodes.has(node_id):
		if node.has_signal("child_entered_tree") and node.child_entered_tree.is_connected(_on_new_child_entered):
			node.child_entered_tree.disconnect(_on_new_child_entered)
		_watched_text_nodes.erase(node_id)

	for child in node.get_children():
		_unwatch_child_entered_tree_recursive(child)


## child_entered_tree 回调：新节点进入场景树时，递归扫描其子树并应用冻土字体
func _on_new_child_entered(new_child: Node) -> void:
	if not is_instance_valid(new_child):
		return

	# 找到此节点属于哪个 container
	var node_id := new_child.get_instance_id()
	# 向上追溯：检查当前节点或祖先节点是否在有 themed 的容器中
	# 实际上我们从 _watched_text_nodes 中找匹配的 container_id
	var container_id := _find_text_theme_container(new_child)
	if container_id == 0:
		# 未找到对应主题缓存 → 新节点进入前未被 watched 树覆盖
		# 为新节点本身也注册监听（它可能有子节点）
		return

	var themes: Dictionary = _active_text_themes.get(container_id, {})
	if themes.is_empty():
		return

	# 递归扫描新节点的子树并应用主题
	_apply_text_theme_to_subtree(new_child, themes, container_id)

	# 新节点也需要注册 child_entered_tree 监听它的子节点
	_watch_child_entered_tree_recursive(new_child, container_id)


## 向上追溯节点的 ancestors，找到某个被 watched 的节点对应的 container_id
func _find_text_theme_container(node: Node) -> int:
	var current: Node = node
	while is_instance_valid(current):
		var cid := current.get_instance_id()
		if _watched_text_nodes.has(cid):
			return _watched_text_nodes[cid]
		current = current.get_parent() if current.get_parent() else null
	# 兜底：搜索所有活跃 container_id 中有主题缓存的
	# 这种情况不常见，但覆盖 _active_text_themes 比 _watched_text_nodes 更宽泛的情况
	for cid in _active_text_themes:
		return cid
	return 0


## 递归扫描节点子树中的文本控件并应用冻土主题
func _apply_text_theme_to_subtree(node: Node, themes: Dictionary, container_id: int) -> void:
	if not is_instance_valid(node):
		return

	if node is RichTextLabel:
		var old_variation: String = node.theme_type_variation
		var narrative_theme: String = themes.get("narrative_text_theme", "")
		var inner_thought_theme: String = themes.get("inner_thought_theme", "")
		if old_variation == "NarrativeText" or old_variation.is_empty():
			if not narrative_theme.is_empty():
				if node.has_theme_color_override(&"default_color"):
					node.remove_theme_color_override(&"default_color")
				if node.has_theme_color_override(&"font_color"):
					node.remove_theme_color_override(&"font_color")
				node.theme_type_variation = narrative_theme
		elif old_variation == "InnerThought":
			if not inner_thought_theme.is_empty():
				if node.has_theme_color_override(&"default_color"):
					node.remove_theme_color_override(&"default_color")
				if node.has_theme_color_override(&"font_color"):
					node.remove_theme_color_override(&"font_color")
				node.theme_type_variation = inner_thought_theme

	elif node is Label:
		var old_variation: String = node.theme_type_variation
		var default_theme: String = themes.get("default_text_theme", "")
		var title_theme: String = themes.get("title_text_theme", "")
		if old_variation == "DefaultText" or old_variation.is_empty():
			if not default_theme.is_empty():
				if node.has_theme_color_override(&"font_color"):
					node.remove_theme_color_override(&"font_color")
				node.theme_type_variation = default_theme
		elif old_variation == "TitleText":
			if not title_theme.is_empty():
				if node.has_theme_color_override(&"font_color"):
					node.remove_theme_color_override(&"font_color")
				node.theme_type_variation = title_theme

	for child in node.get_children():
		_apply_text_theme_to_subtree(child, themes, container_id)


# ============================================================
# 生命周期清理
# ============================================================

func _exit_tree() -> void:
	if _signal_connected and PlayerState.has_signal("player_stat_changed"):
		if PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
			PlayerState.player_stat_changed.disconnect(_on_player_stat_changed)

	# ── 清理 child_entered_tree 信号 ──
	for node_id in _watched_text_nodes:
		var node := instance_from_id(node_id) if is_instance_id_valid(node_id) else null
		if node and node.has_signal("child_entered_tree") and node.child_entered_tree.is_connected(_on_new_child_entered):
			node.child_entered_tree.disconnect(_on_new_child_entered)
	_watched_text_nodes.clear()
	_active_text_themes.clear()

	_strategies.clear()
	_default_states.clear()
	_active_strategy.clear()
	_container_peers.clear()
	_signal_connected = false

	Logging.info("%s: _exit_tree — StyleManager 已清理" % LOG_TAG)
