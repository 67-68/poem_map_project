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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var prov = get_province()
		if not prov:
			Logging.debug('用户没有点击到province')
			return
		on_prov_clicked(prov)

func on_prov_clicked(prov: ProvinceResource):
	Logging.info('user click %s prov with a capital of %s' % [prov.name,prov.capital])
		
func get_province():
	if not index_image: return null
	var local_pos = $background.to_local(get_global_mouse_position())
	local_pos += $background.texture.get_size() / 2
	var s = index_image.get_size()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > s.x or local_pos.y > s.y:
		Logging.err('点偏了')
		return

	var c = index_image.get_pixelv(Vector2i(local_pos))
	return color_2_province.get(c.to_html(false).to_lower())

func create_provinces():
	var map_tex = load(Global.PROVINCE_MAP_PATH)
	index_image = map_tex.get_image()
	load_indexs()

func load_indexs():
	if not FileAccess.file_exists(Global.PROVINCE_INDEX_PATH):
		Logging.err('can not found province index csv in %s' % Global.PROVINCE_INDEX_PATH)
		return
	
	var file = FileAccess.open(Global.PROVINCE_INDEX_PATH,FileAccess.READ)
	file.get_line()
	while !file.eof_reached():
		var data = file.get_csv_line()
		var color = data[0].to_lower().strip_edges()
		var province = ProvinceResource.new({
			'color': data[0],
			'uuid': data[1],
			'capital': (data[2]),
			'stability': float(data[3])
		})
		province.color = Color.from_string(color,Color.WHEAT)
		color_2_province[province.color.to_html(false)] = province
