extends Control

var tw: Tween
var original_position: Vector2

func on_text_popup(text: String):
	reset()
	$Con/TextLabel.text = text
	$Con/TextLabel.fit_content = true
	$Con.clip_contents = true
	var combined_size = self.get_combined_minimum_size()
	custom_minimum_size[1] = combined_size[1]

	SizeService.enlarge($Con/TextLabel)
	show()
	tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self,'custom_minimum_size:x',combined_size[0],0.5)
	tw.parallel().tween_property(self,'position',position,0.5).from(position + Vector2(0,10))
	
	tw.tween_interval(3)
	tw.tween_callback(hide)

func reset():
	custom_minimum_size = Vector2.ZERO
	if tw: tw.kill()
	position = original_position


func _ready() -> void:
	Global.request_text_popup.connect(on_text_popup)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	original_position = position
	hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
