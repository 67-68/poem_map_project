# StyleManager — 属性驱动视觉风格管理器

## 概述

`StyleManager` 是一个 Autoload 管理器，负责：

1. **属性→Shader 映射**：将 `PlayerState` 属性值实时映射为 `ShaderMaterial` 的 shader parameter
2. **策略模式**：每个控件可注册多个命名策略（`StyleData.strategy_name`），运行时自由切换
3. **背景纹理管理**：接管 `PanelContainer` 的 `StyleBoxTexture.texture` 切换（含事件临时背景覆盖）

## 数据模型: StyleData

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `strategy_name` | `String` | `""` | 策略唯一标识，如 `"frost"`、`"decay_dirt_crack"` |
| `target_property` | `String` | `""` | PlayerState 属性名 |
| `start_property_value` | `float` | `0.0` | progress=0.0 对应的属性值 |
| `target_property_value` | `float` | `100.0` | progress=1.0 对应的属性值 |
| `shader_resource` | `Shader` | `null` | `.gdshader` 资源（若 `shader_material` 已提供可为 null） |
| `shader_material` | `ShaderMaterial` | `null` | 预制 ShaderMaterial（含 noise 纹理等预设参数） |
| `shader_parameter_names` | `Array[String]` | `[]` | 被驱动的 param 列表，共用同一 progress 值 |
| `stylebox_texture` | `Texture2D` | `null` | 策略激活时替换的 StyleBoxTexture（仅 PanelContainer），null=不碰 |
| `container` | `Control` | `null` | 目标节点 |

### Progress 计算公式

```
range   = target - start         （可为负，自然表达方向）
raw     = (current - start) / range
clamped = clamp(raw, 0.0, 1.0)
```

- `start=0, target=100` → 属性越高 progress 越高
- `start=100, target=0` → 属性越低 progress 越高（反向）
- `target == start` → 返回 `0.0`（除零保护）

## API

### bind(data: StyleData) → void

注册一个命名策略。首次 bind 时自动捕获 default 状态。若 `strategy_name` 非空，自动激活。

### switch_strategy(container, name: String) → void

切换活跃策略。`name` 为空 → 回滚到 default 状态。

### apply_event_background(container, texture) → void

事件临时背景覆盖。`texture` 非 null → 覆盖；null → 还原策略默认背景。

### get_container_background(container) → Texture2D?

读取当前 StyleBoxTexture.texture。

### get_default_background(container) → Texture2D?

读取 default 状态中的背景纹理。

### unbind(container) → void

取消所有注册，还原 default 状态。

## 使用示例

### Frost 策略（NarrativeOverlay tape_container）

血量 100 → frost=0，血量 0 → frost=1

```gdscript
var data = StyleData.new()
data.strategy_name = "frost"
data.target_property = "health"
data.start_property_value = 100.0
data.target_property_value = 0.0
data.shader_resource = preload("res://shaders/frost.gdshader")
data.shader_parameter_names = ["freeze_progress"]
data.container = $TapeContainer
StyleManager.bind(data)
StyleManager.switch_strategy($TapeContainer, "frost")
```

### Decay Dirt Crack 策略（AmbitionHUD）

距离 0 → progress=0，距离 100 → progress=1

```gdscript
var mat = ShaderMaterial.new()
mat.shader = preload("res://shaders/decay_dirt_crack.gdshader")
mat.set_shader_parameter("dirt_noise", dirt_noise_tex)
mat.set_shader_parameter("crack_noise", crack_noise_tex)

var data = StyleData.new()
data.strategy_name = "decay_dirt_crack"
data.target_property = "distance"
data.start_property_value = 0.0
data.target_property_value = 100.0
data.shader_material = mat
data.shader_parameter_names = ["progress"]
data.container = self
StyleManager.bind(data)
StyleManager.switch_strategy(self, "decay_dirt_crack")
```

### 事件背景临时覆盖

```gdscript
# 事件携带自定义背景
StyleManager.apply_event_background(tape_container, custom_texture)

# 事件结束，还原默认
StyleManager.apply_event_background(tape_container, null)
```

## 架构流转

```
bind(data)
  ├── 契约检查
  ├── 首次 bind → capture_default(container): {material, background_tex}
  ├── 注册到 _strategies[id][name]
  ├── 绑定 tree_exiting → auto-cleanup
  ├── strategy_name 非空 → _apply_strategy()
  │       ├── material = shader_material or 新建 ShaderMaterial
  │       ├── PanelContainer → stylebox_texture 不为 null 时替换
  │       ├── _active_strategy[id] = name
  │       └── _sync_progress()

switch_strategy(container, name)
  ├── name 为空 → _restore_default(container)
  │       ├── material = saved_material
  │       ├── PanelContainer → stylebox = saved_background_tex
  │       └── _active_strategy.erase(id)
  └── name 非空 → _apply_strategy(container, _strategies[id][name])

PlayerState.player_stat_changed("health")
  └── _on_player_stat_changed()
        └── 遍历 _active_strategy
              └── 匹对 target_property → _sync_progress()

apply_event_background(container, tex)
  ├── tex 非 null → 临时覆盖 StyleBoxTexture
  └── tex null → 还原 get_default_background()
```

## 防御性清单

| 场景 | 处理 |
|---|---|
| `container` 为 null / 已销毁 | `bind()` 返回 + `Logging.err` |
| `target == start`（除零） | `compute_progress()` 返回 `0.0` |
| `shader_parameter_names` 为空 | for 循环自然跳过 |
| 同一策略名重复 bind | `Logging.warn` + 覆盖 |
| container.tree_exiting | 自动 unbind |
| 非 PanelContainer 调 apply_event_background | `Logging.warn` + skip |
| `_exit_tree()` | 断开 signal + 清空所有字典 |
| PlayerState 中不存在该属性 | `get_stat_val` 返回 0，由 PlayerState 输出 err |

## 文件位置

| 文件 | 职责 |
|---|---|
| `core/model/style_data.gd` | 纯数据模型 |
| `features/style_manager.gd` | Autoload 管理器 |
