extends Node2D

var datamodel: PoetData
var index_image: Image
var color_2_province: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	for item in Global.poet_data.values():
		var node = character_point.instantiate()
		var vec = Vector2(Global.life_path_points[item.path_point_keys[0]].position)
		var color = item.color
		node.modulate = color
		node.position = vec
		node.get_node('Label').text = item.name
		node.datamodel = item
		add_child(node)
	
	create_provinces()
	render_factions()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func render_factions():
	# 1. 建立 [州ID -> 势力对象] 的映射
	var prov_2_fac := {}
	for fac_id in Global.factions:
		var fac: Faction = Global.factions[fac_id]
		# 解析该势力下属的所有原子州 ID
		var prov_ids = Util.resolve_to_provinces(fac.provinces)
		for p_id in prov_ids:
			prov_2_fac[p_id] = fac

	# 2. 更新势力颜色查找表 (LUT)
	# 这个函数应该返回那张 512x1 的贴图
	var lut_tex = $FactionMapRenderer.refresh_lut_image(prov_2_fac)
	
	# 3. 【核心修正】重焙地理索引图
	# 你需要拿到那张原始的、带颜色的 index_map 图片资源
	# 假设你已经把它加载到了某个变量里，比如 Global.original_index_image
	var original_map_img = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	
	# 将“原始地理图”重焙为“机器索引图”
	var color_2_idx_tex = Util.bake_index_map(original_map_img, $FactionMapRenderer._color_to_idx_map)
	
	# 4. 获取目标材质
	# 注意：你之前说要用新的 Mesh，请确保路径是对的。
	# 如果是叠层，应该是 $background/FactionOverlayMesh
	var mat = $background/FactionMesh.material as ShaderMaterial
	DebugUtils.save_texture_to_disk(lut_tex, 'lut')
	DebugUtils.save_texture_to_disk(color_2_idx_tex, 'color to idx map')
	if mat:
		mat.set_shader_parameter('faction_lut', lut_tex)
		mat.set_shader_parameter('color_to_idx_map', color_2_idx_tex)
		Logging.info("大唐版图渲染成功：数据已注入 Shader。🤓☝️")
	else:
		Logging.error("材质获取失败！你是想把画涂在空气里吗？😡")
		

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var prov = get_province()
		if not prov:
			Logging.debug('用户没有点击到province')
			return
		on_prov_clicked(prov)

func on_prov_clicked(prov: Territory):
	Logging.info('user click %s prov with a capital of %s' % [prov.name,prov.capital])
	EventBus.user_click_map.emit(prov)
	var mat = $background/ClickMesh.material as ShaderMaterial
	mat.set_shader_parameter('selected_id_color',prov.color)
	print("验证注入:", mat.get_shader_parameter('selected_id_color'))
	print(prov.color)

func get_province():
	if not index_image: return null
	var local_pos = $background.to_local(get_global_mouse_position())
	var aabb_size = $background/TerrainMesh.mesh.get_aabb().size / 2
	var vec2_aabb = Vector2(aabb_size.x, aabb_size.y)
	local_pos += vec2_aabb * $background/TerrainMesh.scale
	var s = index_image.get_size()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > s.x or local_pos.y > s.y:
		Logging.err('点偏了')
		return

	var c = index_image.get_pixelv(Vector2i(local_pos))
	return color_2_province.get(c.to_html(false).to_lower())

func create_provinces():
	var map_tex = load(Global.PROVINCE_INDEX_MAP_PATH)
	index_image = map_tex.get_image()
	load_indexs()

func load_indexs():
	if not FileAccess.file_exists(Global.PROVINCE_INDEX_CSV_PATH):
		Logging.err('can not found province index csv in %s' % Global.PROVINCE_INDEX_CSV_PATH)
		return
	
	var file = FileAccess.open(Global.PROVINCE_INDEX_CSV_PATH,FileAccess.READ)
	file.get_line()
	while !file.eof_reached():
		var data = file.get_csv_line()
		if not data[0]:Territory
		var color = data[0].to_lower().strip_edges()
		var province = Territory.new({
			'color': data[0],
			'uuid': data[1],
			'capital': (data[2]),
			'stability': float(data[3])
		})
		province.color = Color.from_string(color,Color.WHEAT)
		color_2_province[province.color.to_html(false)] = province
