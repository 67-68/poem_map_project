extends Node
const _ChatBubble = preload("res://model/chat_bubble.gd")
const _EraOperator = preload("res://core/operators/era_operator.gd")
const _FactionMapRenderer = preload("res://core/faction_map_renderer.gd")
const _FocusedChat = preload("res://model/focused_chat.gd")
const _ManualBuffer = preload("res://core/manual_buffer.gd")
const _NarrativeOverlay = preload("res://characters/narrative_overlay.gd")
const _PoetData = preload("res://characters/poet_data.gd")
const _PopupQueue = preload("res://core/stack_manager.gd")

# ════════════════════════════════════════════════════════════════
# 持久化状态 — 代理到 GameSave.data
# ════════════════════════════════════════════════════════════════

var is_game_over: bool:
	get: return GameSave.data.is_game_over
	set(val): GameSave.data.is_game_over = val

var death_cause: String:
	get: return GameSave.data.death_cause
	set(val): GameSave.data.death_cause = val

## year — 由 TimeService 驱动写入
var year: float:
	get: return GameSave.data.year
	set(val): GameSave.data.year = val

## current_era — setter 需清零 progress 并记日志
var current_era: String:
	get: return GameSave.data.current_era
	set(val):
		GameSave.data.current_era = val
		PlayerState.set_stat_val(ENUMS.PROPS.PROGRESS, 0)
		Logging.info('current era changed to: %s' % val)

var ratio_time: float:
	get: return GameSave.data.ratio_time
	set(val): GameSave.data.ratio_time = val

var event_counter: int:
	get: return GameSave.data.event_counter
	set(val): GameSave.data.event_counter = val

var mood: float:
	get: return GameSave.data.mood
	set(val): GameSave.data.mood = val


# ════════════════════════════════════════════════════════════════
# 常量 / 非持久化字段（保持原样）
# ════════════════════════════════════════════════════════════════

const start_year := 745.0
const end_year := 755.9
var time_span := end_year - start_year

var sad_color: Color = Color.DARK_BLUE
var happy_color: Color = Color.LIGHT_YELLOW

var current_selected_poet: PoetData

# view
var slider_light_speed: int = 1
var color_2_province: Dictionary

var map: Node2D
var faction_renderer: FactionMapRenderer

# buffer（含 Callable，不可序列化）
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
	if not Database:
		Logging.err("game_state: Database autoload not ready in init_buffers, using empty list")
		event_buffer = ManualBuffer.new(event_popup_queue.add_item, [])
	else:
		event_buffer = ManualBuffer.new(
			event_popup_queue.add_item,
			Database.get_history_events_all().values()
		)

	chat_buffer = ManualBuffer.new(
		func(item):
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


func test_change_prestige(num: int) -> void:
	PlayerState.append_stat("prestige", num)
