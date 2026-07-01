class_name ImaginarySoundListener extends Node
## 意象音效监听器 V6 (Imaginary Sound Listener)
##
## 职责：监听 EventBus.imaginary_changed 信号，通过快照 diff 检测意象坍缩，
## 对新坍缩的意象播放对应音效（通过 AudioManager 统一管理）。
##
## V6 变更: level 系统已删除，改为检测 merged 数组（坍缩标记）的变化。

const LOG_TAG := "ImaginarySoundListener"

## 上次快照：imaginary_name (String) → was_merged (bool)
var _merged_snapshot: Dictionary = {}


func _ready() -> void:
	Logging.info("%s: 初始化，连接 EventBus.imaginary_changed 信号" % LOG_TAG)
	
	if not EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.connect(_on_imaginary_changed)
		Logging.info("%s: 已连接 imaginary_changed 信号" % LOG_TAG)
	else:
		Logging.warn("%s: imaginary_changed 信号已连接，跳过重复连接" % LOG_TAG)
	
	_refresh_snapshot()
	Logging.info("%s: 初始快照已建立，共 %d 条意象" % [LOG_TAG, _merged_snapshot.size()])


## 当 imaginary_changed 信号触发时，diff 快照并播放音效
func _on_imaginary_changed() -> void:
	Logging.debug("%s: 收到 imaginary_changed 信号，开始 diff 坍缩状态" % LOG_TAG)
	
	var all_imaginaries = Database.get_imaginaries_all()
	if all_imaginaries.is_empty():
		Logging.debug("%s: Database.imaginaries 为空，跳过 diff" % LOG_TAG)
		_refresh_snapshot()
		return
	
	for uuid in all_imaginaries:
		var ima = all_imaginaries[uuid] as ImaginaryConcept
		if not ima:
			continue
		
		var name_key = ima.name
		if name_key.is_empty():
			continue
		
		var now_merged: bool = not ima.merged.is_empty()
		var was_merged: bool = _merged_snapshot.get(name_key, false)
		
		if now_merged and not was_merged:
			Logging.info("%s: 检测到意象 '%s' 刚刚坍缩" % [LOG_TAG, name_key])
			var tier: int = ima.current_tier
			Logging.info("%s: 播放意象 '%s' tier %d 音效" % [LOG_TAG, name_key, tier])
			AudioManager.play_imaginary_sound(tier)
		
		_merged_snapshot[name_key] = now_merged


## 刷新快照
func _refresh_snapshot() -> void:
	_merged_snapshot.clear()
	
	var all_imaginaries = Database.get_imaginaries_all()
	for uuid in all_imaginaries:
		var ima = all_imaginaries[uuid] as ImaginaryConcept
		if ima and not ima.name.is_empty():
			_merged_snapshot[ima.name] = not ima.merged.is_empty()
	
	Logging.debug("%s: 快照已刷新，共 %d 条" % [LOG_TAG, _merged_snapshot.size()])
