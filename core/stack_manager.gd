class_name PopupQueue extends RefCounted

var is_playing: bool = false
var items: Array = []
var resolve_item: Callable
var stop_time := false

func add_item(item):
	Logging.info("Adding item to queue: %s" % str(item))
	items.append(item)
	if not is_playing:
		Logging.info("Queue was idle, starting animation for first item")
		play_animation()
	else: 
		Logging.warn('current is playing, if not play can be a state errorl; Check if SIGNAL is connected or MARK_AS_FINISHED is called')
		Logging.warn('you can emit signal: EventBus.event_confirmed[ONLY FOR EVENT SYSTEM] to continue')

func add_items(items_: Array):
	"""
	单个item不能是uuid, 需要是对象
	"""
	Logging.info("Adding multiple items to queue: %d items" % items_.size())
	items.append_array(items_)
	if not is_playing:
		Logging.info("Queue was idle, starting animation for first batch")
		play_animation()
	else:
		Logging.warn("Queue is playing, %d items queued for later processing" % items_.size())

func play_animation():
	Logging.info("Starting animation for queue item: %s" % str(items[0]))
	pause_time()
	# 默认play [0]
	is_playing = true
	resolve_item.call(items[0])
	
func _on_animation_finished():
	Logging.info("Animation finished, removing item from queue")
	items.pop_front()
	if items.is_empty():
		Logging.info("Queue is now empty, stopping animation and resuming time")
		start_time()
		is_playing = false
	else:
		Logging.info("Queue has %d remaining items, continuing with next" % items.size())
		play_animation()

func _init(resolve_item_: Callable, animation_finished_signal: Signal, stop_time_: bool = true):
	"""
	这里的item就是传入的item
	这个函数允许自己处理item, 例如发信号
	"""
	Logging.not_exists('stack manager',resolve_item_)
	resolve_item = resolve_item_
	stop_time = stop_time_

	if animation_finished_signal:
		animation_finished_signal.connect(_on_animation_finished)
	else:
		Logging.warn('没发现signal, 需要手动调用mark_as_finish')

func start_time():
	if stop_time: 
		Logging.info("Resuming time service")
		TimeService.play()
	else:
		Logging.debug("Time service not controlled by this queue")

func pause_time():
	if stop_time: 
		Logging.info("Pausing time service")
		TimeService.pause()
	else:
		Logging.debug("Time service not controlled by this queue")

func mark_as_finish():
	Logging.info("Manual finish called for current queue item")
	_on_animation_finished()
