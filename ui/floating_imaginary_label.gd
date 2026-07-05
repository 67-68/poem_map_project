class_name FloatingImaginaryLabel extends Label
## 漂浮灵感标签 — 在 poem_crafter 的背景层随机漂移，纯展示，不可交互
##
## 行为:
##   - _ready() 时随机分配到左/右侧，设置初始随机位置，启动漂移 Tween 循环
##   - 漂移: Tween 移动到同侧随机目标点，到达后重新选点，无限循环
##   - 中心禁区: 左右各 150px（总计 300px）不进入
##
## 等级视觉:
##   L1: modulate.a = 0.25~0.35 (半透明)
##   L2: modulate.a = 0.65~0.75 (正常)
##   L3: modulate.a = 0.9~1.0 + shadow 微弱发光感

const CENTER_NOZONE_HALF: float = 150.0  ## 中轴线单侧禁区宽度
const SIDE_PADDING: float = 20.0          ## 屏幕边缘留白

## 每段漂移时长范围（秒）
const DRIFT_DURATION_MIN: float = 3.0
const DRIFT_DURATION_MAX: float = 6.0

## 字体大小随机范围
const FONT_SIZE_MIN: int = 22
const FONT_SIZE_MAX: int = 28

## 等级透明度范围
const ALPHA_L1_MIN: float = 0.25
const ALPHA_L1_MAX: float = 0.35
const ALPHA_L2_MIN: float = 0.65
const ALPHA_L2_MAX: float = 0.75
const ALPHA_L3_MIN: float = 0.90
const ALPHA_L3_MAX: float = 1.00

## ── 状态 ──
var _side: int = -1         ## 0=左, 1=右
var _drift_tween: Tween = null
var _imaginary_name: String = ""
var _imaginary_level: int = 1


## 初始化标签: 设置文字、等级、随机分配侧边
func setup(imag_name: String, imag_level: int) -> void:
	_imaginary_name = imag_name
	_imaginary_level = imag_level
	Logging.info('FloatingImaginaryLabel(%s): setup — name=%s, level=%d' % [get_instance_id(), imag_name, imag_level])

	# 1. 显示文字
	text = imag_name

	# 2. 等级视觉
	_apply_level_visual()

	# 3. 随机字体大小
	var font_sz := randi_range(FONT_SIZE_MIN, FONT_SIZE_MAX)
	add_theme_font_size_override("font_size", font_sz)

	# 4. 鼠标穿透
	mouse_filter = MOUSE_FILTER_IGNORE

	# 5. 随机分配侧边
	_side = randi() % 2
	Logging.info('FloatingImaginaryLabel(%s): 分配到%s侧' % [get_instance_id(), "左" if _side == 0 else "右"])

	# 6. 定位到随机初始位置 & 启动漂移
	_snap_to_random_position()
	_start_drift_loop()


## 应用等级视觉（透明度 + 微光）
func _apply_level_visual() -> void:
	match _imaginary_level:
		1:
			var alpha := randf_range(ALPHA_L1_MIN, ALPHA_L1_MAX)
			modulate = Color(1.0, 1.0, 1.0, alpha)
			Logging.info('FloatingImaginaryLabel(%s): L1 半透明 alpha=%.3f' % [get_instance_id(), alpha])
		2:
			var alpha := randf_range(ALPHA_L2_MIN, ALPHA_L2_MAX)
			modulate = Color(1.0, 1.0, 1.0, alpha)
			Logging.info('FloatingImaginaryLabel(%s): L2 正常 alpha=%.3f' % [get_instance_id(), alpha])
		3:
			var alpha := randf_range(ALPHA_L3_MIN, ALPHA_L3_MAX)
			modulate = Color(1.0, 1.0, 1.0, alpha)
			# 微弱发光感: 启用 label 的 shadow
			if has_method("set_label_settings"):
				pass  # Godot 4.x LabelSettings 方式，暂且用 modulate 模拟
			Logging.info('FloatingImaginaryLabel(%s): L3 微光 alpha=%.3f' % [get_instance_id(), alpha])
		_:
			modulate = Color(1.0, 1.0, 1.0, 0.7)
			Logging.warn('FloatingImaginaryLabel(%s): 未知等级 %d，使用默认透明度' % [get_instance_id(), _imaginary_level])


## 立即跳到随机位置（不带动画）
func _snap_to_random_position() -> void:
	var vp_size := _get_viewport_size()
	if vp_size.x <= 0:
		Logging.warn('FloatingImaginaryLabel(%s): viewport 尺寸无效，延迟定位' % get_instance_id())
		return

	var target := _random_position_in_side(vp_size)
	position = target
	Logging.info('FloatingImaginaryLabel(%s): snap to (%d, %d)' % [get_instance_id(), int(target.x), int(target.y)])


## 启动漂移循环
func _start_drift_loop() -> void:
	_drift_to_new_position()


## 单次漂移到新位置，完成后递归调用自身
func _drift_to_new_position() -> void:
	var vp_size := _get_viewport_size()
	if vp_size.x <= 0:
		Logging.warn('FloatingImaginaryLabel(%s): viewport 尺寸无效，跳过漂移' % get_instance_id())
		return

	# 清除旧 Tween
	if _drift_tween and _drift_tween.is_valid():
		_drift_tween.kill()
		Logging.info('FloatingImaginaryLabel(%s): 终止旧 tween' % get_instance_id())

	var target := _random_position_in_side(vp_size)
	var duration := randf_range(DRIFT_DURATION_MIN, DRIFT_DURATION_MAX)

	Logging.info('FloatingImaginaryLabel(%s): 漂移 → (%d, %d), %.2fs' % [get_instance_id(), int(target.x), int(target.y), duration])

	_drift_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_drift_tween.tween_property(self, "position", target, duration)
	_drift_tween.tween_callback(_drift_to_new_position)


## 在所属侧边内随机选一个位置，避开中心禁区
func _random_position_in_side(vp_size: Vector2) -> Vector2:
	var x: float
	var mid := vp_size.x / 2.0

	if _side == 0:
		# 左侧: [SIDE_PADDING, mid - CENTER_NOZONE_HALF]
		x = randf_range(SIDE_PADDING, max(SIDE_PADDING + 1, mid - CENTER_NOZONE_HALF))
	else:
		# 右侧: [mid + CENTER_NOZONE_HALF, vp_size.x - SIDE_PADDING]
		x = randf_range(mid + CENTER_NOZONE_HALF, max(mid + CENTER_NOZONE_HALF + 1, vp_size.x - SIDE_PADDING))

	var y := randf_range(SIDE_PADDING, max(SIDE_PADDING + 1, vp_size.y - SIDE_PADDING))
	return Vector2(x, y)


func _get_viewport_size() -> Vector2:
	if get_viewport():
		return get_viewport().get_visible_rect().size
	Logging.warn('FloatingImaginaryLabel(%s): get_viewport() 返回 null' % get_instance_id())
	return Vector2.ZERO


## 停止漂移并清理（页面关闭时调用）
func stop_and_cleanup() -> void:
	if _drift_tween and _drift_tween.is_valid():
		_drift_tween.kill()
		_drift_tween = null
		Logging.info('FloatingImaginaryLabel(%s): 漂移已停止' % get_instance_id())
