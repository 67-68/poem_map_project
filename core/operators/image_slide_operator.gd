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

	var uv = _parse_position_to_uv(target_position)
	if uv == Vector2.INF:
		Logging.err("ImageSlideOperator.operate: 无效目标位置 '%s'，跳过" % target_position)
		return

	handle.slide_to(uv, duration)
	Logging.info("ImageSlideOperator.operate: 滑动 id='%s' → uv=%s (%.2f秒)" % [image_id, uv, duration])


## 将枚举名转为 UV Vector2 (使用 ImageManager.resolve_uv)
static func _parse_position_to_uv(pos_str: String) -> Vector2:
	var upper = pos_str.to_upper()
	var keys = ENUMS.IMAGE_POS.keys()
	for i in range(keys.size()):
		if keys[i] == upper:
			return ImageManager.resolve_uv(i)
	return Vector2.INF
