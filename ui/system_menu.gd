extends CanvasLayer
class_name SystemMenu

## SystemMenu — 遁入虚无
## Esc 唤出，全屏高斯模糊 + 时间绝对静止
## 第一期：仅「继续游戏」+「返回主菜单」

@onready var _blur_rect: ColorRect = $BlurRect
@onready var _continue_btn: Button = $CenterContainer/VBoxContainer/ContinueBtn
@onready var _return_btn: Button = $CenterContainer/VBoxContainer/ReturnBtn

# BlurOverlay 的 shader material 引用（与 main.tscn 中共享同一个 shader）
var _blur_material: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000

	# 从 main.tscn 的 BlurOverlay 复用 shader
	_load_blur_material()

	# 初始隐藏
	visible = false

	# 按钮连线
	_continue_btn.pressed.connect(_on_continue)
	_return_btn.pressed.connect(_on_return_to_menu)

	Logging.info("SystemMenu: 就绪")


func _load_blur_material() -> void:
	var tree := get_tree()
	if not tree:
		return
	var root := tree.root
	if not root:
		return

	var main_node := root.get_node_or_null("Main")
	if not main_node:
		Logging.warn("SystemMenu: 无法找到 Main 节点，无法加载模糊材质")
		return

	var blur_overlay := main_node.get_node_or_null("MapLayer/Worldroot/BlurOverlay") as ColorRect
	if not blur_overlay:
		Logging.warn("SystemMenu: 无法找到 BlurOverlay 节点")
		return

	_blur_material = blur_overlay.material as ShaderMaterial
	if _blur_material:
		# 创建独立副本，避免影响原有 BlurOverlay
		_blur_rect.material = _blur_material.duplicate() as ShaderMaterial
		Logging.info("SystemMenu: 模糊材质已加载")
	else:
		Logging.warn("SystemMenu: BlurOverlay 的材质不是 ShaderMaterial")


# ═══════════════════════════════════════════════
# 显示/隐藏生命周期
# ═══════════════════════════════════════════════

func open_menu() -> void:
	Logging.info("SystemMenu: 打开系统菜单")
	visible = true

	# ── 激活高斯模糊 ──
	if _blur_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _blur_rect.material as ShaderMaterial
		mat.set_shader_parameter("blur_amount", 4.0)
		mat.set_shader_parameter("darken_amount", 0.6)

	# ── 世界绝对静止 ──
	TimeService.pause_world(true)


func close_menu() -> void:
	Logging.info("SystemMenu: 关闭系统菜单")
	visible = false

	# ── 关闭模糊 ──
	if _blur_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _blur_rect.material as ShaderMaterial
		mat.set_shader_parameter("blur_amount", 0.0)
		mat.set_shader_parameter("darken_amount", 0.0)

	# ── 恢复世界 ──
	TimeService.resume_world()


# ═══════════════════════════════════════════════
# 按钮回调
# ═══════════════════════════════════════════════

func _on_continue() -> void:
	Logging.info("SystemMenu: 继续游戏")
	close_menu()


func _on_return_to_menu() -> void:
	Logging.info("SystemMenu: 返回主菜单")
	# 先恢复世界时间，避免主菜单卡死
	TimeService.resume_world()
	get_tree().change_scene_to_file("res://main_menu.tscn")
