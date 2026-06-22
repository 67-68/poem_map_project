extends Node
## 视觉风格管理器 (Autoload) — 属性驱动 shader + StyleBox 策略引擎
##
## 核心职责:
##   • bind(data) — 注册一个命名策略，自动应用 shader + stylebox
##   • switch_strategy(container, name) — 切换策略，空串回滚到 default
##   • apply_event_background(container, tex) — 事件临时背景覆盖
##   • 监听 PlayerState.player_stat_changed，按活跃策略同步 progress
##
## 用法:
##   var data = StyleData.new()
##   data.strategy_name = "frost"
##   data.target_property = "health"
##   data.start_property_value = 100.0   # 起点（血满）
##   data.target_property_value = 0.0    # 终点（血空 → progress=1）
##   data.shader_resource = preload("res://shaders/frost.gdshader")
##   data.shader_parameter_names = ["freeze_progress"]
##   data.container = $TapeContainer
##   StyleManager.bind(data)

const LOG_TAG := "StyleManager"

# ── 内部数据结构 ──────────────────────────────────────────

## { instance_id → { strategy_name: StyleData } }
var _strategies: Dictionary = {}

## { instance_id → { "material": Variant|null, "background_tex": Texture2D|null } }
var _default_states: Dictionary = {}

## { instance_id → active_strategy_name }
var _active_strategy: Dictionary = {}

## 防重连标记
var _signal_connected := false


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

## 注册一个策略到目标 container
##
## [param data] StyleData，包含完整的策略描述
##
## 防御性:
##   • container 为 null → Logging.err + return
##   • strategy_name 重名 → Logging.warn，覆盖旧策略
##   • 首次 bind 此 container → 自动 capture_default()
##   • strategy_name 非空 → 自动 apply 此策略
func bind(data: StyleData) -> void:
	if Engine.is_editor_hint():
		return

	# ── 契约检查 ──────────────────────────────────────────
	if data.container == null:
		Logging.err("%s: bind 失败 — container 为 null" % LOG_TAG)
		return

	if not is_instance_valid(data.container):
		Logging.err("%s: bind 失败 — container 已被销毁" % LOG_TAG)
		return

	if data.strategy_name.is_empty():
		Logging.warn("%s: bind — strategy_name 为空，策略不会被自动激活 (container=%s)" % [LOG_TAG, data.container.name])

	var id := data.container.get_instance_id()

	# ── 首次 bind 此 container → 捕获 default 状态 ──────
	if not _default_states.has(id):
		_capture_default(data.container)

	# ── 注册策略 ──────────────────────────────────────────
	if not _strategies.has(id):
		_strategies[id] = {}

	if _strategies[id].has(data.strategy_name):
		Logging.warn("%s: bind — 策略 '%s' 已存在，覆盖旧策略 (container=%s)" % [LOG_TAG, data.strategy_name, data.container.name])

	_strategies[id][data.strategy_name] = data

	# ── 绑定 tree_exiting → 自动清理 ─────────────────────
	if not data.container.tree_exiting.is_connected(_on_container_tree_exiting.bind(data.container)):
		data.container.tree_exiting.connect(_on_container_tree_exiting.bind(data.container))

	Logging.info("%s: bind → strategy='%s' prop=%s container=%s params=%s start=%.1f target=%.1f" % [
		LOG_TAG,
		data.strategy_name,
		data.target_property,
		data.container.name,
		str(data.shader_parameter_names),
		data.start_property_value,
		data.target_property_value,
	])

	# ── 自动激活（若 strategy_name 非空） ────────────────
	if not data.strategy_name.is_empty():
		_apply_strategy(data.container, data)


## 切换 container 的活跃策略
##
## [param container] 目标控件
## [param name] 策略名，空串 → 回滚到 default 状态
func switch_strategy(container: Control, name: String) -> void:
	if container == null:
		Logging.err("%s: switch_strategy — container 为 null" % LOG_TAG)
		return

	if not is_instance_valid(container):
		Logging.err("%s: switch_strategy — container 已销毁" % LOG_TAG)
		return

	var id := container.get_instance_id()

	if name.is_empty():
		# 回滚到 default
		_restore_default(container)
		Logging.info("%s: switch_strategy → 回滚 default (container=%s)" % [LOG_TAG, container.name])
		return

	# 查找策略
	if not _strategies.has(id) or not _strategies[id].has(name):
		Logging.err("%s: switch_strategy — 策略 '%s' 未找到 (container=%s)" % [LOG_TAG, name, container.name])
		return

	var data: StyleData = _strategies[id][name]
	_apply_strategy(container, data)
	Logging.info("%s: switch_strategy → '%s' (container=%s)" % [LOG_TAG, name, container.name])


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

	var style: StyleBoxTexture = container.get("theme_override_styles/panel") as StyleBoxTexture
	if not style:
		Logging.warn("%s: apply_event_background — container '%s' 没有 StyleBoxTexture panel style" % [LOG_TAG, container.name])
		return

	if texture != null:
		# 临时覆盖
		style.texture = texture
		Logging.info("%s: apply_event_background → 临时覆盖 tex='%s' (container=%s)" % [LOG_TAG, texture.resource_path, container.name])
	else:
		# 还原当前策略默认背景
		var default_tex := get_default_background(container)
		style.texture = default_tex
		Logging.info("%s: apply_event_background → 还原默认 tex='%s' (container=%s)" % [
			LOG_TAG,
			default_tex.resource_path if default_tex else "(null)",
			container.name,
		])


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
	return def_state.get("background_tex", null) as Texture2D


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
	if container is PanelContainer and data.stylebox_texture != null:
		var style: StyleBoxTexture = container.get("theme_override_styles/panel") as StyleBoxTexture
		if style:
			style.texture = data.stylebox_texture
			Logging.info("%s: _apply_strategy → StyleBox 已切换 (container=%s tex=%s)" % [
				LOG_TAG, container.name, data.stylebox_texture.resource_path
			])

	# ── 标记活跃策略 ──────────────────────────────────────
	_active_strategy[id] = data.strategy_name

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

	# 还原 StyleBox 背景
	if container is PanelContainer:
		var saved_tex: Texture2D = def_state.get("background_tex", null)
		var style: StyleBoxTexture = container.get("theme_override_styles/panel") as StyleBoxTexture
		if style:
			style.texture = saved_tex

	Logging.info("%s: _restore_default → container=%s" % [LOG_TAG, container.name])


## 捕获 container 的当前状态为 default
func _capture_default(container: Control) -> void:
	var id := container.get_instance_id()

	var def_state := {
		"material": container.material if container.material is ShaderMaterial else null,
		"background_tex": null,
	}

	# 捕获 StyleBox 背景（仅 PanelContainer）
	if container is PanelContainer:
		var style: StyleBoxTexture = container.get("theme_override_styles/panel") as StyleBoxTexture
		if style:
			def_state["background_tex"] = style.texture

	_default_states[id] = def_state
	Logging.info("%s: _capture_default → container=%s bg_tex=%s" % [
		LOG_TAG,
		container.name,
		def_state["background_tex"].resource_path if def_state["background_tex"] else "(null)",
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

	# ── 计算 progress ─────────────────────────────────────
	var progress: float = data.compute_progress(current_val)

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
# 生命周期清理
# ============================================================

func _exit_tree() -> void:
	if _signal_connected and PlayerState.has_signal("player_stat_changed"):
		if PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
			PlayerState.player_stat_changed.disconnect(_on_player_stat_changed)

	_strategies.clear()
	_default_states.clear()
	_active_strategy.clear()
	_signal_connected = false

	Logging.info("%s: _exit_tree — StyleManager 已清理" % LOG_TAG)
