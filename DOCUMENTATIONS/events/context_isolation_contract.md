# Context 隔离契约 (Context Isolation Contract)

## 为什么要有这个契约？

在事件系统中，`context: Dictionary` 在多个层级之间传递：`NarrativeOverlay` → `BaseEvent` → `EventOption` → `BaseOperator`。**字典在 GDScript 中是引用类型**，如果不做隔离，一个环节的修改会像多米诺骨牌一样污染上游/下游的数据。

这条契约定义了 **谁持有谁的副本、谁可以改谁的数据**。违反契约的代码会在运行时产生幽灵 Bug（所有按钮都指向同一个人、退栈后数据乱套等）。

---

## 核心原则：栈帧隔离 (Stack Frame Isolation)

> 每一个被 push 到事件栈的事件，都必须拥有自己独立的 context 沙盒。

```
事件栈 (NarrativeOverlay._event_stack)
  ├── [0] 李白私宴  ← context 是独立深拷贝，改 drunkenness 不影响下面
  └── [1] 宴会 Hub  ← context 是独立深拷贝，不受上面影响
```

---

## 契约条文

### 条文 1：入栈必复制 (Push Must Copy)

**位置：** [`characters/narrative_overlay.gd:77`](../../characters/narrative_overlay.gd:77)

```gdscript
# ✅ 正确：入栈前深拷贝
_event_stack.push_front({ "data": ev, "context": context.duplicate(true) })
```

**契约：** `NarrativeOverlay._on_push_event()` **必须**对收到的 context 做 `duplicate(true)` 再入栈。

**理由：** 防御性编程。调用方（`PushEventOperator`）已经 duplicate 过了，但这是一个隐式约定——任何代码都可以 emit `push_event` 信号，我们不能假设调用方都记得做隔离。

---

### 条文 2：Operator 捕获必须快照 (Operator Must Snapshot)

**位置：** 所有 `BaseOperator` 子类的 `init()` 方法

```gdscript
# ✅ PushEventOperator / EventOperator / QueueEventOperator
func init(context: Dictionary) -> Dictionary:
    _captured_context = context.duplicate()  # 浅拷贝足够，因为 context 本身已是沙盒
    return context
```

**契约：** 所有需要在 `operate()` 时使用 context 的 Operator，必须在 `init()` 时用 `duplicate()` 保存快照。

**例外：** 不需要在 `operate()` 时使用 context 的 Operator（如 `PropertyOperator`、`FlagOperator`）可以跳过。

---

### 条文 3：Operator 不得持久化外部引用 (No External Reference Hoarding)

**位置：** [`core/operators/menu_start_operator.gd:10`](../../core/operators/menu_start_operator.gd:10)

```gdscript
# ✅ 正确：深拷贝后持有
var sandbox = context.duplicate(true)
self.context = sandbox

# ❌ 错误：直接持有外部引用
self.context = context  # 外部修改 self.context 会变成脏数据
```

**契约：** 如果一个 Operator 需要把 context 存为成员变量以备后用（如 `MenuStartOperator`），**必须** `duplicate(true)` 持有自己的副本。

**理由：** `MenuStartOperator` 的 `context` 会在 `init()` 时保存，在 `operate()` 时使用。中间可能有其他代码修改了原始 context 字典，导致 `operate()` 时拿到的是污染后的数据。

---

### 条文 4：Option Init 必须隔离 (Option Must Sandbox)

**位置：** [`model/event/event_option.gd:12`](../../model/event/event_option.gd:12)

```gdscript
func init(context: Dictionary) -> Dictionary:
    var context_ = context.duplicate()       # 第一步：创建沙盒
    Util.merge_context(context_, custom_context_params)  # 第二步：合并自定义参数
    ...
    choice_result.init(context_)              # 第三步：传递给 Operator
    return context_
```

**契约：** `EventOption.init()` **必须**对收到的 context 做 `duplicate()` 再操作。这是防止选项间 context 污染的最后一道防线。

**理由：** 多个选项共享同一个来自 `BaseEvent.init()` 的 context。如果选项 A 修改了 context（通过 `merge_context` 或直接赋值），选项 B 会看到被修改后的数据。

---

### 条文 5：BaseEvent.init 不得修改持久属性 (No Persistent Mutation)

**位置：** [`model/event.gd:10`](../../model/event.gd:10)

```gdscript
func init(context: Dictionary) -> void:
    var all_options: Array[BaseOption] = options.duplicate()  # ✅ 用临时数组
    if provider:
        var extra_options = provider.provide(context)
        if extra_options.size() > 0:
            all_options.append_array(extra_options)            # ✅ 追加到临时数组
    
    for o in all_options:  # ✅ 迭代临时数组
        o.init(context)
```

**契约：** `BaseEvent.init()` **不得**修改 `self.options`（`@export` 持久属性）。provider 生成的选项必须合并到本地临时数组中。

**理由：** 事件对象可能在游戏生命周期中被多次 `init()`（debug 触发、队列排队、重新入栈等）。每次 `init()` 都往 `options` 追加数据会导致选项累积。

---

### 条文 6：Provider 只读 Context (Provider is Read-Only)

**位置：** [`core/model/item_provider.gd:27`](../../core/model/item_provider.gd:27)

```gdscript
func init(context: Dictionary) -> Dictionary:
    # ✅ 只读：不修改 context 内容
    return context

func provide(context: Dictionary) -> Array:
    var target_list = context.get(list_key, [])  # ✅ 只读读取
    for item in target_list:
        var option = _build_option(item)         # ✅ 每个选项独立 payload
    return options
```

**契约：** Provider 的 `init()` 和 `provide()` **不得**修改传入的 context 字典。

**理由：** Provider 在 `BaseEvent.init()` 的 Phase 1/2 被调用，此时 context 还是"公共的"（尚未被 EventOption 隔离）。修改它会污染所有后续选项。

---

## 契约违反检测 (Contract Violation Detection)

如果你怀疑某个地方违反了隔离契约，按这个流程排查：

```
症状：所有按钮都指向同一个人 / context 数据乱套
  ↓
问题出在哪个环节？
  ↓
1. 检查 Operator.init() 有没有 duplicate()？
   → PushEventOperator / EventOperator 的 _captured_context 是快照吗？
   ↓ 是
2. 检查 EventOption.init() 有没有 duplicate()？
   → 看 context_ 是不是 context.duplicate() 的结果
   ↓ 是
3. 检查 NarrativeOverlay._on_push_event() 有没有 duplicate()？
   → 看存入栈的是原始引用还是深拷贝
   ↓ 是
4. 检查 MenuStartOperator 等持有引用的 Operator
   → self.context 是深拷贝还是外部引用？
```

---

## 隔离层级总览

```
NarrativeOverlay.apply_narrative(data, context)
  │  context 来自栈（已 duplicate）或 request_event（原始）
  │
  ▼
BaseEvent.init(context)
  │  ⚠️ 只读操作：不修改 context，不使用 options.append_array
  │
  ▼
EventOption.init(context)
  │  ├── context.duplicate() → context_  ← 🔒 沙盒开始
  │  ├── merge_context(context_, custom_context_params)
  │  └── choice_result.init(context_)
  │        └── operator.init(context_)
  │              ├── PushEventOperator: context.duplicate() → _captured_context 🔒
  │              ├── EventOperator: context.duplicate() → _captured_context 🔒
  │              ├── MenuStartOperator: context.duplicate(true) → self.context 🔒
  │              └── 其他 Operator: 不需要保存则跳过
  │
  ▼ 沙盒随函数结束释放
```

---

## 相关文件

| 文件 | 契约点 | 状态 |
|------|--------|------|
| [`characters/narrative_overlay.gd:77`](../../characters/narrative_overlay.gd:77) | 入栈深拷贝 | ✅ 已修复 |
| [`model/event.gd:10`](../../model/event.gd:10) | 临时数组代替 append_array | ✅ 已修复 |
| [`core/operators/menu_start_operator.gd:10`](../../core/operators/menu_start_operator.gd:10) | 深拷贝持有 | ✅ 已修复 |
| [`core/operators/push_event_operator.gd:15`](../../core/operators/push_event_operator.gd:15) | 快照捕获 | ✅ 原本正确 |
| [`core/operators/event_operator.gd:15`](../../core/operators/event_operator.gd:15) | 快照捕获 | ✅ 原本正确 |
| [`core/operators/queue_event_operator.gd:15`](../../core/operators/queue_event_operator.gd:15) | 快照捕获 | ✅ 原本正确 |
| [`model/event/event_option.gd:12`](../../model/event/event_option.gd:12) | 沙盒隔离 | ✅ 原本正确 |
| [`core/model/item_provider.gd:32`](../../core/model/item_provider.gd:32) | 只读 context + 循环内创建 payload | ✅ 原本正确 |
