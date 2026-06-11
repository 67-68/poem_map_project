@tool
class_name ImageSlideOperator extends BaseOperator

## 滑动已有图片到目标位置 — 由 image_slide DSL 解析生成
##
## DSL 语法: image_slide(id="juanzhou", pos="top_center", duration=1.5)
##
## [param image_id] 图片 ID (必须已通过 present / present_by_id 展示)
## [param target_position] 目标位置枚举名
## [param duration] 滑动动画时长 (秒)

@export var image_id: String = ""
@export var target_position: String = "center"
@export var duration: float = 1.0


func operate() -> void:
	Logging.info("ImageSlideOperator.operate: id='%s', target='%s', duration=%.2f" % [image_id, target_position, duration])

	if image_id.is_empty():
		Logging.err("ImageSlideOperator.operate: image_id 为空，跳过")
		return

	var handle = ImageManager.recall(image_id)
	if handle == null:
		Logging.warn("ImageSlideOperator.operate: 图片 '%s' 不在活跃列表中，无法滑动" % image_id)
		return

	var pos_enum = _parse_position(target_position)
	if pos_enum == null:
		Logging.err("ImageSlideOperator.operate: 无效目标位置 '%s'，跳过" % target_position)
		return

	var target_vec = ImageManager._resolve_pos(pos_enum)
	handle.slide_to(target_vec, duration)
	Logging.info("ImageSlideOperator.operate: 滑动 id='%s' → %s (%.2f秒)" % [image_id, target_vec, duration])


static func _parse_position(pos_str: String) -> Variant:
	var upper = pos_str.to_upper()
	var keys = ENUMS.IMAGE_POS.keys()
	for i in range(keys.size()):
		if keys[i] == upper:
			return i
	return null
