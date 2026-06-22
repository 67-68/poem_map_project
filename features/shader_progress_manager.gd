extends Node
##  Shader 进度管理器 (Autoload) — 属性值 → shader parameter 实时驱动
##
##  核心职责:
##    • bind(data)   — 注册一个属性→shader 映射，自动创建 ShaderMaterial 并挂载
##    • unbind(container) — 取消注册，清理 material
##    • 监听 PlayerState.player_stat_changed 信号，自动同步 progress
##
##  用法:
##    var data = ShaderProgressData.new()
##    data.target_property = "health"
##    data.shader_resource = preload("res://shaders/frost.gdshader")
##    data.shader_parameter_names = ["freeze_progress"]
##    data.start_property_value = 0.0
##    data.target_property_value = 100.0
##    data.container = $HealthPanel
##    ShaderProgressManager.bind(data)

const LOG_TAG := "ShaderProgressManager"

# ── 内部绑定结构 ──────────────────────────────────────────
## 内部 Binding 字典: { "data": ShaderProgressData, "material": ShaderMaterial }
var _bindings: Array[Dictionary] = []

## 防重连标记：player_stat_changed 信号是否已连接
var _signal_connected := false


# ============================================================
# _ready() — 初始化信号连接
# ============================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ensure_player_stat_signal_connected()
	Logging.info("%s: _ready — ShaderProgressManager 已就绪" % LOG_TAG)


# ============================================================
# 公共 API
# ============================================================

## 注册一个属性→shader 驱动的绑定
##
## [param data] ShaderProgressData，包含完整的映射描述
##
## 防御性:
##   • container 为 null → Logging.err + return
##   • target_property 为空 → Logging.err + return
##   • shader_resource 为 null → Logging.err + return
##   • 同一 container 已有 binding → 先 unbind 旧再 bind 新
func bind(data: ShaderProgressData) -> void:
	if Engine.is_editor_hint():
		return

	# ── 契约检查 ──────────────────────────────────────────
	if data.container == null:
		Logging.err("%s: bind 失败 — container 为 null" % LOG_TAG)
		return

	if not is_instance_valid(data.container):
		Logging.err("%s: bind 失败 — container 已被销毁" % LOG_TAG)
		return

	if data.target_property.is_empty():
		Logging.err("%s: bind 失败 — target_property 为空 (container=%s)" % [LOG_TAG, data.container.name])
		return

	if data.shader_resource == null:
		Logging.err("%s: bind 失败 — shader_resource 为 null (container=%s)" % [LOG_TAG, data.container.name])
		return

	# ── 去重：同一 container 先解绑旧 binding ────────────
	_remove_binding_by_container(data.container)

	# ── 确保信号已连接 ────────────────────────────────────
	_ensure_player_stat_signal_connected()

	# ── 创建 ShaderMaterial ───────────────────────────────
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = data.shader_resource

	# 挂载 material 到控件
	data.container.material = shader_mat

	# 绑定 container.tree_exiting → 自动清理
	if not data.container.tree_exiting.is_connected(_on_container_tree_exiting.bind(data.container)):
		data.container.tree_exiting.connect(_on_container_tree_exiting.bind(data.container))

	# ── 写入 _bindings ────────────────────────────────────
	var binding := {
		"data": data,
		"material": shader_mat,
	}
	_bindings.append(binding)

	Logging.info("%s: bind → prop=%s container=%s params=%s invert=%s start=%.1f target=%.1f" % [
		LOG_TAG,
		data.target_property,
		data.container.name,
		str(data.shader_parameter_names),
		str(data.property_progress_inverted),
		data.start_property_value,
		data.target_property_value,
	])

	# ── 首次同步 ──────────────────────────────────────────
	_sync_progress(binding)


## 取消注册（按 container 匹配）
##
## [param container] 目标控件
func unbind(container: Control) -> void:
	if container == null:
		Logging.warn("%s: unbind — container 为 null，跳过" % LOG_TAG)
		return

	_remove_binding_by_container(container)


## 强制刷新所有绑定的进度（调试 / 手动触发用）
func refresh_all() -> void:
	if Engine.is_editor_hint():
		return

	Logging.debug("%s: refresh_all — 强制刷新 %d 个 binding" % [LOG_TAG, _bindings.size()])
	for binding in _bindings:
		_sync_progress(binding)


# ============================================================
# 信号处理
# ============================================================

## PlayerState.player_stat_changed 信号回调
## 遍历 _bindings，匹配 target_property，同步对应 binding
func _on_player_stat_changed(prop_name: String) -> void:
	if _bindings.is_empty():
		return

	Logging.debug("%s: player_stat_changed → prop=%s, 扫描 %d 个 binding" % [LOG_TAG, prop_name, _bindings.size()])

	for binding in _bindings:
		var data: ShaderProgressData = binding["data"]
		if data == null:
			Logging.err("%s: binding.data 为 null，跳过 (疑似已被 GC)" % LOG_TAG)
			continue

		if data.target_property == prop_name:
			_sync_progress(binding)


## 控件即将退出场景树 → 自动清理 binding
func _on_container_tree_exiting(container: Control) -> void:
	if container == null:
		return

	Logging.info("%s: container '%s' tree_exiting → 自动 unbind" % [LOG_TAG, container.name])
	_remove_binding_by_container(container)


# ============================================================
# 内部方法
# ============================================================

## 确保 PlayerState.player_stat_changed 已连接（防重连）
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


## 同步单个 binding：读取当前属性值 → 计算 progress → 写入所有 shader parameter
func _sync_progress(binding: Dictionary) -> void:
	var data: ShaderProgressData = binding["data"]
	var mat: ShaderMaterial = binding["material"]

	if data == null or mat == null:
		Logging.err("%s: _sync_progress — data 或 material 为 null" % LOG_TAG)
		return

	# ── 读取当前属性值 ────────────────────────────────────
	var current_val: float = float(PlayerState.get_stat_val(data.target_property))

	# ── 计算 progress ─────────────────────────────────────
	var progress: float = data.compute_progress(current_val)

	# ── 写入所有 shader parameter ─────────────────────────
	for param_name in data.shader_parameter_names:
		mat.set_shader_parameter(param_name, progress)

	Logging.debug("%s: _sync_progress → prop=%s val=%.1f progress=%.3f params=%s" % [
		LOG_TAG,
		data.target_property,
		current_val,
		progress,
		str(data.shader_parameter_names),
	])


## 按 container 移除 binding（断开信号 + 清理 material）
func _remove_binding_by_container(container: Control) -> void:
	for i in range(_bindings.size() - 1, -1, -1):
		var binding := _bindings[i]
		var data: ShaderProgressData = binding["data"]
		if data == null:
			# 残留 entry，直接清除
			_bindings.remove_at(i)
			Logging.warn("%s: 清除残留 binding (data 为 null)" % LOG_TAG)
			continue

		if data.container == container:
			# 清理 material（避免残留 shader 渲染）
			var mat: ShaderMaterial = binding["material"]
			if mat != null and is_instance_valid(mat):
				# 不 free material，让 Godot 的引用计数处理
				pass

			# 还原 container.material 为默认（可选，避免视觉残留）
			if is_instance_valid(container):
				container.material = null

			# 断开 tree_exiting 信号
			if is_instance_valid(container) and container.tree_exiting.is_connected(_on_container_tree_exiting):
				container.tree_exiting.disconnect(_on_container_tree_exiting)

			_bindings.remove_at(i)
			Logging.info("%s: unbind → container=%s, 剩余 bindings=%d" % [LOG_TAG, container.name, _bindings.size()])
			return

	Logging.warn("%s: _remove_binding_by_container — container '%s' 未找到" % [LOG_TAG, container.name])


# ============================================================
# 生命周期清理
# ============================================================

func _exit_tree() -> void:
	# 断开 signal
	if _signal_connected and PlayerState.has_signal("player_stat_changed"):
		if PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
			PlayerState.player_stat_changed.disconnect(_on_player_stat_changed)

	# 清空所有 binding（不 free 外部数据）
	_bindings.clear()
	_signal_connected = false

	Logging.info("%s: _exit_tree — ShaderProgressManager 已清理" % LOG_TAG)
