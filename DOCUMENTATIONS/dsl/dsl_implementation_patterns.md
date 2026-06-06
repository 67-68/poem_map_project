# DSL 实现模式 — 常见业务场景的 DSL 实现方案与经验原则

## 概述

本文档记录从实际代码走查中总结的 DSL 实现模式，包含常见业务场景的实现方案、约束条件和注意事项。

---

## 1. 前置概率检查模式（Pre-event Probability Check）

### 场景

在某个事件触发**之前**，检查一个条件，如果满足则按概率触发另一个事件。

### 实现方案

使用 `interrupt_event` + `random` 操作符组合：

```csv
interrupt_event(<requirement>|random(val=<概率0-100>; success=push_event(event_key=<目标事件>)))
```

**示例**：在 `mid_of_wenhuaquan_party` 之前检查李白关系 > 20，5% 概率触发 `request_libai_changhe`

```csv
random_event,,,,mid_of_wenhuaquan_party,,,title,description,,,,interrupt_event(flag_int_gt(name=flag_relation_with_libai;val=20)|random(val=5;success=push_event(event_key=request_libai_changhe)))
```

### 约束条件

#### 1. `interrupt_event` 只接受 2 个参数

`interrupt_event(requirement_syntax|operator_syntax)` 的值通过 [`split_expressions`](parser/named_dsl_parser.gd) 按**顶级 `|`** 分割，只能拆出 2 段：

```gdscript
# parser/dsl_parser.gd:289
var args = NamedDSLParser.split_expressions(args_str)
if args.size() < 2:
    Logging.err("需要 2 个参数（requirement, operator）")
```

这意味着 `requirement_syntax` 只能是一个**单一的条件表达式**，不能放入 `条件A|条件B` 这样的复合条件（因为额外的 `|` 会被当成 `operator_syntax` 解析，造成逻辑错误）。

**如果需要多条件守卫**，使用 ` and ` 语法（带空格）在 `requirement_syntax` 中组合多个条件：

```
interrupt_event(cond1 and cond2|operator_syntax)
```

示例：
```csv
interrupt_event(flag_int_gt(name=flag_relation_with_libai;val=20) and flag_int_lt(name=flag_libai_changhe_request;val=1)|random(val=99; success=push_event(event_key=request_libai_changhe)))
```

解析器会将 ` and ` 前后的表达式分别解析为独立的 `BaseRequirements`，然后合并为 `ComplexRequirements`（AND 逻辑）。详见 [`parser/dsl_parser.gd`](parser/dsl_parser.gd):383。

#### 2. `interrupt_event` 不阻断原事件

```gdscript
# model/event.gd:37
# 该方法不阻断事件本身触发。
```

`check_interruption` 在事件 `init` 之前执行。如果其 operator 是 `push_event`，目标事件会被推入栈。但有一个重要的短路逻辑：

```gdscript
# characters/narrative_overlay.gd:169-172
# 中断序列 push 了事件到栈 → 让栈事件替代当前事件
if _is_active:
    Logging.info("apply_narrative: 被中断序列替换，放弃当前事件 " + data.name)
    return
```

如果 interrupt 中的 `push_event` 导致 `_process_stack` → `apply_narrative` 被同步调用，_is_active 被设为 true，则**原事件被放弃，新事件替代它**。

#### 3. `random` 操作符

DSL 语法：`random(val=<概率>; success=<操作符>; fail=<操作符（可选）>; success_hint=<提示>; failed_hint=<提示>)`

- `val`：0-100 的整数，表示成功概率
- `success`：成功时执行的操作符表达式（字符串）
- `fail`：失败时执行的操作符表达式（可选）
- 随机值范围 0-99，`rand < val` 时视为成功

实现见 [`core/operators/random_operator.gd`](core/operators/random_operator.gd)，DSL 解析见 [`parser/micro_dsl_parser.gd:487`](parser/micro_dsl_parser.gd:487)。

---

## 2. 事件栈返回模式（Push & Return）

### 场景

事件 A 被 push 到事件栈触发后，用户操作完毕后需要"返回"到事件 A 之前的上下文。

### 实现方案

使用 `pop_event()` + `push_event()` 组合：

```csv
>option,,,,,,返回,"pop_event(), push_event(event_key=<目标事件>)"
```

**执行顺序**：
1. `pop_event()` — 从栈中弹出**当前事件**（移除栈顶的自身条目）
2. `push_event(event_key=<目标事件>)` — 将目标事件推入栈顶
3. 当前事件结束时，`_process_next` 从栈顶取出目标事件播放

### 为什么需要 `pop_event()`

`_event_stack` 使用 `push_front` 添加事件，`_process_stack`/`_process_next` 使用 `peek`（只看不移除）：

```gdscript
# characters/narrative_overlay.gd:120-127
var entry = _event_stack[0]  # peek，不移除
```

事件必须通过 `pop_event()` 显式弹出，否则会一直留在栈顶，导致 `_process_next` 无限重复播放它。

### 注意：避免循环触发

如果 `push_event` 的目标事件包含 `interrupt_event` 且条件相同，可能导致循环。解决方案：
- 在目标事件的 `requirements` 中添加防重复标志检查
- 或在返回路径中设置一个标志位防止重复触发

---

## 3. 标志位注册模式

### 数据层

所有标志位在 [`data/flags/flags.csv`](data/flags/flags.csv) 中注册：

```csv
flag_id,type,default_value
flag_relation_with_libai,int,0
flag_libai_changhe_shown,bool,FALSE
```

支持的类型：`bool`、`int`、`str`

如果是 `int` 类型，还可以创建对应的 `.tres` 文件（如 [`flag_relation_with_libai.tres`](data/flags/flag_relation_with_libai.tres)），但这不是必需的 — `csv_cloud_loader` 会在加载 CSV 时自动创建缺失的 flag 资源。

### DSL 层使用

| 操作 | DSL 语法 |
|------|---------|
| 检查 int 大于 | `flag_int_gt(name=flag_relation_with_libai; val=20)` |
| 检查 bool 为真 | `flag_bool_has(name=flag_libai_changhe_shown)` |
| 设置 bool | `flag_bool_set(name=flag_libai_changhe_shown; val=true)` |
| 追加 int | `flag_int_append(name=flag_relation_with_libai; val=5)` |

---

## 4. CSV 列扩展模式

### 添加新列

当前 [`random_events.csv`](data/random_events/random_events.csv) 的表头结构：

```
row_type | template | provider | uuid | context | requirements | title | description | results | emotion_config | interruptions
```

添加新列时：
1. 在表头行末尾追加列名
2. 在所有现有行末尾追加对应数量的逗号（保持列数一致）
3. 目标行填入数据

---

## 5. 关键代码位置速查

| 组件 | 文件 | 关键行 |
|------|------|--------|
| interrupt_event 解析 | [`parser/dsl_parser.gd`](parser/dsl_parser.gd) | :253 |
| random 操作符 DSL 解析 | [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) | :487 |
| random 操作符运行时 | [`core/operators/random_operator.gd`](core/operators/random_operator.gd) | :1 |
| check_interruption 运行时 | [`model/event.gd`](model/event.gd) | :28 |
| 中断替换短路逻辑 | [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) | :169 |
| 事件栈管理 | [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) | :74 |
| 标志位 CSV | [`data/flags/flags.csv`](data/flags/flags.csv) | :1 |
| 事件 CSV | [`data/random_events/random_events.csv`](data/random_events/random_events.csv) | :1 |

---

## 6. 常见陷阱

### 陷阱 1（已修复）：`interrupt_event` 的多条件限制

~~`interrupt_event` 只接受 2 个参数（条件 + 操作），无法在单个中断中表达复杂逻辑。~~

**已修复**（2026-05-30）：

1. **CSV 解析器**已修复：[`core/utils/csv_parser.gd`](core/utils/csv_parser.gd) 和 [`core/csv_cloud_loader.gd`](core/csv_cloud_loader.gd) 的 `_parse_csv_line()` 现在会跟踪括号深度（`paren_depth`），函数内部的 `;` 不再被当作 CSV 列分隔符。

2. **interruptions 列**现在支持多个 `interrupt_event()` 调用，用 `|` 分隔（Layer 0）即可：
   ```
   interrupt_event(cond1; op1) | interrupt_event(cond2; op2)
   ```

3. **` and ` 语法**（2026-05-30 新增）：`requirement_syntax` 支持用 ` and `（带空格）连接多个条件，自动组合为 AND 逻辑：
   ```
   interrupt_event(cond1 and cond2; operator_syntax)
   ```
   解析器内部将 ` and ` 分割的每个条件独立解析，合并为 `ComplexRequirements`。详见 [`parser/dsl_parser.gd`](parser/dsl_parser.gd):383。

4. **注意**：`interrupt_event` 本身**不阻断**原事件触发，只是向事件栈 push 事件。替换行为是因为 operator（`push_event`）触发了嵌套的 `apply_narrative` 导致 `_is_active = true`，然后短路逻辑放弃原事件。

### 陷阱 2：忘记 `pop_event()` 导致栈事件循环

❌ **错误**：选项结果只写 `push_event(event_key=xxx)` 而不 `pop_event()`，导致原事件留在栈中，`_process_next` 无限重复。

✅ **正确**：`pop_event(), push_event(event_key=xxx)`

### 陷阱 3：`interrupt_event` 不阻断原事件

❌ **误解**：认为 `interrupt_event` 会替换原事件。

✅ **实际**：`interrupt_event` 不阻断。替换行为是因为 operator（push_event）触发了嵌套的 `apply_narrative` 导致 `_is_active = true`，然后短路逻辑放弃原事件。

### 陷阱 4：CSV 逗号引号

如果 `description` 等纯文本字段包含英文逗号，必须用双引号包裹整个字段，否则 CSV 解析会列错位。

---

## 7. 中断多步优先级模式（Interruption Priority Chain）

### 场景

同一个事件前需要检查多个独立的中断条件，且**优先级不同**（先检查特例，再检查通用条件）。

### 实现方案

多个 `interrupt_event()` 用 `|` 分隔（Layer 0），按优先级从高到低排列。`check_interruption` 是 **first-match-wins**，第一个条件通过就执行对应操作并结束，后面的不检查。

```csv
interrupt_event(<高优先级条件>; <操作>) | interrupt_event(<低优先级条件>; <操作>)
```

### 实战案例：李白唱和两步序列

```csv
interrupt_event(flag_int_eq(name=flag_libai_changhe_request;val=1)|push_event(event_key=libai_force_changhe))|interrupt_event(flag_int_gt(name=flag_relation_with_libai;val=20) and flag_int_eq(name=flag_libai_changhe_request;val=0)|random(val=99;success=push_event(event_key=request_libai_changhe)))
```

| Step | 优先级 | 条件 | 触发时 flag | 操作 |
|------|--------|------|------------|------|
| **0** | 🔴 高（先检查） | `flag == 1` | 递减到 1 | 强制唱和 `libai_force_changhe` |
| **1** | 🟢 低（后检查） | `relation > 20 AND flag == 0` | 无进行中 | 常规唱和 `request_libai_changhe` |

### 核心经验

**1. 用 flag 的值语义来表达"状态阶段"，而不是用独立 bool 标志**

这条规则是本次 debug 最重要的教训。用一个 int flag 的不同值域表达完整生命周期：

| flag 值 | 语义 | 触发的中断 |
|---------|------|-----------|
| `0` | 无进行中的唱和请求 | Step 1：可开启新唱和 |
| `> 0`（1-5） | 有进行中的唱和请求（递减中） | 无（等待递减到 1） |
| `== 1` | 即将强制唱和 | Step 0：优先拦截，强制唱和 |

不需要额外 bool 标志来跟踪"是否已触发"。**flag 的值本身就是状态机** 🤓☝️。减少一个 flag 就减少一个可能泄露/忘记重置的状态。

对应的 DSL 条件：
- `flag_int_eq(name=xxx; val=0)` — flag 不存在或为 0（空闲状态）
- `flag_int_gt(name=xxx; val=0)` — flag 存在且 > 0（活跃状态）
- `flag_int_eq(name=xxx; val=1)` — flag 精确等于 1（临界状态）

**2. `flag_int_eq(val=0)` 不会"永远不可能实现"**

👉 参考 [`flag_requirement.gd:60-63`](core/requirements/flag_requirement.gd:60)：

```gdscript
var current_val = PlayerState.get_flag(flag_id)
if current_val == null:
    current_val = 0
```

| flag 状态 | `get_flag()` | `has_flag()` | `val=0` 比较结果 |
|-----------|-------------|-------------|-----------------|
| 从未设置 | null → 0 | false | `0 == 0` = **true** ✅ |
| 设值为 0 | 0 | true | `0 == 0` = **true** ✅ |
| 设值为 5 | 5 | true | `5 == 0` = **false** ❌ |

`flag_int_eq(val=0)` 在 flag 未设置或被设为 0 时返回 true——这正是"空闲状态"的检测逻辑。不会"永远不可能"。

**3. `check_interruption` 在 `event_result` 之前执行**

这是 [`apply_narrative`](characters/narrative_overlay.gd:228) 的执行顺序：

```gdscript
# Phase 1: check_interruption（先！）
data.check_interruption(context)
if _is_active: return  # 中断触发 → 跳过 init

# Phase 2: data.init() → 这里才执行 event_result
var all_options = data.init(context)
```

所以 `reduce_if_above` 这类 `event_result` 中的操作在中断**之后**才执行。如果中断触发了（step 1 条件通过），`reduce_if_above` 根本不会跑。

**这对设计的直接影响**：不能依赖 `event_result` 修改 flag 来"改变中断的检查结果"——因为中断先跑，跑完才执行 `event_result`。如果 step 1 条件 `flag > 0 AND relation > 20` 在 flag=5 时通过了，它**每次都通过**，`reduce_if_above` 永远没机会执行，flag 永远减不下去，形成无限循环 💀。

**修复方案**：step 1 条件改为 `flag == 0`（空闲状态才触发），这样当 flag 为 5 时已经活跃了，step 1 不触发 → `event_result` 执行 → `reduce_if_above` 递减 → 最终减到 1 触发 step 0。

**4. 中断条件和 Entry Requirement 是正交的**

`push_event` 绕过 pool 筛选，**不检查目标事件的 entry requirement**。中断条件必须自行涵盖目标事件的所有守卫逻辑。

原始 bug 的根因就在这：中断条件只检查了 `relation > 20`，但目标事件 `request_libai_changhe` 的 entry requirement 是 `flag > 0`。中断 push 了一个"目标事件进场条件不满足"的事件——虽然本例中 `push_event` 无视了 entry requirement，但这个语义鸿沟是设计陷阱。

**经验**：写中断的 condition 时，默认目标事件的 entry requirement 不存在。必须把你的意图显式写到 condition 里。

---

## 8. CSV 语法雷区

### 雷区 1：参数分隔符是逗号，不是句点

```csv
# 💀 错误：flag_int_set(name=flag_libai_changhe_request.val=0)
#                           ^ 这里用了句点，解析器认为参数名是 "flag_libai_changhe_request.val"

# ✅ 正确：flag_int_set(name=flag_libai_changhe_request; val=0)
```

所有 DSL 参数分隔符必须是英文逗号 `,`。句点 `.` 不会被识别为分隔符，整个字符串会被当成一个参数名。

### 雷区 2：`Logging.err` 有门槛

```gdscript
# 💀 错误：条件检查失败用 err 级别
Logging.err('ComplexRequirements: AND operation failed at operator index %d' % i)

# ✅ 正确：条件检查失败是正常代码路径，用 debug 级别
Logging.debug('ComplexRequirements: AND operation failed at operator index %d' % i)
```

`Logging.err` 是为**系统级异常**保留的——数据损坏、空指针、契约违约。**条件评估自然返回 false 不是异常**，是 `if` 语句的日常工作 💀。用 `err` 级别记录条件 false 会导致日志里到处是假阳性噪音，真正的错误被淹没。

`Logging.err` 的使用门槛：这个状况是否**不应该出现**？如果是"某些数据下会自然发生"的情况，用 `debug` 或 `warn`。

---

## 9. 完整数据流验证：李白唱和生命周期

这是一个"中断两步序列 + int flag 状态机"的完整实战验证，覆盖所有分支。

### 初始条件
- `flag_libai_changhe_request = 0`（无进行中的唱和）
- `flag_relation_with_libai > 20`

### 分支追踪

```
第 1 次进入 mid_of_wenhuaquan_party
├─ check_interruption
│  ├─ Step 0: flag == 1? → 0 == 1 → ❌
│  └─ Step 1: relation > 20 AND flag == 0? → ✅ → random(99) → push request_libai_changhe
│     └─ 用户"欣然应和" → flag_int_set(5), pop_event()
│
第 2 次进入 mid_of_wenhuaquan_party（flag=5）
├─ check_interruption
│  ├─ Step 0: 5 == 1? → ❌
│  └─ Step 1: 5 == 0? → ❌（flag 活跃，不重复触发）
├─ init → event_result: reduce_if_above(5→4)
└─ 事件正常显示
│
第 3-5 次进入：reduce 4→3→2→1（每次-1）
├─ check_interruption 都不通过（flag==1和flag==0都不匹配）
├─ init → reduce_if_above
└─ 事件正常显示
│
第 6 次进入（reduce 2→1 之后）
├─ check_interruption
│  ├─ Step 0: 1 == 1? → ✅ → push libai_force_changhe 🎯
│  └─ （Step 1 不执行，first-match-wins）
├─ 强制唱和 → flag_int_set(0), pop_event()
│
第 7 次进入（flag=0）
├─ Step 0: 0 == 1? → ❌
├─ Step 1: 0 == 0? → ✅ → 重新开启新唱和周期
└─ （回到第 1 次的状态，循环 ∞）
```

### 分支表

| 分支 | 条件 | flag 范围 | 结果 |
|------|------|----------|------|
| 无唱和 | `flag==0 AND rel≤20` | 0 | 无事发生，事件正常显示 |
| 新人唱和 | `flag==0 AND rel>20` | 0 → 5 | 开启新唱和周期 |
| 唱和进行中 | `flag>0 AND flag≠1` | 5→4→3→2 | 递减中，不触发中断 |
| 强制唱和 | `flag==1` | 1 | 优先触发强制唱和 |
| 拒绝唱和 | 用户点婉言谢绝 | 5 | `relation -5`，可能降到 ≤20 关掉 Step 1 |

### 关键教训

1. **`event_result` 在 `check_interruption` 之后执行** — 如果想用减量来触发中断（减到 1），必须确保中断在减量之前不触发（用 `==0` 而非 `>0` 做守卫）
2. **First-match-wins 的优先级可以精确控制** — Step 0 的 `== 1` 是精确匹配，Step 1 的 `== 0` 是范围匹配。精确匹配放前面确保不会被范围匹配抢走
3. **不需要额外 bool flag 来防重入** — int flag 的值域天然提供了"空闲/活跃/临界"三种状态。多一个 flag 就多一个可能忘记重置的状态
4. **中断条件和目标事件的 entry requirement 不能互斥** — 如果中断的条件是 `flag == 0`（flag 为空时触发），但目标事件 `request_libai_changhe` 的 entry requirement 是 `flag > 0`（flag 非空才能显示），这俩条件是互斥的。`push_event` 绕过了 pool 筛选，但 `_on_push_event` 中的防御检查会**重新检查 entry requirement** → 条件不满足 → push 被静默丢弃 → 事件不显示也没有任何错误提示 😭。修复：要么中断条件包含 entry requirement 的逻辑，要么干脆移除目标事件的 entry requirement（如果它只通过 push_event 触发的话）。
