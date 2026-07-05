class_name AbstractConcept
extends Area2D

## 抽象概念节点 — SubViewport 中表示一个可选意象的可视化节点
##
## V7 变更: 解除 ImaginaryConcept 强绑定，改为可配置的 data 对象。
## 调用方设置 display_name + data，信号携带 data。
## 不再有合并/坍缩/merge_animation/Tier 相关逻辑。

## Tier 色彩常量（保留用于可配置颜色）
const TIER_COLORS := {
	1: Color(0.3, 0.3, 0.25, 1.0),
	2: Color(0.45, 0.15, 0.1, 1.0),
	3: Color(0.7, 0.85, 1.0, 1.0),
}

## 关联的数据对象（可以是 Imaginary 或其他任意对象）
var data: Variant = null

## 左键点击信号 — 提交
signal concept_selected(data: Variant)
## 右键点击信号 — 备选操作
signal concept_alternate(data: Variant)

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
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			AudioManager.play_sfx_category("leather")
			concept_selected.emit(data)
		MOUSE_BUTTON_RIGHT:
			AudioManager.play_sfx_category("stone_throw_in_lake")
			concept_alternate.emit(data)


func _on_mouse_entered() -> void:
	var hover_color := modulate.lerp(Color.WHITE, 0.25)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate", hover_color, 0.12)


func _on_mouse_exited() -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate", _original_modulate, 0.15)


func _apply_label() -> void:
	var label := get_node_or_null("Label") as Label
	if not label:
		Logging.warn("AbstractConcept: Label child not found")
		return
	label.text = concept_name


## 根据 tier 获取对应的颜色
static func get_tier_color(tier: int) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)
