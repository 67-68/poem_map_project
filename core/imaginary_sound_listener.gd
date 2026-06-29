class_name ImaginarySoundListener extends Node
## 意象音效监听器 (Imaginary Sound Listener)
##
## 职责：监听 EventBus.imaginary_changed 信号，通过快照 diff 检测意象等级变化，
## 对等级提升播放对应音效（通过 AudioManager 统一管理）。
##
## 与 Operator 解耦：Operator 只需要修改数据 + 发射信号，不再直接调用 AudioManager。
##
## 快照机制：维护 {imaginary_name: current_level} 的字典，
## 每次收到信号时与当前 Database 状态 diff，只对 level 增加的意象播放音效。
##
## Debug 要求：每个分支都存在 logging 日志

const LOG_TAG := "ImaginarySoundListener"

## 上次快照：imaginary_name (String) → current_level (int)
var _level_snapshot: Dictionary = {}


func _ready() -> void:
	Logging.info("%s: 初始化，连接 EventBus.imaginary_changed 信号" % LOG_TAG)
	
	if not EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.connect(_on_imaginary_changed)
		Logging.info("%s: 已连接 imaginary_changed 信号" % LOG_TAG)
	else:
		Logging.warn("%s: imaginary_changed 信号已连接，跳过重复连接" % LOG_TAG)
	
	# 初始化快照：读取当前所有意象的 level
	_refresh_snapshot()
	Logging.info("%s: 初始快照已建立，共 %d 条意象" % [LOG_TAG, _level_snapshot.size()])


## 当 imaginary_changed 信号触发时，diff 快照并播放音效
func _on_imaginary_changed() -> void:
	Logging.debug("%s: 收到 imaginary_changed 信号，开始 diff" % LOG_TAG)
	
	var all_imaginaries = Database.get_imaginaries_all()
	if all_imaginaries.is_empty():
		Logging.debug("%s: Database.imaginaries 为空，跳过 diff" % LOG_TAG)
		_refresh_snapshot()
		return
	
	var level_increases: Array[Dictionary] = []
	
	for uuid in all_imaginaries:
		var ima = all_imaginaries[uuid] as ImaginaryTag
		if not ima:
			continue
		
		var name_key = ima.name
		if name_key.is_empty():
			continue
		
		var new_level: int = ima.current_level
		var old_level: int = _level_snapshot.get(name_key, 0)
		
		if new_level > old_level:
			Logging.info("%s: 检测到意象 '%s' 等级提升: %d → %d" % [LOG_TAG, name_key, old_level, new_level])
			level_increases.append({
				"name": name_key,
				"old_level": old_level,
				"new_level": new_level
			})
		
		# 更新快照
		_level_snapshot[name_key] = new_level
	
	if level_increases.is_empty():
		Logging.debug("%s: 未检测到等级提升，跳过音效" % LOG_TAG)
		return
	
	# 对每个等级提升播放对应音效
	for entry in level_increases:
		var new_lv: int = entry["new_level"]
		Logging.info("%s: 播放意象 '%s' 等级 %d 音效" % [LOG_TAG, entry["name"], new_lv])
		AudioManager.play_imaginary_sound(new_lv)


## 刷新快照：从 Database 读取所有当前意象的 level
func _refresh_snapshot() -> void:
	_level_snapshot.clear()
	
	var all_imaginaries = Database.get_imaginaries_all()
	for uuid in all_imaginaries:
		var ima = all_imaginaries[uuid] as ImaginaryTag
		if ima and not ima.name.is_empty():
			_level_snapshot[ima.name] = ima.current_level
	
	Logging.debug("%s: 快照已刷新，共 %d 条" % [LOG_TAG, _level_snapshot.size()])
