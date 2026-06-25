# 诗梦地图 HTML5 导出调试总结

## 问题概述

Godot 4 项目（诗梦地图 Poem Map）使用 `export_filter="scenes"` 导出 HTML5/Web 时，大量 `class_name` 脚本被"孤儿剔除"，导致运行时 `Could not find script for class` 级联报错，游戏无法启动。

## 根因分析

### Godot HTML5 导出的 class_name 注册机制差异

在桌面平台，Godot 编辑器会预扫描所有 `.gd` 文件并注册 `class_name`。但在 HTML5 导出时：

1. **不会预扫描**：只处理实际被导出器追踪到的 `.gd` 文件
2. **追踪链路**：`.tscn` → `[ext_resource]` → `.gd` 文件 → `class_name` 注册
3. **断链点**：`.gd` 文件内部的 `preload()` / `const ClassName = preload(...)` / 类型注解 `var x: ClassName` **都不会**被导出器的依赖追踪器识别

### export_filter="scenes" 的孤儿剔除

`export_presets.cfg` 中 `export_filter="scenes"` 只导出显式列出的 56 个 `.tscn`。纯 `class_name` 脚本（特别是 `extends RefCounted` 的纯逻辑类）如果没有被任何 `.tscn` 直接引用，就会被剔除。

## 失败的方案

### 方案 1：在 game_config.gd 中 preload 所有 class_name

```gdscript
const _Logging = preload("res://core/logging.gd")
const _ENUMS = preload("res://model/enumerates.gd")
# ... 89 条 preload
```

**失败原因**：`preload()` 在 `.gd` 内部不会触发导出依赖追踪。HTML5 Worker 初始化时其他 autoload 编译顺序不同步，看不到这些 class_name。

### 方案 2：_class_registry.gd 作为第一个 autoload

创建包含所有 class_name 脚本 preload 的注册表，放在 autoload 链最前面。

**失败原因**：HTML5 Worker 线程在加载这个 autoload 时直接崩溃（`Worker sent an error! undefined:undefined: undefined`），可能是循环依赖或 preload 量过大导致。
不对, 实际上是gd的随机崩溃, 这个东西的可行性暂时不确定. 多刷新几次就能进入

### 方案 3：在 export_presets.cfg 的 export_files 中添加 .gd 路径

通过 Python 脚本向 `export_presets.cfg` 的 `export_files` 数组追加 42 个 `.gd` 文件路径。

**失败原因**：Godot 编辑器打开时会用自己的内存缓存覆盖 `export_presets.cfg`，外部 Python 修改被回滚。

## 最终方案：ext_resource 锚点场景

### 核心原理

Godot 导出器的依赖追踪**只认** `.tscn` 中的 `[ext_resource]` 声明。这是唯一可靠的硬引用链：

```
.tscn → [ext_resource type="Script" path="res://xxx.gd"] → class_name 注册
```

### 实现

**文件 1：`core/_export_dependency_anchor.tscn`**

```gdscript
[gd_scene format=3 uid="uid://ctqvas214nx8r"]

[ext_resource type="Script" path="res://core/_export_dependency_anchor.gd" id="anchor_script"]
[ext_resource type="Script" path="res://core/model/action.gd" id="res_00"]
[ext_resource type="Script" path="res://core/model/action_tag_filter.gd" id="res_01"]
# ... 共 57 条 ext_resource 条目
[ext_resource type="ShaderMaterial" path="res://shaders/flame_shader_material.tres" id="res_56"]

[node name="ExportDependencyAnchor" type="Node"]
script = ExtResource("anchor_script")
```

**文件 2：`core/_export_dependency_anchor.gd`**

```gdscript
extends Node
const __preload_00 = preload("res://core/model/action.gd")
const __preload_01 = preload("res://core/model/action_tag_filter.gd")
# ... 共 57 条 preload（辅佐 .tscn 的 ext_resource）
```

**文件 3：`export_presets.cfg`**

在 HTML5 导出预设的 `export_files` 数组第一位插入锚点场景路径：

```
"res://core/_export_dependency_anchor.tscn"
```

### 为什么这个方案有效

1. `.tscn` 中的 `[ext_resource type="Script" path="..."]` 是 Godot 导出器**内置的**依赖追踪入口
2. 不是 hack —— 这是 Godot 引擎资源系统的标准引用方式
3. 锚点场景本身不包含任何实例化逻辑，运行时零开销
4. 57 个条目覆盖了项目中所有需要跨脚本引用的 `class_name`

## 额外修复：HTML5 Worker 异步初始化 Nil 守卫

HTML5 环境下，`_process()` 可能在 autoload 完全初始化前被调用，导致 `Nil.function()` 错误。

### 已加守卫的文件

| 文件 | 行号 | 守卫条件 | 日志 |
|---|---|---|---|
| `core/time_service.gd` | 129 | `if not GameState` | `Logging.err("time_service: GameState autoload not ready in _process, skipping frame")` |
| `debuggers/property_label.gd` | 12 | `if not Database` | `Logging.err("property_label: Database autoload not ready in _process, skipping frame")` |
| `ui/left_player_panel.gd` | 174 | `if not Database` | `Logging.err("LeftPlayerPanel: Database autoload not ready in _rebuild_prop_grid, skipping")` |
| `ui/left_player_panel.gd` | 195 | `if not Database` | `Logging.err("LeftPlayerPanel: Database autoload not ready in _refresh_prop_grid, skipping")` |

## 修改文件总览

| 文件 | 变更类型 |
|---|---|
| `project.godot` | 添加 Logging + ENUMS 为 autoload（第 2、3 位） |
| `model/enumerates.gd` | `extends RefCounted` → `extends Node`（autoload 要求） |
| `core/_export_dependency_anchor.tscn` | **新建** — 57 条 ext_resource 锚点 |
| `core/_export_dependency_anchor.gd` | **新建** — 57 条 preload 辅佐 |
| `export_presets.cfg` | 锚点场景插入 export_files 首位 |
| `core/time_service.gd` | `if not GameState` 守卫 + Logging.err |
| `debuggers/property_label.gd` | `if not Database` 守卫 + Logging.err |
| `ui/left_player_panel.gd` | 2 处 `if not Database` 守卫 + Logging.err |
| `tools/toggle_export_fix.py` | 更新 toggle 脚本支持新 autoload 配置 |

## 级联依赖链（判定依据）

```
BaseEventPoolFilter ← ActionTagFilter, CooldownFilter, RequirementFilter
MapMarker ← PoemData, PoetData, PoetLifePoint
UIDecl ← GameEntity
BaseProvider ← Disease
Util ← PoemData
ConditionalOperator ← BaseOperator (已在 anchor)
BaseRequirements ← BaseProvider (已在 anchor)
```

两个不在 anchor 的父类 `BaseEventPoolFilter` 和 `MapMarker` 导致了 8 个子类的级联失败。扩展锚点后所有级联链被完整覆盖。

## 注意事项

1. 新增 `class_name` 脚本时，必须同步添加到锚点场景的两个文件中
2. 修改 `export_presets.cfg` 前必须关闭 Godot 编辑器
3. 纯 preload 引用的非 class_name 文件（如 `custom_tooltip.gd`、`flame_shader_material.tres`）也需加入锚点

导出模式 = support thread很容易出问题. 