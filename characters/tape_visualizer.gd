class_name TapeVisualizer extends Node


# =============================================================================
# TapeVisualizer — 纯渲染奴隶
# =============================================================================
# 职责：Tween 动画 + 墨迹 dim/undim。
# 不知道任何业务类（BaseEvent / EventUI / EventBus / NarrativeDirector /
#   PlayerState / TimeService / ConsequenceExecuter / Database）。
# =============================================================================

## overlay 动画（如 slide_out_and_back）完成时发射
signal overlay_animation_finished

# ═══════════════════════════════════════════════════════════════════
# @export 引用 — 在场景中挂载后配置
# ═══════════════════════════════════════════════════════════════════

## 外层容器 — 重构后指向 NarrativeOverlay 的 ShadowBox 父节点
@export var shadow_box: Control

## 内层纸纹理容器 — 重构后指向 TapeContainer（原 NarrativeOverlay 自身）
@export var tape_container: Control

## 纸带内容容器 — EventUI._tape_content
@export var tape_content: VBoxContainer

# ═══════════════════════════════════════════════════════════════════
# 常量
# ═══════════════════════════════════════════════════════════════════

const DIM_HISTORY_INK_COLOR: Color = Color(0.75, 0.62, 0.42, 0.35)

# ═══════════════════════════════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════════════════════════════

var _tween: Tween
var _tape_initialized: bool = false
var _tape_target_y: float = 0.0

# ═══════════════════════════════════════════════════════════════════
# 1. play_show_tape() — 纸带从屏幕顶部外滑入
# ═══════════════════════════════════════════════════════════════════

func play_show_tape() -> void:
	if _tape_initialized:
		shadow_box.show()
		tape_container.show()
		return

	_tape_initialized = true
	if _tween:
		_tween.kill()

	# 延迟记录 shadow_box 的静止位置（第一次调用时布局必定完成）
	if _tape_target_y == 0.0:
		_tape_target_y = shadow_box.position.y

	var viewport_height := get_tree().root.get_visible_rect().size.y

	# 物理重置：shadow_box 埋到屏幕顶部外
	shadow_box.position.y = -(viewport_height + 100.0)
	tape_container.modulate.a = 0.0

	# 显示
	shadow_box.show()
	tape_container.show()

	# 音效：纸张摩擦声
	AudioManager.play_sfx(load("res://assets/sounds/rustling_paper.wav"))

	# 并行 Tween：shadow_box 下落刹车 + tape_container 显形
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)

	# CUBIC + EASE_OUT：「快速拔出 → 极速刹车 → 稳稳停住」
	# 🚨 关键：tween 的是 shadow_box.position:y，不是 self.position:y！
	_tween.tween_property(shadow_box, "position:y", _tape_target_y, 0.65) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# SINE EASE_IN_OUT：前 0.3 秒平滑显形，避免像素撕裂
	_tween.tween_property(tape_container, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ═══════════════════════════════════════════════════════════════════
# 2. play_hide_tape() — 纸带隐藏（全空时）
# ═══════════════════════════════════════════════════════════════════

func play_hide_tape() -> void:
	shadow_box.hide()
	tape_container.hide()
	_tape_initialized = false


# ═══════════════════════════════════════════════════════════════════
# 2-b. play_show_tape_from_bottom() — 纸带从屏幕底部外滑入（↑）
# ═══════════════════════════════════════════════════════════════════

func play_show_tape_from_bottom() -> void:
	if _tape_initialized:
		shadow_box.show()
		tape_container.show()
		return

	_tape_initialized = true
	if _tween:
		_tween.kill()

	# 延迟记录 shadow_box 的静止位置（第一次调用时布局必定完成）
	if _tape_target_y == 0.0:
		_tape_target_y = shadow_box.position.y

	var viewport_height := get_tree().root.get_visible_rect().size.y

	# 物理重置：shadow_box 埋到屏幕底部外
	shadow_box.position.y = viewport_height + 100.0
	tape_container.modulate.a = 0.0

	# 显示
	shadow_box.show()
	tape_container.show()

	# 音效：纸张摩擦声
	AudioManager.play_sfx(load("res://assets/sounds/rustling_paper.wav"))

	# 并行 Tween：shadow_box 上升刹车 + tape_container 显形
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)

	# CUBIC + EASE_OUT：「快速上冲 → 极速刹车 → 稳稳停住」
	_tween.tween_property(shadow_box, "position:y", _tape_target_y, 0.65) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# SINE EASE_IN_OUT：前 0.3 秒平滑显形，避免像素撕裂
	_tween.tween_property(tape_container, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ═══════════════════════════════════════════════════════════════════
# 3. play_swap_background() — 抽纸动画
# ═══════════════════════════════════════════════════════════════════

func play_swap_background(new_texture: Texture2D, apply_callback: Callable) -> void:
	# 防御性检查：场景可能在销毁中（如 game_over 切换场景），get_tree() 可能为 null
	var tree := get_tree()
	if not tree or not tree.root:
		Logging.warn("TapeVisualizer.play_swap_background: tree or tree.root is null, skipping")
		return
	var viewport_height := tree.root.get_visible_rect().size.y

	# 1. 杀死所有活跃 Tween，防止干扰
	if _tween:
		_tween.kill()
		_tween = null

	# 2. 向上滑出：target = 屏幕顶部外
	var slide_out_target := -(viewport_height + 100.0)
	var slide_out_duration := 0.5
	var slide_out_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide_out_tween.tween_property(shadow_box, "position:y", slide_out_target, slide_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_out_tween.set_parallel(true)
	slide_out_tween.tween_property(tape_container, "modulate:a", 0.0, slide_out_duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await slide_out_tween.finished

	# 3. 应用回调（由 NarrativeOverlay 注入：清空条目 + 应用新纹理）
	# 注意：这里不直接操作 EventUI，而是通过回调让 Overlay 去做
	apply_callback.call()

	# 4. 重置 _tape_initialized，让 play_show_tape 重新播放完整动画
	_tape_initialized = false

	# 5. 标准滑入动画
	play_show_tape()
	if _tween:
		await _tween.finished


# ═══════════════════════════════════════════════════════════════════
# 4. play_exit_to_top() — main.gd 地图模式：往上推出 + 淡出
# ═══════════════════════════════════════════════════════════════════

func play_exit_to_top(duration: float = 0.5) -> void:
	if _tween:
		_tween.kill()
	var viewport_h := get_tree().root.get_visible_rect().size.y

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(shadow_box, "position:y", _tape_target_y - viewport_h, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tape_container, "modulate:a", 0.0, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		shadow_box.visible = false
	)


# ═══════════════════════════════════════════════════════════════════
# 5. play_enter_from_top() — main.gd 退出地图模式：从上滑入
# ═══════════════════════════════════════════════════════════════════

func play_enter_from_top(duration: float = 0.5) -> void:
	if _tween:
		_tween.kill()
	var viewport_h := get_tree().root.get_visible_rect().size.y

	shadow_box.visible = true
	shadow_box.position.y = _tape_target_y - viewport_h
	tape_container.modulate.a = 0.0

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(shadow_box, "position:y", _tape_target_y, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tape_container, "modulate:a", 1.0, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ═══════════════════════════════════════════════════════════════════
# 6. dim_history_ink() — 递归遍历压暗墨迹
# ═══════════════════════════════════════════════════════════════════

func dim_history_ink(exclude_node: Control) -> void:
	if not tape_content:
		Logging.warn("dim_history_ink: tape_content 为空")
		return

	var dimmed_count := 0
	for child in tape_content.get_children():
		if child == exclude_node:
			continue
		dimmed_count += _dim_text_nodes_recursive(child)
	Logging.info("dim_history_ink: 已压暗 %d 个文本节点" % dimmed_count)


# ═══════════════════════════════════════════════════════════════════
# 7. undim_history_ink() — 恢复所有墨迹颜色
# ═══════════════════════════════════════════════════════════════════

func undim_history_ink() -> void:
	if not tape_content:
		Logging.warn("undim_history_ink: tape_content 为空")
		return
	var restored_count := 0
	for child in tape_content.get_children():
		restored_count += _undim_text_nodes_recursive(child)
	Logging.info("undim_history_ink: 已恢复 %d 个文本节点" % restored_count)


# ═══════════════════════════════════════════════════════════════════
# 8. play_slide_out_and_back() — 纸带下滑出视口再滑回原位
# ═══════════════════════════════════════════════════════════════════

## strategy="slide_out_and_back" 的动画实现。
## 将 shadow_box 向下滑出屏幕底部，然后立即滑回 _tape_target_y。
## 两段动画各占 duration/2 秒。
## 🚨 关键：使用 tween 链式回调 + 信号，禁止 await，
## 否则控制权交还给 Director → 栈空 → tape_needs_hide → shadow_box.hide() 让动画白做。
func play_slide_out_and_back(duration: float = 0.5) -> void:
	if _tween:
		_tween.kill()

	var viewport_h := get_tree().root.get_visible_rect().size.y
	# 确保 _tape_target_y 已初始化（第一次 show 后才会有值，但此时纸带必定已展示）
	if _tape_target_y == 0.0:
		_tape_target_y = shadow_box.position.y

	var half_duration := duration * 0.5
	var slide_out_target: float = viewport_h + 100.0  # 滑到屏幕底部外

	Logging.info("TapeVisualizer.play_slide_out_and_back: duration=%.2f, target_y=%.1f, slide_out_target=%.1f" % [duration, _tape_target_y, slide_out_target])

	# 第一段：下滑到屏幕底部外
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(shadow_box, "position:y", slide_out_target, half_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Chain: 下滑完成 → 滑回原位
	_tween.tween_callback(_on_slide_out_finished.bind(duration, half_duration))


## 下滑段完成后，触发回弹段
func _on_slide_out_finished(duration: float, half_duration: float) -> void:
	const HOLD_TIME: float = 2.0  # 滑出后停顿 2 秒再回弹
	Logging.info("TapeVisualizer._on_slide_out_finished: 下滑完成，等待 %.1f 秒后回弹" % HOLD_TIME)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 停顿 HOLD_TIME 秒后再回弹
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(shadow_box, "position:y", _tape_target_y, half_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Chain: 回弹完成 → 发射完成信号
	_tween.tween_callback(_on_slide_back_finished)


## 回弹段完成后，发射完成信号
func _on_slide_back_finished() -> void:
	const POST_HOLD_TIME: float = 1.0  # 回弹后停顿再隐藏
	Logging.info("TapeVisualizer._on_slide_back_finished: 回弹完成，等待 %.1f 秒后完成" % POST_HOLD_TIME)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(POST_HOLD_TIME)
	_tween.tween_callback(func():
		Logging.info("TapeVisualizer.play_slide_out_and_back: 动画完成")
		overlay_animation_finished.emit()
	)


# ═══════════════════════════════════════════════════════════════════
# 9. play_slide_in_from_right() — Hover 流：从屏幕右侧滑入
# ═══════════════════════════════════════════════════════════════════

## HoverDisplayFlow SLIDE_FROM_RIGHT 的 enter 动画。
## 将 shadow_box 从屏幕右侧外滑入到 _tape_target_y 位置。
## 同时 tape_container alpha 从 0→1。
## ⚠️ 动画期间不修改 _tape_initialized — 由调用方管理状态。
func play_slide_in_from_right(duration: float = 0.3) -> void:
	if _tween:
		_tween.kill()

	var viewport_w := get_tree().root.get_visible_rect().size.x

	if _tape_target_y == 0.0:
		_tape_target_y = shadow_box.position.y

	# 物理重置：shadow_box 埋到屏幕右侧外
	shadow_box.position.x = viewport_w + 100.0
	shadow_box.position.y = _tape_target_y
	tape_container.modulate.a = 0.0

	shadow_box.show()
	tape_container.show()

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	# 水平滑动：从右侧外 → 0（恢复到 tscn 的 anchor 计算位置）
	_tween.tween_property(shadow_box, "position:x", 0.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tape_container, "modulate:a", 1.0, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	Logging.info("TapeVisualizer.play_slide_in_from_right: duration=%.2f" % duration)


# ═══════════════════════════════════════════════════════════════════
# 10. play_slide_to_right() — Hover 流：滑出到屏幕右侧
# ═══════════════════════════════════════════════════════════════════

## HoverDisplayFlow SLIDE_FROM_RIGHT 的 exit 动画。
## 将 shadow_box 从当前位置滑出到屏幕右侧外 + 淡出。
func play_slide_to_right(duration: float = 0.3) -> void:
	if _tween:
		_tween.kill()

	var viewport_w := get_tree().root.get_visible_rect().size.x
	var slide_out_target: float = viewport_w + 100.0

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(shadow_box, "position:x", slide_out_target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(tape_container, "modulate:a", 0.0, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		shadow_box.visible = false
		Logging.info("TapeVisualizer.play_slide_to_right: 动画完成，shadow_box 隐藏")
	)

	Logging.info("TapeVisualizer.play_slide_to_right: duration=%.2f" % duration)
# ═══════════════════════════════════════════════════════════════════
# 私有递归方法
# ═══════════════════════════════════════════════════════════════════

func _dim_text_nodes_recursive(node: Node) -> int:
	var count := 0
	for child_node in node.get_children():
		if child_node is Label or child_node is RichTextLabel:
			if child_node is Label:
				child_node.add_theme_color_override(&"font_color", DIM_HISTORY_INK_COLOR)
				child_node.add_theme_color_override(&"font_outline_color", DIM_HISTORY_INK_COLOR)
			elif child_node is RichTextLabel:
				child_node.add_theme_color_override(&"default_color", DIM_HISTORY_INK_COLOR)
			count += 1
		else:
			count += _dim_text_nodes_recursive(child_node)
	return count


func _undim_text_nodes_recursive(node: Node) -> int:
	var count := 0
	for child_node in node.get_children():
		if child_node is Label or child_node is RichTextLabel:
			if child_node is Label:
				child_node.remove_theme_color_override(&"font_color")
				child_node.remove_theme_color_override(&"font_outline_color")
			elif child_node is RichTextLabel:
				child_node.remove_theme_color_override(&"default_color")
			count += 1
		else:
			count += _undim_text_nodes_recursive(child_node)
	return count
