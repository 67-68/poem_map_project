# StateTransistor — 状态转移器文档

## 概述

`StateTransistor` 是一种声明式的**状态转移描述单元**。它描述了一个原子操作：**"在条件满足时，把某个资源从状态 A 转移到状态 B"**。

它不关心"为什么要转移"，只关注"怎么转移"。这是一种数据驱动的状态变更模式——转移逻辑写死在 `.tres` 资源里，而不是散落在各个脚本的 if/else 中。

**核心文件:** [`core/model/state_transistor.gd`](../core/model/state_transistor.gd)

---

## 设计动机

在事件驱动的游戏系统中，经常出现这样的逻辑：

> "如果玩家已经见过李白 (= flag 已设置)，就把当前事件切换到另一个分支"

传统做法是在脚本里写：

```gdscript
if PlayerState.has_flag('met_libai'):
    trigger_event('event_li_bai_farewell')
```

这本身没问题，当这种逻辑散落在 50 个地方、且需要策划通过配置调整时，就变成了一场噩梦。`StateTransistor` 的作用就是把这种"条件→转移→后效"的逻辑**封装成一个可配置的资源对象**，可以在 `.tres` 文件或 DSL 中声明式地定义。

---

## 属性说明

| 属性 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `uuid` | `String` | 否 | 唯一标识符，用于资源查找和引用 |
| `target_resource_urn` | `String` | 否 | 目标资源的 URN，表示"要转移到哪个资源"。**为空时跳过状态转移（Phase 2/3），仅执行 operators 和 triggered_event。** 适用于纯事件触发场景（如距离阈值触发），配合 operators 中的 `flag_int_set` 可实现一次性触发。 |
| `transist_value` | `String` | 否 | 转移的值，格式见下方约定 |
| `current_resource_urn` | `String` | 否 | 当前资源的 URN（仅用于上下文日志，目前不参与逻辑） |
| `triggered_event_key` | `String` | 否 | 转移完成后触发的事件 key |
| `requirements` | `BaseRequirements` | 否 | 转移的前置条件，不满足则跳过 |
| `operators` | `Array[BaseOperator]` | 否 | 转移完成后执行的附加操作列表 |

### `transist_value` 格式约定

对 `flag` 类型的资源，`transist_value` 使用前缀来区分操作类型：

| 格式 | 操作 | 示例 | 效果 |
|------|------|------|------|
| `=value` | **SET** — 直接设置值 | `=true` | `PlayerState.set_flag('key', 'true')` → bool 类型自动识别 |
| `=value` | **SET** — 字符串/数字赋值 | `=长安` | `PlayerState.set_flag('key', '长安')` |
| `^value` | **APPEND** — 追加值（int 累加，str 拼接） | `^3` | `PlayerState.append_flag('key', 3)` |
| `^value` | **APPEND** | `^abc` | `PlayerState.append_flag('key', 'abc')` |
| (空) | **CLEAR** — 隐式清空 | `""` | 调用 `set_flag(key, "")`，零值会被 `PlayerState` 自动 erase |

> **注意:** 非 `=` 前缀统一走 APPEND 路径。按照约定使用 `^` 作为 append 前缀，技术上任何非 `=` 字符都可以，但请保持一致。

---

## 执行管线

调用 [`transition()`](../core/model/state_transistor.gd:12) 后的完整流程：

```
Phase 1: 需求检查
  ├─ requirements 为 null? → 日志警告，继续执行
  ├─ requirements.compare() 返回 false? → 日志 debug，跳过
  └─ 通过 → 进入 Phase 2

Phase 2: URN 解析
  ├─ 解析 target_resource_urn → { type, resource_id }
  ├─ 资源 ID 为空? → 日志 error，返回
  └─ 解析 current_resource_urn（可选，仅日志）

Phase 3: 状态转移
  ├─ type == 'flag' → _apply_flag_transition()
  │   ├─ transist_value 为空 → set_flag(key, "") 清空
  │   ├─ 以 '=' 开头 → SET 操作
  │   └─ 其他 → APPEND 操作
  └─ 其他 type → URN.get_resource_through_urn() 通用兜底

Phase 4: 后效 Operators
  ├─ operators 为空 → 跳过
  └─ 遍历执行每个 op.operate()

Phase 5: 链式事件
  ├─ triggered_event_key 为空 → 跳过
  └─ 发射 EventBus.request_event_key(key, {})
```

---

## 使用场景

### 场景 1：Flag 开关转移

最简单的用法：条件满足时，打开一个 flag。

**配置示例 (.tres):**
```
target_resource_urn = "urn:flag:met_du_fu"
transist_value = "=true"
requirements = <FlagRequirement: 玩家在长安>
triggered_event_key = "event_du_fu_intro"
```

### 场景 2：Flag 累加（计数器）

```gdscript
# 每触发一次，flag 'wine_count' +1
target_resource_urn = "urn:flag:wine_count"
transist_value = "^1"
```

### 场景 3：多步骤状态机

通过 `triggered_event_key` 串联多个 `StateTransistor`，形成状态机：

```
Transistor A (检查是否见过李白)
  └─ 条件满足 → 设置 flag 'met_libai' = true
      └─ 触发事件 'event_li_bai_farewell'
          └─ 事件选项中包含 Transistor B
              └─ 设置 flag 'parted_libai' = true
                  └─ 触发事件 'event_chang_an_departure'
```

### 场景 4：带后效的转移

```gdscript
# 转移后同时执行附加操作（比如加属性、加 trait）
target_resource_urn = "urn:flag:finished_quest_01"
transist_value = "=true"
operators = [
    PropertyOperator({ property: "money", value: 50 }),
    TraitOperator({ trait: "reputation_rising" })
]
```

---

## 与相关组件的关系

```
EventOption
  └── choice_result: ChoiceResult
        ├── operators: Array[BaseOperator]   ← 选择后直接执行
        └── (未来) 可能包含 StateTransistor 引用

StateTransistor（独立资源，通过 URN 或直接引用使用）
  ├── requirements: BaseRequirements         ← 转移前提
  ├── operators: Array[BaseOperator]         ← 转移后执行
  └── triggered_event_key                    ← 转移后触发事件
```

区别：
- [`ChoiceResult`](../model/choice_result.gd) 是**事件选项的结果**，无前置条件检查，直接执行
- `StateTransistor` 是**带条件守卫的状态转移**，条件不满足就跳过

---

## 最佳实践

1. **职责单一**：一个 `StateTransistor` 只做一件事。不要在一个 transistor 里既改 flag 又改 trait，把 trait 操作放到 `operators` 数组里。

2. **URN 先行**：所有资源引用优先使用 URN 字符串而非直接传 ID，保持与项目 URN 体系一致。参见 [`URN 系统文档`](urn_system.md)。

3. **事件链不要太长**：`triggered_event_key` 链式触发不要超过 3 层，否则调试时会变成追踪老鼠迷宫 💀。

4. **requirements 不能省**：即使"永远为真"，也建议显式设置一个空 `BaseRequirements`，而不是留 null。null 虽然能工作但会打 warn 日志。

5. **transist_value 不要裸写数字**：`^5` 比 `5` 更明确表示"追加"语义。`=5` 比 `5` 更明确表示"设置"语义。显式前缀是契约的一部分。

---

## CSV / DSL 格式

`StateTransistor` 支持通过 CSV 表格声明式定义，由 [`DSLParser.parse_state_transistor()`](../parser/dsl_parser.gd:697) 解析。

### 表头约定

CSV 表头映射到 [`StateTransistor`](../core/model/state_transistor.gd) 的属性：

| CSV 列名 | 映射属性 | 处理方式 |
|----------|----------|----------|
| `uuid` | `uuid` | 直接赋值 |
| `target_resource` | `target_resource_urn` | 直接赋值（解析器追加 `_urn`） |
| `transist_value` | `transist_value` | 直接赋值 |
| `current_resource` | `current_resource_urn` | 直接赋值（解析器追加 `_urn`） |
| `triggered_event` | `triggered_event_key` | 直接赋值（解析器追加 `_key`） |
| `requirement` | `requirements` | **DSL 解析** → `BaseRequirements` |
| `operators` | `operators` | **DSL 解析** → `Array[BaseOperator]` |

> **注意：** CSV 列名是 `requirement`（单数），但 [`StateTransistor` 属性](../core/model/state_transistor.gd:8) 是 `requirements`（复数）。解析器自动做了映射，不用纠结。

### `requirement` 列的 DSL 语法

复用 [`DSLParser.parse_requirements()`](../parser/dsl_parser.gd:346) 逻辑，与 [`RandomEvent` 的 requirements 列](../parser/dsl_parser.gd:193) 完全一致。

**格式：** 多个条件用 `|` 竖线分隔，逻辑关系为 **AND**（全部满足才通过）。

| 前缀 | 格式 | 示例 | 含义 |
|------|------|------|------|
| `prop:` | `prop:<属性>:<比较符><值>` | `prop:location:=长安` | 玩家位置在长安 |
| `prop:` | | `prop:money:>50` | 金钱大于 50 |
| `trait:` | `trait:<子命令>:<trait_id>` | `trait:has:reputation_rising` | 拥有 rising reputation trait |
| `flag:` | `flag:<类型>:<操作>:<flag_id>` | `flag:bool:is:met_libai` | flag 'met_libai' 为 true |

**示例：**
```
prop:location:=长安,flag:bool:is:met_libai
```
→ 当玩家**在长安** 且 **已经见过李白** 时，转移条件满足。

### `operators` 列的 DSL 语法

复用 [`MicroDSLParser.parse_consequence_operators()`](../parser/micro_dsl_parser.gd:131) 逻辑，与 [`ChoiceResult` 的 operators](../parser/dsl_parser.gd:440) 和 [`Trait.trait_effect_operations`](../parser/dsl_parser.gd:666) 完全一致。

**格式：** 多个操作符用 `|` 竖线分隔，逐个执行。

| 前缀 | 格式 | 示例 | 含义 |
|------|------|------|------|
| `prop:` | `prop:<属性>:±<数值>` | `prop:money:+50` | 金钱 +50 |
| `prop:` | | `prop:reputation:-10` | 声望 -10 |
| `trait:` | `trait:add:<trait_id>` | `trait:add:reputation_rising` | 添加 rising reputation trait |
| `trait:` | `trait:remove:<trait_id>` | `trait:remove:corrupt` | 移除 corrupt trait |

### 完整示例

**CSV 行（在 Google Sheets 中）：**

| uuid | target_resource | transist_value | current_resource | triggered_event | requirement | operators |
|------|----------------|---------------|-----------------|----------------|-------------|-----------|
| | `urn:flag:met_du_fu` | `=true` | | `event_du_fu_intro` | `prop:location:=长安` | `prop:money:+50` |
| | `urn:flag:wine_count` | `^1` | `urn:flag:current_tavern` | | | |
| `transistor_quest_reward` | `urn:flag:finished_quest_01` | `=true` | | `event_quest_reward` | `prop:quest_progress:>=100,flag:bool:is:accepted_quest_01` | `prop:money:+200,trait:add:reputation_rising` |

**解析结果等价于:**

```gdscript
# 行 1
var t1 = StateTransistor.new()
t1.target_resource_urn = "urn:flag:met_du_fu"
t1.transist_value = "=true"
t1.triggered_event_key = "event_du_fu_intro"
t1.requirements = DSLParser.parse_requirements("prop:location:=长安")
t1.operators = MicroDSLParser.parse_consequence_operators("prop:money:+50")

# 行 2
var t2 = StateTransistor.new()
t2.target_resource_urn = "urn:flag:wine_count"
t2.transist_value = "^1"
t2.current_resource_urn = "urn:flag:current_tavern"
# (没有 requirement 和 operators)

# 行 3 — 带 uuid，会作为 .tres 文件名
var t3 = StateTransistor.new()
t3.uuid = "transistor_quest_reward"
t3.target_resource_urn = "urn:flag:finished_quest_01"
t3.transist_value = "=true"
t3.triggered_event_key = "event_quest_reward"
t3.requirements = DSLParser.parse_requirements("prop:quest_progress:>=100|flag:bool:is:accepted_quest_01")
t3.operators = MicroDSLParser.parse_consequence_operators("prop:money:+200,trait:add:reputation_rising")
```

### 在同步管线中使用

在 [`csv_cloud_loader.gd`](../core/csv_cloud_loader.gd) 的 [`DATA_MANIFEST`](../core/csv_cloud_loader.gd:21) 中添加一条记录，`data_type` 设为 `"state_transistor"`：

```gdscript
{
    "name": "状态转移器数据",
    "url": "https://docs.google.com/spreadsheets/d/e/.../pub?gid=XXX&single=true&output=csv",
    "save_path": "res://data/state_transistors/state_transistors.csv",
    "data_type": "state_transistor"
}
```

> **⚠️ 解析顺序注意：** 如果 `state_transistor` 的 `requirement` 引用了 `flag` 或 `trait`，确保 `flag` 和 `trait` 数据表排在 `state_transistor` 之前。
