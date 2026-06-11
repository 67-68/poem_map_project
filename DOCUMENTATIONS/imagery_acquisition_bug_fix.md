# 意象获取管线：旧 Bug 复盘与正确操作方式

> **最后更新：** 2026-06-11
> **涉及文件：**
> - [`core/player_state.gd`](../core/player_state.gd)（信号处理逻辑）
> - [`core/operators/imagery_acquisition_operator.gd`](../core/operators/imagery_acquisition_operator.gd)
> - [`core/eventbus.gd`](../core/eventbus.gd)（信号定义）
> - [`core/database.gd`](../core/database.gd)（意象注册表加载）
> - [`data/tres_imaginaries_registry.tres`](../data/tres_imaginaries_registry.tres)（意象文件注册表）
> - [`data/tres_imaginaries/`](../data/tres_imaginaries/)（意象资源目录）

---

## 一、旧 Bug 复盘

### Bug 1：信号链路断裂（Signal Deadlock）

**表现：** 运行时没有任何报错，但意象获取后 UI 从未刷新，意象条目从未增加。

**根源：** 两个信号的连接/发射两端均未实现——

| 信号 | 问题 |
|------|------|
| [`EventBus.request_add_imaginary`](../core/eventbus.gd:75) | 只有 `emit()` 方（`ImageryAcquisitionOperator`），**没有 `connect()` 消费者** |
| [`EventBus.imaginary_changed`](../core/eventbus.gd:74) | 只有 `connect()` 方（UI 组件），**没有 `emit()` 触发者** |

**修复：** 在 [`PlayerState._ready()`](../core/player_state.gd:71) 中添加了 `_connect_imaginary_signals()`，注册 `request_add_imaginary` 的消费者；在 [`_on_request_add_imaginary()`](../core/player_state.gd:89) 末尾添加 `EventBus.imaginary_changed.emit()` 通知 UI 刷新。

### Bug 2：Tag 格式不匹配（`_` vs `:`）

**表现：** `imagery_acquisition_operator.gd` 广播 `request_add_imaginary` 后，`PlayerState` 报错：

```
[ERROR] PlayerState._on_request_add_imaginary:
  Database.imaginaries 中未找到 tag 'TARGET_MYTH_GIANTROC_DAYAN'
```

**根源：** 两套系统使用了不同格式的标识符——

| 系统 | 格式 | 示例 |
|------|------|------|
| CSV 事件标签（场景配置） | 4 段式，下划线分隔 | `TARGET_MYTH_GIANTROC_DAYAN` |
| `Database.imaginaries` 键 | 2 段式，冒号分隔 | `myth:giantroc` |

**修复：** [`_on_request_add_imaginary()`](../core/player_state.gd:89) 不再直接把完整 tag 作为 key 查询，而是 **解析中间两段**：

```gdscript
var segments = tag.split("_")           # ["TARGET", "MYTH", "GIANTROC", "DAYAN"]
var imaginary_key = segments[1] + ":" + segments[2]  # "MYTH:GIANTROC"
var imaginary = Database.imaginaries.get(imaginary_key) as ImaginaryTag
```

同时，完整的 4 段 tag（如 `TARGET_MYTH_GIANTROC_DAYAN`）作为 `blueprint_id` 存入 `basic_imaginaries` 数组，保留场景来源追溯能力。

### Bug 3：重复条目被静默跳过

**表现：** 相同 `blueprint_id` 的意象只被存入一次，无法触发重复获取。

**修复（用户决策）：** 移除去重检查，每次 `request_add_imaginary` 都向 `basic_imaginaries` 追加新条目。

---

## 二、完整数据流

```
[DSL 解析器] → [场景配置 JSON] → [imagery_acquisition 插件]
    ↓
imagery_add(name=TARGET_MYTH_GIANTROC_DAYAN)
    ↓
[ImageryAcquisitionOperator.operate()]
    ↓  Logging: "[INFO] imagery_name='TARGET_MYTH_GIANTROC_DAYAN'"
EventBus.request_add_imaginary.emit("TARGET_MYTH_GIANTROC_DAYAN")
    ↓
[PlayerState._on_request_add_imaginary("TARGET_MYTH_GIANTROC_DAYAN")]
    │  1. tag.split("_") → ["TARGET","MYTH","GIANTROC","DAYAN"]
    │  2. imaginary_key = "MYTH:GIANTROC"  (segments[1] + ":" + segments[2])
    │  3. Database.imaginaries.get("MYTH:GIANTROC") → ImaginaryTag
    │  4. imaginary.basic_imaginaries.append({"blueprint_id": tag, "contexts": []})
    │  5. Logging: "[INFO] blueprint 'TARGET_MYTH_GIANTROC_DAYAN' 已存入意象 'myth:giantroc'"
    ↓
EventBus.imaginary_changed.emit()
    ↓
[UI 组件刷新] (poem_crafter.gd / imaginary_label.gd)
```

---

## 三、Tag → ImaginaryKey 映射规则

### 3.1 中间两段匹配

所有触发意象获取的 tag 遵循 **4 段式下划线格式**：

```
PREFIX_CATEGORY_TYPE_SCENE
   ↑       ↑       ↑
  段1     段2     段3    段4
```

运行时提取 **段2** 和 **段3**，用 `:` 拼接，作为 `Database.imaginaries` 的查询键：

| 完整 Tag | 段1 | 段2 | 段3 | 段4 | Imaginary Key |
|----------|-----|-----|-----|-----|---------------|
| `TARGET_MYTH_GIANTROC_DAYAN` | TARGET | MYTH | GIANTROC | DAYAN | `myth:giantroc` |
| `TARGET_PLACE_JADESTEP_DAILOU` | TARGET | PLACE | JADESTEP | DAILOU | `place:jadestep` |
| `ENV_POLITICS_CLOUD_ZHONGNAN` | ENV | POLITICS | CLOUD | ZHONGNAN | `politics:cloud` |
| `TARGET_OBJECT_MEDICINE_DONGSHI` | TARGET | OBJECT | MEDICINE | DONGSHI | `object:medicine` |
| `TARGET_OBJECT_INK_WENYING` | TARGET | OBJECT | INK | WENYING | `object:ink` |
| `ENV_SOCIETY_FAMINE` | ENV | SOCIETY | FAMINE | — | `society:famine` |

> **注意：** `ENV_SOCIETY_FAMINE` 只有 3 段（无场景标识段），但仍满足 `segments.size() >= 3` 的条件。

### 3.2 文件名命名规则

`.tres` 文件使用双下划线 `__` 代替冒号 `:`：

| Imaginary Key | .tres 文件名 |
|---------------|-------------|
| `myth:giantroc` | `myth__giantroc.tres` |
| `politics:cloud` | `politics__cloud.tres` |
| `place:jadestep` | `place__jadestep.tres` |
| `object:medicine` | `object__medicine.tres` |
| `object:ink` | `object__ink.tres` |
| `society:famine` | `society__famine.tres` |

### 3.3 注册表

所有 `.tres` 文件必须在 [`data/tres_imaginaries_registry.tres`](../data/tres_imaginaries_registry.tres) 中注册，格式为：

```gdscript
"key:value": "res://data/tres_imaginaries/key__value.tres"
```

---

## 四、所有场景意象一览

以下是根据 [`tools/event_base_config_scene_imagery.json`](../tools/event_base_config_scene_imagery.json) 提取的完整 tag 与意象映射表（共 16 个场景，涉及 6 个 ImaginaryTag）：

| 场景 | stored_to | Tag | Imaginary Key |
|------|-----------|-----|---------------|
| 待漏院听更 | fengzhao | `TARGET_PLACE_JADESTEP_DAILOU` | `place:jadestep` |
| 待漏院听更 | fengzhao | `ENV_POLITICS_CLOUD_DAILOU` | `politics:cloud` |
| 集贤院修书 | fengzhao | `TARGET_PLACE_JADESTEP_JIXIAN` | `place:jadestep` |
| 集贤院修书 | fengzhao | `ENV_POLITICS_CLOUD_JIXIAN` | `politics:cloud` |
| 华清池扈从 | fengzhao | `TARGET_PLACE_JADESTEP_HUAQING` | `place:jadestep` |
| 华清池扈从 | fengzhao | `ENV_POLITICS_CLOUD_HUAQING` | `politics:cloud` |
| 终南山绝顶 | denggao | `TARGET_MYTH_GIANTROC_ZHONGNAN` | `myth:giantroc` |
| 终南山绝顶 | denggao | `ENV_POLITICS_CLOUD_ZHONGNAN` | `politics:cloud` |
| 乐游原残阳 | denggao | `TARGET_MYTH_GIANTROC_LEYOU` | `myth:giantroc` |
| 乐游原残阳 | denggao | `ENV_POLITICS_CLOUD_LEYOU` | `politics:cloud` |
| 慈恩寺大雁塔 | denggao | `TARGET_MYTH_GIANTROC_DAYAN` | `myth:giantroc` |
| 慈恩寺大雁塔 | denggao | `ENV_POLITICS_CLOUD_DAYAN` | `politics:cloud` |
| 破败客舍寒夜 | duzhuo | `TARGET_MYTH_GIANTROC_KESHE` | `myth:giantroc` |
| 繁华酒肆暗角 | duzhuo | `TARGET_MYTH_GIANTROC_JIUSI` | `myth:giantroc` |
| 灞桥风雪酒亭 | duzhuo | `TARGET_MYTH_GIANTROC_BAQIAO` | `myth:giantroc` |
| 曲江池流觞亭 | jiaoyou | `TARGET_MYTH_GIANTROC_QUJIANG` | `myth:giantroc` |
| 曲江池流觞亭 | jiaoyou | `ENV_POLITICS_CLOUD_QUJIANG` | `politics:cloud` |
| 权贵宅邸外院 | jiaoyou | `TARGET_MYTH_GIANTROC_ZHAIDI` | `myth:giantroc` |
| 权贵宅邸外院 | jiaoyou | `ENV_POLITICS_CLOUD_ZHAIDI` | `politics:cloud` |
| 胡姬酒肆狂欢 | jiaoyou | `TARGET_MYTH_GIANTROC_HUJI` | `myth:giantroc` |
| 胡姬酒肆狂欢 | jiaoyou | `ENV_POLITICS_CLOUD_HUJI` | `politics:cloud` |
| 东市卖药 | fangshi | `TARGET_OBJECT_MEDICINE_DONGSHI` | `object:medicine` |
| 东市卖药 | fangshi | `ENV_SOCIETY_FAMINE` | `society:famine` |
| 文英阁鬻文 | fangshi | `TARGET_OBJECT_INK_WENYING` | `object:ink` |
| 文英阁鬻文 | fangshi | `ENV_SOCIETY_FAMINE` | `society:famine` |
| 南苑种药 | fangshi | `TARGET_OBJECT_MEDICINE_NANYUAN` | `object:medicine` |
| 南苑种药 | fangshi | `ENV_SOCIETY_FAMINE` | `society:famine` |
| 朱门干谒 | fangshi | `TARGET_PLACE_JADESTEP_FUMEN` | `place:jadestep` |
| 朱门干谒 | fangshi | `ENV_SOCIETY_FAMINE` | `society:famine` |

---

## 五、如何添加新的意象 Tag

### 5.1 场景配置层

在 [`tools/event_base_config_scene_imagery.json`](../tools/event_base_config_scene_imagery.json) 中，向场景的 `tags` 数组添加新的 4 段式 tag，并在 `linked_value_ids` 中引用对应的意象概念 ID。

### 5.2 意象数据库层

如果 tag 对应的 ImaginaryKey 尚未在 `Database.imaginaries` 中注册：

1. 在 [`data/tres_imaginaries/`](../data/tres_imaginaries/) 创建 `.tres` 文件，格式为：

```gdscript
[gd_resource type="Resource" script_class="ImaginaryTag" load_steps=2 format=3]

[ext_resource type="Script" uid="uid://dk86isxs4lamx" path="res://core/model/imaginary.gd" id="1_6fl8j"]

[resource]
script = ExtResource("1_6fl8j")
uuid = "domain:type"       # ← ImaginaryKey
name = "中文名称"
metadata/_custom_type_script = "uid://dk86isxs4lamx"
```

2. 在 [`data/tres_imaginaries_registry.tres`](../data/tres_imaginaries_registry.tres) 添加注册条目：

```gdscript
"domain:type": "res://data/tres_imaginaries/domain__type.tres"
```

3. **文件名规则：** `domain__type.tres`（双下划线代替冒号）

### 5.3 代码层

**不需要修改代码。** [`_on_request_add_imaginary()`](../core/player_state.gd:89) 使用通用匹配逻辑，只要 `Database.imaginaries` 中存在对应的 key，任何 tag 都会被正确处理。

---

## 六、调试指南

### 日志关键字

| 日志级别 | 关键字 | 含义 |
|---------|--------|------|
| `INFO` | `PlayerState: connected request_add_imaginary signal` | 信号连接成功 |
| `INFO` | `blueprint 'xxx' 已存入意象 'yyy'` | 意象条目已存入 |
| `WARN` | `在 Database.imaginaries 中不存在` | tag 没有对应注册的 ImaginaryTag |
| `ERROR` | `段数不足` | tag 格式异常，少于 3 段 |
| `ERROR` | `未找到对应的 ImaginaryTag` | 中间两段拼接后的 key 不在注册表中 |

### 常见失败场景

1. **`Database.imaginaries` 中没有对应 ImaginaryTag** → 检查 `.tres` 文件是否存在且在注册表中
2. **UI 不刷新** → 检查 `EventBus.imaginary_changed` 是否被正确 `emit()`
3. **Tag 段数不足 3** → 检查 tag 格式，必须为 `PREFIX_CATEGORY_TYPE[_SCENE]`
4. **意象重复但没增加** → 确认去重逻辑已被移除（当前版本总是追加）
