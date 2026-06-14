# AudioManager.gd (完整版)
extends Node

const LOG_TAG := "AudioManager"

# ── 音效类别缓存 ──
# 在 _ready() 时扫描 assets/sounds/ 下的一级子目录，预加载所有音效
# 每个子目录名 = 类别名，例如: "click" → [AudioStream, AudioStream, ...]
var _sfx_category_cache: Dictionary = {}
const SFX_ROOT: String = "res://assets/sounds"

# BGM 轨道
var _bgm_track_1: AudioStreamPlayer
var _bgm_track_2: AudioStreamPlayer
var _current_bgm_track: int = 1

# SFX 池子
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8 # 8个声道足够应付大多数 UI 情况了

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # 必须全天候运行！
	
	# 1. 初始化 BGM 轨道
	_bgm_track_1 = _create_player("BGM_1")
	_bgm_track_2 = _create_player("BGM_2")
	
	# 2. 初始化 SFX 池
	for i in range(SFX_POOL_SIZE):
		var p = _create_player("SFX_%d" % i)
		_sfx_pool.append(p)
	
	# 3. 扫描 assets/sounds/ 子目录，预加载分类音效
	_load_sfx_categories()

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
	var root_dir = DirAccess.open(SFX_ROOT)
	if not root_dir:
		Logging.warn("%s: 音效目录不存在 [%s]" % [LOG_TAG, SFX_ROOT])
		return
	
	root_dir.list_dir_begin()
	var dir_name = root_dir.get_next()
	while dir_name != "":
		# 跳过 .import 文件和普通文件，只进子目录
		if dir_name.begins_with(".") or dir_name.ends_with(".import"):
			dir_name = root_dir.get_next()
			continue
		if not root_dir.current_is_dir():
			dir_name = root_dir.get_next()
			continue
		
		# 进入子目录 = 一个类别
		var category = dir_name
		var cat_dir = DirAccess.open(SFX_ROOT.path_join(category))
		if not cat_dir:
			dir_name = root_dir.get_next()
			continue
		
		var streams: Array[AudioStream] = []
		cat_dir.list_dir_begin()
		var file_name = cat_dir.get_next()
		while file_name != "":
			if file_name.begins_with(".") or file_name.ends_with(".import"):
				file_name = cat_dir.get_next()
				continue
			# 只加载支持的音效格式
			var ext = file_name.get_extension().to_lower()
			if ext in ["ogg", "wav", "mp3"]:
				var full_path = SFX_ROOT.path_join(category).path_join(file_name)
				var stream = load(full_path)
				if stream:
					streams.append(stream)
			file_name = cat_dir.get_next()
		cat_dir.list_dir_end()
		
		if not streams.is_empty():
			_sfx_category_cache[category] = streams
			Logging.info("%s: 已加载类别 [%s] → %d 个音效" % [LOG_TAG, category, streams.size()])
		else:
			Logging.info("%s: 类别 [%s] 为空，跳过" % [LOG_TAG, category])
		
		dir_name = root_dir.get_next()
	root_dir.list_dir_end()


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


func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null

# 预加载常用音效，方便全局调用
const SONG_SAD = preload("res://assets/sounds/sad_song.mp3") # 假设你有这个
const SONG_TENSE = preload("res://assets/sounds/tense_song.mp3")
const SFX_EXPAND = preload("res://assets/sounds/rustling_paper.wav")

func play_expand():
	play_sfx(SFX_EXPAND, 1) # 点击声给大一点的随机

func play_sad():
	play_music(SONG_SAD)

func play_tense():
	play_music(SONG_TENSE)