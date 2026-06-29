# AudioManager.gd (完整版)
extends Node
const _Util = preload("res://core/util.gd")
const _PropertySoundMapper = preload("res://core/property_sound_mapper.gd")

const LOG_TAG := "AudioManager"

# ── 音效类别缓存 ──
# 在 _ready() 时扫描 assets/sounds/ 下的一级子目录，预加载所有音效
# 每个子目录名 = 类别名，例如: "click" → [AudioStream, AudioStream, ...]
var _sfx_category_cache: Dictionary = {}
const SFX_ROOT: String = "res://assets/sounds"

# ── 属性音效播放间隔控制 ──
# 连续属性变化时，两次播放至少间隔 0.4s，避免音效同时盖过
const PROPERTY_SOUND_COOLDOWN: float = 0.4
var _last_property_sound_time: float = 0.0

# BGM 轨道
var _bgm_track_1: AudioStreamPlayer
var _bgm_track_2: AudioStreamPlayer
var _current_bgm_track: int = 1

# SFX 池子
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8 # 8个声道足够应付大多数 UI 情况了

# ── Loop 播放器（独立，不占用 SFX 池）──
var _loop_player: AudioStreamPlayer

# ── Ambient System（环境背景音）──
var _ambient_active: bool = false
var _ambient_paused: bool = false
var _ambient_layers: Array = []  # Array[AmbientLayer]
var _profiles: Dictionary = {}   # String -> Array[Dictionary] 注册的 profile
var _bgm_was_playing: bool = false  # _process() 边缘检测

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # 必须全天候运行！
	
	# 1. 初始化 BGM 轨道
	_bgm_track_1 = _create_player("BGM_1")
	_bgm_track_2 = _create_player("BGM_2")
	
	# 2. 初始化 SFX 池
	for i in range(SFX_POOL_SIZE):
		var p = _create_player("SFX_%d" % i)
		_sfx_pool.append(p)
	
	# 3. 初始化 Loop 播放器
	_loop_player = _create_player("SFX_Loop")
	
	# 4. 扫描 assets/sounds/ 子目录，预加载分类音效
	_load_sfx_categories()

# ── _process: 被动 BGM 互斥监控 ──
func _process(_delta: float) -> void:
	# 边缘检测：BGM 轨道状态变化时自动 pause/resume ambient
	var bgm_now_playing: bool = false
	if is_instance_valid(_bgm_track_1) and _bgm_track_1.playing:
		bgm_now_playing = true
	if is_instance_valid(_bgm_track_2) and _bgm_track_2.playing:
		bgm_now_playing = true
	
	if not _ambient_active:
		_bgm_was_playing = bgm_now_playing
		return
	
	if bgm_now_playing and not _bgm_was_playing:
		# BGM 从无到有 → pause ambient
		_pause_ambient_internal()
	elif not bgm_now_playing and _bgm_was_playing:
		# BGM 从有到无 → resume ambient
		_resume_ambient_internal()
	
	_bgm_was_playing = bgm_now_playing

# 辅助函数：创建播放器
func _create_player(node_name: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = "Master" # 以后你可以改成 "BGM" 或 "SFX" 总线来单独控制音量
	add_child(p)
	return p

# ---------------------------------------------------------
# BGM 逻辑 (保留之前的)
# ---------------------------------------------------------
func play_music(new_stream: AudioStream, fade_duration: float = 2.0):
	var active = _bgm_track_1 if _current_bgm_track == 1 else _bgm_track_2
	var next = _bgm_track_2 if _current_bgm_track == 1 else _bgm_track_1
	
	if active.stream == new_stream and active.playing: return
	
	# 下一首准备
	next.stream = new_stream
	next.volume_db = -80.0
	next.play()
	
	var tween = create_tween().set_parallel(true)
	# 淡出旧的
	if active.playing:
		tween.tween_property(active, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE)
	# 淡入新的
	tween.tween_property(next, "volume_db", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	
	tween.chain().tween_callback(active.stop)
	_current_bgm_track = 2 if _current_bgm_track == 1 else 1

# ---------------------------------------------------------
# SFX 逻辑 (新加的！)
# ---------------------------------------------------------
# pitch_scale: 音高偏移。强烈建议 UI 音效加上 0.9 ~ 1.1 的随机，防止听觉疲劳
func play_sfx(stream: AudioStream, pitch_randomness: float = 0.1, volume_db: float = 0.0):
	if not stream: return
	
	# 1. 找一个空闲的播放器
	var player = _get_available_sfx_player()
	
	# 如果所有声道都在忙（极其罕见），那就不播了，或者强制抢占第一个
	if not player: 
		# 抢占策略：在这个慢节奏游戏里，丢音效比截断音效要好，所以直接 return
		# 或者你可以选择 player = _sfx_pool[0]
		return 
		
	player.stream = stream
	player.volume_db = volume_db
	
	# 2. 注入灵魂：随机音高 🤓☝️
	# 这一步至关重要！否则连点按钮听起来像机关枪，加了随机就像真实的物理碰撞。
	if pitch_randomness > 0:
		player.pitch_scale = randf_range(1.0 - pitch_randomness, 1.0 + pitch_randomness)
	else:
		player.pitch_scale = 1.0
		
	player.play()

# ---------------------------------------------------------
# 音效类别系统 (支持按文件夹分类随机播放)
# ---------------------------------------------------------
# 扫描 assets/sounds/ 下的所有一级子目录，每个子目录名 = 类别名
# 把 .ogg / .wav / .mp3 预加载到分类缓存
func _load_sfx_categories() -> void:
	var INDEX_PATH = SFX_ROOT.path_join("_file_index.json")

	# 第一级：DirAccess 扫描（桌面端 / HTML5 都先试）
	var dir_count := _try_load_sfx_via_diraccess()
	Logging.info("%s: DirAccess 加载了 %d 个音效类别" % [LOG_TAG, _sfx_category_cache.size()])

	# 第二级：比较索引，索引文件数更多则用索引降级
	var index_files := Util.get_files_from_index(INDEX_PATH)
	# 统计当前所有类别的总文件数
	var total_loaded := 0
	for streams in _sfx_category_cache.values():
		total_loaded += (streams as Array).size()

	if index_files.size() > total_loaded:
		Logging.warn("%s: DirAccess 仅加载 %d 个音效文件，索引有 %d 个，降级到索引" % [LOG_TAG, total_loaded, index_files.size()])
		_sfx_category_cache.clear()
		_try_load_sfx_via_index(index_files)

	Logging.info("%s: 音效加载完成，共 %d 个类别" % [LOG_TAG, _sfx_category_cache.size()])


# DirAccess 扫描子目录，返回加载的类别数
func _try_load_sfx_via_diraccess() -> int:
	var root_dir = DirAccess.open(SFX_ROOT)
	if not root_dir:
		Logging.warn("%s: 音效目录不存在 [%s]" % [LOG_TAG, SFX_ROOT])
		return 0

	root_dir.list_dir_begin()
	var dir_name = root_dir.get_next()
	while dir_name != "":
		if dir_name.begins_with(".") or dir_name.ends_with(".import"):
			dir_name = root_dir.get_next()
			continue
		if not root_dir.current_is_dir():
			dir_name = root_dir.get_next()
			continue

		var category = dir_name
		_load_sfx_category(category)

		dir_name = root_dir.get_next()
	root_dir.list_dir_end()
	return _sfx_category_cache.size()


# 从 JSON 索引加载（HTML5 降级路径）
func _try_load_sfx_via_index(index_files: PackedStringArray) -> void:
	var category_map: Dictionary = {}  # String -> Array[String]
	for path in index_files:
		var slash_idx = path.find("/")
		if slash_idx <= 0:
			continue  # 根级文件（如 royal_music.mp3），跳过类别加载
		var category = path.substr(0, slash_idx)
		if not category_map.has(category):
			category_map[category] = []
		(category_map[category] as Array).append(path)

	for category in category_map:
		_load_sfx_category(category)


# 加载单个类别（DirAccess 和索引路径共用）
# 策略：DirAccess 优先；若 DirAccess 成功但 load() 全返回 null（HTML5 常见），
#       自动降级到索引路径逐个 load()
func _load_sfx_category(category: String) -> void:
	var streams: Array[AudioStream] = []
	var loaded_via_diraccess := false

	var cat_dir = DirAccess.open(SFX_ROOT.path_join(category))
	if cat_dir:
		cat_dir.list_dir_begin()
		var file_name = cat_dir.get_next()
		while file_name != "":
			if file_name.begins_with(".") or file_name.ends_with(".import"):
				file_name = cat_dir.get_next()
				continue
			var ext = file_name.get_extension().to_lower()
			if ext in ["ogg", "wav", "mp3"]:
				var full_path = SFX_ROOT.path_join(category).path_join(file_name)
				var stream = load(full_path)
				if stream:
					streams.append(stream)
				else:
					Logging.debug("%s: load() 返回 null: %s" % [LOG_TAG, full_path])
			file_name = cat_dir.get_next()
		cat_dir.list_dir_end()
		loaded_via_diraccess = not streams.is_empty()

	# DirAccess 失败或 load() 全部返回 null → 降级到索引路径
	if streams.is_empty():
		var index_files := Util.get_files_from_index(SFX_ROOT.path_join("_file_index.json"))
		for path in index_files:
			if path.begins_with(category + "/"):
				var ext = path.get_extension().to_lower()
				if ext in ["ogg", "wav", "mp3"]:
					var full_path = SFX_ROOT.path_join(path)
					var stream = load(full_path)
					if stream:
						streams.append(stream)
					else:
						Logging.debug("%s: load() 返回 null（索引路径）: %s" % [LOG_TAG, full_path])

	if not streams.is_empty():
		_sfx_category_cache[category] = streams
		var via_label := "DirAccess" if loaded_via_diraccess else "索引"
		Logging.info("%s: 已加载类别 [%s] → %d 个音效 (via %s)" % [LOG_TAG, category, streams.size(), via_label])
	else:
		Logging.info("%s: 类别 [%s] 为空，跳过" % [LOG_TAG, category])


# 从指定类别中随机选一个音效播放
# category: 对应 assets/sounds/ 下的子目录名
# 返回是否成功播放
func play_sfx_category(category: String, pitch_randomness: float = 0.1, volume_db: float = 0.0) -> bool:
	if category.is_empty():
		return false
	
	if not _sfx_category_cache.has(category):
		Logging.warn("%s: 未找到音效类别 [%s]，请确认 assets/sounds/%s/ 目录存在且包含音效文件" % [LOG_TAG, category, category])
		return false
	
	var streams = _sfx_category_cache[category] as Array[AudioStream]
	if streams.is_empty():
		Logging.warn("%s: 音效类别 [%s] 为空" % [LOG_TAG, category])
		return false
	
	# 随机选取一个
	var stream = streams[randi() % streams.size()]
	play_sfx(stream, pitch_randomness, volume_db)
	return true
# 获取类别缓存（暴露给外部调试用）
func get_sfx_category(category: String) -> Array[AudioStream]:
	return _sfx_category_cache.get(category, [])

# 获取所有已加载的类别名
func get_all_sfx_categories() -> Array[String]:
	return _sfx_category_cache.keys()


# ---------------------------------------------------------
# 属性变化音效 (Property Sound Effects)
# ---------------------------------------------------------
## 播放属性变化音效，带 0.4s 防重叠间隔
## 由 PropertyOperator 等 DSL 操作符在属性变化后调用
func play_property_sound(prop_name: String, delta: int) -> void:
	if delta == 0 or prop_name.is_empty():
		return

	# ── 0.4s 防重叠间隔 ──
	# 连续属性变化时，若上次播放不足 0.4s 前，跳过本次播放
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_property_sound_time < PROPERTY_SOUND_COOLDOWN:
		Logging.debug("%s: 属性音效被防重叠间隔跳过: prop=%s, delta=%d" % [LOG_TAG, prop_name, delta])
		return

	var stream := _PropertySoundMapper.get_property_sound(prop_name, delta)
	if stream:
		play_sfx(stream)
		_last_property_sound_time = now


## 播放意象升级音效，带 0.4s 防重叠间隔
func play_imaginary_sound(level: int) -> void:
	if level < 1 or level > 3:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_property_sound_time < PROPERTY_SOUND_COOLDOWN:
		Logging.debug("%s: 意象音效被防重叠间隔跳过: level=%d" % [LOG_TAG, level])
		return

	var stream := _PropertySoundMapper.get_imaginary_sound(level)
	if stream:
		play_sfx(stream)
		_last_property_sound_time = now

func play_sfx_loop(category: String, pitch_randomness: float = 0.0, volume_db: float = 0.0) -> bool:
	"""从类别随机选一个音效，用独立循环播放器无限循环。返回是否成功。"""
	if category.is_empty():
		return false
	if not _loop_player:
		Logging.warn("%s: _loop_player 未初始化" % LOG_TAG)
		return false
	if not _sfx_category_cache.has(category):
		Logging.warn("%s: 未找到音效类别 [%s]，无法循环" % [LOG_TAG, category])
		return false
	
	var streams = _sfx_category_cache[category] as Array[AudioStream]
	if streams.is_empty():
		return false
	
	var stream = streams[randi() % streams.size()]
	_loop_player.stream = stream
	_loop_player.volume_db = volume_db
	if pitch_randomness > 0:
		_loop_player.pitch_scale = randf_range(1.0 - pitch_randomness, 1.0 + pitch_randomness)
	else:
		_loop_player.pitch_scale = 1.0
	# 循环：使用 finished 信号重新 play
	if not _loop_player.finished.is_connected(_on_loop_finished):
		_loop_player.finished.connect(_on_loop_finished)
	_loop_player.play()
	return true


func stop_sfx_loop() -> void:
	"""停止循环播放器。"""
	if _loop_player:
		if _loop_player.finished.is_connected(_on_loop_finished):
			_loop_player.finished.disconnect(_on_loop_finished)
		_loop_player.stop()


func is_sfx_loop_playing() -> bool:
	return _loop_player and _loop_player.playing


func _on_loop_finished() -> void:
	"""循环回调：重新播放。"""
	if _loop_player and _loop_player.stream:
		_loop_player.play()


func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null

# ═══════════════════════════════════════════════════════
# Ambient System（环境背景音）
# ═══════════════════════════════════════════════════════

class AmbientLayer:
	var player: AudioStreamPlayer
	var streams: Array[AudioStream] = []
	var volume_db: float = 0.0
	var replay_gap: float = 0.0       # 0 = 连续循环; >0 = 间隔重播
	var replay_gap_max: float = 0.0   # 仅 replay_gap > 0 时有效
	var gap_timer: SceneTreeTimer = null
	var _index: int = -1

	func _to_string() -> String:
		return "AmbientLayer(idx=%d, streams=%d, vol=%.1fdB, gap=%.1f-%.1f)" % [_index, streams.size(), volume_db, replay_gap, replay_gap_max]

	func setup(parent: Node, idx: int, config: Dictionary) -> bool:
		_index = idx
		player = AudioStreamPlayer.new()
		player.name = "Ambient_%d" % idx
		player.bus = "Master"
		parent.add_child(player)

		# streams
		var raw = config.get("streams", [])
		if raw is AudioStream:
			streams = [raw as AudioStream]
		elif raw is Array:
			for s in raw:
				if s is AudioStream:
					streams.append(s)
		if streams.is_empty():
			Logging.warn("AmbientLayer[%d]: streams 为空，跳过" % idx)
			return false

		volume_db = config.get("volume_db", 0.0)
		replay_gap = config.get("replay_gap", 0.0)
		replay_gap_max = config.get("replay_gap_max", replay_gap)

		if not player.finished.is_connected(_on_finished.bind(self)):
			player.finished.connect(_on_finished.bind(self))
		return true

	func start() -> void:
		if streams.is_empty():
			return
		player.volume_db = volume_db
		_pick_and_play()

	func _pick_and_play() -> void:
		if streams.is_empty():
			return
		if streams.size() == 1:
			player.stream = streams[0]
		else:
			player.stream = streams[randi() % streams.size()]
		player.play()

	func pause() -> void:
		if player and player.playing:
			player.stream_paused = true

	func resume() -> void:
		if player:
			player.stream_paused = false

	func stop() -> void:
		_cancel_gap_timer()
		if player and player.finished.is_connected(_on_finished.bind(self)):
			player.finished.disconnect(_on_finished.bind(self))
		if player:
			player.stop()

	func destroy() -> void:
		stop()
		if player:
			player.queue_free()
			player = null

	func _cancel_gap_timer() -> void:
		if gap_timer:
			gap_timer.timeout.disconnect(_on_gap_timeout)
			gap_timer = null

	static func _on_finished(layer: AmbientLayer) -> void:
		if not is_instance_valid(layer) or not is_instance_valid(layer.player):
			return
		if layer.replay_gap <= 0.0:
			# 连续循环
			layer._pick_and_play()
		else:
			# 随机间隔
			layer._cancel_gap_timer()
			var delay = randf_range(layer.replay_gap, layer.replay_gap_max)
			layer.gap_timer = layer.player.get_tree().create_timer(delay)
			layer.gap_timer.timeout.connect(layer._on_gap_timeout)

	func _on_gap_timeout() -> void:
		gap_timer = null
		if not player:
			return
		_pick_and_play()


# ── Public API ──

## 注册 ambient profile。key 用于 set_ambient_profile() 快速引用。
## layers: Array[Dictionary]，每项 { streams, volume_db, replay_gap, replay_gap_max }
func register_ambient_profile(key: String, layers: Array) -> void:
	if key.is_empty():
		Logging.warn("%s: register_ambient_profile key 为空" % LOG_TAG)
		return
	if layers.is_empty():
		Logging.warn("%s: register_ambient_profile layers 为空 [%s]" % [LOG_TAG, key])
		return
	_profiles[key] = layers
	Logging.info("%s: 已注册 ambient profile [%s] → %d 层" % [LOG_TAG, key, layers.size()])


## 激活指定 profile。若已有 active → 先 clear。
## 若 BGM 正在播 → 加载但不启动（标记 paused 等待 _process 恢复）
func set_ambient_profile(key: String) -> void:
	if not _profiles.has(key):
		Logging.warn("%s: 未找到 ambient profile [%s]" % [LOG_TAG, key])
		return

	clear_ambient_profile()

	var layers_config = _profiles[key] as Array
	for i in range(layers_config.size()):
		var layer = AmbientLayer.new()
		if layer.setup(self, i, layers_config[i]):
			_ambient_layers.append(layer)

	if _ambient_layers.is_empty():
		Logging.warn("%s: set_ambient_profile [%s] 无有效层" % [LOG_TAG, key])
		return

	_ambient_active = true
	Logging.info("%s: 已设置 ambient profile [%s] → %d 层" % [LOG_TAG, key, _ambient_layers.size()])

	# 若 BGM 正在播，标记 paused 不启动
	var bgm_playing := false
	if is_instance_valid(_bgm_track_1) and _bgm_track_1.playing:
		bgm_playing = true
	if is_instance_valid(_bgm_track_2) and _bgm_track_2.playing:
		bgm_playing = true

	if bgm_playing:
		_ambient_paused = true
		_bgm_was_playing = true
		Logging.info("%s: ambient profile [%s] 已加载但暂停（BGM 正在播放）" % [LOG_TAG, key])
	else:
		_ambient_paused = false
		_bgm_was_playing = false
		for layer in _ambient_layers:
			(layer as AmbientLayer).start()
		Logging.info("%s: ambient profile [%s] 开始播放" % [LOG_TAG, key])


## 停止所有 ambient 层并清理
func clear_ambient_profile() -> void:
	if not _ambient_active:
		return

	Logging.info("%s: 清除 ambient profile，停止 %d 层" % [LOG_TAG, _ambient_layers.size()])
	for layer in _ambient_layers:
		(layer as AmbientLayer).destroy()
	_ambient_layers.clear()
	_ambient_active = false
	_ambient_paused = false


## 暂停所有 ambient 层
func pause_ambient() -> void:
	_pause_ambient_internal()


## 恢复所有 ambient 层
func resume_ambient() -> void:
	_resume_ambient_internal()


func is_ambient_active() -> bool:
	return _ambient_active


## 内部暂停（不记录日志，_process 也会调用）
func _pause_ambient_internal() -> void:
	if not _ambient_active or _ambient_paused:
		return
	_ambient_paused = true
	Logging.info("%s: 暂停 ambient (%d 层)" % [LOG_TAG, _ambient_layers.size()])
	for layer in _ambient_layers:
		(layer as AmbientLayer).pause()


## 内部恢复（不记录日志，_process 也会调用）
func _resume_ambient_internal() -> void:
	if not _ambient_active or not _ambient_paused:
		return
	_ambient_paused = false
	Logging.info("%s: 恢复 ambient (%d 层)" % [LOG_TAG, _ambient_layers.size()])
	for layer in _ambient_layers:
		(layer as AmbientLayer).resume()


# ═══════════════════════════════════════════════════════
