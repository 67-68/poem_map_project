extends Camera2D

# ---------------------------------------------------------
# 🛠️ 架构师的 Debug 工具箱：全知之眼 (Omniscient Eye)
# ---------------------------------------------------------
# 这是一个极其务实的 Debug 摄像机。
# 它不追求平滑的插值（Lerp），只追求像手术刀一样精准的控制。
# 
# 使用方法：
# 1. 将此脚本挂载到你的 Camera2D 节点上。
# 2. 运行游戏。
# 3. 滚轮缩放，右键/中键拖拽。
# 4. 按 Q 键复位。
# ---------------------------------------------------------

@export_group("Debug Zoom")
@export var min_zoom: float = 0.1 # 拉得极远，看清全局 (0.1 = 10倍视野)
@export var max_zoom: float = 5.0 # 拉得极近，看清像素
@export var zoom_speed: float = 0.1

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("🎥 [DebugCamera] Online. Use Wheel to Zoom, Right/Middle Click to Drag, Q to Reset.")
	# 确保摄像机是启用的
	enabled = true
	# 某些情况下，我们需要忽略父节点的变换，但这取决于你的场景结构
	# top_level = true 

var zoom_level := 1.0
const ZOOM_MAX = 2.0  # 拉到最近，看长安的街道
const ZOOM_MIN = 0.3  # 拉到最远，退回大唐地图的阈值
const ZOOM_SPEED = 0.1
var current_state = 'city' # 'city' or 'world'

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: # 拉近
			zoom_level += ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: # 拉远
			zoom_level -= ZOOM_SPEED
			
		# 限制缩放范围
		zoom_level = clamp(zoom_level, ZOOM_MIN - 0.1, ZOOM_MAX)
		
		# 使用 Tween 让缩放极其丝滑 (强烈建议！)
		var tween = create_tween()
		tween.tween_property(self, "zoom", Vector2(zoom_level, zoom_level), 0.2)
		
		# 🌟 核心魔法：跨越阈值的维度打击！
		if zoom_level >= ZOOM_MIN and current_state != 'city':
			Global.focus_city_map.emit(true)
			current_state = 'city'
		elif zoom_level <= ZOOM_MAX and current_state != 'world':
			Global.focus_city_map.emit(false)
			current_state = 'world'

func _unhandled_input(event: InputEvent) -> void:
	# 1. 缩放控制 (滚轮)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 向上滚，放大 (Zoom 值变大，视野变小？Godot 的 Zoom 是放大倍数)
			# Godot 4: Zoom (2,2) = 2x Magnification (Objects look bigger)
			_change_zoom(1 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 向下滚，缩小
			_change_zoom(1 - zoom_speed)
		
		# 2. 拖拽控制 (右键 或 中键)
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_dragging = true
				_last_mouse_pos = event.position
			else:
				_dragging = false

	# 3. 拖拽移动逻辑
	if event is InputEventMouseMotion and _dragging:
		# 屏幕上的移动增量
		var delta = event.position - _last_mouse_pos
		
		# 摄像机移动方向与鼠标相反（拖拽地图的感觉）
		# 并且移动速度需要除以当前的缩放倍率，否则放大时移动太快
		position -= delta / zoom.x 
		
		_last_mouse_pos = event.position

	# 4. 快捷键复位 (Q)
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		print("🎥 [DebugCamera] Resetting Position")
		position = Vector2.ZERO # 或者你的地图中心
		zoom = Vector2(1, 1)

func _change_zoom(factor: float) -> void:
	var new_zoom = zoom * factor
	# 限制缩放范围，防止视界坍缩 💀
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	zoom = new_zoom
	
	# 可选：打印当前缩放，让你心里有数
	# print("🔍 Zoom Level: ", snapped(zoom.x, 0.01))