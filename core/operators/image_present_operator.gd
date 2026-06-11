@tool
class_name ImagePresentOperator extends BaseOperator

## 按 ID 展示图片 — 由 image_present DSL 解析生成
##
## DSL 语法: image_present(id="juanzhou", pos="center")
##
## [param image_id] 图片 ID (TextureResLoader 可解析的名字, 或已注册的 ID)
## [param position] 位置枚举名 (center / top_left / top_center / ...)

@export var image_id: String = ""
@export var position: String = "center"


func operate() -> void:
	Logging.info("ImagePresentOperator.operate: id='%s', pos='%s'" % [image_id, position])

	if image_id.is_empty():
		Logging.err("ImagePresentOperator.operate: image_id 为空，跳过")
		return

	# 转换位置枚举字符串 → ENUMS.IMAGE_POS
	var pos_enum = _parse_position(position)
	if pos_enum == null:
		Logging.err("ImagePresentOperator.operate: 无效位置 '%s'，跳过" % position)
		return

	var handle = ImageManager.present_by_id(image_id, pos_enum)
	if handle == null:
		Logging.err("ImagePresentOperator.operate: present_by_id 失败 id='%s'" % image_id)


## 将小写枚举名转为 ENUMS.IMAGE_POS 值
static func _parse_position(pos_str: String) -> Variant:
	var upper = pos_str.to_upper()
	# ENUMS.IMAGE_POS 的 keys() 返回 ["CENTER", "TOP_LEFT", ...]
	var keys = ENUMS.IMAGE_POS.keys()
	for i in range(keys.size()):
		if keys[i] == upper:
			return i
	return null
