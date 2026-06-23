# StyleManager 使用指南

StyleManager 是属性驱动 shader + StyleBox + 文本字体的视觉策略引擎。
属性变化（血量、距离等）→ 自动驱动 shader 参数进度。

---

## 1. 基础模式：单容器

```gdscript
var data := StyleData.new()
data.strategy_name = "frost"
data.target_property = "health"           # 绑定 PlayerState 属性
data.start_property_value = 100.0         # 属性值 → progress=0 的锚点
data.target_property_value = 0.0          # 属性值 → progress=1 的锚点
data.shader_material = preload("res://shaders/frost_shader.tres")
data.shader_parameter_names = ["freeze_progress"]
data.stylebox = preload("res://shaders/frostland_stylebox.tres")
data.narrative_text_theme = "FrozenNarrativeText"
data.container = $TapeContainer           # 单数，向后兼容
StyleManager.bind(data)
```

## 2. 策略组模式：多容器同时切换

```gdscript
data.containers = [$TapeContainer, $SidePanel, $HeaderPanel]
# containers 非空时忽略 container；都为空则 bind() 报错
StyleManager.bind(data)
```

## 3. 策略切换

```gdscript
# 激活策略（组内全部容器同时切换）
StyleManager.switch_strategy($TapeContainer, "frost")

# 回滚到默认状态
StyleManager.switch_strategy($TapeContainer, "")
```

通过 `StyleStrategyOperator` (DSL) 触发，无需手写 `switch_strategy`。

## 4. 事件临时背景

```gdscript
StyleManager.apply_event_background($TapeContainer, some_texture)  # 覆盖
StyleManager.apply_event_background($TapeContainer, null)           # 还原
```

## 5. progress 输出区间

部分 shader 只在特定区间有效果。`progress_output_min/max` 将 0→1 remap 到目标区间：

```gdscript
data.progress_output_min = 0.27
data.progress_output_max = 0.326  # decay_dirt_crack 可见窗口
```
