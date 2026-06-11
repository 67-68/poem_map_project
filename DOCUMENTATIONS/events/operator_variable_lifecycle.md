# Operator Variable 生命周期文档

> 基于 `model/event.gd`、`model/event/event_option.gd` 及 `core/operators/*.gd` 中所有 operator 的变量分类。

---

## 目录

1. [变量生命周期的四个层次](#1-变量生命周期的四个层次)
2. [Event.gd 变量生命周期](#2-eventgd-变量生命周期)
3. [EventOption.gd 变量生命周期](#3-eventoptiongd-变量生命周期)
4. [Operator 变量生命周期总览](#4-operator-变量生命周期总览)
5. [Operator 逐类分析](#5-operator-逐类分析)
   - [5.1 纯 @export 变量 Operator](#51-纯-export-变量-operator)
   - [5.2 Context 捕获型 Operator](#52-context-捕获型-operator)
   - [5.3 Context 读取+修改型 Operator](#53-context-读取修改型-operator)
   - [5.4 临时/回滚型 Operator](#54-临时回滚型-operator)
   - [5.5 复合/条件型 Operator](#55-复合条件型-operator)
6. [变量引用的三类数据源](#6-变量引用的三类数据源)
7. [变量使用总谱](#7-变量使用总谱)
8. [历史 Bug 与生命周期关系](#8-历史-bug-与生命周期关系)
9. [执行阶段契约：operator 的三层铁幕](#9-执行阶段契约operator-的三层铁幕)
   - [9.1 问题的起源：执行顺序依赖](#91-问题的起源执行顺序依赖)
   - [9.2 铁幕契约总览](#92-铁幕契约总览)
   - [9.3 第一层：Event on_enter（舞台置景）](#93-第一层event-on_enter舞台置景)
   - [9.4 第二层：Option requirements（只读守卫）](#94-第二层option-requirements只读守卫)
   - [9.5 第三层：Option choice_result（因果爆破）](#95-第三层option-choice_result因果爆破)
   - [9.6 契约对照表：当前代码库现状](#96-契约对照表当前代码库现状)
   - [9.7 契约违反场景与修复](#97-契约违反场景与修复)

---

## 1. 变量生命周期的四个层次

在理解 operator variable 之前，必须理解整个系统中变量的四种**存储层次**：

| 层次 | 持久化方式 | 作用域 | 代表变量 |
|------|-----------|--------|---------|
| **A. Resource 持久层** | `.tres` 文件序列化 | 跨游戏会话 | `@export var` 字段 |
| **B. Transient 运行时层** | 不持久化，每次 init() 重新计算 | 单次事件触发 | `var _resolved_description`、`var _captured_context` |
| **C. Context 事件链层** | `Dictionary` 在 init/operate 链中传递 | 一次事件触发周期 | `context` 参数、`custom_context_params` |
| **D. PlayerState 全局状态层** | `PlayerState` 单例 | 整个游戏流程 | 属性、flag、trait、emotion |

---

## 2. Event.gd 变量生命周期

文件：[`model/event.gd`](../../model/event.gd)

### 2.1 Resource 持久层 (@export)

| 变量 | 类型 | 生命周期 |
|------|------|---------|
| `options` | `Array[BaseOption]` | 永久存储在 `.tres`，每次 `init()` 时**只读**（用 `duplicate()` 生成临时数组） |
| `provider` | `BaseProvider` | 永久存储在 `.tres`，`init()` 时生成额外选项 |
| `example` | `String` | 永久存储，展示用 |
| `audio` | `AudioStream` | 永久存储，事件音频 |
| `epitaph_text` | `String` | 永久存储，墓志铭文字 |
| `emotion_configs` | `Array[EmotionConfigs]` | 永久存储，情感配置 |
| `pre_event_interrupter_sequence` | `Array` (ConditionalOperator[]) | 永久存储，前置中断序列 |

### 2.2 RandomEvent 额外持久层

文件：[`model/random_event.gd`](../../model/random_event.gd)

| 变量 | 类型 | 生命周期 |
|------|------|---------|
| `weight` | `float` | 永久存储，事件池权重 |
| `requirement` | `BaseRequirements` | 永久存储，入口守卫条件 |
| `event_result` | `ChoiceResult` | 永久存储，事件级结果 |
| `custom_context_params` | `Dictionary` | 永久存储，CSV context 中提取的自定义参数 |
| `target_tags` | `Array[String]` (getter 合成) | 运行时合成，从 `_action_tags` + `_area_tags` + `_target_tags` 动态计算 |

### 2.3 init() 调用链中的变量流

```
RandomEvent.init(context)
  │
  ├─ Util.merge_context(context, custom_context_params)
  │     将 .tres 中的持久参数合并进运行时 context
  │
  ├─ BaseEvent.init(context)
  │   ├─ provider.init(context)        ← 修改 context（Provider 读 context）
  │   ├─ provider.provide(context)     ← 根据 context 动态生成选项
  │   ├─ options.duplicate()           ← 临时数组，不污染 self.options
  │   └─ option.init(context)          ← 每个 option 隔离自己的 context
  │
  └─ event_result.init(context)
     └─ event_result.operate()         ← 事件级结果立即执行
```

**关键约束**（见 [`context_isolation_contract.md`](context_isolation_contract.md)）：
- `BaseEvent.init()` **不得**修改 `self.options`（用临时数组）
- Provider **只读** context，每个选项独立 payload

---

## 3. EventOption.gd 变量生命周期

文件：[`model/event/event_option.gd`](../../model/event/event_option.gd)

### 3.1 Resource 持久层 (@export)

| 变量 | 类型 | 生命周期 |
|------|------|---------|
| `description` | `String` | 永久存储，按钮文本（可能含 `{placeholder}` 占位符） |
| `choice_result` | `ChoiceResult` | 永久存储，选择结果（内含 operator 数组） |
| `requirement` | `BaseRequirements` | 永久存储，选项守卫条件 |
| `emotion_configs` | `Array[EmotionConfigs]` | 永久存储，情感配置 |
| `custom_context_params` | `Dictionary` | 永久存储，选项级自定义参数（CSV 或 ItemProvider 注入） |

### 3.2 Transient 运行时层

| 变量 | 类型 | 生命周期 |
|------|------|---------|
| `_resolved_description` | `String` | **每次 `init()` 重新计算**，不持久化。用于存储解析 `{placeholder}` 后的按钮文本 |

### 3.3 init() 内部变量流

```gdscript
func init(context: Dictionary) -> Dictionary:
    var context_ = context.duplicate()          # ← 创建沙盒（防止污染其他选项）
    
    # 合并自定义参数（乘法叠加，同 RandomEvent）
    Util.merge_context(context_, custom_context_params)
    
    # 解析 description 中的占位符
    # {some_prop}  → self.some_prop（选项自身属性）
    # {@some_prop} → context_["some_prop"]（context 字典）
    _resolved_description = Util.tr_and_resolve(description, context_, self)
    
    # 级联初始化
    requirement.init(context_)      # 守卫条件
    choice_result.init(context_)    # 结果（内部 operator 的 init）
    
    return context_                 # 返回沙盒（调用方可丢弃）
```

**关键约束**：
- `_resolved_description` 是 transient 字段，不修改 `self.description`（不污染 Resource 持久属性）
- `context_` 是 `context.duplicate()` 的沙盒，选项间相互隔离
- `custom_context_params` 在 `init()` 时被 merge 进 context，之后 operator 可以在 `init()` 中读取

---

## 4. Operator 变量生命周期总览

所有 operator 继承自 [`core/model/base_operator.gd`](../../core/model/base_operator.gd)

### 4.1 BaseOperator 接口

```gdscript
class_name BaseOperator extends Resource

# 通用 hint（在 operate() 完成后展示）
var hint: String = ''

func operate():                     # 执行操作（必须重写）
func init(_context: Dictionary):    # 从 context 解析参数，返回 context（可选重写）
func get_referenced_flags() -> Array:
func get_provided_flags() -> Array:
func get_demanded_flags() -> Array:
func get_referenced_traits() -> Array:
func get_provided_traits() -> Array:
func get_demanded_traits() -> Array:
```

### 4.2 Operator 变量分类矩阵

| Operator | @export 持久变量 | Transient 变量 | 是否使用 context |
|----------|-----------------|---------------|-----------------|
| `FlagOperator` | `flag_id`, `type`, `value`, `operation`, `threshold`, `amount`, `target_flag_id_from_context`, `flag_id_prefix` | — | ✅ `init()` 从 context 解析动态 flag_id |
| `TempFlagOperator` | (继承 FlagOperator) | — | ✅ 同上，+ operate 时注册 cleanup |
| `FlagReplaceOperator` | `to_be_replaced_flag_id`, `replace_with_flag_id` | — | ❌ |
| `PushEventOperator` | `event_key` | `_captured_context` | ✅ `init()` 捕获 context 快照 |
| `QueueEventOperator` | `event_key` | `_captured_context` | ✅ `init()` 捕获 context 快照 |
| `MenuStartOperator` | `resource_to_put_in_context`, `key_of_resource_in_context`, `next_event_key` | `context` (成员变量) | ✅ `init()` 深拷贝 + 注入资源 |
| `PoemTypeChooseOperator` | `poem_taste` (Resource), `key_to_get_poem_taste`, `property_multiplication` | — | ✅ `init()` 从 context 解析 poem_taste |
| `EmotionOperator` | `_emotion` (ENUM), `str_emotion`, `value`, `archetype`, `mode` | — | ❌ |
| `ImaginaryOperator` | `imaginary_name`, `operation` | — | ❌ |
| `TraitReplaceOperator` | `_replace_other_trait`, `_to_be_replaced_trait` | — | ❌ |
| `RandomOperator` | `random_value`, `success_operator`, `fail_operator`, `success_hint`, `failed_hint` | — | ❌ |
| `SystemOperator` | `command`, `death_hint` | — | ❌ |
| `InfoDemoOperator` | `info` | — | ❌ |
| `PropertyRangeOperator` | `min_value`, `max_value`, `_property` (ENUM), `result_operator` | — | ❌ |
| `ForceSetPropertyOperator` | `_property` (ENUM), `value` | — | ❌ |
| `PopEventOperator` | (无) | — | ❌ |
| `ConditionalOperator` | `condition`, `condition_success_result`, `condition_fail_result` | — | ✅ 内部 operator 的 init/operate 链 |

---

## 5. Operator 逐类分析

### 5.1 纯 @export 变量 Operator

这些 operator **只有 `@export` 持久变量**，不涉及 context 传递。所有数据在 `.tres` 文件中硬编码，`init()` 不做任何事。

| Operator | 数据来源 | operate() 目标 |
|----------|---------|---------------|
| `FlagReplaceOperator` | 硬编码 `to_be_replaced_flag_id` / `replace_with_flag_id` | `Database.flags` |
| `ImaginaryOperator` | 硬编码 `imaginary_name` / `operation` | `Database.imaginaries` |
| `EmotionOperator` | 硬编码 `_emotion` / `str_emotion` / `value` / `archetype` / `mode` | `PlayerState` |
| `ForceSetPropertyOperator` | 硬编码 `_property` / `value` | `PlayerState` |
| `TraitReplaceOperator` | 硬编码 `_replace_other_trait` / `_to_be_replaced_trait` | `PlayerState` |
| `SystemOperator` | 硬编码 `command` / `death_hint` | 全局系统 |
| `InfoDemoOperator` | 硬编码 `info` | `EventBus.request_warning_toast` |
| `PopEventOperator` | (无) | `EventBus.pop_event` |

**典型使用场景**：
```
# 在 .tres 中硬编码
[sub_resource type="EmotionOperator" id="emo_op"]
value = 15
emotion = "sorrow"

[sub_resource type="FlagReplaceOperator" id="flag_rep"]
to_be_replaced_flag_id = "flag_baiye_commoner"
replace_with_flag_id = "flag_baiye_official"
```

**生命周期图**：
```
.tres 加载 → @export 变量初始化 → operate() 时直接使用
  ↑──────────── 永久存储 ────────────→↓
      不经过 init()，不依赖 context
```

---

### 5.2 Context 捕获型 Operator

这些 operator 需要 **在 `init()` 时捕获 context 快照**，在 `operate()` 时使用。

#### 5.2.1 PushEventOperator / QueueEventOperator

[`core/operators/push_event_operator.gd`](../../core/operators/push_event_operator.gd) / [`core/operators/queue_event_operator.gd`](../../core/operators/queue_event_operator.gd)

```gdscript
# @export（持久）
var event_key: String       # 要推送/排队的事件 key

# transient（运行时）
var _captured_context: Dictionary = {}   # context 快照

func init(context: Dictionary) -> Dictionary:
    _captured_context = context.duplicate()   # ← 浅拷贝快照
    return context

func operate():
    EventBus.push_event.emit(event_key, _captured_context)     # Push
    EventBus.request_event_key.emit(event_key, _captured_context)  # Queue
```

**变量生命周期**：
```
init(context)
  │
  ├─ _captured_context = context.duplicate()
  │                          ↑
  │              从运行时 context 快照（仅存活于 init→operate 之间）
  │
operate()
  │
  └─ emit(event_key, _captured_context)
                    ↑
          快照传递给下游事件，成为下游事件的 context 入口
```

**注意**：`_captured_context` 是**不加 `@export` 的 transient 变量**，不会被序列化到 `.tres`。每次事件触发时都通过 `init()` 重新捕获。

#### 5.2.2 MenuStartOperator

[`core/operators/menu_start_operator.gd`](../../core/operators/menu_start_operator.gd)

```gdscript
# @export（持久）
var resource_to_put_in_context: Resource   # 要注入 context 的资源
var key_of_resource_in_context: String     # context 中对应的 key
var next_event_key: String                 # 下一个事件 key

# transient（运行时，深拷贝持有）
var context: Dictionary

func init(context: Dictionary):
    var sandbox = context.duplicate(true)   # ← 深拷贝！
    
    # 如果已有数据且自身无资源，保留原 context
    if not sandbox.is_empty() and (resource_to_put_in_context == null or key_of_resource_in_context.is_empty()):
        self.context = sandbox
        return sandbox
    
    # 注入资源到沙盒
    sandbox[key_of_resource_in_context] = resource_to_put_in_context
    self.context = sandbox
    return sandbox

func operate():
    EventBus.request_event_key.emit(next_event_key, context)
```

**与 PushEventOperator 的区别**：
- `MenuStartOperator` 使用**深拷贝** `duplicate(true)`，因为它是 `self.context` 成员变量持有（需完全隔离）
- `PushEventOperator` 使用**浅拷贝** `duplicate()`，因为 context 本身已经是沙盒
- `MenuStartOperator` 可以在 init 时**向 context 注入持久资源**（`resource_to_put_in_context`）

---

### 5.3 Context 读取+修改型 Operator

这些 operator 在 `init()` 时从 context **读取并修改自身**，然后在 `operate()` 时使用修改后的自身变量。

#### 5.3.1 FlagOperator

[`core/operators/flag_operator.gd`](../../core/operators/flag_operator.gd)

```gdscript
# @export（持久）
var flag_id: String = ""                    # flag 标识符（可能被动态覆盖）
var type: String                            # 'str' / 'int' / 'bool'
var value: Variant                          # 值
var operation: String = 'set'               # 'set' / 'append' / 'reduce_if_above'
var threshold: int = 0
var amount: int = 0
var target_flag_id_from_context: String = ''  # context 中的 key
var flag_id_prefix: String = ''               # 前缀（用于动态拼接）

func init(_context: Dictionary) -> Dictionary:
    if target_flag_id_from_context.is_empty():
        return _context  # 无动态解析，使用硬编码 flag_id
    
    # ⚡ 从 context 读取值，动态覆盖 flag_id
    var flag_uid = _context.get(target_flag_id_from_context)
    if flag_uid:
        flag_id = flag_id_prefix + str(flag_uid)  # ← 修改 @export 变量！
    return _context

func operate():
    # 使用（可能已被动态覆盖的）flag_id 操作 PlayerState
    PlayerState.set_flag(flag_id, ...)
```

**关键区别**：⚠️ `FlagOperator` 是唯一一个在 `init()` 中**修改自己的 `@export` 变量**的 operator。这意味着：
- 如果同一个 `FlagOperator` 资源被**复用**，前一次 `init()` 修改的 `flag_id` 会**污染**下一次使用
- 这在 Godot Resource 共享模式下是潜在的坑（不过在当前设计中，每个 `ChoiceResult` 的 operator 通常在事件触发时一次性 init+operate，复用的概率较低）

**变量生命周期**：
```
.tres 加载
  │  flag_id = "default_flag"        ← @export 默认值
  │
init(context)
  │  _context.get("target") → "libai"
  │  flag_id = "talked_to_libai"     ← 被 context 动态覆盖
  │
operate()
  │  PlayerState.set_flag("talked_to_libai", ...)
  │
[下一次 init()]
  │  flag_id 会恢复到 @export 默认值 "default_flag" 吗？
  │  答：不会自动恢复！除非重新从 .tres 加载。
```

#### 5.3.2 PoemTypeChooseOperator

[`core/operators/trait_choose_operator.gd`](../../core/operators/trait_choose_operator.gd)

```gdscript
# @export（持久）
var poem_taste: PoemTaste = PoemTaste.new()       # 可能被 context 覆盖
var key_to_get_poem_taste: String = 'poem_taste'  # context 中读取的 key
var property_multiplication: float = 1.0           # 乘法倍率

func init(_context: Dictionary) -> Dictionary:
    # 从 context 读取 poem_taste URN
    if key_to_get_poem_taste and _context.get(key_to_get_poem_taste):
        var taste = _context.get(key_to_get_poem_taste)
        var taste_instance = URN.get_resource_through_urn(taste)
        if taste_instance is PoemTaste:
            poem_taste = taste_instance        # ← 覆盖 @export 变量！
    
    # 修改 context 中的 property_multiplication
    _context["property_multiplication"] = ...  # ← 修改 context
    
    # 级联初始化内部的三个 ChoiceResult
    poem_taste.accepted_result.init(_context)
    poem_taste.rejected_result.init(_context)
    poem_taste.not_entered_result.init(_context)
    
    return _context
```

**双重变量操作**：
1. **修改自身 `@export` 变量**：用 context 中的 URN 替换 `poem_taste`
2. **修改 context**：对 `property_multiplication` 做乘法叠加

---

### 5.4 临时/回滚型 Operator

#### 5.4.1 TempFlagOperator

[`core/operators/temp_flag_operator.gd`](../../core/operators/temp_flag_operator.gd)

继承自 `FlagOperator`，但在 `operate()` 时**额外注册反向清理算子**。

```gdscript
func operate():
    # 1. 捕获旧值
    var had_flag_before = PlayerState.has_flag(flag_id)
    var old_value = PlayerState.get_flag(flag_id)
    
    # 2. 执行父类操作（修改 PlayerState）
    super.operate()
    
    # 3. 构造反向清理 FlagOperator
    var cleanup_op = FlagOperator.new()
    cleanup_op.flag_id = flag_id
    # ... 根据类型设置反向值
    
    # 4. 注册到 PlayerState 清理队列
    PlayerState.defer_cleanup(cleanup_op)
```

**变量生命周期**：
```
init(context)
  │  (继承 FlagOperator 行为，可能修改 flag_id)
  │
operate()
  │
  ├─ 1. 捕获 old_value          ← transient 快照
  ├─ 2. 修改 PlayerState        ← 全局状态层
  ├─ 3. 构造 cleanup_op         ← 反向操作的 FlagOperator（新资源）
  └─ 4. defer_cleanup(cleanup_op)
                                 ↓
                          session 结束时逆序回滚
```

---

### 5.5 复合/条件型 Operator

#### 5.5.1 ConditionalOperator

[`core/model/conditional_operator.gd`](../../core/model/conditional_operator.gd)

```gdscript
# @export（持久）
var condition: BaseRequirements                  # 守卫条件
var condition_success_result: Array[BaseOperator] # 条件通过时执行
var condition_fail_result: Array[BaseOperator]    # 条件失败时执行

func operate():
    if condition.compare(PlayerState):
        for op in condition_success_result: op.operate()
    else:
        if condition_fail_result:
            for op in condition_fail_result: op.operate()
```

**使用场景**：`pre_event_interrupter_sequence` 中的每个 step。
**变量生命周期**：所有子 operator 各自独立管理自己的变量生命周期。

#### 5.5.2 RandomOperator

[`core/operators/random_operator.gd`](../../core/operators/random_operator.gd)

```gdscript
# @export（持久）
var random_value: int                 # 触发概率 0-99
var success_operator: BaseOperator    # 成功时执行
var fail_operator: BaseOperator       # 失败时执行
var success_hint: String
var failed_hint: String
```

纯粹的概率分支，不涉及 context。子 operator 各自管理生命周期。

#### 5.5.3 PropertyRangeOperator

[`core/operators/property_range_operator.gd`](../../core/operators/property_range_operator.gd)

```gdscript
# @export（持久）
var min_value: float
var max_value: float
var _property: ENUMS.PROPS            # 要检查的属性
var result_operator: BaseOperator      # 条件满足时执行

func operate():
    if PlayerState.get(property) >= min_value and PlayerState.get(property) <= max_value:
        result_operator.operate()
```

属性值范围守卫，从 `PlayerState` 全局状态层读取数据。

---

## 6. 变量引用的三类数据源

Operator 的变量可以引用以下三类数据源，每种有**不同的生命周期风险**：

### 6.1 PlayerState（全局游戏状态）

| Operator | 读取操作 | 写入操作 |
|----------|---------|---------|
| `FlagOperator` | `PlayerState.get_flag()`、`PlayerState.has_flag()` | `PlayerState.set_flag()`、`PlayerState.append_flag()` |
| `FlagReplaceOperator` | `Database.flags.get()` | `flag.val_bool =` |
| `TraitReplaceOperator` | `PlayerState.get_traits()` | `PlayerState.remove_trait()`、`PlayerState.add_trait()` |
| `EmotionOperator` | `PlayerState.get_emotion()` (reduce_to_lowest_zero mode) | `PlayerState.append_emotion()`、`PlayerState.set_emotion()`（取决于 `mode`） |
| `ForceSetPropertyOperator` | — | `PlayerState.force_set_stat_val()` |
| `PropertyRangeOperator` | `PlayerState.get(property)` | — |
| `PoemTypeChooseOperator` | `PlayerState.get_traits()` | — |

**生命周期**：永久，贯穿整个游戏流程。

### 6.2 Database（全局数据表）

| Operator | 读取操作 |
|----------|---------|
| `FlagReplaceOperator` | `Database.flags.get()` |
| `ImaginaryOperator` | `Database.imaginaries.get()` |
| `PoemTypeChooseOperator` | `Database.traits.get()` |

**生命周期**：永久，数据加载后常驻内存。

### 6.3 Context（事件链运行时）

| Operator | 读取操作 | 写入操作 |
|----------|---------|---------|
| `PushEventOperator` | `context.duplicate()` → `_captured_context` | —（仅捕获） |
| `QueueEventOperator` | `context.duplicate()` → `_captured_context` | —（仅捕获） |
| `MenuStartOperator` | `context.duplicate(true)` → `self.context` | `self.context[key] = resource` |
| `FlagOperator` | `context.get(target_flag_id_from_context)` | 修改自身 `flag_id` |
| `PoemTypeChooseOperator` | `context.get(key_to_get_poem_taste)` | 修改 context 自身 + 覆盖自身 `poem_taste` |

**生命周期**：
```
事件 A init() → context 创建
  ↓
选项选择 → operator.init(context) 捕获快照
  ↓
operator.operate() → 使用快照 emit 下一个事件
  ↓
事件 B init() → 新的 context（从上一个快照 duplicate 而来）
```

---

## 7. 变量使用总谱

### 7.1 按生命周期分类

| 生命周期 | 变量特征 | 例子 |
|---------|---------|------|
| **永久 (Permanent)** | `@export`，存储在 `.tres` | `event_key`, `flag_id`, `value`, `poem_taste` |
| **Transient (单次交互)** | 不加 `@export`，`init()` 时赋值 | `_captured_context`, `_resolved_description`, `context` |
| **上下文 (Per-Event)** | Dictionary 参数，在 init 链中传递 | `context` 参数，`custom_context_params` |
| **全局状态 (Global)** | `PlayerState`/`Database` 单例 | flag 值、trait 列表、属性值 |

### 7.2 按修改方式分类

| 修改方式 | 危险性 | 代表 |
|---------|-------|------|
| 修改自身 `@export` 变量 | ⚠️ 复用时会污染 | `FlagOperator.flag_id`、`PoemTypeChooseOperator.poem_taste` |
| 修改 context 字典 | ✅ 沙盒隔离，安全 | `MenuStartOperator.context[key]`、`PoemTypeChooseOperator._context[key]` |
| 修改全局状态 | ✅ 设计如此 | `PlayerState.set_flag()` |
| 捕获后不修改 | ✅ 安全 | `_captured_context = context.duplicate()` |

---

## 8. 历史 Bug 与生命周期关系

### Bug 1: MenuStartOperator 参数遮蔽成员变量

> 见 [`old_bugs.md#2026-05-28-menustartoperator-参数遮蔽成员变量导致-context-丢失`](../../DOCUMENTATIONS/old_bugs.md)

```gdscript
# ❌ 旧代码：参数 context 遮蔽了成员变量 context
var context: Dictionary            # 成员变量

func init(context: Dictionary):   # ← 参数遮蔽
    context[key] = resource       # 改的是参数，不是 self.context
    return context                # 返回的也是参数
                                  # self.context 从未被赋值！

func operate():
    emit(next_event_key, context)  # 永远为 {}
```

**根因**：函数参数与成员变量同名的**遮蔽（shadowing）** 问题。成员变量 `context` 从未被赋值。

### Bug 2: EventOption template duplicate 丢失 operator

> 见 [`old_bugs.md#2026-05-28-eventoption-template-的-operators-通过-pda-链路丢失`](../../DOCUMENTATIONS/old_bugs.md)

**根因**：`resource_local_to_scene=true` 的 Resource 调用 `duplicate()` 后，非 `@export` 属性变成只读。修复方案是**手动 `new()` + 逐字段拷贝**，而不是 `duplicate()`。

### Bug 3: ItemProvider 依赖上游 context 传递

> 见 [`old_bugs.md#2026-05-30-itemprovider-依赖上游-context-传递事件链从中道切入导致列表为空`](../../DOCUMENTATIONS/old_bugs.md)

**根因**：context 是"谁放进去谁负责"的模式。如果调试时从中道切入，上游 context 从未被填充，`ItemProvider.provide()` 的 `context.get(list_key, [])` 返回空。

### 生命周期教训总结

1. **`@export` 变量被 `init()` 修改后不会自动恢复** → 复用同一 Resource 实例有污染风险
2. **`_captured_context` 是 transient** → 不存在于 `.tres`，每次事件触发重新捕获
3. **`_resolved_description` 是 transient** → 不污染 `self.description`（Resource 持久属性）
4. **`duplicate()` 不是万能药** → 有 `resource_local_to_scene` 时慎用
5. **参数遮蔽是 GDScript 的隐式陷阱** → 函数参数和成员变量同名时，参数优先
6. **context 是"应声虫"** → 你不传给它，它就没有。没有隐式默认值

---

## 9. 执行阶段契约：operator 的三层铁幕

> 本节讲述的不是"变量在内存里活多久"，而是 **「哪种 operator 应该放在事件生命周期的哪个阶段执行」**。
> 上一节（第 8 节）的 Bug 体现了违反此契约的后果。
>
> 参考来源：外部 repo 的 [`operator 执行契约`] 文档

### 9.1 问题的起源：执行顺序依赖

考虑这个场景：

```
选项 A 的 choice_result.operators:
  [0] FlagOperator(flag_id="can_drink", type="bool", value=true)     ← 设置 flag
  [1] FlagOperator(flag_id="can_drink", type="bool", value=false)    ← 依赖上一个 flag
  [2] PushEventOperator(event_key="some_event")                       ← 依赖 flag
```

这里的 **执行顺序问题** 其实是一个**伪问题** 😨。表面上是"operator B 依赖 operator A 先执行"，但根因是：

> **你把"制造条件"和"消耗条件"塞进了同一个按钮的点击动作里。**
>
> 这好比士兵扣下扳机之后，才想起来自己应该先去兵工厂造子弹 💀。

正确的做法是：**把初始化 flag 的操作提升到事件层面（event_result），和选项的执行解耦。**

当前代码库中，[`RandomEvent.init()`](../../model/random_event.gd:51) 已经在做这件事了：

```gdscript
func init(context: Dictionary) -> Array:
    # ... merge_context ...
    var all_options = super.init(context)
    if event_result:
        event_result.init(context)
        event_result.operate()     # ← 在选项展示前执行事件级结果
    return all_options
```

但仅靠代码实现不够——需要在**架构契约层面**把这个隔离焊死，防止后人再踩同一个坑。

---

### 9.2 铁幕契约总览

整个事件生命周期必须被严格划分为**三层**，每一层有自己**绝对禁止越界**的职责：

```
时间线 ──────────────────────────────────────────────►

┌──────────────────────────────────────────────────────────┐
│  第一层：Event on_enter（舞台置景）                        │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  职责：构建当前事件的绝对上下文。                         │  │
│  │        所有前置计算、flag 初始化、依赖注入必须在此完成。    │  │
│  │  隐喻：话剧开场前，场务把李白的酒杯摆好，把灯光打亮。      │  │
│  │  合法操作：FlagOperator(set), EmotionOperator,          │  │
│  │            ImaginaryOperator, TraitReplaceOperator      │  │
│  │  契约红线：玩家甚至还没看到 UI，一切准备工作必须在此刻结束。 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│                    ↓ 事件展示给玩家 ↓                      │
│                                                          │
│  第二层：Option requirements（只读守卫）                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  职责：纯粹的只读查询。根据事件层面已经算好的 context/    │  │
│  │        PlayerState，决定这个选项是否展示/可用。          │  │
│  │  隐喻：夜总会门口查身份证的保安。只看身份证，绝不现场办证。 │  │
│  │  合法操作：BaseRequirements.compare(PlayerState)       │  │
│  │  契约红线：绝对不允许任何带副作用的 operator。            │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│                    ↓ 玩家选择某个选项 ↓                    │
│                                                          │
│  第三层：Option choice_result（因果爆破）                  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  职责：玩家做出选择后产生的纯粹后果。                     │  │
│  │  隐喻：玩家按下了核弹发射钮。程序不需要再判断什么了，直接炸。│  │
│  │  合法操作：PropertyOperator, FlagOperator(consume),    │  │
│  │            PushEventOperator, PopEventOperator,        │  │
│  │            QueueEventOperator, RandomOperator          │  │
│  │  契约红线：这里的每个 operator 都必须是"因为玩家按了这个  │  │
│  │            按钮才发生的状态改变"。                       │  │
│  │            如果你在这里放了 Op_Init_Flag，代码就"叛逃"了。 │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

### 9.3 第一层：Event on_enter（舞台置景）

**执行时机**：`RandomEvent.init()` → `event_result.operate()`，在选项渲染之前。

**当前代码落点**：

| 阶段 | 代码位置 | 说明 |
|------|---------|------|
| `custom_context_params` merge | [`RandomEvent.init()`](../../model/random_event.gd:53-54) | CSV context 自定义参数合入运行时 context |
| `pre_event_interrupter_sequence` | [`BaseEvent.check_interruption()`](../../model/event.gd:29) | 前置中断序列检查，first-match-wins |
| `event_result.operate()` | [`RandomEvent.init()`](../../model/random_event.gd:58-59) | **事件级结果立即执行** |

**合法 operator 类型**：
- `FlagOperator` — 初始化 flag（`set` 操作）
- `FlagReplaceOperator` — flag 替换
- `EmotionOperator` — 情感值初始化
- `ImaginaryOperator` — imagenary 初始化
- `TraitReplaceOperator` — trait 替换
- `PropertyRangeOperator` — 条件守卫（用在 `ConditionalOperator` 内）
- `SystemOperator` — 系统命令

**不允许的操作**：
- ❌ `PushEventOperator` — 不应该在事件刚展示时就 push 另一个事件（那是 interruption 的职责）
- ❌ `PopEventOperator` — 同上面
- ❌ 任何"因为你选了某个特定选项才应该发生"的后果操作

---

### 9.4 第二层：Option requirements（只读守卫）

**执行时机**：选项按钮创建时，`EventBtn._init()` 调用 `requirement.compare(PlayerState)`。

**当前代码落点**：

| 阶段 | 代码位置 | 说明 |
|------|---------|------|
| `requirement.init(context_)` | [`EventOption.init()`](../../model/event/event_option.gd:36) | 守卫条件从 context 解析参数 |
| `requirement.compare(PlayerState)` | [`EventBtn`](../../characters/event_btn.gd)（外部 UI 层） | 决定选项是否禁用 |

**合法操作**：
- ✅ `BaseRequirements.compare(PlayerState)` — 纯粹的只读查询
- ✅ 所有 `init()` 阶段（从 context 解析参数）是允许的，因为结果是只读的

**契约红线**：
- ❌ 绝对不允许在 `requirements` 中放置任何带副作用的 operator
- ❌ 守卫条件不应该修改 context 或 PlayerState
- ❌ 如果某个选项的 requirements 触发了 flag 初始化，说明那个 flag 应该在事件层的 `event_result` 里初始化

---

### 9.5 第三层：Option choice_result（因果爆破）

**执行时机**：玩家点击某个选项后，`ConsequenceExecuter.execute_result()` → `choice_result.operate()`。

**当前代码落点**：

| 阶段 | 代码位置 | 说明 |
|------|---------|------|
| `choice_result.init(context_)` | [`EventOption.init()`](../../model/event/event_option.gd:38) | operator 从 context 解析参数 |
| `choice_result.operate()` | [`ChoiceResult.operate()`](../../model/choice_result.gd:6) | 执行所有 operator |

**合法 operator 类型**：
- `PushEventOperator` — 推入新事件到栈顶
- `QueueEventOperator` — 排队新事件
- `PopEventOperator` — 退栈
- `MenuStartOperator` — 跳转到新事件
- `FlagOperator` — 消耗/修改 flag（`append`、`reduce_if_above`）
- `TempFlagOperator` — 临时 flag（会话结束时回滚）
- `EmotionOperator` — 情感值变更
- `ImaginaryOperator` — imagenary 升级/降级
- `RandomOperator` — 概率分支
- `PropertyRangeOperator` — 属性范围守卫
- `InfoDemoOperator` — toast 提示

**不允许的操作**：
- ❌ 任何"初始化"语义的 operator（`set` flag 给后续同一选项的其他 operator 用）
- ❌ 如果发现 `FlagOperator(operation="set")` 出现在 choice_result 中，且其 flag_id 被同一 choice_result 的后序 operator 依赖，应该提升到 `event_result`

---

### 9.6 契约对照表：当前代码库现状

| 场景 | 当前实现位置 | 是否符合三层契约 |
|------|------------|----------------|
| `event_result` 中的 FlagOperator(set) 初始化 flag | [`RandomEvent.init()`](../../model/random_event.gd:59) → `event_result.operate()` | ✅ 正确——事件层初始化 |
| `choice_result` 中的 FlagOperator(consume) 消耗 flag | [`ChoiceResult.operate()`](../../model/choice_result.gd:6) | ✅ 正确——选项层因果 |
| `custom_context_params` 注入 context | [`RandomEvent.init()`](../../model/random_event.gd:53-54) | ✅ 正确——事件层置景 |
| `requirement` 检查守卫条件 | 外部 UI 层 | ✅ 正确——只读守卫 |
| `PoemTypeChooseOperator.init()` 从 context 解析 poem_taste | [`core/operators/trait_choose_operator.gd`](../../core/operators/trait_choose_operator.gd:8) | ⚠️ 边界情况——它在 `init()` 中修改了 `@export` 变量 `poem_taste`，但从语义上这是"从 context 解析参数"，不是"初始化环境" |
| `CustomEventOption.init()` 动态设置 description 和 choice_result | [`model/event/custom_event_option.gd`](../../model/event/custom_event_option.gd) | ⚠️ 边界情况——属于"选项展示前动态计算"，但严格来说应该在事件层完成 |
| `pre_event_interrupter_sequence` 在前置中断中 push_event | [`BaseEvent.check_interruption()`](../../model/event.gd:29) | ✅ 正确——特殊机制，有 first-match-wins 保护 |
| `ItemProvider` 在 `provide()` 中动态生成选项 | [`core/model/item_provider.gd`](../../core/model/item_provider.gd:32) | ✅ 正确——在事件层执行，生成的是**选项本身**，不是初始化 flag |

---

### 9.7 契约违反场景与修复

#### 场景 1：选项的 choice_result 中包含了初始化 flag 的 operator

```
❌ 违反前：
option.choice_result.operators = [
  FlagOperator(flag_id="can_drink", operation="set", value=true),   ← 初始化
  PushEventOperator(event_key="after_drinking"),                     ← 消耗
]

✅ 修复后：
event.event_result.operators = [
  FlagOperator(flag_id="can_drink", operation="set", value=true),   ← 提升到事件层
]
option.choice_result.operators = [
  PushEventOperator(event_key="after_drinking"),                     ← 选项层只保留因果
]
```

#### 场景 2：两个选项共享同一个依赖 flag

```
❌ 违反前：
option_a.choice_result = [FlagOperator(set, flag_x), ...]   ← A 负责初始化
option_b.choice_result = [...]                              ← B 依赖 flag_x

✅ 修复后：
event.event_result = [FlagOperator(set, flag_x)]            ← 共用依赖提升到事件层
option_a.choice_result = [...]
option_b.choice_result = [...]
```

#### 场景 3：requirements 中带有副作用

```
❌ 违反前：
option.requirement = CustomRequirement {
  init() {
    PlayerState.set_flag(...)     ← 守卫条件中修改状态！
  }
}

✅ 修复后：
event.event_result = [FlagOperator(set, flag_x)]
option.requirement = BaseRequirements { compare() { /* 只读 */ } }
```

#### Linter 检查建议

如果坚持要写 linter，这些是最有价值的检查点（而不是去检查"执行顺序"）：

1. **`ChoiceResult` 中的 `FlagOperator(operation="set")` 警告** — 建议检查是否应该提升到 `event_result`
2. **`BaseRequirements` 子类中的 `compare()` 是否有写操作** — 只读守卫不允许副作用
3. **`CustomEventOption.init()` 中的复杂初始化逻辑** — 检查是否应该迁移到事件层

但说实话，🤓☝️ 如果你遵守三层铁幕契约写 CSV/填表，根本不需要 linter——当你看到一个 Option 的 operators 列表里出现 `Init`、`Set`、`Prepare` 这种语义的 operator 时，你可以在 Code Review 时直接把这个 PR 驳回 💀。
