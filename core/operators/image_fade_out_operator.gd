@tool
class_name ImageFadeOutOperator extends BaseOperator

## 淡出已有图片 — 由 image_fade_out DSL 解析生成
##
## DSL 语法: image_fade_out(id="juanzhou", duration=2.0)
##
## [param image_id] 图片 ID (必须已通过 present / present_by_id 展示)
## [param duration] 淡出动画时长 (秒)

@export var image_id: String = ""
@export var duration: float = 1.0


func operate() -> void:
	Logging.info("ImageFadeOutOperator.operate: id='%s', duration=%.2f" % [image_id, duration])

	if image_id.is_empty():
		Logging.err("ImageFadeOutOperator.operate: image_id 为空，跳过")
		return

	var handle = ImageManager.recall(image_id)
	if handle == null:
		Logging.warn("ImageFadeOutOperator.operate: 图片 '%s' 不在活跃列表中，无法淡出" % image_id)
		return

	handle.fade_out(duration)
	Logging.info("ImageFadeOutOperator.operate: 淡出 id='%s'" % image_id)
