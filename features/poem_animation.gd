extends AnimationPlayer

var is_playing: bool = false
var poems: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.poems_created.connect(add_poems)
	Global.poem_animation_finished.connect(self._on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func add_poem(poem: PoetData):
	poems.append(poem)
	if not is_playing:
		play_poem_animation()


func add_poems(poems_: Array):
	for p in poems_:
		poems.append(Global.poem_data[p])
	if not is_playing:
		play_poem_animation()
			
func _apply_poem_data(_poem_data: PoemData):
	"""
	把poem data设置到view中
	"""
	var poet_data = Global.poet_data[_poem_data.owner_uuids[0]]
	Global.request_apply_poem.emit(_poem_data, poet_data)

func play_poem_animation():
	TimeService.pause()
	# 默认play [0]
	is_playing = true
	_apply_poem_data(poems[0])
	
func _on_animation_finished():
	poems.pop_at(0)
	if poems.is_empty():
		TimeService.play()
		is_playing = false
	else:
		play_poem_animation()
