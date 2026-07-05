class_name ImaginarySoundListener extends Node
## 意象音效监听器 V7 (Imaginary Sound Listener)
##
## V7 变更: ImaginaryConcept 已删除。diff 基于 Imaginary (imaginaries_detail) 的存在性变化。
## 只走 T1 音效（tier 1 固定）。

const LOG_TAG := "ImaginarySoundListener"

## 上次快照：imaginary_uuid → bool（是否存在）
var _imaginary_snapshot: Dictionary = {}


func _ready() -> void:
	Logging.info("%s: V7 初始化，连接 EventBus.imaginary_changed 信号" % LOG_TAG)

	if not EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.connect(_on_imaginary_changed)
		Logging.info("%s: 已连接 imaginary_changed 信号" % LOG_TAG)
	else:
		Logging.warn("%s: imaginary_changed 信号已连接，跳过重复连接" % LOG_TAG)

	_refresh_snapshot()
	Logging.info("%s: 初始快照已建立，共 %d 条意象" % [LOG_TAG, _imaginary_snapshot.size()])


## 当 imaginary_changed 信号触发时，检测新增的 Imaginary
func _on_imaginary_changed() -> void:
	Logging.debug("%s: 收到 imaginary_changed 信号，开始 diff" % LOG_TAG)

	var all_imag = Database.imaginaries_detail
	if all_imag.is_empty():
		Logging.debug("%s: imaginaries_detail 为空，跳过 diff" % LOG_TAG)
		_refresh_snapshot()
		return

	for uuid in all_imag:
		var imag = all_imag[uuid]
		if not (imag is Imaginary):
			continue

		var was_present: bool = _imaginary_snapshot.get(uuid, false)
		var now_present: bool = true

		if now_present and not was_present:
			Logging.info("%s: 检测到新 Imaginary '%s'(%s)，播放 T1 音效" % [LOG_TAG, uuid, imag.name])
			AudioManager.play_imaginary_sound(1)

		_imaginary_snapshot[uuid] = now_present

	# 检测删除的 Imaginary
	for uuid in _imaginary_snapshot.keys():
		if not all_imag.has(uuid):
			_imaginary_snapshot.erase(uuid)


## 刷新快照
func _refresh_snapshot() -> void:
	_imaginary_snapshot.clear()

	var all_imag = Database.imaginaries_detail
	for uuid in all_imag:
		var imag = all_imag[uuid]
		if imag is Imaginary:
			_imaginary_snapshot[uuid] = true

	Logging.debug("%s: 快照已刷新，共 %d 条" % [LOG_TAG, _imaginary_snapshot.size()])
