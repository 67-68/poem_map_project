# 入幕系统（Rumu System）— 功能意图

**状态**: 🏗️ 框架已建立，待填充具体数据

---

## 意图摘要（<200字）

为 baiye_touzeng（拜谒·入幕）行动提供 per-xun 事件选择机制。三种入幕模式（清流/浊流/富商）各有独立的 `ArchetypeEventPicker` 子类，每旬均分概率选择 archetype，注入其 operators 到 fallback 事件。Picker 不负责事件推送 — 由 ActionManager 通过 `DeferConfig.event_picked_per_xun` (UUID) → `Database.get_event_picker()` 查实例，调用 `pick(ctx)` 注入 archetype context，再 `push_event` 携带 context 推入事件栈。

---

## 核心玩法

- **三种入幕模式**：`RumuQingliuPicker`（清流引荐）、`RumuZhuoliuPicker`（浊流权贵）、`RumuFushangPicker`（富商铺路）
- **每旬触发**：defer 期间每旬（最后一旬除外）通过 Picker 选取并推送一个叙事事件
- **Archetype 注入**：Picker 向 ctx 注入 `archetype_base` + `outcome`，`RandomEvent.init()` 自动从 `Database.get_archetype_by_uuid()` 加载 operators 并注入每个 option 的 `choice_result`

---

## 数据流

```
resource_converters.csv
  │  context 列: event_picked_per_xun=rumu_qingliu_picker
  ↓
DSLParser._parse_resource_converter()
  │  dc.event_picked_per_xun = "rumu_qingliu_picker"  (字符串 UUID)
  ↓
ActionManager.activate_defer()
  │  _deferring_actions[action_id]["event_picked_per_xun"] = "rumu_qingliu_picker"
  ↓
ActionManager._tick_deferring_actions()  [每旬]
  │  1. Database.get_event_picker("rumu_qingliu_picker") → RumuQingliuPicker 实例
  │  2. picker.pick(pick_ctx)
  │     ├─ 均分概率选 archetype
  │     ├─ 查 _fallback_map → fallback_uuid
  │     ├─ pick_ctx["archetype_base"] = archetype_key
  │     └─ pick_ctx["outcome"] = "success"
  │  3. Database.resolve(fallback_uuid) → event_data
  │  4. EventBus.push_event.emit(event_data, pick_ctx)  ← context 携带注入信息
  ↓
NarrativeDirector._push_event_inner(data, context)
  │  context 存入栈条目
  ↓
RandomEvent.init(context)
  │  读取 context["archetype_base"] + context["outcome"]
  │  → Database.get_archetype_by_uuid(arch, "success")
  │  → duplicate operators → 注入 choice_result ✅
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `model/base_event_picker.gd` | **修改** | 新增 `uuid` 导出字段 |
| `model/archetype_event_picker.gd` | **新建** | `ArchetypeEventPicker extends BaseEventPicker` — 均分选 archetype → 查 fallback → 注入 ctx |
| `model/rumu_qingliu_picker.gd` | **新建** | `RumuQingliuPicker extends ArchetypeEventPicker` |
| `model/rumu_zhuoliu_picker.gd` | **新建** | `RumuZhuoliuPicker extends ArchetypeEventPicker` |
| `model/rumu_fushang_picker.gd` | **新建** | `RumuFushangPicker extends ArchetypeEventPicker` |
| `data/1_core_rules/event_pickers/rumu_qingliu_picker.tres` | **新建** | .tres 文件供 DataScanner 扫描 |
| `data/1_core_rules/event_pickers/rumu_zhuoliu_picker.tres` | **新建** | 同上 |
| `data/1_core_rules/event_pickers/rumu_fushang_picker.tres` | **新建** | 同上 |
| `model/defer_config.gd` | **修改** | `event_picked_per_xun`: `BaseEventPicker` → `String`（存 UUID） |
| `parser/dsl_parser.gd` | **修改** | 不再创建临时 `BaseEventPicker`，直接赋值字符串 UUID |
| `core/database.gd` | **修改** | 新增 `event_pickers` 字典 + `get_event_picker()` getter + 类型分类分支 |
| `core/action_manager.gd` | **修改** | per-xun tick 改为 `Database.get_event_picker()` 查实例 + `push_event.emit(event_data, pick_ctx)` |
| `core/_export_dependency_anchor.gd` | **修改** | 预加载 5 个新 picker 脚本 |

---

## 状态转换

```
[baiye_touzeng action 执行]
    │
    ├─ defer 激活 → _deferring_actions[action_id]["event_picked_per_xun"] = "rumu_*_picker"
    │
    └─ 每旬 tick:
        │
        ├─ 最后一旬 → 跳过 per-xun 事件
        │
        └─ 非最后一旬:
            │
            ├─ Database.get_event_picker(uuid) → null
            │   └─ warn: picker 未找到
            │
            ├─ picker.pick(ctx) → 空字符串
            │   └─ info: picker 返回空
            │
            └─ picker.pick(ctx) → fallback_uuid
                ├─ Database.resolve(fallback_uuid) → null
                │   └─ warn: 事件未找到
                │
                └─ 有效 event_data
                    └─ push_event.emit(event_data, ctx_with_archetype)
                        └─ RandomEvent.init() 注入 operators
```

---

## 待填充

三个 Picker 子类的 `_archetypes` 和 `_fallback_map` 目前为空。需要：
1. 在 `resource_converters.csv` 中为 baiye_touzeng 行添加 `event_picked_per_xun=rumu_qingliu_picker`（或 zhuoliu/fushang）
2. 为每种入幕模式创建对应的 ActionArchetype（用于注入 operators）
3. 为每种入幕模式创建对应的 fallback 叙事事件
4. 填充 `_archetypes` 和 `_fallback_map` 的具体映射
