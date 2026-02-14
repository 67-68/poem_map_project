class_name FloatingText extends Node2D

signal recycle_requested(text_instance)

@onready var label: RichTextLabel = $Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play(content, pos):
	position = pos
	scale = Vector2(0.4,0.4)
	modulate.a = 1
	show()

	label.text = content

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 1.5).from(position.y + 50)
	tw.parallel()
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(0.7,0.7), 0.4)
	tw.parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tw.tween_callback(on_finished)

func on_finished():
	recycle_requested.emit(self)
