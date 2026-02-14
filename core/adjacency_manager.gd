class_name AdjacencyManager extends RefCounted

static func get_adjacency_map(idx_img: Image, color_to_id: Dictionary, force_babake := false):
	if not force_babake and FileAccess.file_exists(Global.ADJACENCY_CACHE_PATH):
		var file = FileAccess.open(Global.ADJACENCY_CACHE_PATH,FileAccess.READ)
		var json_data = JSON.parse_string(file.get_as_text())
		if json_data is Dictionary:
			Logging.info('已经加载缓存数据')
			return json_data
		
	Logging.info('正在扫描像素')
	#breakpoint # 是不是这里没有数据导致的，没错
	var connections = _scan_pixels(idx_img,color_to_id)

	Util.save_to(connections,Global.ADJACENCY_CACHE_PATH)
	return connections

static func _scan_pixels(index_img: Image,color_2_id: Dictionary):
	var connections = {}
	var w = index_img.get_width()
	var h = index_img.get_height()
	
	var step = 3 # 每3像素看一眼
	
	for y in range(0, h - step, step):
		for x in range(0, w - step, step):
			var pix = index_img.get_pixel(x,y)
			if pix.a < 0.1: continue # 不是要找的

			var id = color_2_id.get(pix.to_html(false))
			if not id: continue

			var check_points = [Vector2i(x + step,y), Vector2i(x, y + step)]
			for cp in check_points:
				var p_next = index_img.get_pixel(cp.x, cp.y)
				if p_next.a < 0.1: continue

				var id_next = color_2_id.get(p_next.to_html(false))
				if id_next and id_next != id:
					_add_connection(connections, id,id_next)
	return connections

static func _add_connection(dict: Dictionary, a: String, b: String):
	if not dict.has(a): dict[a] = []
	if not dict.has(b): dict[b] = []
	
	if not b in dict[a]: dict[a].append(b)
	if not a in dict[b]: dict[b].append(a)
