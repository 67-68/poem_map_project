# 图像特效管理器架构 (Image Effect Manager)

## 1. 整体架构 (System Topology)

```
┌── 调用方（事件系统 / 剧情脚本 / 调试命令）─────────────────────┐
│  ImageEffectManager.play_shatter(texture, global_pos)          │
│  EventBus.request_play_shatter.emit(texture, global_pos)       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌── ImageEffectManager (Autoload) ──────────────────────────────┐
│  extends Node                                                  │
│  - _ready(): 创建 ImageEffectLayer 并挂到 SceneTree            │
│  - play_shatter(tex, pos, duration): 工厂方法                   │
│  - play_fade(tex, pos, duration): (预留扩展点)                  │
│  - 日志记录每一个 spawn 的特效实例                              │
└──────────────────────────────┬──────────────────────────────────┘
                               │ add_child()
                               ▼
┌── ImageEffectLayer (CanvasLayer) ─────────────────────────────┐
│  layer = 128 (确保在所有 UI 之上)                               │
│  纯容器，无逻辑，只负责 depth sorting                            │
│  当所有子节点清空时可自动隐藏（预留优化）                        │
└──────────────────────────────┬──────────────────────────────────┘
                               │ instantiate()
                               ▼
┌── ShatterEffect.tscn ─────────────────────────────────────────┐
│  Node2D                                                        │
│  └─ Sprite2D                                                   │
│     └─ ShaderMaterial → shaders/image_shatter.gdshader         │
│                                                               │
│  ShatterEffect.gd:                                             │
│  - initialize(texture, pos, duration)                          │
│  - Tween: shader_param/progress: 0.0 → 1.0                    │
│  - Tween 完成后 emit finished → queue_free()                   │
└────────────────────────────────────────────────────────────────┘
```

## 2. 组件职责边界 (Contract)

### 2.1 ImageEffectManager (`features/image_effect_manager.gd`)

```
角色: 全局协调者 + 工厂
责任:
  ✅ 管理 EffectLayer 的生命周期
  ✅ 提供 play_* 系列公共接口
  ✅ 日志记录（每个特效 spawn 都记）
  ❌ 绝对不碰 Shader 参数
  ❌ 绝对不处理具体图片内容
```

**伪代码接口:**

```gdscript
class_name ImageEffectManager extends Node

const SHATTER_SCENE := preload("res://effects/shatter_effect.tscn")

var _effect_layer: CanvasLayer

func _ready() -> void:
    # 创建一个 CanvasLayer，设置最高层
    _effect_layer = CanvasLayer.new()
    _effect_layer.layer = 128
    _effect_layer.name = "ImageEffectLayer"
    # 挂在 SceneTree 根节点下
    # 注意: 使用 Callable 延迟挂载，避免 _ready() 阶段 SceneTree 还没稳定
    get_tree().root.call_deferred("add_child", _effect_layer)

func play_shatter(tex: Texture2D, global_pos: Vector2, duration: float = 1.0) -> void:
    # 契约检查
    assert(tex != null, "ImageEffectManager: texture is null 💀")
    
    var effect = SHATTER_SCENE.instantiate() as ShatterEffect
    _effect_layer.add_child(effect)
    effect.initialize(tex, global_pos, duration)
    
    Logging.info("ImageEffectManager: play_shatter → %s @ %s" % [tex.resource_path, global_pos])

# --- 预留扩展点 ---
# func play_fade(tex: Texture2D, pos: Vector2, duration: float) -> void:
# func play_pixelate(tex: Texture2D, pos: Vector2, duration: float) -> void:
```

### 2.2 ShatterEffect (`effects/ShatterEffect.gd`)

```
角色: 自包含的特效实体，播完就死
责任:
  ✅ 初始化 texture、position
  ✅ Tween 驱动 progress
  ✅ 播完 queue_free()
  ❌ 不持有 Manager 引用
  ❌ 不关心是谁创建的
```

```gdscript
class_name ShatterEffect extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D

func initialize(tex: Texture2D, pos: Vector2, duration: float) -> void:
    _sprite.texture = tex
    global_position = pos
    
    var shader_material = _sprite.material as ShaderMaterial
    shader_material.set_shader_parameter("progress", 0.0)
    
    var tw = create_tween()
    tw.tween_method(_update_progress, 0.0, 1.0, duration)
    tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
    tw.finished.connect(_on_finished)

func _update_progress(val: float) -> void:
    var mat = _sprite.material as ShaderMaterial
    mat.set_shader_parameter("progress", val)

func _on_finished() -> void:
    queue_free()
```

### 2.3 Voronoi 解体 Shader (`shaders/image_shatter.gdshader`)

```
角色: 纯渲染算法，完成 UV 切割 + 碎片散开 + Alpha 淡出
责任:
  ✅ 接受 uniform float progress (0.0→完整, 1.0→完全消散)
  ✅ 内置 Voronoi 噪声函数生成碎片图案
  ✅ 每块碎片独立随机偏移方向和速度
  ✅ Alpha 随 progress 递增衰减
  ❌ 不感知游戏逻辑
  ❌ 不做纹理修改
```

**Shader 架构拆解:**

```glsl
shader_type canvas_item;

// ── 输入契约 ──
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// ── 碎片参数 ──
uniform float cell_size : hint_range(4.0, 64.0) = 32.0;  // Voronoi 细胞大小
uniform float scatter_strength : hint_range(0.0, 1.0) = 0.3; // 散开强度
uniform float alpha_fade_start : hint_range(0.0, 1.0) = 0.6; // 从多少 progress 开始淡化

// ── Voronoi 噪声函数 ──
// 用途: 生成每个细胞的随机偏移方向和大小
// 输入: 细胞坐标 (ivec2)
// 输出: 伪随机 vec2 偏移量

// ── fragment() ──
// 1. 将 UV 除以 cell_size → 得到细胞坐标 cell_coord
// 2. 对 cell_coord 求 Voronoi 噪声 → 每个细胞得到一个随机偏移种子
// 3. 计算 UV 偏移量: offset = 随机种子 * scatter_strength * ease_out(progress)
// 4. 计算 Alpha: 
//    - 如果 progress < alpha_fade_start → alpha = 1.0
//    - 否则 → alpha = 1.0 - (progress - alpha_fade_start) / (1.0 - alpha_fade_start)
// 5. 采样偏移后的 UV → COLOR
// 6. 应用 Alpha
```

## 3. 数据流 (Data Flow)

```
调用时序:

时间 t=0:
  play_shatter(tex, pos) 被调用
  → Manager 实例化 ShatterEffect
  → 添加到 EffectLayer
  → effect.initialize() 设置 texture, position
  → Shader progress = 0.0 (图片完整显示)

时间 t=0→1.0 (duration):
  Tween.ease_in_cubic(progress: 0.0 → 1.0)
  → Shader fragment() 逐帧:
    - Voronoi 细胞逐渐分离
    - 碎片向外扩散
    - Alpha 逐渐降低

时间 t=duration:
  Tween.finished → queue_free()
  → 特效实体被销毁
  → EffectLayer 继续等待下一个效果
```

## 4. 文件清单

| 文件 | 类型 | 用途 |
|------|------|------|
| `shaders/image_shatter.gdshader` | 新建 | Voronoi 解体着色器 |
| `effects/shatter_effect.tscn` | 新建 | 特效场景 (Sprite2D + ShaderMaterial) |
| `effects/ShatterEffect.gd` | 新建 | 特效逻辑脚本 |
| `features/image_effect_manager.gd` | 新建 | 全局管理单例 |
| `core/eventbus.gd` | 修改 | +1 信号 `request_play_shatter` |
| `project.godot` | 修改 | 注册 autoload |

## 5. 未来扩展 (Backlog)

- `play_fade()` — 简单的渐隐消失
- `play_pixelate()` — 像素化瓦解
- `play_glow_out()` — 发光消散
- EffectPool — 对象池复用，避免频繁 instantiate/free (当特效频率高时引入)
