@tool
class_name ImagePresentOperator extends BaseOperator

## 按 ID 展示图片 — 由 image_present DSL 解析生成
##
## DSL 语法: image_present(id="juanzhou", pos="center")
## DSL 语法: image_present(id="juanzhou", pos="center", size="100,100")
## DSL 语法: image_present(id="juanzhou", pos="0.5,0.3", size="100,100")
## DSL 语法: image_present(id="juanzhou", pos="960,540", size="100,100")
##
## [param image_id] 图片 ID (TextureResLoader 可解析的名字, 或已注册的 ID)
## [param position] 位置枚举名 (center / top_left / top_center / ...)
##                 或 "x,y" UV 坐标 (0.0~1.0)。如 "0.5,0.3" = UV(0.5, 0.3)。
##                 若两个值均 > 1.0 则视为绝对像素坐标，内部自动转换为 UV。
## [param size] 显示尺寸 "width,height" (默认 "100,100")，保持宽高比缩放

@export var image_id: String = ""
@export var position: String = "center"
@export var size: String = "100,100"


func operate() -> void:
	Logging.info("ImagePresentOperator.operate: id='%s', pos='%s', size='%s'" % [image_id, position, size])

	if image_id.is_empty():
		Logging.err("ImagePresentOperator.operate: image_id 为空，跳过")
		return

	# 解析尺寸字符串 → Vector2 (_parse_size 内部已处理无效输入返回默认值)
	var size_vec: Vector2 = _parse_size(size)

	# 优先尝试解析 position 为 "x,y" 格式的数值坐标
	var raw_pos: Variant = _try_parse_position_as_vector(position)
	if raw_pos != null:
		var pos_vec: Vector2 = raw_pos as Vector2
		# 两个值都 ≤ 1.0 → 当作 UV 坐标 (0.0~1.0)
		if pos_vec.x <= 1.0 and pos_vec.y <= 1.0:
			Logging.info("ImagePresentOperator.operate: 使用 UV 坐标 pos=%s" % pos_vec)
			var handle = ImageManager.present_by_id(image_id, pos_vec, size_vec)
			if handle == null:
				Logging.err("ImagePresentOperator.operate: present_by_id 失败 id='%s'" % image_id)
		else:
			# > 1.0 → 视为绝对像素坐标，转换为 UV
			Logging.info("ImagePresentOperator.operate: 使用绝对像素坐标 pos=%s" % pos_vec)
			var uv = _pixel_to_uv(pos_vec)
			var handle = ImageManager.present_by_id(image_id, uv, size_vec)
			if handle == null:
				Logging.err("ImagePresentOperator.operate: present_by_id 失败 id='%s'" % image_id)
		return

	# 兜底: 转换位置枚举字符串 → UV
	var uv: Vector2 = _parse_position_to_uv(position)
	if uv == Vector2.INF:
		Logging.err("ImagePresentOperator.operate: 无效位置 '%s'，跳过" % position)
		return

	var handle = ImageManager.present_by_id(image_id, uv, size_vec)
	if handle == null:
		Logging.err("ImagePresentOperator.operate: present_by_id 失败 id='%s'" % image_id)


## 尝试将 "x,y" 格式的字符串解析为 Vector2。
## 例如: "0.5,0.3" → Vector2(0.5, 0.3)
##       "960,540" → Vector2(960, 540)
## 若无法解析（如枚举名 "center"），返回 null。
## 两个值 ≤ 1.0 时视为 UV 坐标，否则视为绝对像素坐标。
static func _try_parse_position_as_vector(pos_str: String) -> Variant:
	var parts := pos_str.split(",", false)
	if parts.size() != 2:
		return null

	var x := float(parts[0].strip_edges())
	var y := float(parts[1].strip_edges())

	# 如果任一值解析为 NaN，说明不是数值格式
	if is_nan(x) or is_nan(y):
		return null

	return Vector2(x, y)


## 将绝对像素坐标转换为 UV (0.0~1.0)
static func _pixel_to_uv(pixel: Vector2) -> Vector2:
	var screen := _get_screen_size()
	if screen == Vector2.ZERO:
		return pixel  # fallback: 原值
	return Vector2(pixel.x / screen.x, pixel.y / screen.y)


## 获取屏幕尺寸 (像素)
static func _get_screen_size() -> Vector2:
	var viewport: Viewport = Engine.get_main_loop().root.get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return Vector2(1920, 1080)


## 将枚举名转为 UV Vector2 (使用 ImageManager.resolve_uv)
static func _parse_position_to_uv(pos_str: String) -> Vector2:
	var upper = pos_str.to_upper()
	# ENUMS.IMAGE_POS 的 keys() 返回 ["CENTER", "TOP_LEFT", ...]
	var keys = ENUMS.IMAGE_POS.keys()
	for i in range(keys.size()):
		if keys[i] == upper:
			return ImageManager.resolve_uv(i)
	return Vector2.INF


## 将 "width,height" 格式的尺寸字符串转为 Vector2
## 例如: "200,150" → Vector2(200, 150)
static func _parse_size(size_str: String) -> Vector2:
	var parts := size_str.split(",", false)
	if parts.size() != 2:
		Logging.warn("ImagePresentOperator: 尺寸格式无效 '%s'，应为 'width,height'" % size_str)
		return Vector2(100, 100)
	
	var w := float(parts[0].strip_edges())
	var h := float(parts[1].strip_edges())
	if w <= 0 or h <= 0:
		Logging.warn("ImagePresentOperator: 尺寸值必须为正数 '%s'" % size_str)
		return Vector2(100, 100)
	
	return Vector2(w, h)
