class_name FactionMapRenderer extends Node

var lut_image: Image
const LUT_SIZE = 512
var lut_texture: ImageTexture

var _color_to_idx_map: Dictionary = {}
var _next_available_index := 1

var prov_state_2_color = {
	PROV_STATE.NORMAL: Color.TRANSPARENT,
	PROV_STATE.REBEL: Color(0.7, 0.1, 0.1),   # 叛乱红：血腥的暗红
	PROV_STATE.RUINED: Color(0.15, 0.15, 0.15) # 焦土黑：比纯黑稍微亮一点，保留质感
}

var special_state := {}

func _ready() -> void:
	Global.faction_renderer = self
	_build_color_index()
	_init_lut_texture()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func refresh_lut_image(ownership: Dictionary) -> ImageTexture:
	lut_texture = _update_faction(ownership)
	lut_texture = _update_special_state(special_state)
	return lut_texture

func _update_special_state(states: Dictionary):
	for prov_uuid in states:
		var province_color = Global.base_province[prov_uuid].color.to_html(false)
		var col = prov_state_2_color.get(int(states[prov_uuid]))
		
		# 这里prov state to color 为什么不能使用get? because int as key?
		# 因为该死的Float和Int
		if not col: col = prov_state_2_color.get(PROV_STATE[states[prov_uuid]])
		if not col: col = Color.from_string(states[prov_uuid],Color.WHITE)
		# 支持该死的三种写法
		
		lut_image.set_pixel(
			_color_to_idx_map[province_color],
			0,
			col
			# 也就是说可以使用prov-state内的东西也可以使用string color
			# 但上游应该做了数据校验
		)
		lut_texture.update(lut_image)
	return lut_texture
	

func _update_faction(ownership: Dictionary):
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
