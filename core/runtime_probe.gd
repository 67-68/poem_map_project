extends Node

# =============================================================================
# RuntimeProbe - 活体探针 (Read-Only Runtime Probe)
# 本 Autoload 在游戏运行时启动一个极简的 HTTP 本地服务器，
# 通过纯只读接口暴露游戏当前内存状态（场景树、全局状态、事件系统）。
#
# 🛡️ 契约：只读 (Read-Only)
#   - 仅支持 GET 请求
#   - 不暴露任何写操作、反射调用、或 eval()
#   - 任何非 GET 请求返回 405 Method Not Allowed
#
# 端口：6066
# 协议：纯 HTTP (无状态，无 WebSocket，断线重连、心跳包皆不存在)
# =============================================================================

const PORT := 6066
const MAX_SCENE_TREE_DEPTH := 20

var _server := TCPServer.new()
var _active_connections: Array[StreamPeerTCP] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var err := _server.listen(PORT, "0.0.0.0")
	if err != OK:
		Logging.err("[RuntimeProbe] 活体探针启动失败！端口 " + str(PORT) + " 被占用，错误码: " + str(err))
		return

	Logging.info("[RuntimeProbe] 🟢 活体探针已上线，监听端口: " + str(PORT))
	Logging.info("[RuntimeProbe] 端点列表:")
	Logging.info("[RuntimeProbe]   GET /api/scene_tree   - 当前场景树结构")
	Logging.info("[RuntimeProbe]   GET /api/game_state   - 玩家/全局状态")
	Logging.info("[RuntimeProbe]   GET /api/event_system - 事件系统状态")
	Logging.info("[RuntimeProbe]   GET /api/logs         - 运行日志流（环形缓冲区）")


func _process(_delta: float) -> void:
	# ── 1. 接受新连接 ──
	if _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer:
			_active_connections.append(peer)
			Logging.debug("[RuntimeProbe] 新连接接入")

	# ── 2. 处理已就绪的连接 ──
	var remaining: Array[StreamPeerTCP] = []
	for conn in _active_connections:
		if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue  # 连接已断开，跳过

		var bytes_avail := conn.get_available_bytes()
		if bytes_avail <= 0:
			remaining.append(conn)
			continue  # 数据未就绪，留待下一帧

		# 读取 HTTP 请求
		var request_data := _read_http_request(conn)
		if request_data.is_empty():
			remaining.append(conn)
			continue  # 请求尚未完整接收

		# 解析并响应
		_handle_request(conn, request_data)
		# 关闭连接（HTTP 无状态，用完即走）
		conn.disconnect_from_host()

	_active_connections = remaining


# ─────────────────────────────────────────────────────────────────────────────
# HTTP 请求解析（极简版 – 只解析第一行，不解析 headers）
# ─────────────────────────────────────────────────────────────────────────────
static func _read_http_request(peer: StreamPeerTCP) -> Dictionary:
	"""
	从 StreamPeerTCP 读取 HTTP 请求。
	返回: { "method": "GET", "path": "/api/scene_tree" }，或空字典表示未就绪。
	"""
	const BUFFER_SIZE := 4096

	var raw := peer.get_partial_data(BUFFER_SIZE)
	if raw[0] != OK:
		return {}

	var data: PackedByteArray = raw[1]
	var request_str := data.get_string_from_utf8()
	if request_str.is_empty():
		return {}

	# 只解析第一行 (请求行)
	var lines := request_str.split("\r\n")
	if lines.is_empty():
		return {}

	var request_line := lines[0]
	var parts := request_line.split(" ")
	if parts.size() < 2:
		return {}

	return {
		"method": parts[0].to_upper(),
		"path": parts[1],
		"raw": request_str
	}


# ─────────────────────────────────────────────────────────────────────────────
# 请求路由（只读契约的核心防御层）
# ─────────────────────────────────────────────────────────────────────────────
func _handle_request(peer: StreamPeerTCP, request: Dictionary) -> void:
	# 🛡️ 只允许 GET
	if request["method"] != "GET":
		_send_http_response(peer, 405, JSON.stringify({
			"error": "Method Not Allowed",
			"message": "本探针仅接受 GET 请求。"
		}))
		return

	var full_path := request["path"] as String

	# ── 分离路径和 query string ──
	var endpoint_path := full_path
	var query_params: Dictionary = {}
	var qmark := full_path.find("?")
	if qmark != -1:
		endpoint_path = full_path.substr(0, qmark)
		query_params = _parse_query_string(full_path.substr(qmark + 1))

	match endpoint_path:
		"/api/scene_tree":
			_send_http_response(peer, 200, _serialize_scene_tree())

		"/api/game_state":
			_send_http_response(peer, 200, _serialize_game_state())

		"/api/event_system":
			_send_http_response(peer, 200, _serialize_event_system())

		"/api/logs":
			var since := int(query_params.get("since", "0"))
			var limit := int(query_params.get("limit", "500"))
			_send_http_response(peer, 200, _serialize_logs(since, limit))

		_:
			_send_http_response(peer, 404, JSON.stringify({
				"error": "Not Found",
				"message": "未知端点。可用端点: /api/scene_tree, /api/game_state, /api/event_system, /api/logs",
				"available_endpoints": ["/api/scene_tree", "/api/game_state", "/api/event_system", "/api/logs"]
			}))


# ── 极简 query string 解析器 ──
static func _parse_query_string(qs: String) -> Dictionary:
	"""
	解析 URL query string，如 "since=10&limit=50" → {"since": "10", "limit": "50"}
	只支持简单键值对，不处理嵌套/数组/URL 解码。
	"""
	var result: Dictionary = {}
	if qs.is_empty():
		return result
	for pair in qs.split("&"):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2 and not kv[0].is_empty():
			result[kv[0]] = kv[1]
	return result


# ─────────────────────────────────────────────────────────────────────────────
# HTTP 响应发送（标准 HTTP/1.1）
# ─────────────────────────────────────────────────────────────────────────────
static func _send_http_response(peer: StreamPeerTCP, status_code: int, body: String) -> void:
	var status_text := "OK"
	match status_code:
		404:
			status_text = "Not Found"
		405:
			status_text = "Method Not Allowed"
		500:
			status_text = "Internal Server Error"

	var body_bytes := body.to_utf8_buffer()
	var response := "HTTP/1.1 " + str(status_code) + " " + status_text + "\r\n" \
			+ "Content-Type: application/json; charset=utf-8\r\n" \
			+ "Content-Length: " + str(body_bytes.size()) + "\r\n" \
			+ "Access-Control-Allow-Origin: *\r\n" \
			+ "Cache-Control: no-store\r\n" \
			+ "Connection: close\r\n" \
			+ "\r\n"

	# 先发 headers
	var header_bytes := response.to_utf8_buffer()
	peer.put_data(header_bytes)
	# 再发 body
	peer.put_data(body_bytes)


# ─────────────────────────────────────────────────────────────────────────────
# API 1: GET /api/scene_tree
# 返回当前场景树的层级结构（元数据，不序列化属性值）
# ─────────────────────────────────────────────────────────────────────────────
func _serialize_scene_tree() -> String:
	if not is_inside_tree():
		return JSON.stringify({"error": "RuntimeProbe 尚未挂入场景树"})

	var root := get_tree().root
	var data := _serialize_node(root, 0)
	var result := {
		"ok": true,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data
	}
	return JSON.stringify(result)


static func _serialize_node(node: Node, depth: int) -> Dictionary:
	"""
	递归序列化节点。
	返回: { name, class_name, child_count, visible, children[...] }
	"""
	# Window 节点继承 Node 而非 CanvasItem，没有 is_visible_in_tree() 方法
	var visible: bool = true
	if node is CanvasItem:
		visible = node.is_visible_in_tree()
	elif node.has_method("is_visible_in_tree"):
		visible = node.is_visible_in_tree()

	var result: Dictionary = {
		"name": node.name,
		"class_name": "",  # 后续尝试获取
		"child_count": node.get_child_count(),
		"visible": visible,
	}

	# 尝试获取脚本的 class_name（如果有 class_name 声明）
	var script_obj = node.get_script()
	if script_obj:
		var script: Script = script_obj
		var global_name = script.get_global_name()
		if not global_name.is_empty():
			result["class_name"] = global_name

	# 递归子节点（限制深度）
	if depth < MAX_SCENE_TREE_DEPTH and node.get_child_count() > 0:
		var children: Array[Dictionary] = []
		for child in node.get_children():
			children.append(_serialize_node(child, depth + 1))
		result["children"] = children

	return result


# ─────────────────────────────────────────────────────────────────────────────
# API 2: GET /api/game_state
# 合并输出 PlayerState + GameState 的当前关键状态
# ─────────────────────────────────────────────────────────────────────────────
func _serialize_game_state() -> String:
	var ps := PlayerState  # Autoload
	var gs := GameState    # Autoload

	if not ps or not gs:
		return JSON.stringify({"error": "PlayerState 或 GameState Autoload 不可用"})

	# 收集所有属性统计值
	var stats := {}
	var prop_names := ["OFFICIAL_PRESTIGE", "LITERARY_FAME", "TALENT", "MONEY",
		"HEALTH", "FATIGUE", "BURNOUT", "DRUNK", "SICK",
		"INSPIRATION", "CAREER_PROGRESS"]
	for prop_name in prop_names:
		var val = ps.get_stat_val(prop_name)
		stats[prop_name.to_lower()] = val

	# 收集 flags
	var flags_copy := {}
	for key in ps.flags:
		flags_copy[key] = ps.flags[key]

	# 收集 emotions
	var emotions_copy := {}
	for key in ps.emotions:
		emotions_copy[key] = ps.emotions[key]

	# 重构 trait 列表（包含名称）
	var traits_data: Array[Dictionary] = []
	for t_key in ps.traits:
		var t = Database.get_trait(t_key)
		traits_data.append({
			"key": t_key,
			"name": t.name if t else "unknown"
		})

	var result := {
		"ok": true,
		"timestamp": Time.get_unix_time_from_system(),
		"data": {
			"player": {
				"name": ps.player_name,
				"current_location": ps.current_location,
				"ambition": {
					"key": ps.ambition.uuid if ps.ambition else null,
					"name": ps.ambition.name if ps.ambition else null
				} if ps.ambition else null,
				"current_action_tags": ps.current_action_tags,
				"created_poems_count": ps.created_poems.size() if ps.created_poems else 0,
			},
			"stats": stats,
			"traits": traits_data,
			"flags": flags_copy,
			"emotions": emotions_copy,
			"game": {
				"year": gs.year,
				"ratio_time": gs.ratio_time,
				"mood": gs.mood,
				"time_span": gs.time_span,
				"start_year": gs.start_year,
				"end_year": gs.end_year,
			}
		}
	}
	return JSON.stringify(result)


# ─────────────────────────────────────────────────────────────────────────────
# API 3: GET /api/event_system
# 导出 EventManager 的当前签筒和保证事件状态
# ─────────────────────────────────────────────────────────────────────────────
func _serialize_event_system() -> String:
	var em := EventManager  # Autoload

	if not em:
		return JSON.stringify({"error": "EventManager Autoload 不可用"})

	# 序列化当前签筒
	var event_pool_data: Array[Dictionary] = []
	for ticket in em.current_event_pool:
		event_pool_data.append({
			"event_uuid": ticket.event_uuid,
			"weight": ticket.weight,
			"original_weight": ticket.original_weight
		})

	# 序列化 guarantee FIFO 队列（已从 _guaranteed_event_key/_guaranteed_main_tag 重构为 _guaranteed_events: Array[Dictionary]）
	var guaranteed_events_data: Array[Dictionary] = []
	for entry in em._guaranteed_events:
		guaranteed_events_data.append({
			"event_key": entry.event_key,
			"main_tag": entry.main_tag,
		})

	var result := {
		"ok": true,
		"timestamp": Time.get_unix_time_from_system(),
		"data": {
			"current_event_pool": event_pool_data,
			"guaranteed_events": guaranteed_events_data,
			"guaranteed_event_key": "",  # 向后兼容：已废弃，保留字段避免下游解析崩溃
			"guaranteed_main_tag": "",   # 向后兼容：已废弃
			"pool_size": event_pool_data.size(),
		}
	}
	return JSON.stringify(result)


# ─────────────────────────────────────────────────────────────────────────────
# API 4: GET /api/logs
# 返回 Logging 环形缓冲区中的最近日志
# ─────────────────────────────────────────────────────────────────────────────
func _serialize_logs(since: int = 0, limit: int = 500) -> String:
	var logs := Logging.get_logs_since(since, limit)
	var total := Logging.get_total_buffered()
	var current_seq := Logging.get_current_seq()
	var result := {
		"ok": true,
		"timestamp": Time.get_unix_time_from_system(),
		"data": {
			"logs": logs,
			"total_buffered": total,
			"current_seq": current_seq
		}
	}
	return JSON.stringify(result)
