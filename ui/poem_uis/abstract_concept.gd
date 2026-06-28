class_name AbstractConcept
extends Area2D

## 抽象概念节点 — SubViewport 中表示一个 ImaginaryTag 大概念
## 每一个 AbstractConcept 是一个轨道圆心，DetailImaginary 绕其旋转
## 左键：提交意象给诗词创作；右键：合并坍缩碎片

## 关联的 ImaginaryTag
var imaginary_tag: ImaginaryTag

## 左键点击信号 — 提交意象
signal concept_selected(imaginary_tag: ImaginaryTag)
## 右键点击信号 — 请求合并
signal concept_merge_requested(imaginary_tag: ImaginaryTag)

@export var concept_name: String = "":
	set(value):
		concept_name = value
		if is_inside_tree():
			_apply_label()

func _ready() -> void:
	_apply_label()
	# 连接输入事件
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
