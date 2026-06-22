class_name ShaderProgressData extends RefCounted
##  Shader 进度数据模型 — 描述属性到 shader parameter 的映射
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

# ── 日志标签 ──────────────────────────────────────────────
const LOG_TAG := "ShaderProgressData"

# ── 基础字段 ──────────────────────────────────────────────
## PlayerState 属性名，如 "health"、"fatigue"
var target_property: String = ""
## .gdshader 资源
var shader_resource: Shader = null
## 所有被驱动的 shader parameter 名，共用同一 progress 值
var shader_parameter_names: Array[String] = []
## true → 属性值越高 progress 越低（如 health 越低 frost 越重）
var property_progress_inverted: bool = false
## progress=1.0 对应的属性值（"终点"）
var target_property_value: float = 100.0
## progress=0.0 对应的属性值（"起点"）
var start_property_value: float = 0.0
## 目标控件，其 material 属性将被设置为 ShaderMaterial
var container: Control = null

# ============================================================
# 公共方法
# ============================================================

## 根据当前属性值计算 0.0~1.0 的进度值
##
## 公式:
##   raw = (current_val - start) / (target - start)
##   clamped = clamp(raw, 0.0, 1.0)
##   return 1.0 - clamped if inverted else clamped
##
## 除零保护: target == start 时返回 0.0
func compute_progress(current_val: float) -> float:
	var range_val := target_property_value - start_property_value
	if is_zero_approx(range_val):
		Logging.warn("%s: compute_progress — target == start (%.1f), 返回 0.0" % [LOG_TAG, target_property_value])
		return 0.0

	var raw := (current_val - start_property_value) / range_val
	var clamped := clampf(raw, 0.0, 1.0)

	if property_progress_inverted:
		return 1.0 - clamped
	return clamped
