# 诗梦地图 HTML5 导出调试总结

## 问题概述

Godot 4 项目（诗梦地图 Poem Map）使用 `export_filter="scenes"` 导出 HTML5/Web 时，大量 `class_name` 脚本被"孤儿剔除"，导致运行时 `Could not find script for class` 级联报错，游戏无法启动。

---

## 第一轮：class_name 注册问题（Session 1）

### 根因分析

#### Godot HTML5 导出的 class_name 注册机制差异

在桌面平台，Godot 编辑器会预扫描所有 `.gd` 文件并注册 `class_name`。但在 HTML5 导出时：

1. **不会预扫描**：只处理实际被导出器追踪到的 `.gd` 文件
2. **追踪链路**：`.tscn` → `[ext_resource]` → `.gd` 文件 → `class_name` 注册
3. **断链点**：`.gd` 文件内部的 `preload()` / `const ClassName = preload(...)` / 类型注解 `var x: ClassName` **都不会**被导出器的依赖追踪器识别

#### export_filter="scenes" 的孤儿剔除

`export_presets.cfg` 中 `export_filter="scenes"` 只导出显式列出的 56 个 `.tscn`。纯 `class_name` 脚本（特别是 `extends RefCounted` 的纯逻辑类）如果没有被任何 `.tscn` 直接引用，就会被剔除。

### 失败的方案

#### 方案 1：在 game_config.gd 中 preload 所有 class_name

```gdscript
const _Logging = preload("res://core/logging.gd")
const _ENUMS = preload("res://model/enumerates.gd")
# ... 89 条 preload
```

**失败原因**：`preload()` 在 `.gd` 内部不会触发导出依赖追踪。HTML5 Worker 初始化时其他 autoload 编译顺序不同步，看不到这些 class_name。

#### 方案 2：_class_registry.gd 作为第一个 autoload

创建包含所有 class_name 脚本 preload 的注册表，放在 autoload 链最前面。

**失败原因**：HTML5 Worker 线程在加载这个 autoload 时崩溃（`Worker sent an error! undefined:undefined:undefined`）。实际上可能是 GDScript 的随机崩溃，多刷新几次就能进入，方案可行性尚不确定。

#### 方案 3：在 export_presets.cfg 的 export_files 中添加 .gd 路径

通过 Python 脚本向 `export_presets.cfg` 的 `export_files` 数组追加 42 个 `.gd` 文件路径。

**失败原因**：Godot 编辑器打开时会用自己的内存缓存覆盖 `export_presets.cfg`，外部 Python 修改被回滚。

### 最终方案：ext_resource 锚点场景

#### 核心原理

Godot 导出器的依赖追踪**只认** `.tscn` 中的 `[ext_resource]` 声明。这是唯一可靠的硬引用链：

```
.tscn → [ext_resource type="Script" path="res://xxx.gd"] → class_name 注册
```

#### 实现

**文件 1：`core/_export_dependency_anchor.tscn`** — 227 条 `[ext_resource type="Script" path="..."]` 条目

覆盖：
- 220 个 `class_name` 脚本（包括 extends RefCounted 的纯逻辑类）
- 7 个 `preload`-only 脚本（无 class_name 但被其他脚本动态 preload）

**文件 2：`core/_export_dependency_anchor.gd`** — 对应的 preload 辅佐

**文件 3：`export_presets.cfg`** — 锚点场景插入 `export_files` 数组第一位

#### 为什么这个方案有效

1. `.tscn` 中的 `[ext_resource type="Script" path="..."]` 是 Godot 导出器**内置的**依赖追踪入口
2. 不是 hack —— 这是 Godot 引擎资源系统的标准引用方式
3. 锚点场景本身不包含任何实例化逻辑，运行时零开销

### 额外修复：HTML5 Worker 异步初始化 Nil 守卫

HTML5 环境下，`_process()` 可能在 autoload 完全初始化前被调用，导致 `Nil.function()` 错误。

| 文件 | 守卫条件 | 日志 |
|---|---|---|
| `core/time_service.gd` | `if not GameState` | `Logging.err(... skipping frame)` |
| `debuggers/property_label.gd` | `if not Database` | `Logging.err(... skipping frame)` |
| `ui/left_player_panel.gd` | `if not Database` ×2 | `Logging.err(... skipping)` |

---

## 第二轮：运行时数据 & 资产加载问题（Session 2）

第一轮修复解决 class_name 注册后，游戏能启动了，但立即暴露出新的问题：**地图为空，没有任何事件、行动、决策、特性数据**。

### 问题 1：CSV 文件"次元放逐"

**现象**：`DataScanner` 用 `DirAccess` 扫描数据文件时找不到 CSV，用 JSON 索引也找不到。

**根因**：`data/1_core_rules/base_province.csv.import` 和 `territories.csv.import` 的 importer 设为 `csv_translation`。Godot 在导出时将 CSV 转换为二进制 `.translation` 格式，**原始 CSV 文件不在 .pck 中**。

**修复**：将 `.csv.import` 的 importer 改为 `"keep"`：
```ini
[remap]
importer="keep"
type=""
source_file="res://data/1_core_rules/base_province.csv"
dest_files=[]
```

✅ 验证通过：日志显示 `load 295 model from base_province.csv` 和 `load 23 model from territories.csv`。

### 问题 2：资产文件缺失

**现象**：`No loader found for resource: res://assets/...` — PNG/WAV/MP3 文件全部无法加载。

**根因**：`export_presets.cfg` 的 `include_filter` 只有 `"data/**/*, data/*"`，没有包含 `assets/`。

**修复**：`include_filter` 追加 `"assets/**/*"`：
```
include_filter="data/**/*, data/*, assets/**/*"
```

### 问题 3：TRAITS 枚举缺失 disease 条目

**现象**：`Invalid trait string: disease_fenghan_acute` 等 4 个疾病 trait 无法解析。

**根因**：`model/enumerates.gd` 的 `TRAITS` 枚举中没有 `DISEASE_FENGHAN_ACUTE` 等条目。

**修复**：在 `TRAITS` 枚举末尾追加 4 个疾病条目：
```gdscript
DISEASE_FENGHAN_ACUTE,    # 风寒急性期
DISEASE_FEILAO_CHRONIC,   # 肺痨慢性期
DISEASE_SHIYI_DEPRESSION, # 失意抑郁
DISEASE_ZHANWANG_MANIA,   # 谵妄狂躁
```

同时在 `from_traits_str()` 中增加提示日志：
```gdscript
Logging.err("  💡 提示：如果 trait 名称无误，请检查是否已在 TRAITS 枚举中注册")
```

### 问题 4：to_action_str 数组越界

**现象**：`Invalid action tag` 后跟 index out of bounds 崩溃。

**根因**：遍历池中所有 action 的 `action_tag` 时，某些枚举值超出 `ACTION_TAGS` 字典范围，未做边界检查。

**修复**：`to_action_str()` 增加边界保护：
```gdscript
static func to_action_str(item) -> String:
    if item < 0 or item >= ACTION_TAGS.size():
        Logging.err("Invalid action tag: %d (bounds: [0, %d))" % [item, ACTION_TAGS.size()])
        return "default_storable_item"
```

### 问题 5：animation_controller.gd 字符串格式化错误

**现象**：`String formatting error` at line 89。

**根因**：GDScript 的 `%` 格式化操作符不支持某些复杂类型直接传入。

**修复**：将 `"..." % shader_mappings.keys()` 改为 `"..." + str(shader_mappings.keys())`。

### 问题 6：DataScanner 两级策略的致命漏洞 ⚠️

**现象**：DirAccess 扫到 2 个 CSV 文件 → `scanned_file_count = 2 > 0` → **不触发 fallback** → 564 个 .tres 数据文件全部丢失 → Database 0 events / 0 actions / 0 decisions。

**根因**：DataScanner 的两级策略（DirAccess 优先 → 0 文件时 fallback 到 JSON 索引）的 fallback 条件过于简单。在 HTML5 Web 环境下：
- `DirAccess.list_dir_begin()` 只能穿透到部分子目录
- 能找到 `1_core_rules/` 下的 CSV 文件（`.csv.import` 改为 `keep` 后已在 .pck 中）
- 但 **找不到** 子目录中的 `.tres` 文件（原因不明，可能是 Godot 4 Web 导出的 DirAccess 实现限制）

因为扫到了 2 个文件（> 0），`scanned_file_count == 0` 条件不满足，JSON 索引 fallback 永远不触发。

**修复（最终版）**：不再用阈值或百分比，改为**无条件比较**：只要索引文件数 > DirAccess 扫到的文件数，就用索引。

```gdscript
# 比较 DirAccess 结果与预构建索引，索引文件数更多则用索引
var index_file = FileAccess.open(_FILE_INDEX_PATH, FileAccess.READ)
if index_file:
    # ... 解析 JSON ...
    if result.scanned_file_count < index_file_count:
        Logging.warn("DirAccess 扫到 %d 个文件，索引有 %d 个文件，降级到索引")
        var fallback_result = _scan_from_index(start_path, delim)
        if fallback_result.scanned_file_count > 0:
            result = fallback_result
```

**逻辑**：
- HTML5: DirAccess 2 < 索引 564 → 用索引 ✅
- 桌面端: DirAccess 600 ≥ 索引 564 → 用 DirAccess ✅

### 问题 7：CSV 完整性检查（`_scan_from_index` 中）

**现象**：即使 fallback 到 JSON 索引，CSV 文件也可能因 `csv_translation` importer 而被转换为 `.translation`，导致 `FileAccess.file_exists()` 返回 false。

**修复**：在 `_scan_from_index()` 中加载 CSV 前增加完整性检查：
```gdscript
elif file_name.ends_with(".csv"):
    if not FileAccess.file_exists(file_path):
        Logging.warn("索引中的 CSV 文件未打包！可能被 translation importer 转换: " + file_path)
        Logging.warn("  提示：检查 %s.import 是否设为 importer=\"csv_translation\"，需改为 importer=\"keep\"")
        continue
    result.scanned_file_count += 1
    _load_csv(file_path, current_ns, result, top_level_base, file_name)
```

### 问题 8：SHADER 错误（未修复）

**现象**：`#include` directive not supported in WebGL。

**根因**：`height_shader.gdshader` 和 `faction_shader.gdshader` 使用了 `#include` 预处理指令，WebGL/OpenGL ES 不支持。

**状态**：尚未修复，不影响 core gameplay 数据加载。

### 问题 9：级联错误（数据加载修复后预期自动解决）

以下错误均为 DataScanner 未加载 .tres 数据的级联效应：

| 错误 | 根因 |
|---|---|
| `do not find stat official_prestige` 等 11 个 stat | PlayerState 的属性数据来自 .tres，未加载 |
| `MessagerManager array index 0 out of bounds` | 消息数据未加载 |
| `MessagerManager Nil.source_id` | 同上 |
| 10 traits not found in Database | trait .tres 文件未加载 |
| Database 0 random_events / 0 history_events / 0 actions / 0 decisions | 所有 .tres 数据文件未加载 |
| NarrativeOverlay 不显示 | Database 没有事件可显示 |

**预期**：DataScanner fallback 修复后，JSON 索引路径加载 564 个 .tres → 级联问题全部自动解决。

---

## 修改文件总览

| 文件 | 变更类型 | 轮次 |
|---|---|---|
| `project.godot` | 添加 Logging + ENUMS 为 autoload | 1 |
| `model/enumerates.gd` | `extends RefCounted` → `extends Node`（autoload 要求）；追加 4 个 disease TRAITS；`to_action_str()` 边界保护；`from_traits_str()` 提示 | 1+2 |
| `core/_export_dependency_anchor.tscn` | **新建** — 227 条 ext_resource 锚点 | 1 |
| `core/_export_dependency_anchor.gd` | **新建** — 227 条 preload 辅佐 | 1 |
| `export_presets.cfg` | 锚点场景插入 export_files 首位；`include_filter` 追加 `assets/**/*` | 1+2 |
| `data/1_core_rules/base_province.csv.import` | importer `csv_translation` → `keep` | 2 |
| `data/1_core_rules/territories.csv.import` | importer `csv_translation` → `keep` | 2 |
| `core/time_service.gd` | `if not GameState` 守卫 + Logging.err | 1 |
| `debuggers/property_label.gd` | `if not Database` 守卫 + Logging.err | 1 |
| `ui/left_player_panel.gd` | 2 处 `if not Database` 守卫 + Logging.err | 1 |
| `core/animation_controller.gd` | `%s` → `str()` 修复格式化 | 2 |
| `core/data_scanner.gd` | 两级策略 + CSV 完整性检查 + fallback 无条件比较（索引文件数 > DirAccess → 用索引） | 2 |
| `core/model/action.gd` | （可能涉及边界处理） | 2 |
| `tools/toggle_export_fix.py` | 更新 toggle 脚本支持新 autoload 配置 | 1 |
| `tools/build_data_index.py` | **新建** — 构建 `data/_file_index.json`（564 条目） | 2 |
| `data/_file_index.json` | **新建** — 预构建文件索引，供 HTML5 降级路径使用 | 2 |

---

## 经验教训

### 1. Simple is better 🤷

折腾了一个晚上的「最小化 ext_resource 锚点」、preload 注入、class_registry autoload……最后发现方案还是得全部打包进去. 压根没有那么多需要筛选的资源。

> 「自由即是无序，有序即是自由。」—— 你给了 DirAccess 在 HTML5 下「自由」扫描文件系统的权利，结果它只给你扫出 2 个 CSV 🤣。老老实实建个 JSON 索引把约束做死，它才能稳定工作。

### 2. Godot HTML5 导出的"三不认"

| 引用方式 | HTML5 导出追踪？ | 可靠性 |
|---|---|---|
| `.tscn` 中的 `[ext_resource]` | ✅ 认 | 唯一可靠 |
| `.gd` 中的 `preload("res://...")` | ❌ 不认 | 不可靠 |
| `.gd` 中的类型注解 `var x: ClassName` | ❌ 不认 | 不可靠 |
| `class_name` 声明本身 | ❌ 不认（不预扫描） | 不可靠 |

### 3. `export_filter="scenes"` 的致命陷阱

这个模式是给「只有场景、没有纯脚本逻辑」的简单项目用的。任何有 `extends RefCounted` 纯逻辑 class_name 的项目，用它就是自残。要么：
- 改用 `export_filter="all_resources"`（简单粗暴，体积可能大一些）
- 维护 ext_resource 锚点（需要纪律：每新增一个 class_name 都要同步加锚点）

### 4. DirAccess 在 HTML5 下不可信

不要假设 `DirAccess.list_dir_begin()` 在 HTML5 Web 导出中能正常工作。它可能：
- 只能穿透部分目录层级
- 只返回特定文件类型
- 在不同浏览器表现不一致

**策略**：永远有一个降级路径（如预构建 JSON 索引），并且用**无条件比较**决定走哪条路。

### 5. 导出前必须关闭 Godot 编辑器

编辑器在内存中缓存 `.tscn` 和 `export_presets.cfg`，关闭时会用内存中的旧版本覆盖文件。外部对 `.tscn` 或 `.cfg` 的任何修改，只要编辑器还开着就会被回滚。

---

## 注意事项

1. 新增 `class_name` 脚本时，必须同步添加到锚点场景的 ext_resource 中
2. 新增数据文件后，运行 `tools/build_data_index.py` 重建 `data/_file_index.json`
3. 修改 `export_presets.cfg` 或 `.tscn` 前必须关闭 Godot 编辑器
4. 新增 CSV 文件时，确保 `.csv.import` 的 importer 为 `"keep"` 而非 `"csv_translation"`
5. 纯 preload 引用的非 class_name 文件（如 `custom_tooltip.gd`、`flame_shader_material.tres`）也需加入锚点
6. 导出模式使用 `export_filter="scenes"` + `include_filter` 组合；如果后续数据量暴涨，考虑直接切 `export_filter="all_resources"` 避免锚点维护负担
