@tool
class_name ImageShatterOperator extends BaseOperator

## 粉碎已有图片 — 由 image_shatter DSL 解析生成
##
## DSL 语法: image_shatter(id="juanzhou", duration=1.0)
##
## [param image_id] 图片 ID (必须已通过 present / present_by_id 展示)
## [param duration] 粉碎动画时长 (秒)

@export var image_id: String = ""
@export var duration: float = 1.0


func operate() -> void:
	Logging.info("ImageShatterOperator.operate: id='%s', duration=%.2f" % [image_id, duration])

	if image_id.is_empty():
		Logging.err("ImageShatterOperator.operate: image_id 为空，跳过")
		return

	var handle = ImageManager.recall(image_id)
	if handle == null:
		Logging.warn("ImageShatterOperator.operate: 图片 '%s' 不在活跃列表中，无法粉碎" % image_id)
		return

	handle.shatter(duration)
	Logging.info("ImageShatterOperator.operate: 粉碎 id='%s'" % image_id)
