class_name AbstractConcept
extends Area2D

## 抽象概念节点 — SubViewport 中表示一个 ImaginaryTag 大概念
## 每一个 AbstractConcept 是一个轨道圆心，DetailImaginary 绕其旋转

@export var concept_name: String = "":
	set(value):
		concept_name = value
		if is_inside_tree():
			_apply_label()

func _ready() -> void:
	_apply_label()

func _apply_label() -> void:
	var label := get_node_or_null("Label") as Label
	if not label:
		Logging.warn("AbstractConcept: Label child not found")
		return
	label.text = concept_name
