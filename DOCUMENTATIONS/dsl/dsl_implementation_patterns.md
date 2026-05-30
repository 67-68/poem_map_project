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
interrupt_event(<requirement>, random(val=<概率0-100>, success=push_event(event_key=<目标事件>)))
```

**示例**：在 `mid_of_wenhuaquan_party` 之前检查李白关系 > 20，5% 概率触发 `request_libai_changhe`

```csv
random_event,,,,mid_of_wenhuaquan_party,,,title,description,,,,interrupt_event(flag_int_gt(name=flag_relation_with_libai,val=20),random(val=5,success=push_event(event_key=request_libai_changhe)))
```

### 约束条件

#### 1. `interrupt_event` 只接受 2 个参数

`interrupt_event(requirement_syntax, operator_syntax)` 的值通过 [`split_expressions`](parser/named_dsl_parser.gd) 按**顶级逗号**分割，只能拆出 2 段：

```gdscript
# parser/dsl_parser.gd:289
var args = NamedDSLParser.split_expressions(args_str)
if args.size() < 2:
    Logging.err("需要 2 个参数（requirement, operator）")
```

这意味着 `requirement_syntax` 只能是一个**单一的条件表达式**，不能放入 `条件A, 条件B` 这样的复合条件（因为额外的逗号会被当成第 3 个参数）。

**如果需要多条件守卫**，使用 ` and ` 语法（带空格）在 `requirement_syntax` 中组合多个条件：

```
interrupt_event(cond1 and cond2, operator_syntax)
```

示例：
```csv
interrupt_event(flag_int_gt(name=flag_relation_with_libai,val=20) and flag_int_lt(name=flag_libai_changhe_request,val=1), random(val=99, success=push_event(event_key=request_libai_changhe)))
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

DSL 语法：`random(val=<概率>, success=<操作符>, fail=<操作符（可选）>, success_hint=<提示>, failed_hint=<提示>)`

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
| 检查 int 大于 | `flag_int_gt(name=flag_relation_with_libai, val=20)` |
| 检查 bool 为真 | `flag_bool_has(name=flag_libai_changhe_shown)` |
| 设置 bool | `flag_bool_set(name=flag_libai_changhe_shown, val=true)` |
| 追加 int | `flag_int_append(name=flag_relation_with_libai, val=5)` |

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

1. **CSV 解析器**已修复：[`core/utils/csv_parser.gd`](core/utils/csv_parser.gd) 和 [`core/csv_cloud_loader.gd`](core/csv_cloud_loader.gd) 的 `_parse_csv_line()` 现在会跟踪括号深度（`paren_depth`），函数内部的逗号不再被当作 CSV 列分隔符。

2. **interruptions 列**现在支持多个 `interrupt_event()` 调用，用逗号分隔即可：
   ```
   interrupt_event(cond1, op1), interrupt_event(cond2, op2)
   ```

3. **` and ` 语法**（2026-05-30 新增）：`requirement_syntax` 支持用 ` and `（带空格）连接多个条件，自动组合为 AND 逻辑：
   ```
   interrupt_event(cond1 and cond2, operator_syntax)
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

## 7. 已完成的实现（本次任务）

### 修改内容

1. [`data/random_events/random_events.csv`](data/random_events/random_events.csv)
   - 表头添加 `interruptions` 列
   - `mid_of_wenhuaquan_party` 行添加：
     ```
     interrupt_event(flag_int_gt(name=flag_relation_with_libai,val=20), random(val=5, success=push_event(event_key=request_libai_changhe)))
     ```

2. [`data/flags/flags.csv`](data/flags/flags.csv)
   - 新增 `flag_libai_changhe_shown`（bool, 默认 FALSE）用于防循环
