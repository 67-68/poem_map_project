class_name FatigueManager extends Node
# FatigueManager — 疲劳惩罚倍率管理器
#
# 架构概要：
#   PlayerState.append_stat() 在属性变更前发射 before_property_change 信号，
#   PlayerState.append_emotion() 在情绪变更前发射 before_emotion_change 信号，
#   FatigueManager 监听这两个信号，根据当前 fatigue 值计算惩罚倍率，
#   存入静态变量，调用方在信号返回后读取并应用。
#
# 倍率规则（fatigue > 70）：
#   好属性（玩家希望增加的）→ 0.5x（收益减半）
#   坏属性（玩家希望减少的）→ 2.0x（代价加倍）
#   情绪 → 0.5x（感受钝化）
#
# fatigue <= 70 → 倍率 = 1.0（无影响）
# ═══════════════════════════════════════════════════════════

## 硬编码的"好属性"对照表（key 为 Database.prop 的 uuid/name）
const GOOD_PROPS: Dictionary = {
	"literary_fame": true,
	"official_prestige": true,
	"talent": true,
	"money": true,
	"health": true,
	"inspiration": true,
	"career_progress": true,
}

## 硬编码的"坏属性"对照表
const BAD_PROPS: Dictionary = {
	"fatigue": true,
	"burnout": true,
	"sick": true,
	"drunk": true,
}

## 疲劳触发阈值
const FATIGUE_THRESHOLD: int = 70

## 由 before_property_change 信号处理器写入、append_stat 读取并重置的属性倍率
static var _current_fatigue_multiplier: float = 1.0

## 由 before_emotion_change 信号处理器写入、append_emotion 读取并重置的情绪倍率
static var _current_emotion_multiplier: float = 1.0


func _ready() -> void:
	connect_to_player_state()


## 连接 PlayerState 的信号
static func connect_to_player_state() -> void:
	PlayerState.before_property_change.connect(_on_before_property_change)
	PlayerState.before_emotion_change.connect(_on_before_emotion_change)
	Logging.info("FatigueManager: connected to PlayerState.before_property_change and before_emotion_change")


## 信号处理器：属性即将变更时根据疲劳值计算惩罚倍率
static func _on_before_property_change(prop_name: String, delta: int) -> void:
	var fatigue = PlayerState.get_stat_val(&"fatigue")
	if fatigue <= FATIGUE_THRESHOLD:
		_current_fatigue_multiplier = 1.0
		return

	# 只对已知的好/坏属性施加疲劳倍率
	var is_good = GOOD_PROPS.has(prop_name)
	var is_bad = BAD_PROPS.has(prop_name)
	if not is_good and not is_bad:
		_current_fatigue_multiplier = 1.0
		return

	if is_good:
		_current_fatigue_multiplier = 0.5
	else:
		_current_fatigue_multiplier = 2.0
	Logging.info("FatigueManager: fatigue=%d, prop=%s, is_good=%s, multiplier=%.2f" % [fatigue, prop_name, is_good, _current_fatigue_multiplier])


## 信号处理器：情绪即将变更时根据疲劳值计算惩罚倍率
static func _on_before_emotion_change(_emo_name: String, _delta: int) -> void:
	var fatigue = PlayerState.get_stat_val(&"fatigue")
	if fatigue > FATIGUE_THRESHOLD:
		_current_emotion_multiplier = 0.5
	else:
		_current_emotion_multiplier = 1.0


## 消费者模式：获取当前属性倍率并重置为 1.0
##
## 由 PlayerState.append_stat() 在 before_property_change 信号发射后调用。
static func get_and_reset_fatigue_multiplier() -> float:
	var m = _current_fatigue_multiplier
	_current_fatigue_multiplier = 1.0
	return m


## 消费者模式：获取当前情绪倍率并重置为 1.0
##
## 由 PlayerState.append_emotion() 在 before_emotion_change 信号发射后调用。
static func get_and_reset_emotion_multiplier() -> float:
	var m = _current_emotion_multiplier
	_current_emotion_multiplier = 1.0
	return m
