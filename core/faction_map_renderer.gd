class_name FactionMapRenderer extends Node

var lut_image: Image
const LUT_SIZE = 512
var lut_texture: ImageTexture

var _color_to_idx_map: Dictionary = {}
var _next_available_index := 1

func _ready() -> void:
	_build_color_index()
	_init_lut_texture()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func refresh_lut_image(ownership: Dictionary) -> ImageTexture:
	# ownership: {省份: 势力}
	for p_id in ownership.keys():
		var province = Global.base_province.get(p_id)
		if not province: continue

		var color_hex = province.color.to_html(false)
		if _color_to_idx_map.has(color_hex):
			lut_image.set_pixel(
				_color_to_idx_map[color_hex],
				0,
				ownership[p_id].map_color
			)
		
		lut_texture.update(lut_image)
	return lut_texture

func _build_color_index():
	for p_id in Global.base_province.keys():
		var province: Territory = Global.base_province[p_id]
		var color_hex = province.color.to_html(false)

		if not _color_to_idx_map.has(color_hex):
			_color_to_idx_map[color_hex] = _next_available_index
			_next_available_index += 1
		
		Logging.info("✅ 自动索引构建完成：已映射 %d 个地理颜色到 LUT。" % _color_to_idx_map.size())

func _init_lut_texture():
	lut_image = Image.create(LUT_SIZE,1,false,Image.FORMAT_RGBA8)
	lut_texture = ImageTexture.create_from_image(lut_image)
