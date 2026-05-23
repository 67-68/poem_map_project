@tool
extends Control

@export var maximize := false:
	set(value):
		if value:
			maximize = false
			size = Vector2(909,500)
			position = Vector2(121,50)

@export var minimize := false:
	set(value):
		if value:
			minimize = false
			size = Vector2(103,47)
			position = Vector2(520,565)
			

var expand := false

func _ready() -> void:
	hide()
	EventBus.poem_start_clicked.connect(func(): 
		if not expand:
			show_page()
		else: hide_page()
	)

func show_page():
	show()
	expand = true
	var tween := create_tween()
	tween.tween_property(self, "size", Vector2(909,500), 0.5)
	tween.parallel().tween_property(self, "position", Vector2(121,50), 0.5)

func hide_page():
	var tween := create_tween()
	tween.tween_property(self, "size", Vector2(103,47), 0.5)
	tween.parallel().tween_property(self, "position", Vector2(520,565), 0.5)
	tween.tween_callback(func(): 
		expand = false
		hide()
	)
