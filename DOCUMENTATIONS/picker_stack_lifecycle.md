# Picker 栈生命周期文档

> 本文档解释了 `PoemTypeChooseOperator` (Picker) 在 NarrativeOverlay 栈系统中的完整生命周期、调用链、以及预期的测试行为。

---

## 1. 核心概念：事件栈（LIFO）设计

[`NarrativeOverlay`](characters/narrative_overlay.gd) 维护两个优先级队列：

| 容器 | 顺序 | 用途 |
|------|------|------|
| `_event_stack` | LIFO（栈顶优先） | 中断事件、子事件（由 PushEventOperator 推入） |
| `_event_queue` | FIFO（入队顺序） | 普通排队事件（当 `_is_active` 时的后备） |

**栈的契约（关键设计）**：

- **Peek，不 Pop**：事件被 peek（读取栈顶）后显示给玩家，但不移除。事件从栈中移除的唯一方式是：
  - `PopEventOperator` 显式 pop
  - Picker 条目完成后的自销毁（`_on_end_picking` 中 pop picker 自己）
- **栈 > 队列**：只要栈非空，优先处理栈事件；栈空才处理队列。

这意味着：一个事件被推入栈后，会一直留在栈中，直到被显式 pop。

---

## 2. Picker 的定位

Picker 不是事件，它是**事件的一个临时模态子层**。

```
栈状态:
┌─────────────┐
│  Picker      │  ← 模态层，完成后自销毁
├─────────────┤
│  事件 B      │  ← 触发 picker 的源事件，显示 picker 时暂停
├─────────────┤
│  事件 A      │  ← 父事件，通过 PushEventOperator 推入事件 B
└─────────────┘
```

Picker 被实现为栈条目的一种特殊类型（`{ "type": "picker", ... }`），而非独立 UI 层。这是为了复用 `_is_active` 的防重入保护机制。

---

## 3. 完整调用链

### Phase 1: 事件展示 → 选项选择

```
用户操作 → _on_option_selected(choice_result)
  └─ _end_narrative(choice)
       ├─ 播放退场动画
       ├─ await _tween.finished
       ├─ hide()
       ├─ TimeService.resume_world()
       ├─ EventBus.event_confirmed.emit()
       │
       ├─ await ConsequenceExecuter.execute_result(choice)
       │    └─ 遍历 choice.operators，逐个调用 .operate()
       │         ├─ PushEventOperator.operate()
       │         │    └─ EventBus.push_event.emit(event_key, context)
       │         │         └─ _on_push_event():
       │         │              ├─ _resolve_event_for_stack(data) → BaseEvent
       │         │              ├─ _event_stack.push_front({ data, context, processed: false })
       │         │              └─ if not _is_active: _process_stack()
       │         │                   ← 🔒 _is_active 仍为 true，不触发
       │         │
       │         └─ ...其他 operator
       │
       ├─ _is_active = false  ← 🚩 execute_result 完成后才释放
       │
       ├─ imaginary_manager.add_imagenary(_completed_data)
       │
       └─ _process_next()
            └─ _process_stack()
                 ├─ peek _event_stack[0]
                 ├─ entry["processed"] = true
                 └─ apply_narrative(entry.data, entry.context)
                      ├─ _is_active = true
                      ├─ data.init(context) → all_options
                      └─ 展示事件 UI
```

### Phase 2: 触发 Picker

```
用户点击「触发 Picker」按钮
  └─ _on_option_selected(choice_result)
       └─ _end_narrative(choice)
            ├─ 退场动画...
            │
            ├─ execute_result(choice):
            │    ├─ PoemTypeChooseOperator.operate()
            │    │    ├─ 收集 PlayerState 中 topic == "POEM" 的 trait
            │    │    └─ EventBus.push_picker.emit(data, _on_trait_picked, null)
            │    │         └─ _on_push_picker(data, on_selected, ui_constructor)
            │    │              ├─ _event_stack.push_front({ type: "picker", data, on_selected, ui_constructor })
            │    │              └─ if not _is_active: _process_stack()
            │    │                   ← 🔒 _is_active 仍为 true，不触发
            │    │
            │    └─ TempFlagOperator.operate()
            │         └─ flag "temp_picker_triggered" = true
            │
            ├─ _is_active = false
            └─ _process_next()
                 └─ _process_stack()
                      ├─ peek _event_stack[0]
                      ├─ entry.type == "picker" → _show_picker_from_stack(entry)
                      ├─ _is_active = true
                      └─ EventBus.start_picker.emit(data, ui_constructor)
                           └─ picker.gd → 展示 UI
```

### Phase 3: Picker 完成

```
用户在 Picker 中选择一个 trait
  └─ picker.gd 发射 EventBus.end_picking.emit(selected_entity)
       └─ _on_end_picking(entity)
            ├─ 校验栈顶是 picker 条目
            ├─ _event_stack.pop_front()  ← ✅ 只 pop picker 自己
            ├─ callback.call(entity)     ← 执行 _on_trait_picked
            │    ├─ 检查 level、poem_type
            │    └─ 执行 accepted/rejected/not_entered_result.operate()
            │
            ├─ 🚩 注意：不自动 pop 源事件
            │   源事件（事件 B）保留在栈顶，由 _process_next() 重新展示
            │   源事件的后续生命周期由其自身的 PopEventOperator 管理
            │
            ├─ TimeService.resume_world()
            ├─ _is_active = false
            └─ _process_next()
                 └─ _process_stack()
                      ├─ peek _event_stack[0]  ← 事件 B
                      ├─ entry["processed"] = true
                      └─ apply_narrative(事件 B)
                           ← 事件 B 重新展示，选项根据 flag 状态重新计算
```

### Phase 4: 返回父事件

```
事件 B 重新展示后：
  - 「触发 Picker」按钮:
      requirement: flag "temp_picker_triggered" NOT_EQUAL true
      → flag now = true → 按钮 DISABLED ✅
  - 「返回」按钮:
      requirement: flag "temp_picker_triggered" EQUAL true
      → flag now = true → 按钮 ENABLED ✅

用户点击「返回」
  └─ _end_narrative(choice)
       ├─ execute_result():
       │    └─ PopEventOperator.operate()
       │         └─ EventBus.pop_event.emit()
       │              └─ _on_pop_event()
       │                   ├─ _event_stack.pop_front()  ← pop 事件 B
       │                   ├─ Logging.err 如果 processed == false
       │                   └─ if not _is_active: _process_next()
       │
       └─ _process_next()
            └─ _process_stack()
                 ├─ peek _event_stack[0]  ← 事件 A（仍留在栈中）
                 ├─ entry["processed"] = true
                 └─ apply_narrative(事件 A)
```

---

## 4. 竞态保护机制

### `_is_active` 锁

[`_end_narrative()`](characters/narrative_overlay.gd:304) 中的 `_is_active` 控制：

```
❌ 错误（修复前）:
  _is_active = false  ← execute_result 之前释放
  await execute_result(choice)
      ├─ PushEventOperator.operate() → _on_push_event()
      │    → if not _is_active: _process_stack()  → 触发！竞态！
      └─ ...

✅ 正确（修复后）:
  await execute_result(choice)
      ├─ PushEventOperator.operate() → _on_push_event()
      │    → if not _is_active: _process_stack()  → _is_active=true，跳过 ✅
      └─ ...
  _is_active = false  ← execute_result 完成后才释放
  _process_next()
```

这防止了 operator 迭代期间 `push_picker` 或 `push_event` 信号误触 `_process_stack`，导致新事件在 operator 迭代中途被处理。

### `processed` 标记

- 事件从栈被 `_process_stack()` 处理时：`entry["processed"] = true`
- 事件从栈被 `_on_pop_event()` 弹出时：检查 `processed`，如果 `false` 则报错

这只保护经过 `_process_stack()` 的路径，`_process_next()` 不会设 `processed` 标记。

---

## 5. 测试事件配置

### [`test_picker_chain_A`](data/tres_history_event/test_picker_chain_A.tres)

```
一个选项:
  - 描述: "推入事件 B 到栈（测试 picker 链）"
  - choice_result.operators:
      [0] PushEventOperator → event_key = "test_picker_chain_B"
  - ❌ 无 PopEventOperator
    → 事件 A 不会被自动 pop，完成测试后事件 A 回到栈顶展示
```

### [`test_picker_chain_B`](data/tres_history_event/test_picker_chain_B.tres)

```
PoemTaste:
  - uuid = "test_picker_taste"
  - accepted_result = empty
  - rejected_result = empty
  - not_entered_result = empty

选项 1: 「触发 Picker（测试栈行为）」
  requirement:
    - FlagRequirement: flag_id="temp_picker_triggered", operator=3 (NOT_EQUAL)
    - 说明：首次 flag 未设 → 通过；后续 flag 已设 → 禁用
  choice_result.operators:
    [0] PoemTypeChooseOperator → 展示 Picker
    [1] TempFlagOperator → flag_id="temp_picker_triggered", type=bool, value=true

选项 2: 「返回」
  requirement:
    - FlagRequirement: flag_id="temp_picker_triggered", operator=2 (EQUAL)
    - 说明：触发 Picker 后才可用
  choice_result.operators:
    [0] PopEventOperator → 弹出事件 B
```

### [`registry`](data/tres_history_event_registry.tres)

```gdscript
resources = {
  "test_picker_chain_A": "res://data/tres_history_event/test_picker_chain_A.tres",
  "test_picker_chain_B": "res://data/tres_history_event/test_picker_chain_B.tres"
}
```

---

## 6. 预期测试行为

### 完整场景演练

| 步骤 | 操作 | 栈状态 | 说明 |
|------|------|--------|------|
| 1 | 测试触发 → push 事件 A | `[A]` | 通过 MenuStartOperator 或外部触发 |
| 2 | 自动展示事件 A | `[A]` | `_process_stack()` peek 并显示 |
| 3 | 点击「推入事件 B」 | `[B, A]` | PushEventOperator 推入事件 B |
| 4 | 自动展示事件 B | `[B, A]` | 选项：触发 Picker（可用）/ 返回（禁用） |
| 5 | 点击「触发 Picker」 | `[Picker, B, A]` | Picker 推入栈顶，flag 设为 true |
| 6 | Picker 自动展示 | `[Picker, B, A]` | 展示可选诗词 trait |
| 7 | 选择一个 trait | `[B, A]` | Picker 自销毁，`_on_trait_picked` 执行 |
| 8 | 自动重新展示事件 B | `[B, A]` | 选项：触发 Picker（禁用✅）/ 返回（可用✅） |
| 9 | 点击「返回」 | `[A]` | PopEventOperator pop 事件 B |
| 10 | 自动重新展示事件 A | `[A]` | 测试完成 |

### 关键验证点

1. **Picker 不 pop 源事件**：步骤 7 后栈状态为 `[B, A]`，事件 B 保留
2. **Flag 正确切换**：步骤 5 设置 flag → 步骤 8 选项重算 → 触发 Picker 禁用，返回启用
3. **`_is_active` 竞态保护**：步骤 5 中 `execute_result` 期间不会触发 `_process_stack`
4. **源事件生命周期由 PopEventOperator 管理**：步骤 9 的事件 B 被显式 pop

### 常见错误

- **Picker 完成后事件 A 出现而非事件 B**：这不是 auto-pop 的 bug，而是事件 A 一直留在栈底。事件 B 被正确处理后，`_process_next()` 回到事件 A。这不是错误，是栈设计的行为（解决方案：在事件 A 的选项中加入 PopEventOperator）。
- **弹出未处理的事件报错**：如果 `processed == false` 时事件被 pop，说明该事件从未被 `_process_stack()` 处理过，可能是被推入栈后直接 pop 了，或是动画系统重播导致的二次 push。

---

## 7. 信号总线

[`EventBus`](core/eventbus.gd) 中与 Picker 相关的信号：

| 信号 | 发射者 | 接收者 | 载荷 |
|------|--------|--------|------|
| `push_picker` | `PoemTypeChooseOperator.operate()` | `NarrativeOverlay._on_push_picker()` | `data: Array, on_selected: Callable, ui_constructor` |
| `start_picker` | `NarrativeOverlay._show_picker_from_stack()` | `Picker.start_picker()` | `data: Array, ui_constructor` |
| `end_picking` | `Picker.on_selected()` / `_on_button_pressed()` | `NarrativeOverlay._on_end_picking()` | `entity: Variant` |
| `push_event` | `PushEventOperator.operate()` | `NarrativeOverlay._on_push_event()` | `data: Variant, context: Dictionary` |
| `pop_event` | `PopEventOperator.operate()` | `NarrativeOverlay._on_pop_event()` | 无 |

---

## 8. 扩展：自定义 Picker

`PoemTypeChooseOperator` 不是唯一的 picker 实现。任何 operator 都可以发射 `EventBus.push_picker` 来创建自定义 picker：

```gdscript
# 自定义 picker operator
func operate():
    var picker_data = [...]  # 任意数据
    EventBus.push_picker.emit(picker_data, _on_custom_selected, custom_ui_constructor)

func _on_custom_selected(entity):
    # 处理选择结果
    pass
```

Picker 的 `ui_constructor` 参数允许指定自定义 UI 构建函数，默认为 `Picker.default_constructor()`。
