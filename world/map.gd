extends Node2D

var datamodel: PoetData
var index_image: Image
var color_2_province: Dictionary

func _ready() -> void:
	Global.map = self
	Global.request_add_messager.connect(_on_add_messager)
	# 2. 加载并赋值
	$MessagerManager.mesh = $background/BorderMesh
	Logging.info("✅ 赋值成功，当前 Mesh 资源: %s" % $MessagerManager.mesh)

	create_provinces()
	Logging.done('create province')
	render_factions()
	Logging.done('render faction')

func _on_add_messager(msg: Messager):
	$background/PathMesh.add_child(msg)

func load_character_point():
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
		Logging.done('character point')

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
	
	Logging.done('create prov to faction dict','render factions')
	
	
	# 2. 更新势力颜色查找表 (LUT)
	# 这个函数应该返回那张 512x1 的贴图
	var lut_tex = $FactionMapRenderer.refresh_lut_image(prov_2_fac)
	
	# 3. 【核心修正】重焙地理索引图
	# 你需要拿到那张原始的、带颜色的 index_map 图片资源
	# 假设你已经把它加载到了某个变量里，比如 Global.original_index_image
	var original_map_img = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	# 将“原始地理图”重焙为“机器索引图”
	var color_2_idx_tex = Util.bake_index_map(original_map_img, $FactionMapRenderer._color_to_idx_map)
	# 是重焙的问题！
	Logging.done('rebake index map to machine index map','render faction')
	
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
	Logging.info('user click %s prov with a uv_position of %s' % [prov.name,prov.uv_position])
	Logging.info('uuid: ' + prov.uuid)
	Logging.info('color: ' + prov.color.to_html(false))
	Logging.info('position: %s' % prov.get_local_pos($background/ClickMesh))
	EventBus.user_click_map.emit(prov)
	var mat = $background/ClickMesh.material as ShaderMaterial
	mat.set_shader_parameter('selected_id_color',prov.color)
	#print("验证注入:", mat.get_shader_parameter('selected_id_color'))
	#print(prov.color)

func get_province():
	var mesh_node = $background/ClickMesh
	# 1. 拿到相对于 Mesh 节点的局部位置
	var local_pos = mesh_node.to_local(get_global_mouse_position())
	
	# 2. 获取 Mesh 的实际显示尺寸（考虑缩放）
	var rect_size = mesh_node.mesh.get_aabb().size
	rect_size[0] *= mesh_node.scale[0]
	rect_size[1] *= mesh_node.scale[1]
	
	# 3. 计算归一化坐标 (假设 Mesh 原点在中心)
	# 如果原点在左上角，则不需要加 0.5
	var uv = (Vector2(local_pos.x, local_pos.y) / Vector2(rect_size.x, rect_size.y))
	
	# 边界检查
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return null
		
	# 4. 映射到图片像素坐标
	var img_size = index_image.get_size()
	var pixel_pos = Vector2i(uv.x * float(img_size.x), uv.y * float(img_size.y))
	
	# 5. 直接采样（注意防止越界）
	var c = index_image.get_pixelv(pixel_pos.clamp(Vector2i.ZERO, img_size - Vector2i.ONE))
	
	# 6. 使用整数或原始颜色对象查表
	return color_2_province.get(c.to_html(false))

func create_provinces():
	var map_tex = load(Global.PROVINCE_INDEX_MAP_PATH)
	index_image = map_tex.get_image()
	load_indexs()

func load_indexs():
	for prov_uid in Global.base_province:
		var prov = Global.base_province[prov_uid]
		color_2_province[prov.color.to_html(false)] = prov
	Global.color_2_province = color_2_province


func fade_world_to_dark(duration: float):
	Logging.change('world_color','dark')
	change_world_color(Color.GRAY)
	get_tree().create_timer(duration).timeout.connect(restore_world_color)

func restore_world_color(duration: float):
	Logging.change('world_color','normal')
	change_world_color(Color.WHITE)
	get_tree().create_timer(duration).timeout.connect(fade_world_to_dark)

func change_world_color(color: Color):
	Logging.change('world_color',color.to_html(false))
	$CanvasModulate.color = color
