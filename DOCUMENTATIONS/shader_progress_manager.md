# ShaderProgressManager — 属性驱动 Shader 进度管理器

## 概述

`ShaderProgressManager` 是一个 Autoload 管理器，负责将 `PlayerState` 中的属性值（如 health、fatigue、money 等）实时映射为 `ShaderMaterial` 的 shader parameter，从而驱动 UI 控件上的视觉效果。

典型场景：
- 血量越低 → frost（结霜）越重
- 疲惫越高 → dirt_crack（纸张裂纹）越深
- 金钱越多 → golden_shine（金光）越亮

## 数据模型: ShaderProgressData

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `target_property` | `String` | `""` | PlayerState 属性名，如 `"health"`、`"fatigue"` |
| `shader_resource` | `Shader` | `null` | `.gdshader` 资源，需 `preload` |
| `shader_parameter_names` | `Array[String]` | `[]` | 被驱动的 shader parameter 名列表，**所有 param 共用同一 progress 值** |
| `property_progress_inverted` | `bool` | `false` | `true` → 属性值越高 progress 越低 |
| `target_property_value` | `float` | `100.0` | progress=1.0 对应的属性值（"终点"） |
| `start_property_value` | `float` | `0.0` | progress=0.0 对应的属性值（"起点"） |
| `container` | `Control` | `null` | 目标控件，其 `material` 属性将被注入 `ShaderMaterial` |

### Progress 计算公式

```
raw     = (current_val - start) / (target - start)
clamped = clamp(raw, 0.0, 1.0)
final   = 1.0 - clamped   (if inverted)
          clamped          (otherwise)
```

- `target == start` 时，除零保护 → 返回 `0.0`

## API

### bind(data: ShaderProgressData) -> void

注册一个属性→shader 驱动绑定。

- 自动创建 `ShaderMaterial` 并设置 `container.material`
- 绑定 `container.tree_exiting` 信号，控件销毁时自动清理
- 立即执行首次同步
- 同一 container 重复 bind 会自动解绑旧 binding

### unbind(container: Control) -> void

取消注册，还原 `container.material = null`。

### refresh_all() -> void

强制刷新所有绑定的进度（调试用）。

## 使用示例

### 示例 1: 血量驱动 Frost 效果（inverted 模式）

血量 100 → frost=0（无结霜），血量 0 → frost=1（完全冻结）

```gdscript
var data = ShaderProgressData.new()
data.target_property = "health"
data.shader_resource = preload("res://shaders/frost.gdshader")
data.shader_parameter_names = ["freeze_progress"]
data.start_property_value = 0.0
data.target_property_value = 100.0
data.property_progress_inverted = true   # 血越少 frost 越重
data.container = $HealthPanel
ShaderProgressManager.bind(data)
```

### 示例 2: 金钱驱动 Golden Shine 效果

金钱 0 → shine=0，金钱 5000 → shine=1

```gdscript
var data = ShaderProgressData.new()
data.target_property = "money"
data.shader_resource = preload("res://shaders/golden_shine.gdshader")
data.shader_parameter_names = ["shine_intensity"]
data.start_property_value = 0.0
data.target_property_value = 5000.0
data.container = $MoneyPanel
ShaderProgressManager.bind(data)
```

### 示例 3: 手动解绑

```gdscript
ShaderProgressManager.unbind($HealthPanel)
```

## 架构流转

```
bind(data)
  ├── 契约检查 (container/target_property/shader_resource 非空)
  ├── 去重 (同 container 先解绑旧 binding)
  ├── 创建 ShaderMaterial → container.material = mat
  ├── 绑定 tree_exiting → auto-cleanup
  ├── 首次 _sync_progress()
  └── 写入 _bindings[]

PlayerState.player_stat_changed("health")
  └── _on_player_stat_changed()
        └── 遍历 _bindings，匹对 target_property
              └── _sync_progress(binding)
                    ├── current_val = PlayerState.get_stat_val(prop)
                    ├── progress = data.compute_progress(current_val)
                    └── for param in shader_parameter_names:
                          mat.set_shader_parameter(param, progress)

container.tree_exiting
  └── _on_container_tree_exiting()
        └── _remove_binding_by_container()
              ├── 断开信号
              ├── container.material = null
              └── 从 _bindings 移除
```

## 防御性清单

| 场景 | 处理 |
|---|---|
| `container` 为 null / 已销毁 | `bind()` 返回并输出 `Logging.err` |
| `target_property` 为空 | `bind()` 返回并输出 `Logging.err` |
| `shader_resource` 为 null | `bind()` 返回并输出 `Logging.err` |
| `target == start`（除零） | `compute_progress()` 返回 `0.0` + `Logging.warn` |
| `shader_parameter_names` 为空 | `_sync_progress` 中 for 循环自然跳过，不 crash |
| 同一 container 多次 bind | 先 unbind 旧再 bind 新 |
| container.tree_exiting | 自动 unbind |
| `_exit_tree()` 时 | 断开 signal + 清空 _bindings |

## 文件位置

| 文件 | 职责 |
|---|---|
| `core/model/shader_progress_data.gd` | 纯数据模型 |
| `features/shader_progress_manager.gd` | Autoload 管理器 |
