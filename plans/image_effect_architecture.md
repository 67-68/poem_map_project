# 图像特效管理器架构 (Image Effect Manager)

## 1. 整体架构 (System Topology)

```
┌── 调用方 ──────────────────────────────────────────────────────────────────┐
│  var img = ImageManager.present(texture, start_pos)                       │
│  var img = ImageManager.present_by_id("bg", ENUMS.IMAGE_POS.CENTER)       │
│  var img = ImageManager.recall("bg")         # 回溯已有句柄 (无需 Texture) │
│  await img.slide_to(target_pos, 1.5)                                      │
│  img.shatter(1.0)                                                         │
└───────────────────────────────────┬────────────────────────────────────────┘
                                    │
                                    ▼
┌── ImageManager (Autoload) ─────────────────────────────────────────────────┐
│  extends Node                                                              │
│  ┌─ _effect_layer: CanvasLayer (layer=128)                                 │
│  ├─ _active_handles: Array[ImageHandle]                                    │
│  ├─ _texture_registry: Dictionary    # id → Texture2D                     │
│  ├─ _active_images: Dictionary       # id → ImageHandle (recall 用)       │
│  ├─ present(tex, pos) → ImageHandle                                       │
│  ├─ present_by_id(id, IMAGE_POS) → ImageHandle  # ID 化展示 🆕            │
│  ├─ recall(id) → ImageHandle                      # 回溯句柄 🆕           │
│  ├─ register_image(id, tex)                       # 注册纹理 🆕           │
│  ├─ play_shatter(tex, pos)   # 便捷方法: 快速粉碎(fire&forget)             │
│  └─ play_slide(tex, from, to) # 便捷方法: 快速滑动(fire&forget)            │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ 持有引用
                               ▼
┌── ImageHandle (非 Autoload, 由 Manager 创建并追踪) ───────────────────────┐
│  代表屏幕上的一张图片, 提供链式操作 API                                     │
│                                                                           │
│  _sprite: Sprite2D (实际渲染节点, 挂在 CanvasLayer 下)                      │
│                                                                           │
│  // ── 操作接口 (修改自身 _sprite) ──                                      │
│  slide_to(target_pos, duration) → self  # 可 await                        │
│  shatter(duration, params) → void       # 粉碎+销毁                        │
│  fade_out(duration) → void              # 淡出+销毁                        │
│  remove() → void                         # 立即销毁                        │
│                                                                           │
│  // ── 属性修改 ──                                                         │
│  set_opacity(alpha) → self                                                 │
│  set_scale(scale) → self                                                  │
│  set_modulate(color) → self                                               │
└────────────────────────────────────────────────────────────────────────────┘
```

### 核心思想: 从 fire-and-forget 到 stateful handle

**旧模式 (当前 ShatterEffect):**
```
play_shatter(tex, pos) → 自动播放 → 自动销毁
      ↑                     ↑           ↑
  调用方无法干预         无法中途改变  无法复用
```

**新模式 (ImageHandle):**
```
present(tex, pos) → ImageHandle
                       ├── .slide_to(new_pos)  → 复用 Sprite, 只移位置
                       ├── .shatter()           → 复用 Sprite, 加粉碎材质
                       └── .fade_out()          → 复用 Sprite, 加渐隐
                    同一张图, 不同阶段挂不同行为
```

### ID 化图片管理 (新增)

```
present_by_id("bg_chang_an", ENUMS.IMAGE_POS.CENTER)
  → _resolve_texture("bg_chang_an")
      → 1. _texture_registry 查找
      → 2. TextureResLoader.get_background() 兜底
      → 3. TextureResLoader.get_icon_simpler() 兜底
  → present(tex, resolved_pos) → ImageHandle
  → _active_images["bg_chang_an"] = handle

recall("bg_chang_an")  → 从 _active_images 取回 handle
  → handle.shatter(1.0)
  → handle._destroy() → sprite.queue_free()
  → _on_handle_freed → _active_images.erase("bg_chang_an")
```

## 2. 组件职责边界 (Contract)

### 2.1 ImageManager (`features/image_manager.gd`)

```
角色: 全局协调者 + 工厂 + 句柄池
责任:
  ✅ 管理 CanvasLayer 生命周期
  ✅ 创建 ImageHandle, 跟踪活跃句柄
  ✅ 提供 present() 工厂方法
  ✅ 提供 play_shatter() / play_slide() 便捷方法 (fire-and-forget)
  ❌ 不直接操作 Sprite 属性
  ❌ 不处理具体图片内容
```

**接口设计:**

```gdscript
class_name ImageManager extends Node
## 全局图像管理 Autoload

const LOG_TAG := "ImageManager"

var _effect_layer: CanvasLayer
var _active_handles: Array[ImageHandle] = []

func _ready() -> void:
    _create_effect_layer()

# ── 工厂方法 ──────────────────────────────────────────────

## 展示一张图片并返回操作句柄
func present(tex: Texture2D, global_pos: Vector2) -> ImageHandle:
    var handle = ImageHandle.new(tex, global_pos)
    _effect_layer.add_child(handle._sprite)
    _active_handles.append(handle)
    handle.tree_exited.connect(_on_handle_freed.bind(handle))
    return handle

## 便捷方法: 快速粉碎 (原 play_shatter 行为, 不返回句柄)
func play_shatter(tex: Texture2D, pos: Vector2, duration: float = 1.0, params: Dictionary = {}) -> void:
    var handle = present(tex, pos)
    handle.shatter(duration, params)

## 便捷方法: 快速滑动 (不返回句柄)
func play_slide(tex: Texture2D, from: Vector2, to: Vector2, duration: float = 1.0) -> void:
    var handle = present(tex, from)
    handle.slide_to(to, duration)

# ── 内部 ──────────────────────────────────────────────────

func _create_effect_layer() -> void:
    _effect_layer = CanvasLayer.new()
    _effect_layer.layer = 128
    _effect_layer.name = "ImageEffectLayer"
    get_tree().root.add_child(_effect_layer)

func _on_handle_freed(handle: ImageHandle) -> void:
    _active_handles.erase(handle)
```

### 2.2 ImageHandle (`features/image_handle.gd`)

```
角色: 单张图片的操作句柄, 负责该图片的完整生命周期
责任:
  ✅ 持有 Sprite2D 引用
  ✅ 提供 slide_to / shatter / fade_out 等操作方法
  ✅ 每个操作内部用 Tween 驱动
  ✅ 操作完成后自行清理或等待下个操作
  ❌ 不感知 Manager 存在
  ❌ 不关心其他句柄
```

**接口设计:**

```gdscript
class_name ImageHandle extends RefCounted
## 图片操作句柄 — 代表屏幕上的一张图, 可链式操作

signal finished()  # 所有操作完成 (图片已销毁)

var _sprite: Sprite2D
var _tween: Tween

func _init(tex: Texture2D, pos: Vector2) -> void:
    _sprite = Sprite2D.new()
    _sprite.texture = tex
    _sprite.global_position = pos
    # 默认启用, 让 Sprite 响应式渲染
    _sprite.centered = true

# ── 操作方法 ──────────────────────────────────────────────

## 滑动到目标位置, 返回自身支持链式调用
## 注意: await 此方法等待滑动完成
func slide_to(target_pos: Vector2, duration: float = 1.0) -> Signal:
    _kill_tween()
    _tween = _sprite.create_tween()
    _tween.tween_property(_sprite, "global_position", target_pos, duration)
    _tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    return _tween.finished  # 可 await: await handle.slide_to(pos, 1.0)

## 粉碎解体 (复用 image_shatter.gdshader)
## 播完后自动销毁 Sprite 和自身
func shatter(duration: float = 1.0, params: Dictionary = {}) -> void:
    # 1. 将 Sprite.material 切换为 ShaderMaterial
    var shader_mat = ShaderMaterial.new()
    shader_mat.shader = preload("res://shaders/image_shatter.gdshader")
    _sprite.material = shader_mat

    # 2. 设置默认参数
    shader_mat.set_shader_parameter("progress", 0.0)
    for key in params:
        shader_mat.set_shader_parameter(key, params[key])

    # 3. Tween 驱动 progress
    _kill_tween()
    _tween = _sprite.create_tween()
    _tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
    _tween.tween_method(_update_shader_progress.bind(shader_mat), 0.0, 1.0, duration)
    _tween.finished.connect(_destroy)

## 淡出消散
func fade_out(duration: float = 1.0) -> void:
    _kill_tween()
    _tween = _sprite.create_tween()
    _tween.tween_property(_sprite, "modulate:a", 0.0, duration)
    _tween.finished.connect(_destroy)

## 立即销毁
func remove() -> void:
    _destroy()

# ── 属性修改 ──────────────────────────────────────────────

func set_opacity(alpha: float) -> ImageHandle:
    var c = _sprite.modulate
    c.a = alpha
    _sprite.modulate = c
    return self

func set_scale(s: Vector2) -> ImageHandle:
    _sprite.scale = s
    return self

func set_modulate(color: Color) -> ImageHandle:
    _sprite.modulate = color
    return self

# ── 内部 ──────────────────────────────────────────────────

func _update_shader_progress(val: float, mat: ShaderMaterial) -> void:
    if mat != null:
        mat.set_shader_parameter("progress", val)

func _kill_tween() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = null

func _destroy() -> void:
    _kill_tween()
    if _sprite and is_instance_valid(_sprite):
        _sprite.queue_free()
    finished.emit()
```

### 2.3 ShatterEffect (保留旧实现, 但不再作为主要入口)

旧的 [`effects/ShatterEffect.gd`](effects/ShatterEffect.gd) 和 [`effects/shatter_effect.tscn`](effects/shatter_effect.tscn) 保留不动, 供 `ImageManager.play_shatter()` 便捷方法内部使用。

但实际上在 ImageHandle 模式下, shatter 走的是动态 ShaderMaterial 切换路线 (2.2 所示), 不再需要预制的 tscn 场景。

### 2.4 Voronoi 解体 Shader (不变)

[`shaders/image_shatter.gdshader`](shaders/image_shatter.gdshader) 保持不变。

## 3. 典型使用流程

### 3.1 链式: 展示 → 滑动 → 停留 → 粉碎

```gdscript
# 在某个剧情脚本中
func play_imagery_sequence() -> void:
    var tex = load("res://assets/poem_bgs/juanzhou.png")

    # 1. 从屏幕左侧外飞入
    var start_pos = Vector2(-200, 360)
    var img = ImageManager.present(tex, start_pos)

    # 2. 滑到屏幕中央
    await img.slide_to(Vector2(640, 360), 1.5)

    # 3. 停留 2 秒 (什么都不做)
    await get_tree().create_timer(2.0).timeout

    # 4. 粉碎消散
    img.shatter(1.2, {cell_size = 48.0, scatter_strength = 0.5})
```

### 3.2 Fire-and-forget: 快速粉碎 (向后兼容)

```gdscript
# 等同于原来的 play_shatter 行为
ImageManager.play_shatter(tex, pos, 1.0)
```

### 3.3 Fire-and-forget: 快速滑动

```gdscript
ImageManager.play_slide(tex, Vector2(0, 360), Vector2(640, 360), 1.5)
```

### 3.4 多图并发

```gdscript
# 三张图同时飞入, 各自独立
var img1 = ImageManager.present(tex1, Vector2(-200, 200))
var img2 = ImageManager.present(tex2, Vector2(-200, 360))
var img3 = ImageManager.present(tex3, Vector2(-200, 520))

img1.slide_to(Vector2(300, 200), 1.0)
img2.slide_to(Vector2(640, 360), 1.2)
img3.slide_to(Vector2(980, 520), 1.4)
```

## 4. 数据流 (Data Flow)

```
时序: 展示 → 滑动 → 粉碎

t=0:    ImageManager.present(tex, pos)
        → new ImageHandle
          → new Sprite2D, set texture + position
          → add_child to CanvasLayer
        → 返回 handle

t=0~1.5: handle.slide_to(target, 1.5)
          → Tween: sprite.global_position (from→to)
          → 调用方 await

t=1.5:  slide_to 完成
        → Tween.finished 信号发出
        → 调用方继续执行

t=1.5~2.5: 停留 (调用方自己 await timer)

t=2.5~3.7: handle.shatter(1.2)
            → Sprite.material 切换为 ShaderMaterial
            → Tween: shader progress 0→1
            → Voronoi 碎片散开 + Alpha 淡出

t=3.7:  shatter 完成
        → _destroy()
          → sprite.queue_free()
          → ImageManager._on_handle_freed()
```

## 5. 文件清单

| 文件 | 类型 | 用途 |
|------|------|------|
| `shaders/image_shatter.gdshader` | 已有 | Voronoi 解体着色器 |
| `effects/shatter_effect.tscn` | 保留 | 旧特效场景 (向后兼容) |
| `effects/ShatterEffect.gd` | 保留 | 旧特效脚本 (向后兼容) |
| `features/image_manager.gd` | **已有** | 全局管理 Autoload, 现新增 ID 化 API |
| `features/image_handle.gd` | **已有** | 图片操作句柄 |
| `features/image_effect_manager.gd` | **废弃** | 被 ImageManager 取代 |
| `model/enumerates.gd` | 修改 | 新增 `IMAGE_POS` 枚举 |
| `core/operators/image_present_operator.gd` | **新建** | DSL `image_present` operator |
| `core/operators/image_slide_operator.gd` | **新建** | DSL `image_slide` operator |
| `core/operators/image_shatter_operator.gd` | **新建** | DSL `image_shatter` operator |
| `core/operators/image_fade_out_operator.gd` | **新建** | DSL `image_fade_out` operator |
| `core/operators/image_remove_operator.gd` | **新建** | DSL `image_remove` operator |
| `parser/micro_dsl_parser.gd` | 修改 | 新增 5 个 image_* 函数 dispatch |
| `core/eventbus.gd` | 不修改 | 现有信号已够用 |
| `project.godot` | 不修改 | autoload 已注册 |

## 6. DSL 用法示例

在 CSV 的 results 列中编排图片序列:

```
# 展示一张背景图
image_present(id="bg_chang_an", pos="center")

# ... 中间有其他步骤 ...

# 将图片滑动到顶部
image_slide(id="bg_chang_an", pos="top_center", duration=1.5)

# ... 更多剧情 ...

# 粉碎/淡出/移除
image_shatter(id="bg_chang_an")
# 或
image_fade_out(id="bg_chang_an", duration=2.0)
# 或
image_remove(id="bg_chang_an")
```

## 7. 位置枚举

```
ENUMS.IMAGE_POS:
  CENTER        → 屏幕中心
  TOP_LEFT      → 左上角
  TOP_CENTER    → 顶部居中
  TOP_RIGHT     → 右上角
  CENTER_LEFT   → 左侧居中
  CENTER_RIGHT  → 右侧居中
  BOTTOM_LEFT   → 左下角
  BOTTOM_CENTER → 底部居中
  BOTTOM_RIGHT  → 右下角
  FULL_SCREEN   → 全屏 (scale-to-fit)
```

## 8. 向后兼容策略

旧的 `ImageEffectManager` 和 `EventBus.request_play_shatter` 信号会在过渡期内保留, 但标记为 `@deprecated`:

```gdscript
# features/image_effect_manager.gd (废弃)
@deprecated("改用 ImageManager.play_shatter()")
func play_shatter(tex, pos, duration, params):
    ImageManager.play_shatter(tex, pos, duration, params)
```

调用方迁移路径:
```
旧: ImageEffectManager.play_shatter(tex, pos)       → 新: ImageManager.play_shatter(tex, pos)
旧: EventBus.request_play_shatter.emit(tex, pos, d) → 新: ImageManager.present(tex, pos).shatter(d)
```

## 7. 未来扩展 (Backlog)

- 对象池 (Sprite2D 复用)
- 缩放动画 (`zoom_to()`)
- 旋转动画 (`rotate_to()`)
- 路径动画 (`follow_path(points)`)
- 特效播完后发出 `finished` 信号 (已在 ImageHandle 中实现)
