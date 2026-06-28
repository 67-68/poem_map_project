class_name AbstractConcept
extends Area2D

## 抽象概念节点 — SubViewport 中表示一个 ImaginaryTag 大概念
## 每一个 AbstractConcept 是一个轨道圆心，DetailImaginary 绕其旋转
## 左键：提交意象给诗词创作；右键：合并坍缩碎片

## Tier 色彩常量
const TIER_COLORS := {
	1: Color(0.3, 0.3, 0.25, 1.0),    # T1 世俗污染 — 灰暗铜臭
	2: Color(0.45, 0.15, 0.1, 1.0),   # T2 沉重诗史 — 暗红铁锈
	3: Color(0.7, 0.85, 1.0, 1.0),    # T3 高洁绝唱 — 霜白青蓝
}
const MERGE_READY_COLOR := Color(1.0, 0.9, 0.5, 1.0)  # 暖金闪烁

## 关联的 ImaginaryTag
var imaginary_tag: ImaginaryTag

## 左键点击信号 — 提交意象
signal concept_selected(imaginary_tag: ImaginaryTag)
## 右键点击信号 — 请求合并
signal concept_merge_requested(imaginary_tag: ImaginaryTag)
## 合并动画完成信号
signal merge_animation_finished(imaginary_tag: ImaginaryTag)

var _blink_tween: Tween = null
var _original_modulate: Color

@export var concept_name: String = "":
	set(value):
		concept_name = value
		if is_inside_tree():
			_apply_label()

func _ready() -> void:
	_original_modulate = modulate
	_apply_label()
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			concept_selected.emit(imaginary_tag)
		MOUSE_BUTTON_RIGHT:
			concept_merge_requested.emit(imaginary_tag)

func _apply_label() -> void:
	var label := get_node_or_null("Label") as Label
	if not label:
		Logging.warn("AbstractConcept: Label child not found")
		return
	label.text = concept_name

# ──────────────────────────────────────────────
# 合并就绪闪烁
# ──────────────────────────────────────────────

func start_merge_ready_blink() -> void:
	_stop_blink()
	_blink_tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_blink_tween.tween_property(self, "modulate", MERGE_READY_COLOR, 0.6)
	_blink_tween.tween_property(self, "modulate", _original_modulate, 0.6)

func stop_merge_ready_blink() -> void:
	_stop_blink()

func _stop_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
		_blink_tween = null
	modulate = _original_modulate

# ──────────────────────────────────────────────
# 合并坍缩动画（异步）
# ──────────────────────────────────────────────

## 播放合并动画：吸入碎片 → 色彩过渡到目标 tier
## target_tier: 合并后的目标 tier（不修改 ImaginaryTag，仅用于颜色）
## 调用方 await 此方法，或连接 merge_animation_finished 信号
func play_merge_animation(target_tier: int = 0) -> void:
	stop_merge_ready_blink()

	# Phase 1: 吸入所有子节点中的 OrbitDetail
	var details: Array[OrbitDetail] = []
	for child in get_children():
		if child is OrbitDetail:
			details.append(child)

	if details.size() > 0:
		for d in details:
			d.play_suck_animation()
		await get_tree().create_timer(0.4).timeout

	# Phase 2: 色彩过渡到 tier 颜色
	if target_tier > 0:
		var target_color = TIER_COLORS.get(target_tier, _original_modulate)
		var tw := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(self, "modulate", target_color, 0.5)
		await tw.finished

	emit_signal("merge_animation_finished", imaginary_tag)


## 根据 tier 获取对应的颜色
static func get_tier_color(tier: int) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)
