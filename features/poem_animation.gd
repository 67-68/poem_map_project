extends AnimationPlayer

var is_playing: bool = false
var poems: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func add_poem(poem: PoetData):
	poems.append(poem)
	if not is_playing:
		play_poem_animation()


func add_poems(poems: Array[PoemData]):
	poems.append_array(poems)
	if not is_playing:
		play_poem_animation()

func play_poem_animation():
	# 默认play [0]
	is_playing = true
	_apply_poem_data(poems[0])
	play('poem_created')
	

func _apply_poem_data(poem_data: PoemData):
	"""
	把poem data设置到view中
	"""
	Logging.err('apply poem data 这里还没做!')
	

func _on_animation_finished(args):
	poems.pop_at(0)
	if poems.is_empty():
		is_playing = false
	else:
		play_poem_animation()



