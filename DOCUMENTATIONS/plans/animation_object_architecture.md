# AnimationObject 架构实施计划

## 动机

将 `ImageHandle` 中所有时间驱动的视觉效果（滑动、粉碎、淡出）提升为一等公民 `AnimationObject`，
使 `NarrativeOverlay` 可以感知并追踪这些动画，避免事件队列与后台动画产生冲突。

## 架构概览

```
model/animation_object.gd          ← AnimationObject (abstract base, RefCounted)
model/slide_animation.gd           ← SlideAnimation
model/shatter_animation.gd         ← ShatterAnimation
model/fade_out_animation.gd        ← FadeOutAnimation

features/image_handle.gd           ← 新增 create_*() 工厂方法 (保留旧方法)
characters/narrative_overlay.gd    ← 新增 _active_animations 追踪
```

## 实施步骤

### Step 1: 创建 AnimationObject 基类

**文件:** [`model/animation_object.gd`](model/animation_object.gd)

```gdscript
class_name AnimationObject extends RefCounted
## 时间驱动的舞台动画基类
##
## 所有需要时间呈现的视觉效果继承此类。
## NarrativeOverlay 持有当前活跃的 AnimationObject 列表，独立于事件队列管理。
##
## 每个 AnimationObject 内部使用 Tween 驱动，且强制 TWEEN_PAUSE_PROCESS，
## 确保在世界暂停时动画仍能继续播放。

signal finished

var is_playing: bool = false
var _tween: Tween

# 子类必须 override
func start() -> void:
	push_error("AnimationObject.start() 未实现")

func stop() -> void:
	_kill_tween()
	is_playing = false

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
```

### Step 2: 创建 SlideAnimation

**文件:** [`model/slide_animation.gd`](model/slide_animation.gd)

```gdscript
class_name SlideAnimation extends AnimationObject

var _sprite: Sprite2D
var _target_pos: Vector2
var _duration: float

func _init(sprite: Sprite2D, target_pos: Vector2, duration: float):
	_sprite = sprite
	_target_pos = target_pos
	_duration = duration

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		push_warning("SlideAnimation: sprite 已失效")
		return
	is_playing = true
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # 🚨 关键：不受世界暂停影响
	_tween.tween_property(_sprite, "global_position", _target_pos, _duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.finished.connect(_on_finished)

func _on_finished() -> void:
	is_playing = false
	finished.emit()
```

### Step 3: 创建 ShatterAnimation

**文件:** [`model/shatter_animation.gd`](model/shatter_animation.gd)

```gdscript
class_name ShatterAnimation extends AnimationObject

const SHATTER_SHADER := preload("res://shaders/image_shatter.gdshader")

var _sprite: Sprite2D
var _duration: float
var _params: Dictionary

func _init(sprite: Sprite2D, duration: float, params: Dictionary = {}):
	_sprite = sprite
	_duration = duration
	_params = params

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		push_warning("ShatterAnimation: sprite 已失效")
		return
	is_playing = true
	# 切换 ShaderMaterial
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SHATTER_SHADER
	shader_mat.set_shader_parameter("progress", 0.0)
	for key in _params:
		if shader_mat.get_shader_parameter(key) != null:
			shader_mat.set_shader_parameter(key, _params[key])
	_sprite.material = shader_mat
	
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # 🚨
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_update_shader_progress.bind(shader_mat), 0.0, 1.0, _duration)
	_tween.finished.connect(_on_finished)

func _update_shader_progress(val: float, mat: ShaderMaterial) -> void:
	if mat != null:
		mat.set_shader_parameter("progress", val)

func _on_finished() -> void:
	is_playing = false
	# shatter 播完后自动销毁 sprite
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	finished.emit()
```

### Step 4: 创建 FadeOutAnimation

**文件:** [`model/fade_out_animation.gd`](model/fade_out_animation.gd)

```gdscript
class_name FadeOutAnimation extends AnimationObject

var _sprite: Sprite2D
var _duration: float

func _init(sprite: Sprite2D, duration: float):
	_sprite = sprite
	_duration = duration

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		push_warning("FadeOutAnimation: sprite 已失效")
		return
	is_playing = true
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # 🚨
	_tween.tween_property(_sprite, "modulate:a", 0.0, _duration)
	_tween.finished.connect(_on_finished)

func _on_finished() -> void:
	is_playing = false
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	finished.emit()
```

### Step 5: 修改 ImageHandle（新增工厂方法）

**文件:** [`features/image_handle.gd`](features/image_handle.gd)

新增方法（保留 `slide_to`/`shatter`/`fade_out` 旧方法不动）：

```gdscript
## 创建滑动动画对象（可被 NarrativeOverlay 追踪）
func create_slide(target_pos: Vector2, duration: float = 1.0) -> SlideAnimation:
	return SlideAnimation.new(_sprite, target_pos, duration)

## 创建粉碎动画对象
func create_shatter(duration: float = 1.0, params: Dictionary = {}) -> ShatterAnimation:
	return ShatterAnimation.new(_sprite, duration, params)

## 创建淡出动画对象
func create_fade_out(duration: float = 1.0) -> FadeOutAnimation:
	return FadeOutAnimation.new(_sprite, duration)
```

### Step 6: 修改 NarrativeOverlay（动画追踪）

**文件:** [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd)

新增成员变量：
```gdscript
var _active_animations: Array[AnimationObject] = []
```

新增/修改方法：

```gdscript
## 注册动画到追踪列表（Operator 或 Picker 在创建后调用此方法）
## AnimationObject 播完后自动从列表移除
func track_animation(anim: AnimationObject) -> void:
	if anim.finished.is_connected(_on_animation_finished.bind(anim)):
		return  # 防止重复连接
	_active_animations.append(anim)
	anim.finished.connect(_on_animation_finished.bind(anim), CONNECT_ONE_SHOT)
	anim.start()

func _on_animation_finished(anim: AnimationObject) -> void:
	_active_animations.erase(anim)

## 等待所有活跃动画播完（在 _process_next 前调用）
func _await_stage_animations() -> void:
	if _active_animations.is_empty():
		return
	# 并行等待所有动画播完
	var signals: Array[Signal] = []
	for anim in _active_animations:
		if anim.is_playing:
			signals.append(anim.finished)
	if signals.is_empty():
		return
	await signal(signals)
```

修改 `_process_next()`：
在 `if _is_active: return` 之后、检查栈/队列之前，插入：
```gdscript
func _process_next():
	if _is_active:
		return
	# 🚨 等待后台动画播完再处理下一个事件
	if not _active_animations.is_empty():
		await _await_stage_animations()
	# ... 原逻辑继续
```

## 变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `model/animation_object.gd` | **新建** | 抽象基类 |
| `model/slide_animation.gd` | **新建** | 滑动动画 |
| `model/shatter_animation.gd` | **新建** | 粉碎动画 |
| `model/fade_out_animation.gd` | **新建** | 淡出动画 |
| `features/image_handle.gd` | **修改** | 新增 `create_*()` 工厂 |
| `characters/narrative_overlay.gd` | **修改** | 新增 `_active_animations` + `track_animation()` + `_await_stage_animations()` + `_process_next` 修改 |
| `plans/animation_object_architecture.md` | **新建** | 本文档 |

## 向后兼容

- `ImageHandle.slide_to()` / `shatter()` / `fade_out()` 保持不动
- 旧代码继续使用旧方法不会报错
- 新代码推荐使用 `create_*()` + `track_animation()` 以获得事件系统集成
