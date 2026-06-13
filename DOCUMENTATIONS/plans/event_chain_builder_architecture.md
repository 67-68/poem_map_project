# Event Chain Builder — 架构设计

> 状态: Draft | 最后更新: 2026-06-12

## 1. 概述

一个 GDScript CLI 工具，通过 DSL 命令组装事件之间的层级导航结构（单向 Push / 可逆栈），**直接修改 `.tres` 文件**，自动注入对应的 `PushEventOperator`、`PopEventOperator`、`FlagOperator` 等运行时 Operator。

核心隐喻：事件之间构成 **层级栈** 关系 —— `create_hierarchy` = 进入子层级（Push），`create_reversible_hierarchy` = 可逆的父子栈结构（Push 进入 + Pop 返回）。

## 2. DSL 命令语法

所有命令采用现有 Micro-DSL 的函数调用风格 `func_name(param=val; ...)`：

### 2.1 `create_hierarchy(source, source_opt, target)`

**单向层级（Pure Push）**：从事件 A 的指定选项进入子层级事件 B。仅注入 Push 操作，不创建返回路径。

B 作为 A 的子层级被推入事件栈，B 结束后自然弹出回到 A（或者由 B 自己的其他选项决定去向）。

```
create_hierarchy(source="event_intro_745", source_opt="opt_enter_exam", target="event_exam_747")
```

**注入的操作：**

| 目标文件 | 位置 | 注入内容 |
|---------|------|---------|
| `source` 的 `.tres` | option `source_opt` 的 `choice_result.operators` 末尾 | `PushEventOperator(event_key=target)` |

> 🔒 `target` 事件**不做任何修改**。它可以通过自己的 on_enter / options 自由决定后续流向。

### 2.2 `create_reversible_hierarchy(a, a_opt, b, b_opt)`

**可逆层级栈（Push + Pop）**：事件 A 的选项推入子事件 B，事件 B 的指定选项弹出回到 A。形成标准的栈式父子关系。

```
create_reversible_hierarchy(a="event_intro_745", a_opt="opt_enter_exam", b="event_exam_747", b_opt="opt_leave_exam")
```

**注入的操作：**

| 目标 | 选项 | 注入内容 |
|------|------|---------|
| 事件 A | option `a_opt` 的 `choice_result.operators` 末尾 | `PushEventOperator(event_key=b)` |
| 事件 B | option `b_opt` 的 `choice_result.operators` 末尾 | `PopEventOperator` |

> 🔒 纯粹的栈操作：Push 进去，Pop 回来。不引入 flag 依赖。

### 2.3 `create_once_option(event, opt)`

**一次性选项**：该选项点击后自动标记 flag，再次出现时因 requirement 不满足而不可选。

```
create_once_option(event="event_money_lower_0", opt="opt_beg")
```

**注入的操作：**

| 位置 | 注入内容 |
|------|---------|
| option `opt` 的 `requirement` | `flag_bool_not_has(name=flag_once_{event}_{opt})` |
| option `opt` 的 `choice_result.operators` 末尾 | `FlagOperator(flag_id=flag_once_{event}_{opt}, type='bool', operation='set', value=true)` |

---

## 3. Flag 命名约定

| 场景 | Flag ID 模式 | 示例 |
|------|-------------|------|
| 一次性选项 | `flag_once_{event}_{opt}` | `flag_once_event_money_lower_0_opt_beg` |
| （Hierarchy 命令**不生成 flag**，仅注入 Push/Pop Operator） | — | — |

> 🔒 `create_hierarchy` 和 `create_reversible_hierarchy` 不产生 flag —— 它们是纯粹的栈操作。事件栈本身就是状态的载体，无需额外追踪标记。

虚拟注册策略：一次性 flag 仅在运行时通过 `PlayerState.register_virtual_flag()` 注册（与 `DeferredLockActionOperator` 一致），不写入 `flags_registry.tres`。

---

## 4. 系统架构

```
┌─────────────────────────────────────────────────┐
│           event_chain_builder.gd                 │
│         CLI 入口 (@tool 脚本)                     │
│  - 接收 DSL 命令字符串                            │
│  - 调用 ChainDSLParser → ChainCommand[]           │
│  - 调用 ChainExecutor → 修改 .tres                │
│  - 输出 diff 摘要                                │
├─────────────────────────────────────────────────┤
│            chain_dsl_parser.gd                   │
│  - parse(cmd_str) → Array[ChainCommand]          │
│  - 复用 NamedDSLParser.parse_single() 解析参数    │
├─────────────────────────────────────────────────┤
│            chain_command.gd                      │
│  - ChainCommand 数据类 (Resource)                 │
│  - type: enum {HIERARCHY, REVERSIBLE_HIERARCHY,  │
│          ONCE_OPTION}                            │
│  - params: Dictionary                            │
├─────────────────────────────────────────────────┤
│           chain_tres_editor.gd                   │
│  - load_event(event_key) → BaseEvent             │
│  - save_event(event)                             │
│  - find_option(event, opt_uuid) → BaseOption     │
│  - inject_operator(option, operator)             │
│  - inject_requirement(option, requirement_dsl)   │
│  - 遍历所有 registry 定位事件文件                  │
├─────────────────────────────────────────────────┤
│         chain_flag_generator.gd                  │
│  - generate_once_flag(event, opt) → String       │
│  - 去重检查：如果 flag 已存在追加 _2, _3...       │
└─────────────────────────────────────────────────┘
```

### 4.1 数据流

```
DSL 命令字符串
    │
    ▼
ChainDSLParser.parse()
    │  使用 NamedDSLParser 提取 func_name + params
    │  映射 func_name → ChainCommand.Type
    ▼
Array[ChainCommand]
    │
    ▼
ChainExecutor.execute_all(commands)
    │
    ├─► create_hierarchy(source, source_opt, target):
    │   1. ChainTresEditor.load_event(source) → BaseEvent
    │   2. ChainTresEditor.find_option(event, source_opt) → BaseOption
    │       ├─ 找到 → 注入 PushEventOperator(event_key=target)
    │       └─ 未找到 → 报错（source_opt 必须已存在）
    │   3. ChainTresEditor.save_event(event)
    │
    ├─► create_reversible_hierarchy(a, a_opt, b, b_opt):
    │   1. load_event(a) → 在 a_opt 注入 PushEventOperator(event_key=b)
    │   2. save_event(a)
    │   3. load_event(b) → 在 b_opt 注入 PopEventOperator
    │   4. save_event(b)
    │
    ├─► create_once_option(event, opt):
    │   1. ChainFlagGenerator.generate_once_flag(event, opt)
    │   2. load_event → find_option(opt)
    │       ├─ 注入 requirement: flag_bool_not_has(name=flag_once_...)
    │       └─ 注入 FlagOperator(flag_id=flag_once_..., type='bool', value=true)
    │   3. save_event(event)
    │
    ▼
输出: 每个修改的 .tres 文件路径 + 变更摘要
```

---

## 5. 关键设计决策

### 5.1 `.tres` 修改策略：ResourceLoader + ResourceSaver

| 方案 | 优点 | 缺点 |
|------|------|------|
| Godot API (`load()` + `save()`) | 类型安全，不会破坏序列化格式，正确处理 UID 引用 | 必须在 Godot 运行时内执行 |
| 文本正则替换 | 不依赖 Godot，可在宿主机运行 | .tres 格式复杂（ext_resource、sub_resource、uid 交叉引用），极易写坏 |

✅ **结论**：使用 Godot Resource API。这是 `@tool` 脚本，在 Godot headless 下跑完全合适。

### 5.2 Registry 更新策略

本工具**只修改已有 `.tres` 文件中的 option**，不创建新的事件文件、不新增 registry 条目。因此无需更新任何 registry `.tres`。

### 5.3 调用方式

两种调用方式，对应同一份 `@tool` 脚本：

1. **通过 MCP `run_godot_script`**：传递 DSL 命令字符串作为参数
2. **通过 Godot 编辑器**：挂载到 debugger scene 中手动触发

### 5.4 `create_hierarchy` 和 `create_reversible_hierarchy` 的区别

```
create_hierarchy(A, opt, B)
    A ──[Push B]──► B
    （B 结束后的去向由 B 自己决定）

create_reversible_hierarchy(A, a_opt, B, b_opt)
    A ──[Push B]──► B ──[Pop]──► A
    （B 的 b_opt 显式 Pop 回 A，形成闭环栈）
```

两者都不产生 flag —— 事件栈本身就是层级状态的载体。

### 5.5 与 CSV 系统的关系

DSL 命令语法与现有 Micro-DSL 保持一致（函数调用 + 命名参数），但属于 **build-time macro**，不在 CSV `results` 列中展开。跨事件注入 operator 超出了 CSV 单行模型的语义范围。

若未来要在 CSV 中使用，可在 CSV → `.tres` 同步流水线的后处理阶段调用本工具。

---

## 5.6 选项定位方式

由于现有 .tres 事件的选项大多没有设置 `uuid` 字段（默认空字符串），`find_option()` 支持两种定位方式：

### 通过 UUID（优先）
```
source_opt="实际的UUID字符串"
```

### 通过索引（后备，支持现有事件）
```
source_opt="0"     # 第一个选项
source_opt="1"     # 第二个选项
source_opt="#0"    # 同上，#前缀可选
```

`find_option()` 先在 `event.options` 数组中按 UUID 匹配，若未命中则尝试按索引匹配。

---

## 5.7 场景模式 vs --script 模式

| 模式 | 命令 | Autoload | class_name | DSL 参数获取 |
|------|------|----------|------------|-------------|
| `--script` | `godot -s script.gd -- "DSL"` | ❌ 不可用 | ❌ 不可用 | `OS.get_cmdline_user_args()` |
| 场景模式 | `godot scene.tscn -- "DSL"` | ✅ 可用 | ✅ 可用 | `OS.get_cmdline_user_args()` |

**结论：** 必须使用场景模式（挂载到 `.tscn` 文件）来运行。`--script` 模式无法加载 `Logging` 等 autoload。

---

## 6. 确认结论

| 问题 | 决策 |
|------|------|
| Flag 注册方式 | ✅ 虚拟注册（`PlayerState.register_virtual_flag()`），不入 `flags_registry.tres` |
| `create_hierarchy` 返回选项 | N/A — 不创建返回选项（栈自然弹出） |
| Dry-run 预览 | 暂不需要（在 Phase 5 测试中用真实 .tres 验证） |
| once + hierarchy 组合 | 不需要组合，`create_once_option` 独立使用 |

---

## 7. 实施计划

| Phase | 内容 | 产出文件 |
|-------|------|---------|
| Phase 1 | `chain_command.gd` + `chain_dsl_parser.gd` | 数据类型定义 + DSL 命令解析器 |
| Phase 2 | `chain_flag_generator.gd` + `chain_tres_editor.gd` | Flag 生成 + .tres 定位/加载/注入/保存 |
| Phase 3 | `chain_executor.gd` | 编排器：接收 Command[]，按类型分发执行 |
| Phase 4 | `event_chain_builder.gd` | CLI 入口脚本（`@tool`），接收 DSL 字符串 |
| Phase 5 | 测试：在真实 .tres 上跑 `create_hierarchy`、`create_reversible_hierarchy`、`create_once_option` |
| Phase 6 | 文档更新 + git commit |
