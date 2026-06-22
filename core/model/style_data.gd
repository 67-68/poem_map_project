class_name StyleData extends RefCounted
## 视觉风格数据模型 — 描述属性到 shader parameter + StyleBox 的映射
##
## 用法:
##   var data = StyleData.new()
##   data.strategy_name = "frost"
##   data.target_property = "health"
##   data.shader_resource = preload("res://shaders/frost.gdshader")
##   data.shader_parameter_names = ["freeze_progress"]
##   data.start_property_value = 100.0   # 起点
##   data.target_property_value = 0.0    # 终点（反向：血越少 progress 越高）
##   data.container = $TapeContainer
##   StyleManager.bind(data)

const LOG_TAG := "StyleData"

# ── 策略标识 ──────────────────────────────────────────────
## 策略名称（唯一标识），如 "frost"、"decay_dirt_crack"
## 首次 bind 时若非空会自动激活此策略
## 可通过 StyleManager.switch_strategy(container, name) 切换
var strategy_name: String = ""

# ── 属性驱动 ──────────────────────────────────────────────
## PlayerState 属性名，如 "health"、"distance"
var target_property: String = ""
## progress=0.0 对应的属性值（"起点"）
var start_property_value: float = 0.0
## progress=1.0 对应的属性值（"终点"）
## 若 target < start，则方向自然反转（如 start=100, target=0 → 属性越低 progress 越高）
var target_property_value: float = 100.0

# ── Shader 材质 ───────────────────────────────────────────
## .gdshader 资源（若 shader_material 已预先提供可为 null）
var shader_resource: Shader = null
## 可选：预制 ShaderMaterial（含 noise 纹理等默认参数）
## 若提供，会直接使用此材质，不根据 shader_resource 另建
var shader_material: ShaderMaterial = null
## 被驱动的 shader parameter 名列表，所有 param 共用同一 progress 值
var shader_parameter_names: Array[String] = []

# ── Progress 输出映射 ────────────────────────────────────
## shader progress 参数输出区间下限 (0.0~1.0)
## 某些 shader 只在特定范围内有效果，如 decay_dirt_crack 仅在 [0.27, 0.326]
## compute_progress() 计算出 0.0~1.0 后，会 remap 到此区间再写入 shader
var progress_output_min: float = 0.0
## shader progress 参数输出区间上限 (0.0~1.0)
var progress_output_max: float = 1.0

# ── StyleBox ────────────────────────────────────────────────
## 策略激活时直接替换整个 StyleBox（仅对 PanelContainer 生效）
## 通过 container.set("theme_override_styles/panel", data.stylebox) 整块替换
## null → 不修改 StyleBox
var stylebox: StyleBox = null
## 是否在 bind() 时立即应用 stylebox（而非等待 switch_strategy 事件触发）
var stylebox_active_on_bind: bool = false

# ── Theme Type Variation ─────────────────────────────────
## 叙事文本 theme_type_variation，应用于 RichTextLabel
## 替换原有 "NarrativeText" variation 或无 variation 的 RichTextLabel
var narrative_text_theme: String = ""
## 标题文本 theme_type_variation，应用于 Label
## 替换原有 "TitleText" variation 的 Label
var title_text_theme: String = ""
## 内心独白 theme_type_variation，应用于 RichTextLabel
## 替换原有 "InnerThought" variation 的 RichTextLabel
var inner_thought_theme: String = ""
## 默认文本 theme_type_variation，应用于 Label
## 替换原有 "DefaultText" variation 或无 variation 的 Label
var default_text_theme: String = ""

# ── 目标控件 ──────────────────────────────────────────────
## 目标节点，其 material 属性将被注入 ShaderMaterial
## 若为 PanelContainer 且 stylebox 非 null，还会替换其 theme_override_styles/panel
var container: Control = null

# ============================================================
# 公共方法
# ============================================================

## 根据当前属性值计算 0.0~1.0 的进度值
##
## 公式:
##   range = target - start （可为负）
##   raw = (current_val - start) / range
##   clamped = clamp(raw, 0.0, 1.0)
##
## start=0, target=100 → 属性越高 progress 越高
## start=100, target=0 → 属性越低 progress 越高（自然反向，无需 inverted 标志）
##
## 除零保护: target == start 时返回 0.0
func compute_progress(current_val: float) -> float:
	var range_val := target_property_value - start_property_value
	if is_zero_approx(range_val):
		Logging.warn("%s: compute_progress — target == start (%.1f), 返回 0.0" % [LOG_TAG, target_property_value])
		return 0.0

	var raw := (current_val - start_property_value) / range_val
	var clamped := clampf(raw, 0.0, 1.0)
	return clamped


## 将 compute_progress() 的 0→1 结果 remap 到 [output_min, output_max] 区间
##
## 当 progress_output_min == progress_output_max 时返回 output_min
func compute_progress_remapped(current_val: float) -> float:
	var raw_progress := compute_progress(current_val)
	return lerpf(progress_output_min, progress_output_max, raw_progress)


## 从另一个 StyleData 复制字段（用于 default 快照）
func copy_from(other: StyleData) -> void:
	if other == null:
		return
	strategy_name = other.strategy_name
	target_property = other.target_property
	start_property_value = other.start_property_value
	target_property_value = other.target_property_value
	progress_output_min = other.progress_output_min
	progress_output_max = other.progress_output_max
	shader_resource = other.shader_resource
	shader_material = other.shader_material
	shader_parameter_names = other.shader_parameter_names.duplicate()
	stylebox = other.stylebox
	stylebox_active_on_bind = other.stylebox_active_on_bind
	narrative_text_theme = other.narrative_text_theme
	title_text_theme = other.title_text_theme
	inner_thought_theme = other.inner_thought_theme
	default_text_theme = other.default_text_theme
	container = other.container
