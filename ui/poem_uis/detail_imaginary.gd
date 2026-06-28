class_name OrbitDetail
extends Node2D

## 椭圆轨道节点 — 围绕一个 AbstractConcept（Area2D）做椭圆轨道运动
## 使用绝对坐标重载策略，拒绝浮点误差累积 🤓☝️

@export_group("Orbit Parameters")
@export var center_target: Node2D      ## 绕行的圆心目标（通常是 AbstractConcept）
@export var semi_major_axis: float = 80.0   ## 椭圆长轴半径
@export var semi_minor_axis: float = 60.0   ## 椭圆短轴半径
@export var orbit_speed: float = 1.0        ## 角速度 (ω)
@export var phase_offset: float = 0.0       ## 初始相位角 (φ)

var _orbit_time: float = 0.0
var _sucking: bool = false  ## 正在执行吸入动画

func _process(delta: float) -> void:
	if _sucking:
		return
	if not center_target or not is_instance_valid(center_target):
		return

	# 唯一的状态累加器，拒绝位置增量叠加
	_orbit_time += delta * orbit_speed

	# 绝对坐标重载，把命根子捏在三角函数手里 🤓☝️
	var offset_x = semi_major_axis * cos(_orbit_time + phase_offset)
	var offset_y = semi_minor_axis * sin(_orbit_time + phase_offset)

	global_position = center_target.global_position + Vector2(offset_x, offset_y)


## 吸入动画：飞向中心 → 缩小 → 淡出
func play_suck_animation() -> void:
	_sucking = true
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(self, "position", Vector2.ZERO, 0.35)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()


## 设置 Label 文本（用于显示详细意象）
func set_detail_text(text: String) -> void:
	var label := get_node_or_null("Label") as Label
	if not label:
		Logging.warn("OrbitDetail: Label child not found")
		return
	label.text = text
