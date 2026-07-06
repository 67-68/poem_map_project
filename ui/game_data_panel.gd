extends PanelContainer
class_name GameDataPanel
## GameDataPanel — 单个存档槽 UI 管理
## 由 SystemMenu 调用 configure(meta) 来填充显示
## 「保存到此」和「依此加载」LinkButton 的回调在此处理

@onready var _name_label: Label = $VBoxContainer/NameLabel
@onready var _time_label: Label = $VBoxContainer/TimeLabel
@onready var _save_btn: LinkButton = $VBoxContainer/HBoxContainer/Save
@onready var _load_btn: LinkButton = $VBoxContainer/HBoxContainer/Load

## 当前绑定的存档 UUID，空字符串表示空档位
var _save_uuid: String = ""


func _ready() -> void:
	_save_btn.pressed.connect(_on_save)
	_load_btn.pressed.connect(_on_load)
	Logging.info("GameDataPanel: 就绪")


## 用存档元数据填充面板显示
## meta: Dictionary — 来自 GameSave.list_saves() 的条目
## 传入空 {} 表示空档位
func configure(meta: Dictionary) -> void:
	if meta.is_empty():
		Logging.info("GameDataPanel: 配置为空档位")
		_save_uuid = ""
		_name_label.text = "空存档"
		_time_label.text = "点击保存以占用此槽位"
		_load_btn.visible = false
		_save_btn.visible = true
		return

	_save_uuid = meta.get("uuid", "")
	Logging.info("GameDataPanel: 配置存档 → uuid=%s, year=%.1f" % [_save_uuid, meta.get("year", 0.0)])

	var name_str: String = meta.get("player_name", "杜甫")
	_name_label.text = name_str

	var year: float = meta.get("year", 745.0)
	var days: int = meta.get("total_days_elapsed", 0)
	var location: String = meta.get("current_location", "yong_zhou")
	_time_label.text = "第%dd | %.1f年 | %s" % [days, year, location]

	_load_btn.visible = true
	_save_btn.visible = true


## 「保存到此」按钮回调
func _on_save() -> void:
	Logging.info("GameDataPanel: 保存到此 → uuid=%s" % _save_uuid)
	if _save_uuid.is_empty():
		# 空档位：生成新 UUID
		_save_uuid = _generate_uuid()
		Logging.info("GameDataPanel: 空档位，生成新 UUID → %s" % _save_uuid)
	GameSave.save_to_file(_save_uuid)
	# 保存后刷新自身显示
	_refresh_after_save()


## 「依此加载」按钮回调
func _on_load() -> void:
	if _save_uuid.is_empty():
		Logging.warn("GameDataPanel: 空档位无法加载")
		return
	Logging.info("GameDataPanel: 依此加载 → uuid=%s" % _save_uuid)
	# 先恢复世界时间，避免 load 后时间卡死
	if TimeService:
		TimeService.resume_world()
	GameSave.load_from_file(_save_uuid)


## 保存后刷新面板显示（从刚写入的文件读取元数据）
func _refresh_after_save() -> void:
	var saves := GameSave.list_saves()
	for s in saves:
		if s.get("uuid", "") == _save_uuid:
			configure(s)
			Logging.info("GameDataPanel: 保存后刷新完成 → uuid=%s" % _save_uuid)
			return
	Logging.warn("GameDataPanel: 保存后未在 list_saves 中找到 uuid=%s" % _save_uuid)


## 生成 UUID v4 兼容格式
func _generate_uuid() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() % 256
	# UUID v4: version bits 和 variant bits
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var uuid := ""
	for i in 16:
		if i == 4 or i == 6 or i == 8 or i == 10:
			uuid += "-"
		uuid += "%02x" % bytes[i]
	Logging.info("GameDataPanel: 生成 UUID → %s" % uuid)
	return uuid
