extends Node

var start_year := 720.0
var end_year := 907.0
var time_span := end_year - start_year

var year: float
var ratio_time: float = 0
var mood: float = 0.5

var sad_color: Color = Color.DARK_BLUE
var happy_color: Color = Color.LIGHT_YELLOW

var current_selected_poet: PoetData

# view
var slider_light_speed: int = 1
var color_2_province: Dictionary

var map: Node2D
var faction_renderer: FactionMapRenderer

var poem_stack_manager: PopupQueue
var poem_buffer: ManualBuffer
var event_popup_queue: PopupQueue
var event_buffer: ManualBuffer
var chat_buffer: ManualBuffer


func _ready() -> void:
	init_buffers()


func init_buffers() -> void:
	event_popup_queue = PopupQueue.new(
		func(x): EventBus.request_event.emit(x, {}),
		EventBus.event_confirmed
	)
	event_buffer = ManualBuffer.new(
		event_popup_queue.add_item,
		Database.history_events.values()
	)

	poem_stack_manager = PopupQueue.new(
		_apply_poem_data,
		EventBus.poem_animation_finished
	)
	poem_buffer = ManualBuffer.new(
		poem_stack_manager.add_item,
		Database.poem_data.values()
	)

	chat_buffer = ManualBuffer.new(
		func(item): EventBus.request_add_chat.emit(item),
		[]
	)
	if Database.chat_bubble_data:
		chat_buffer.add_items(
			Database.chat_bubble_data.values() + Database.focused_chat_data.values()
		)


static func _apply_poem_data(_poem_data: PoemData) -> void:
	#var poet_data_ = Database.poet_data[_poem_data.owner_uuids[0]]
	#EventBus.request_apply_poem.emit(_poem_data, poet_data_)
	pass

func test_change_literary_fame(num: int) -> void:
	PlayerState.append_stat("literary_fame", num)
