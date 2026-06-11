@tool
class_name ImageRemoveOperator extends BaseOperator

## 立即移除已有图片 — 由 image_remove DSL 解析生成
##
## DSL 语法: image_remove(id="juanzhou")
##
## [param image_id] 图片 ID (必须已通过 present / present_by_id 展示)

@export var image_id: String = ""


func operate() -> void:
	Logging.info("ImageRemoveOperator.operate: id='%s'" % image_id)

	if image_id.is_empty():
		Logging.err("ImageRemoveOperator.operate: image_id 为空，跳过")
		return

	var handle = ImageManager.recall(image_id)
	if handle == null:
		Logging.warn("ImageRemoveOperator.operate: 图片 '%s' 不在活跃列表中，无法移除" % image_id)
		return

	handle.remove()
	Logging.info("ImageRemoveOperator.operate: 移除 id='%s'" % image_id)
