class_name FatigueManager extends Node
# FatigueManager — 疲劳惩罚倍率管理器
# ⚠️ FATIGUE 属性已从系统中移除，此管理器已停止工作。
#
# 架构概要：
#   PlayerState.append_stat() 在属性变更前发射 before_property_change 信号，
#   PlayerState.append_emotion() 在情绪变更前发射 before_emotion_change 信号，
#   FatigueManager 监听这两个信号。当前由于 fatigue 属性不存在，
#   所有倍率保持 1.0（无影响）。

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


## 信号处理器：Fatigue 属性已移除，始终返回倍率 1.0
static func _on_before_property_change(_prop_name: String, _delta: int) -> void:
	_current_fatigue_multiplier = 1.0


## 信号处理器：Fatigue 属性已移除，始终返回倍率 1.0
static func _on_before_emotion_change(_emo_name: String, _delta: int) -> void:
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
