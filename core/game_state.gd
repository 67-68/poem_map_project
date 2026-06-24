extends Node

## 🆕 游戏结束状态锁。当 system_operator 触发 game_over 时设为 true，
## 用于阻止后续事件继续触发/推送。
var is_game_over: bool = false

## 🆕 死亡原因文本。由 main.gd 在接收到 show_tombstone_screen 信号后写入，
## 供 tomb_stone_screen.tscn（独立场景）在 _ready() 中跨场景读取。
var death_cause: String = ""

var start_year := 745.0
var end_year := 755.9
var time_span := end_year - start_year

var year: float
## 当前时代标识（如 "ambition", "decline"）。
## 空字符串表示无时代限制（所有 era="" 通用事件可用）。
## 由 EraOperator 控制切换，用于 EventManager 事件池 era 过滤。
var current_era: String = "":
	set(val):
		current_era = val
		Logging.info('current era change to' % val)
	
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
		Database.get_history_events_all().values()
	)

	poem_stack_manager = PopupQueue.new(
		_apply_poem_data,
		EventBus.poem_animation_finished
	)
	poem_buffer = ManualBuffer.new(
		poem_stack_manager.add_item,
		Database.get_poem_data_all().values()
	)

	chat_buffer = ManualBuffer.new(
		func(item):
			# FocusedChat 走 NarrativeOverlay 栈系统，ChatBubble 走 PopupQueue
			if item is FocusedChat:
				EventBus.push_focused_chat.emit(item, {})
			else:
				EventBus.request_add_chat.emit(item),
		[]
	)
	if Database.get_chat_bubbles_all():
		chat_buffer.add_items(
			Database.get_chat_bubbles_all().values() + Database.get_focused_chats_all().values()
		)


static func _apply_poem_data(_poem_data: PoemData) -> void:
	#var poet_data_ = Database.poet_data[_poem_data.owner_uuids[0]]
	#EventBus.request_apply_poem.emit(_poem_data, poet_data_)
	pass

func test_change_literary_fame(num: int) -> void:
	PlayerState.append_stat("literary_fame", num)
