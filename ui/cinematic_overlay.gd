@tool
class_name CinematicOverlay extends CanvasLayer

signal finished()

## 打字机速度（秒/字）
@export var typewriter_speed: float = 0.08
## 淡入淡出时长（冷酷切换 = 0.0）
@export var fade_duration: float = 0.0
## 每段文字播完后的额外停留时间
@export var text_pause_duration: float = 2.5

@onready var dimmer: ColorRect = $Dimmer
@onready var text_label: RichTextLabel = $TextLabel

var _tween: Tween
var _is_playing: bool = false
var _skip_requested: bool = false
var _current_timer: Timer = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.cinematic_start.connect(_on_cinematic_start)


## 捕获 Cmd+Space 快捷键，跳过正在播放的过场
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and event.meta_pressed:
		if _is_playing and not _skip_requested:
			_skip()


## 跳过当前过场：加速完成正在运行的动画和定时器，
## 配合各方法中的 _skip_requested 检查实现干净退出
func _skip() -> void:
	_skip_requested = true
	Logging.info("CinematicOverlay: 用户跳过过场")
	# 将当前 tween 加速到瞬间完成（触发 finished 信号，解除依赖它的 await）
	if _tween and _tween.is_valid():
		_tween.speed_scale = 999999.0
	# 将当前 timer 的等待时间归零（下帧立即 timeout）
	if _current_timer:
		_current_timer.wait_time = 0.0


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
	_skip_requested = false
	
	# 合并配置
	var ts: float = config.get("typewriter_speed", typewriter_speed)
	var fd: float = config.get("fade_duration", fade_duration)
	var tpd: float = config.get("text_pause_duration", text_pause_duration)
	
	# 显示并淡入
	show()
	dimmer.modulate.a = 0.0
	text_label.modulate.a = 0.0
	await _fade_in(fd)
	if _skip_requested:
		_cleanup_after_skip()
		return
	
	# 逐段播放
	for i in range(texts.size()):
		if _skip_requested:
			break
		
		var text: String = texts[i]
		
		# 打字机效果
		text_label.text = ""
		text_label.show()
		await _typewrite(text, ts)
		if _skip_requested:
			break
		
		# 停留（使用 pause-proof 定时器）
		if tpd > 0.0:
			await _wait_seconds(tpd)
			if _skip_requested:
				break
		
		# 非最后一段：淡出再淡入显示下一段
		if i < texts.size() - 1:
			await _swap_text(fd)
			if _skip_requested:
				break
	
	# 全部播完，淡出
	if not _skip_requested:
		await _fade_out(fd)
	
	_cleanup_after_skip()


## 跳过或自然结束后的统一清理
func _cleanup_after_skip() -> void:
	hide()
	text_label.text = ""
	text_label.hide()
	_is_playing = false
	_skip_requested = false
	finished.emit()


func _typewrite(full_text: String, speed: float) -> void:
	if speed <= 0.0 or full_text.is_empty():
		text_label.text = full_text
		return
	
	# 按字符逐个追加
	for i in range(full_text.length()):
		if _skip_requested:
			text_label.text = full_text
			return
		text_label.text = full_text.left(i + 1)
		if speed > 0.0:
			await _wait_seconds(speed)
			if _skip_requested:
				text_label.text = full_text
				return


func _wait_seconds(seconds: float) -> void:
	## 创建一个不受世界暂停影响的定时器
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.start()
	_current_timer = timer
	await timer.timeout
	_current_timer = null
	timer.queue_free()


func _fade_in(duration: float) -> void:
	if duration <= 0.0:
		dimmer.modulate.a = 1.0
		text_label.modulate.a = 1.0
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(dimmer, "modulate:a", 1.0, duration)
	_tween.tween_property(text_label, "modulate:a", 1.0, duration)
	await _tween.finished
	if _skip_requested:
		dimmer.modulate.a = 1.0
		text_label.modulate.a = 1.0


func _fade_out(duration: float) -> void:
	if duration <= 0.0:
		dimmer.modulate.a = 0.0
		text_label.modulate.a = 0.0
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(dimmer, "modulate:a", 0.0, duration)
	_tween.tween_property(text_label, "modulate:a", 0.0, duration)
	await _tween.finished
	if _skip_requested:
		dimmer.modulate.a = 0.0
		text_label.modulate.a = 0.0


func _swap_text(duration: float) -> void:
	if duration <= 0.0:
		text_label.text = ""
		return
	# 淡出旧文字
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(text_label, "modulate:a", 0.0, duration * 0.5)
	await _tween.finished
	if _skip_requested:
		text_label.modulate.a = 0.0
		text_label.text = ""
		return
	
	text_label.text = ""
	
	# 淡入新文字
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(text_label, "modulate:a", 1.0, duration * 0.5)
	await _tween.finished
	if _skip_requested:
		text_label.modulate.a = 1.0
