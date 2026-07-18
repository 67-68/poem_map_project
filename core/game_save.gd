extends Node
## GameSave — Autoload，持有 GameSaveData 的唯一实例
##
## 所有需要持久化的运行时状态均通过 GameSave.data 访问。
## 此 Node 本身不在场景树上做任何操作，仅作为 data 的容器。

const _GameSaveData = preload("res://core/model/game_save_data.gd")
const SAVE_DIR := "user://saves"
const SAVE_EXT := ".save"

## 运行时状态的唯一真源 (SSOT)
var data: GameSaveData

func _init() -> void:
	data = GameSaveData.new()

func _ready() -> void:
	Logging.info("GameSave: Autoload ready, data initialized")

# ════════════════════════════════════════════════════════════════
# 文件 I/O
# ════════════════════════════════════════════════════════════════

## 保存当前状态到指定 UUID 的存档文件（覆盖写入）
func save_to_file(uuid: String) -> void:
	Logging.info("GameSave: 保存存档 → uuid=%s" % uuid)
	_ensure_save_dir()
	var dict := data.to_dict()
	var path := SAVE_DIR + "/" + uuid + SAVE_EXT
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		Logging.err("GameSave: 无法打开存档文件写入 → %s 💀" % path)
		return
	file.store_var(dict)
	file.close()
	Logging.info("GameSave: 存档已保存 → %s (%d keys)" % [path, dict.size()])


## 从指定 UUID 的存档文件加载状态，完成后 reload_current_scene
func load_from_file(uuid: String) -> void:
	Logging.info("GameSave: 加载存档 → uuid=%s" % uuid)
	var path := SAVE_DIR + "/" + uuid + SAVE_EXT
	if not FileAccess.file_exists(path):
		Logging.err("GameSave: 存档文件不存在 → %s 💀" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		Logging.err("GameSave: 无法打开存档文件读取 → %s 💀" % path)
		return
	var dict = file.get_var()
	file.close()
	if not dict is Dictionary:
		Logging.err("GameSave: 存档文件内容不是 Dictionary → %s 💀" % path)
		return
	Logging.info("GameSave: 存档字典读取成功 → %d keys" % dict.size())
	data.from_dict(dict)
	Logging.info("GameSave: from_dict 完成，即将 reload_current_scene")
	# 延迟一帧 reload，让调用方的信号链先走完
	get_tree().reload_current_scene.call_deferred()


## 扫描存档目录，返回所有存档文件的元数据列表
## 返回: Array[Dictionary] — [{uuid, file_path, player_name, year, current_location, total_days_elapsed}, ...]
func list_saves() -> Array:
	Logging.info("GameSave: 扫描存档目录 → %s" % SAVE_DIR)
	_ensure_save_dir()
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		Logging.err("GameSave: 无法打开存档目录 → %s 💀" % SAVE_DIR)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.ends_with(SAVE_EXT):
			file_name = dir.get_next()
			continue
		var uuid := file_name.trim_suffix(SAVE_EXT)
		if uuid.is_empty():
			Logging.warn("GameSave: 跳过空 UUID 文件名 → %s" % file_name)
			file_name = dir.get_next()
			continue
		var file_path := SAVE_DIR + "/" + file_name
		var file := FileAccess.open(file_path, FileAccess.READ)
		if not file:
			Logging.warn("GameSave: 无法读取存档文件 → %s，跳过" % file_path)
			file_name = dir.get_next()
			continue
		var dict = file.get_var()
		file.close()
		if not dict is Dictionary:
			Logging.warn("GameSave: 存档内容非 Dictionary → %s，跳过" % file_path)
			file_name = dir.get_next()
			continue
		var meta := {
			"uuid": uuid,
			"file_path": file_path,
			"player_name": dict.get("player_name", tr("TRES_POET_DUFU_002_NAME_0")),
			"year": dict.get("year", 745.0),
			"current_location": dict.get("current_location", "yong_zhou"),
			"total_days_elapsed": dict.get("total_days_elapsed", 0),
		}
		result.append(meta)
		Logging.info("GameSave: 发现存档 → uuid=%s, year=%.1f, days=%d" % [uuid, meta["year"], meta["total_days_elapsed"]])
		file_name = dir.get_next()
	dir.list_dir_end()
	Logging.info("GameSave: 扫描完成，共 %d 个存档" % result.size())
	return result


## 确保存档目录存在
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		Logging.info("GameSave: 创建存档目录 → %s" % SAVE_DIR)
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
