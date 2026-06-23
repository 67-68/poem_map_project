# AnimationController.gd
# 🎯 职责：全局 Autoload，根据事件 uuid 执行动画时间线编排
#
# 两层配置：
#   1. shader_mappings (Dictionary): uuid → ShaderMaterial，简单追加到 tape entry ContentLabel
#   2. timeline_scripts (Dictionary): uuid → Array[Dictionary]，多阶段动画序列
#
# 支持的 action 类型：
#   "clear_stylebox"       — 将目标节点的 theme_override_styles/panel 替换为 StyleBoxEmpty（消除阴影/背景图）
#   "ghostly_white"        — 将 tape entry 内所有文字（title/content/options）设为惨白色
#   "apply_shader"         — 给目标节点挂载 ShaderMaterial
#   "tween_burn"           — 对 TapeContainer 的 burn_progress 做 0→1 tween
#
# 支持的目标 target：
#   "left_panel"           — root/Main/UI/Margin/HBox/LeftPanel 根 PanelContainer
#   "right_panel"          — root/Main/UI/Margin/HBox/RightPanel 根 PanelContainer
#   "narrative_overlay"    — NarrativeOverlay 最外层 PanelContainer（阴影 box）
#   "tape_container"        — NarrativeOverlay/TapeContainer（宣纸纹理）
#   "tape_entry"           — 当前 tape entry（ghostly_white 专用，操作 title/content/options）
#   "option_btns"          — tape entry 的 OptionBtns 容器
#
# 叠加共存：material 与 custom_effects (RichTextEffect) 互不干扰。
extends Node

# ── 简单映射：uuid → ShaderMaterial（仅挂载到 ContentLabel）──
@export var shader_mappings: Dictionary = {}

# ── 时间线脚本：uuid → Array[Dictionary]（多阶段动画序列）──
@export var timeline_scripts: Dictionary = {}

# 纯黑 — 用于 ghostly_white 的文字颜色
const GHOSTLY_WHITE := Color.BLACK

# 硬编码默认：简单 shader 映射
const _DEFAULT_MAPPINGS: Dictionary = {
	"backhome_the_wood": preload("res://shaders/text_chaos_shader_material.tres"),
}

# 硬编码默认：时间线脚本（全体延迟 +10s，等打字机打完）
const _DEFAULT_TIMELINES: Dictionary = {
	"the_end": [
		{ "delay": 0.0, "action": "set_title_font_size", "target": "tape_entry", "font_size": 72 },
		{ "delay": 0.0, "action": "apply_shader", "target": "map_background", "material": preload("res://shaders/anlushan_shader_material.tres") },
		{ "delay": 0.0, "action": "tween_infection", "target": "map_background", "tween_duration": 8.0 },
		{ "delay": 0.0, "action": "camera_shake", "target": "camera", "duration": 8.0, "intensity": 2.0 },
	],
	"backhome_inside_the_wood": [
		# Phase 0 — T+0s (call_deferred): 一开始纯黑字体 + 选项 chaos shader + 消除左右面板及 narrative_overlay 外层阴影
		{ "delay": 0.0, "action": "ghostly_white", "target": "tape_entry" },
		{ "delay": 0.0, "action": "apply_shader", "target": "option_btns", "material": preload("res://shaders/text_chaos_shader_material.tres") },
		{ "delay": 0.0, "action": "clear_stylebox", "target": "left_panel" },
		{ "delay": 0.0, "action": "clear_stylebox", "target": "right_panel" },
		{ "delay": 0.0, "action": "clear_stylebox", "target": "narrative_overlay" },
		# Phase 1 — T+10s: 隐藏 entry 背景图
		{ "delay": 10.0, "action": "hide_entry_bg", "target": "tape_entry" },
		# Phase 2 — T+12s: 生成火焰 sprite + TapeContainer 挂 flame shader + 2s 燃烧
		{ "delay": 11.0, "action": "spawn_fire", "target": "tape_entry" },
		{ "delay": 12.0, "action": "apply_shader", "target": "tape_container", "material": preload("res://shaders/flame_shader_material.tres") },
		{ "delay": 12.0, "action": "tween_burn", "target": "tape_container", "tween_duration": 2.0 },
	],
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 合并简单映射
	if shader_mappings.is_empty():
		shader_mappings = _DEFAULT_MAPPINGS.duplicate()
	else:
		var merged := _DEFAULT_MAPPINGS.duplicate()
		merged.merge(shader_mappings)
		shader_mappings = merged

	# 合并时间线脚本
	if timeline_scripts.is_empty():
		timeline_scripts = _DEFAULT_TIMELINES.duplicate()
	else:
		var merged := _DEFAULT_TIMELINES.duplicate()
		merged.merge(timeline_scripts)
		timeline_scripts = merged

	EventBus.event_shown.connect(_on_event_shown)
	Logging.info("AnimationController: 已连接 EventBus.event_shown")
	Logging.info("  - shader_mappings: %s" % shader_mappings.keys())
	Logging.info("  - timeline_scripts: %s" % timeline_scripts.keys())


# ═══════════════════════════════════════════════
# EventBus 回调
# ═══════════════════════════════════════════════

func _on_event_shown(event: Variant) -> void:
	if not event or not event is BaseEvent:
		return

	var uuid: String = event.uuid
	var entry_id: String = str(event.get_instance_id())

	# 优先时间线脚本
	if uuid in timeline_scripts:
		var stages: Array = timeline_scripts[uuid]
		Logging.info("AnimationController._on_event_shown: uuid='%s' 匹配时间线脚本（%d 阶段），entry_id='%s'" % [uuid, stages.size(), entry_id])
		for stage in stages:
			var delay: float = stage.get("delay", 0.0)
			if delay <= 0.001:
				call_deferred("_execute_stage", stage, entry_id, uuid)
			else:
				_create_stage_timer(delay, stage, entry_id, uuid)
		return

	# 回退：简单 shader 映射（ContentLabel）
	if uuid in shader_mappings:
		var material: ShaderMaterial = shader_mappings[uuid]
		Logging.info("AnimationController._on_event_shown: uuid='%s' 匹配简单 shader 映射，entry_id='%s'" % [uuid, entry_id])
		call_deferred("_apply_content_shader", entry_id, material, uuid)
		return

	Logging.debug("AnimationController._on_event_shown: uuid='%s' 无匹配规则" % uuid)


# ═══════════════════════════════════════════════
# 时间线阶段调度
# ═══════════════════════════════════════════════

func _create_stage_timer(delay: float, stage: Dictionary, entry_id: String, uuid: String) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	timer.timeout.connect(_on_stage_timer_timeout.bind(stage, entry_id, uuid))
	add_child(timer)
	timer.start()
	Logging.info("AnimationController._create_stage_timer: delay=%.1fs action='%s' target='%s'" % [delay, stage.get("action", ""), stage.get("target", "")])


func _on_stage_timer_timeout(stage: Dictionary, entry_id: String, uuid: String) -> void:
	_execute_stage(stage, entry_id, uuid)


# ═══════════════════════════════════════════════
# 阶段执行 — 分发
# ═══════════════════════════════════════════════

func _execute_stage(stage: Dictionary, entry_id: String, uuid: String) -> void:
	var action: String = stage.get("action", "")
	var target: String = stage.get("target", "")
	Logging.info("AnimationController._execute_stage: action='%s' target='%s' entry_id='%s'" % [action, target, entry_id])

	match action:
		"clear_stylebox":
			_clear_stylebox_target(target)
		"hide_entry_bg":
			_hide_entry_bg(entry_id)
		"spawn_fire":
			_spawn_fire(entry_id)
		"ghostly_white":
			_ghostly_white_target(entry_id)
		"apply_shader":
			var material: ShaderMaterial = stage.get("material")
			if not material:
				Logging.err("AnimationController._execute_stage: action='apply_shader' 缺少 material 字段 (uuid='%s')" % uuid)
				return
			_apply_shader_target(target, entry_id, material, uuid)
		"tween_burn":
			var tween_duration: float = stage.get("tween_duration", 2.0)
			_tween_burn_target(target, entry_id, tween_duration, uuid)
		"set_title_font_size":
			var font_size: int = stage.get("font_size", 72)
			_set_title_font_size(entry_id, font_size)
		"tween_infection":
			var tween_duration: float = stage.get("tween_duration", 8.0)
			_tween_infection_target(target, entry_id, tween_duration, uuid)
		"camera_shake":
			var shake_duration: float = stage.get("duration", 8.0)
			var shake_intensity: float = stage.get("intensity", 2.0)
			_camera_shake(shake_duration, shake_intensity)
		_:
			Logging.err("AnimationController._execute_stage: 未知 action='%s'" % action)


# ═══════════════════════════════════════════════
# clear_stylebox — 将目标节点 theme_override_styles/panel 替换为 StyleBoxEmpty
# ═══════════════════════════════════════════════

# ═══════════════════════════════════════════════
# spawn_fire — 生成火焰 sprite（CanvasLayer layer=99，低于 CinematicOverlay layer=100）
# ═══════════════════════════════════════════════

const FIRE_SPRITE_SCENE := preload("res://shaders/fire_sprite.tscn")

func _spawn_fire(_entry_id: String) -> void:
	var main_node := _get_main_node()
	if not main_node:
		Logging.err("AnimationController._spawn_fire: 未找到 Main 节点")
		return

	# 创建 CanvasLayer（layer=99，低于 CinematicOverlay 的 100）
	var fire_layer := CanvasLayer.new()
	fire_layer.name = "FireLayer"
	fire_layer.layer = 99
	main_node.add_child(fire_layer)

	# 实例化火焰 sprite
	var fire_sprite := FIRE_SPRITE_SCENE.instantiate()
	fire_layer.add_child(fire_sprite)

	# 定位到屏幕中下
	var tree := get_tree()
	if tree:
		var viewport_size := tree.root.get_visible_rect().size if tree.root else Vector2(1920, 1080)
		var tex_size := Vector2(512, 384)  # fire1_64.png at 64px × 8hframes / 6vframes 实际帧尺寸
		if fire_sprite is Node2D:
			fire_sprite.position = Vector2(viewport_size.x / 2.0, viewport_size.y - tex_size.y / 2.0 + 50)
		elif fire_sprite is Control:
			fire_sprite.position = Vector2(viewport_size.x / 2.0 - tex_size.x / 2.0, viewport_size.y - tex_size.y - 40)

	# 启动火精灵动画：按时间切换 Sprite2D frame
	var sprite := fire_sprite.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		_animate_fire_sprite(sprite)

	Logging.info("AnimationController._spawn_fire: 火焰 sprite 已生成（FireLayer, layer=99）")


func _animate_fire_sprite(sprite: Sprite2D) -> void:
	const HFRAMES: int = 10
	const VFRAMES: int = 6
	const TOTAL_FRAMES: int = 48
	const FRAME_DURATION: float = 0.066

	var timer := Timer.new()
	timer.name = "FireAnimTimer"
	timer.wait_time = FRAME_DURATION
	timer.one_shot = false
	var frame_data := {
		"current": 0,
		"sprite": sprite,
		"hframes": HFRAMES,
		"vframes": VFRAMES,
		"total": TOTAL_FRAMES,
	}
	timer.timeout.connect(_fire_frame_tick.bind(frame_data))
	add_child(timer)
	timer.start()
	Logging.info("AnimationController._animate_fire_sprite: 火焰帧动画已启动（48 帧, 15fps）")


func _fire_frame_tick(data: Dictionary) -> void:
	var sprite := data["sprite"] as Sprite2D
	if not sprite or not is_instance_valid(sprite):
		return
	var idx: int = data["current"]
	var col: int = idx % data["hframes"]
	var row: int = idx / data["hframes"]
	sprite.frame_coords = Vector2i(col, row)
	data["current"] = (idx + 1) % data["total"]


# ═══════════════════════════════════════════════
# hide_entry_bg — 隐藏 tape entry 的背景 TextureRect
# ═══════════════════════════════════════════════

func _hide_entry_bg(entry_id: String) -> void:
	var entry := _find_tape_entry(entry_id)
	if not entry:
		Logging.err("AnimationController._hide_entry_bg: 未找到 entry_id='%s'" % entry_id)
		return

	var bg := entry.get_node_or_null("TextureRect") as TextureRect
	if bg:
		bg.hide()
		Logging.info("AnimationController._hide_entry_bg: entry_id='%s' 的 TextureRect 已隐藏" % entry_id)
	else:
		Logging.warn("AnimationController._hide_entry_bg: entry_id='%s' 内未找到 TextureRect 子节点" % entry_id)


func _clear_stylebox_target(target: String) -> void:
	match target:
		"left_panel":
			var node := _get_left_panel()
			if node:
				node.hide()
				Logging.info("AnimationController._clear_stylebox: left_panel 已隐藏")
			else:
				Logging.warn("AnimationController._clear_stylebox: 未找到 left_panel")
		"right_panel":
			var node := _get_right_panel()
			if node:
				node.hide()
				Logging.info("AnimationController._clear_stylebox: right_panel 已隐藏")
			else:
				Logging.warn("AnimationController._clear_stylebox: 未找到 right_panel")
		"narrative_overlay":
			var node := _get_narrative_overlay()
			if node:
				var empty_box := StyleBoxEmpty.new()
				node.add_theme_stylebox_override("panel", empty_box)
				Logging.info("AnimationController._clear_stylebox: narrative_overlay shadow stylebox → StyleBoxEmpty")
			else:
				Logging.warn("AnimationController._clear_stylebox: 未找到 narrative_overlay")
		"tape_container":
			var node := _get_tape_container()
			if node:
				var empty_box := StyleBoxEmpty.new()
				node.add_theme_stylebox_override("panel", empty_box)
				Logging.info("AnimationController._clear_stylebox: tape_container panel stylebox → StyleBoxEmpty")
			else:
				Logging.warn("AnimationController._clear_stylebox: 未找到 tape_container")
		_:
			Logging.err("AnimationController._clear_stylebox: 未知 target='%s'" % target)


# ═══════════════════════════════════════════════
# ghostly_white — 将 tape entry 内所有文字设为惨白色
# ═══════════════════════════════════════════════

func _ghostly_white_target(entry_id: String) -> void:
	var entry := _find_tape_entry(entry_id)
	if not entry:
		Logging.err("AnimationController._ghostly_white: 未找到 entry_id='%s'" % entry_id)
		return

	# TitleLabel — Label 用 font_color override
	var title_label := entry.get_node_or_null("MarginContainer/VBox/HBox/TitleLabel") as Label
	if title_label:
		title_label.add_theme_color_override(&"font_color", GHOSTLY_WHITE)
		Logging.info("AnimationController._ghostly_white: TitleLabel → 惨白色")

	# ContentLabel — RichTextLabel 用 default_color override
	var content_label := entry.get_node_or_null("MarginContainer/VBox/ContentLabel") as RichTextLabel
	if content_label:
		content_label.add_theme_color_override(&"default_color", GHOSTLY_WHITE)
		Logging.info("AnimationController._ghostly_white: ContentLabel → 惨白色")

	# ExampleLabel（隐藏，但也设一下以防后续显示）
	var example_label := entry.get_node_or_null("MarginContainer/VBox/ExampleLabel") as RichTextLabel
	if example_label:
		example_label.add_theme_color_override(&"default_color", GHOSTLY_WHITE)

	# OptionBtns — 遍历子 EventBtn 按钮，设置 font_color
	var option_btns := entry.get_node_or_null("MarginContainer/VBox/OptionBtns") as VBoxContainer
	if option_btns:
		var count := 0
		for child in option_btns.get_children():
			if child is Button:
				child.add_theme_color_override(&"font_color", GHOSTLY_WHITE)
				count += 1
		Logging.info("AnimationController._ghostly_white: %d 个选项按钮 → 惨白色" % count)


# ═══════════════════════════════════════════════
# apply_shader 目标
# ═══════════════════════════════════════════════

func _apply_shader_target(target: String, entry_id: String, material: ShaderMaterial, uuid: String) -> void:
	match target:
		"content_label":
			var label := _find_content_label(entry_id)
			if label:
				label.material = material
				Logging.info("AnimationController._apply_shader_target: ContentLabel 已挂载 shader (uuid='%s')" % uuid)
			else:
				Logging.err("AnimationController._apply_shader_target: 未找到 ContentLabel (entry_id='%s')" % entry_id)

		"option_btns":
			var btns := _find_option_btns(entry_id)
			if btns:
				btns.material = material
				Logging.info("AnimationController._apply_shader_target: OptionBtns 已挂载 shader (uuid='%s')" % uuid)
			else:
				Logging.err("AnimationController._apply_shader_target: 未找到 OptionBtns (entry_id='%s')" % entry_id)

		"tape_container":
			var tape := _get_tape_container()
			if tape:
				tape.material = material
				Logging.info("AnimationController._apply_shader_target: TapeContainer 已挂载 shader (uuid='%s')" % uuid)
			else:
				Logging.err("AnimationController._apply_shader_target: 未找到 TapeContainer")

		"map_background":
			var bg := _get_map_background()
			if bg:
				bg.material = material
				Logging.info("AnimationController._apply_shader_target: map_background 已挂载 shader (uuid='%s')" % uuid)
			else:
				Logging.err("AnimationController._apply_shader_target: 未找到 map_background (CanvasGroup)")

		_:
			Logging.err("AnimationController._apply_shader_target: 未知 target='%s'" % target)


# ═══════════════════════════════════════════════
# tween_burn 目标 — 对 TapeContainer 的 burn_progress 做 0→1 tween
# ═══════════════════════════════════════════════

func _tween_burn_target(target: String, _entry_id: String, duration: float, uuid: String) -> void:
	if target != "tape_container":
		Logging.err("AnimationController._tween_burn: target='%s' 不支持（仅支持 tape_container）" % target)
		return

	var tape := _get_tape_container()
	if not tape:
		Logging.err("AnimationController._tween_burn: 未找到 TapeContainer")
		return

	var mat := tape.material as ShaderMaterial
	if not mat:
		Logging.err("AnimationController._tween_burn: TapeContainer 上未挂载 ShaderMaterial，请先 apply_shader")
		return

	mat.set_shader_parameter("burn_progress", 0.0)

	var tween := tape.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_method(_set_burn_progress.bind(mat), 0.0, 1.0, duration)

	Logging.info("AnimationController._tween_burn: TapeContainer burn_progress 0→1 已启动，duration=%.1fs (uuid='%s')" % [duration, uuid])


func _set_burn_progress(value: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("burn_progress", value)


# ═══════════════════════════════════════════════
# 简单映射：ContentLabel shader（向后兼容 + _DEFAULT_MAPPINGS）
# ═══════════════════════════════════════════════

func _apply_content_shader(entry_id: String, material: ShaderMaterial, uuid: String) -> void:
	var content_label: RichTextLabel = _find_content_label(entry_id)
	if not content_label:
		Logging.err("AnimationController._apply_content_shader: 未找到 entry_id='%s' 的 ContentLabel (uuid='%s')" % [entry_id, uuid])
		return

	content_label.material = material
	Logging.info("AnimationController._apply_content_shader: 已为 entry_id='%s' (uuid='%s') 的 ContentLabel 挂载 shader" % [entry_id, uuid])


# ═══════════════════════════════════════════════
# 节点查找 — Tape Entry 子节点
# ═══════════════════════════════════════════════

func _get_tape_content() -> VBoxContainer:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return null
	var tape_layer := main_node.get_node_or_null("TapeLayer")
	if not tape_layer:
		return null
	var narrative_overlay := tape_layer.get_node_or_null("NarrativeOverlay")
	if not narrative_overlay:
		return null
	return narrative_overlay.get_node_or_null("TapeContainer/EventHistory/Margin/ScrollContainer/VBox_TapeContent") as VBoxContainer


func _find_tape_entry(entry_id: String) -> Control:
	var tape_content := _get_tape_content()
	if not tape_content:
		return null
	for child in tape_content.get_children():
		if child.has_meta("entry_id") and child.get_meta("entry_id") == entry_id:
			return child as Control
	return null


func _find_content_label(entry_id: String) -> RichTextLabel:
	var entry := _find_tape_entry(entry_id)
	if not entry:
		return null
	return entry.get_node_or_null("MarginContainer/VBox/ContentLabel") as RichTextLabel


func _find_option_btns(entry_id: String) -> Control:
	var entry := _find_tape_entry(entry_id)
	if not entry:
		return null
	return entry.get_node_or_null("MarginContainer/VBox/OptionBtns") as Control


# ═══════════════════════════════════════════════
# 节点查找 — UI 面板 / NarrativeOverlay
# ═══════════════════════════════════════════════

func _get_main_node() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	return root.get_node_or_null("Main")


func _get_left_panel() -> Control:
	var main_node := _get_main_node()
	if not main_node:
		return null
	return main_node.get_node_or_null("UI/Margin/HBox/LeftPanel") as Control


func _get_right_panel() -> Control:
	var main_node := _get_main_node()
	if not main_node:
		return null
	return main_node.get_node_or_null("UI/Margin/HBox/RightPanel") as Control


func _get_narrative_overlay() -> Control:
	var main_node := _get_main_node()
	if not main_node:
		return null
	var tape_layer := main_node.get_node_or_null("TapeLayer")
	if not tape_layer:
		return null
	return tape_layer.get_node_or_null("NarrativeOverlay") as Control


# ═══════════════════════════════════════════════
# set_title_font_size — 修改 tape entry 的 TitleLabel 字号
# ═══════════════════════════════════════════════

func _set_title_font_size(entry_id: String, font_size: int) -> void:
	var entry := _find_tape_entry(entry_id)
	if not entry:
		Logging.err("AnimationController._set_title_font_size: 未找到 entry_id='%s'" % entry_id)
		return

	var title_label := entry.get_node_or_null("MarginContainer/VBox/HBox/TitleLabel") as Label
	if title_label:
		title_label.add_theme_font_size_override(&"font_size", font_size)
		Logging.info("AnimationController._set_title_font_size: entry_id='%s' TitleLabel 字号 → %d" % [entry_id, font_size])
	else:
		Logging.err("AnimationController._set_title_font_size: 未找到 TitleLabel (entry_id='%s')" % entry_id)


func _get_map_background() -> CanvasItem:
	if not GameState.map:
		Logging.err("AnimationController._get_map_background: GameState.map 为空")
		return null
	return GameState.map.get_node_or_null("background") as CanvasItem


# ═══════════════════════════════════════════════
# tween_infection — 对 map_background 的 infection_progress 做 0→1 tween
# ═══════════════════════════════════════════════

func _tween_infection_target(target: String, _entry_id: String, duration: float, uuid: String) -> void:
	if target != "map_background":
		Logging.err("AnimationController._tween_infection: target='%s' 不支持（仅支持 map_background）" % target)
		return

	var bg := _get_map_background()
	if not bg:
		Logging.err("AnimationController._tween_infection: 未找到 map_background")
		return

	var mat := bg.material as ShaderMaterial
	if not mat:
		Logging.err("AnimationController._tween_infection: map_background 上未挂载 ShaderMaterial，请先 apply_shader")
		return

	mat.set_shader_parameter("infection_progress", 0.0)

	var tween := bg.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_method(_set_infection_progress.bind(mat), 0.0, 1.0, duration)

	Logging.info("AnimationController._tween_infection: map_background infection_progress 0→1 已启动，duration=%.1fs (uuid='%s')" % [duration, uuid])


func _set_infection_progress(value: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("infection_progress", value)


func _get_tape_container() -> PanelContainer:
	var main_node := _get_main_node()
	if not main_node:
		return null
	var tape_layer := main_node.get_node_or_null("TapeLayer")
	if not tape_layer:
		return null
	var narrative_overlay := tape_layer.get_node_or_null("NarrativeOverlay")
	if not narrative_overlay:
		return null
	return narrative_overlay.get_node_or_null("TapeContainer") as PanelContainer


# ═══════════════════════════════════════════════
# camera_shake — 轻微相机震动
# ═══════════════════════════════════════════════

func _get_camera() -> Camera2D:
	var main_node := _get_main_node()
	if not main_node:
		return null
	return main_node.get_node_or_null("MapLayer/Worldroot/Camera") as Camera2D


func _camera_shake(duration: float, intensity: float) -> void:
	var cam := _get_camera()
	if not cam:
		Logging.err("AnimationController._camera_shake: 未找到 Camera2D")
		return

	var shake_timer := Timer.new()
	shake_timer.name = "CameraShakeTimer"
	shake_timer.wait_time = 0.05
	shake_timer.one_shot = false

	var shake_data := {
		"camera": cam,
		"elapsed": 0.0,
		"duration": duration,
		"intensity": intensity,
	}
	shake_timer.timeout.connect(_camera_shake_tick.bind(shake_data))
	add_child(shake_timer)
	shake_timer.start()

	# 到期停止 timer
	var stop_timer := Timer.new()
	stop_timer.name = "CameraShakeStopTimer"
	stop_timer.one_shot = true
	stop_timer.wait_time = duration
	stop_timer.timeout.connect(_camera_shake_stop.bind(shake_timer, shake_data))
	add_child(stop_timer)
	stop_timer.start()

	Logging.info("AnimationController._camera_shake: 震动已启动，duration=%.1fs intensity=%.1f" % [duration, intensity])


func _camera_shake_tick(data: Dictionary) -> void:
	var cam := data["camera"] as Camera2D
	if not cam or not is_instance_valid(cam):
		return
	data["elapsed"] += 0.05
	if data["elapsed"] >= data["duration"]:
		return
	var intensity: float = data["intensity"]
	cam.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))


func _camera_shake_stop(shake_timer: Timer, data: Dictionary) -> void:
	if is_instance_valid(shake_timer):
		shake_timer.queue_free()
	var cam := data["camera"] as Camera2D
	if cam and is_instance_valid(cam):
		cam.offset = Vector2.ZERO
	Logging.info("AnimationController._camera_shake: 震动已结束，offset 归零")
