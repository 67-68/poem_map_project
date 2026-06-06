@tool
class_name CinematicOverlay extends CanvasLayer

signal finished()

## 打字机速度（秒/字）
@export var typewriter_speed: float = 0.05
## 淡入淡出时长
@export var fade_duration: float = 0.5
## 每段文字播完后的额外停留时间
@export var text_pause_duration: float = 1.5

@onready var dimmer: ColorRect = $Dimmer
@onready var text_label: RichTextLabel = $TextLabel

var _tween: Tween
var _is_playing: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	hide()
	EventBus.cinematic_start.connect(_on_cinematic_start)


func _on_cinematic_start(texts: Array[String]) -> void:
	Logging.info("CinematicOverlay: 收到过场请求，%d 段文字" % texts.size())
	if _is_playing:
		Logging.warn("CinematicOverlay: 正在播放中，忽略重复请求")
		return
	await play_text_sequence(texts)
	Logging.info("CinematicOverlay: 过场播放完毕")
	EventBus.cinematic_finished.emit()


## 公开 API：播放一段过场文字序列
## texts: 文字数组，每段依次显示
## config: 可选配置字典，支持 typewriter_speed, fade_duration, text_pause_duration
func play_text_sequence(texts: Array[String], config: Dictionary = {}) -> void:
	if texts.is_empty():
		Logging.warn("CinematicOverlay: texts 为空，跳过播放")
		return
	
	_is_playing = true
	
	# 合并配置
	var ts: float = config.get("typewriter_speed", typewriter_speed)
	var fd: float = config.get("fade_duration", fade_duration)
	var tpd: float = config.get("text_pause_duration", text_pause_duration)
	
	# 显示并淡入
	show()
	dimmer.modulate.a = 0.0
	text_label.modulate.a = 0.0
	await _fade_in(fd)
	
	# 逐段播放
	for i in range(texts.size()):
		var text: String = texts[i]
		
		# 打字机效果
		text_label.text = ""
		text_label.show()
		await _typewrite(text, ts)
		
		# 停留
		if tpd > 0.0:
			await get_tree().create_timer(tpd).timeout
		
		# 非最后一段：淡出再淡入显示下一段
		if i < texts.size() - 1:
			await _swap_text(fd)
	
	# 全部播完，淡出
	await _fade_out(fd)
	hide()
	text_label.text = ""
	text_label.hide()
	
	_is_playing = false
	finished.emit()


func _typewrite(full_text: String, speed: float) -> void:
	if speed <= 0.0 or full_text.is_empty():
		text_label.text = full_text
		return
	
	# 按字符逐个追加
	for i in range(full_text.length()):
		text_label.text = full_text.left(i + 1)
		if speed > 0.0:
			await get_tree().create_timer(speed).timeout


func _fade_in(duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(dimmer, "modulate:a", 1.0, duration)
	_tween.tween_property(text_label, "modulate:a", 1.0, duration)
	await _tween.finished


func _fade_out(duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(dimmer, "modulate:a", 0.0, duration)
	_tween.tween_property(text_label, "modulate:a", 0.0, duration)
	await _tween.finished


func _swap_text(duration: float) -> void:
	# 淡出旧文字
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(text_label, "modulate:a", 0.0, duration * 0.5)
	await _tween.finished
	
	text_label.text = ""
	
	# 淡入新文字
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(text_label, "modulate:a", 1.0, duration * 0.5)
	await _tween.finished
