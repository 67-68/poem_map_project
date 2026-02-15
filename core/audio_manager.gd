# AudioManager.gd (完整版)
extends Node

# BGM 轨道 (上次写的)
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

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null

# 预加载常用音效，方便全局调用
const SFX_CLICK = preload("res://audio/sfx/wood_click.wav") # 假设你有这个
const SFX_SCROLL = preload("res://audio/sfx/paper_rustle.wav")

func play_click():
	play_sfx(SFX_CLICK, 0.2) # 点击声给大一点的随机

func play_scroll():
	play_sfx(SFX_SCROLL, 0.1)