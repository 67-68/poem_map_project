class_name StackManager extends AnimationPlayer

var is_playing: bool = false
var items: Array = []
var resolve_item: Callable
var stop_time := false

func add_item(item: PoetData):
	items.append(item)
	if not is_playing:
		play_animation()


func add_items(items_: Array):
	"""
	单个item不能是uuid, 需要是对象
	"""
	items.append_array(items_)
	if not is_playing:
		play_animation()

func play_animation():
	pause_time()
	# 默认play [0]
	is_playing = true
	resolve_item.call(items[0])
	
func _on_animation_finished():
	items.pop_at(0)
	if items.is_empty():
		start_time()
		is_playing = false
	else:
		play_animation()

func _init(resolve_item_: Callable, animation_finished_signal: Signal, stop_time_: bool = true):
	"""
	这里的item就是传入的item
	这个函数允许自己处理item, 例如发信号
	"""
	Logging.exists('stack manager',resolve_item_)
	resolve_item = resolve_item_
	stop_time = stop_time_
	animation_finished_signal.connect(_on_animation_finished)

func start_time():
	if stop_time: TimeService.play()
func pause_time():
	if stop_time: TimeService.pause()