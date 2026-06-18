extends PanelContainer
# MaobiShake — 毛笔抖动效果
#
# 监听 PlayerState.player_stat_changed 信号，当 fatigue 值变化时，
# 根据疲劳等级触发不同程度的抖动动画。
#
# fatigue <= 50: 不抖动
# 50 < fatigue <= 70: 轻抖（小振幅）
# fatigue > 70: 重抖（大振幅）
# ═══════════════════════════════════════════════════════════

const LIGHT_SHAKE_AMPLITUDE: float = 4.0
const HEAVY_SHAKE_AMPLITUDE: float = 12.0
const SHAKE_FREQUENCY_LIGHT: float = 8.0
const SHAKE_FREQUENCY_HEAVY: float = 16.0

var _amplitude: float = 0.0
var _frequency: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	# 记录初始位置作为基准
	_base_position = position
	
	# 连接玩家属性变更信号
	PlayerState.player_stat_changed.connect(_on_stat_changed)
	
	# 初始检查一次
	_update_shake_from_fatigue()


func _process(delta: float) -> void:
	if _amplitude <= 0.0:
		# 确保回到基准位置
		if position != _base_position:
			position = _base_position
		return
	
	_time += delta * _frequency
	
	# 使用 sin 做水平抖动，垂直抖动副相位
	var offset_x = sin(_time) * _amplitude
	var offset_y = cos(_time * 0.7) * _amplitude * 0.5
	position = _base_position + Vector2(offset_x, offset_y)


func _on_stat_changed(prop_name: String) -> void:
	if prop_name != &"fatigue":
		return
	_update_shake_from_fatigue()


func _update_shake_from_fatigue() -> void:
	var fatigue = PlayerState.get_stat_val(&"fatigue")
	
	if fatigue > 70:
		_amplitude = HEAVY_SHAKE_AMPLITUDE
		_frequency = SHAKE_FREQUENCY_HEAVY
		Logging.info("MaobiShake: fatigue=%d > 70, heavy shake" % fatigue)
	elif fatigue > 50:
		_amplitude = LIGHT_SHAKE_AMPLITUDE
		_frequency = SHAKE_FREQUENCY_LIGHT
		Logging.info("MaobiShake: fatigue=%d > 50, light shake" % fatigue)
	else:
		_amplitude = 0.0
		_frequency = 0.0
		position = _base_position
		Logging.info("MaobiShake: fatigue=%d <= 50, no shake" % fatigue)
