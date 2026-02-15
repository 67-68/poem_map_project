@tool
# ----------------------------------------------------------------
# NavigationService - 逻辑层
# ----------------------------------------------------------------
extends Node


@export var debug_find_orphan_id: bool = false:
	set(val):
		if val:
			init()
			debug_find_orphan_id = false
			var ids := []
			for item in Global.base_province:
				ids.append(item)
			var orphans = DebugUtils.find_orphans(ids,adjacency_map)
			Logging.info('debug orphan done: %s' % orphans)

@export var graph_connectivity: bool = false:
	set(val):
		if val:
			init()
			graph_connectivity = false
			var ids := []
			for item in Global.base_province:
				ids.append(item)
			DebugUtils.analyze_graph_connectivity(ids,adjacency_map)

# 引用这个临时的 Debug 节点
var _debug_overlay: Control

@export var debug_draw_connections: bool = false:
	set(val):
		if val:
			init()
			# 这里的 val 不设为 false，让开关保持开启状态可能更好，看你习惯
			# debug_draw_connections = false 
			_toggle_debug_view()
			debug_draw_connections = false # 复位开关，像个按钮一样用

func _toggle_debug_view():
	# 1. 确保数据存在
	if Global.base_province.is_empty():
		Logging.warn("没有省份数据，无法绘制！")
		return

	# 2. 准备数据
	var centers := {}
	# 注意：在 @tool 模式下获取 BorderMesh 可能需要更稳健的路径查找
	var border_mesh = Global.map.get_node_or_null("background/BorderMesh") 
	
	if not border_mesh:
		push_error("找不到 BorderMesh，无法计算坐标！")
		return

	for item in Global.base_province.values():
		# 确保 get_local_pos 能在工具模式下工作
		centers[item.uuid] = item.get_local_pos(border_mesh)

	# 3. 实例化或获取 Overlay
	if not is_instance_valid(_debug_overlay):
		# 检查是否已经有一个（避免重复添加）
		var existing = get_node_or_null("DebugOverlay")
		if existing:
			_debug_overlay = existing
		else:
			# 动态创建一个节点
			var overlay = preload("res://tests/debug_overlay.gd").new() # 或者直接用内部类
			overlay.name = "DebugOverlay"
			
			# 设置全屏/铺满
			overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # 别挡住鼠标点击
			
			# 挂载到场景树上（建议挂在 Map 节点或者当前节点下）
			add_child(overlay)
			overlay.owner = get_tree().edited_scene_root # 这一步是为了让它在编辑器里可见
			_debug_overlay = overlay
			Logging.info("创建了新的 DebugOverlay")

	# 4. 喂数据并刷新
	_debug_overlay.update_debug_info(adjacency_map, centers)
	Logging.info("已请求绘制连接线...")

# 清理逻辑（可选）：再点一次开关删除 Overlay
func _clear_debug():
	if is_instance_valid(_debug_overlay):
		_debug_overlay.queue_free()

var astar: AStar2D
var prov_2_idx: Dictionary = {} # { "su_zhou": 1 }
var idx_2_prov: Dictionary = {}
var dirty = true
var adjacency_map: Dictionary

func init():
	if not dirty: return
	dirty = false
	astar = AStar2D.new()
	var color_2_prov := {}

	# 预处理颜色字典
	for p_id in Global.base_province:
		var prov = Global.base_province[p_id]
		color_2_prov[prov.color.to_html(false)] = p_id
	
	# 2. 获取邻接数据 (注意：load 需要加上 .get_image())
	var img = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	adjacency_map = AdjacencyManager.robust_scan(img, color_2_prov)
	
	# 3. 注册节点
	var idx = 0
	for uid in Global.base_province:
		var prov = Global.base_province[uid]
		# 警告修复：add_point 的参数顺序是 (id, position)
		var pos = prov.get_local_pos(Global.map.get_node('background/BorderMesh'))
		astar.add_point(idx,pos)  # 这里的position的问题！！！
		prov_2_idx[uid] = idx
		idx_2_prov[idx] = uid
		idx += 1
	
	# 4. 【关键缺失修复】：必须建立连接，AStar 才能工作
	for p_id in adjacency_map:
		var from_idx = prov_2_idx.get(p_id, -1)
		for neighbor_id in adjacency_map[p_id]:
			var to_idx = prov_2_idx.get(neighbor_id, -1)
			if from_idx != -1 and to_idx != -1:
				astar.connect_points(from_idx, to_idx)
	
	create_connection_manual()
	Logging.info('a star done build cache')

func create_connection_manual():
	"""
	如果以后出问题了: 来怀疑是不是这里没连上
	"""
	# ---------------------------------------------------------
	# 👷 架构师补丁：基建狂魔手动架桥模式
	# ---------------------------------------------------------
	# 这是一个手动指定的连接列表，专门用来跨越宽阔的河流或地图裂缝
	var manual_bridges = [
		["wei_zhou_shield",'hua_zhou'],
		["di_zhou",'qi_zhou_zhan_guo'],
		['hui_zhou','wei_zhou'],
		['yong_zhou','jin_zhou_gold'],
		['long_zhou_2','shi_zhou_start'],
		['mian_zhou','shi_zhou_start'],
		['yi_zhou_2','bo1_zhou'],
		['he_zhou_4','dao_zhou'],
		['run_zhou','yang_zhou'],
		['huang_zhou','mian_zhou_2'],
		['chu_zhou_2','si_zhou']
	]

	for bridge in manual_bridges:
		var id_a = bridge[0]
		var id_b = bridge[1]
		
		# 确保双方都在地图里
		if not prov_2_idx.has(id_a) or not prov_2_idx.has(id_b):
			Logging.warn("无法架桥：找不到 ID %s 或 %s" % [id_a, id_b])
			continue
			
		# 强制在邻接表中添加关系（这一步其实为了缓存可以不做，但为了逻辑一致性建议加上）
		if not adjacency_map.has(id_a): adjacency_map[id_a] = []
		if not adjacency_map.has(id_b): adjacency_map[id_b] = []
		
		if not id_b in adjacency_map[id_a]: adjacency_map[id_a].append(id_b)
		if not id_a in adjacency_map[id_b]: adjacency_map[id_b].append(id_a)
		
		# 直接告诉 AStar 连起来！
		var idx_a = prov_2_idx[id_a]
		var idx_b = prov_2_idx[id_b]
		astar.connect_points(idx_a, idx_b, true)
		
		Logging.info("🌉 已手动架桥: %s <---> %s" % [id_a, id_b])
		
# 根据省份 ID 获取路径点 ID 序列
func get_index_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	
	var s = prov_2_idx.get(start_id, -1)
	var e = prov_2_idx.get(end_id, -1)
	if s == -1 or e == -1: return []
	# AStar2D 返回的是 PackedInt32Array
	var path = astar.get_id_path(s, e,true)
	return Array(path)

# 辅助：根据索引反查省份 ID
func get_province_id_from_idx(target_idx: int) -> String:
	if dirty: init()
	return idx_2_prov.get(target_idx)

func get_uuid_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	var path = get_index_id_path(start_id,end_id)
	var uuids = []
	for p in path:
		uuids.append(get_province_id_from_idx(p))
	return uuids

func get_prov_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	var path = get_index_id_path(start_id,end_id)
	var provs = []
	for p in path:
		provs.append(Global.base_province[get_province_id_from_idx(p)])
	return provs
