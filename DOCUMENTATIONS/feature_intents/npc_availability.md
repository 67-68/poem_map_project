# NPC 天数可用性系统

## 设计意图
NPCDocument 新增 `appear_days: Array[int]` 字段，声明每个 NPC 在一旬中的哪些天出现（0~9）。NPCAvailabilityManager + NPCSelector 封装 NPC 选择与天数过滤逻辑，原有 PickNpcOperator / PickNpcByPlaceOperator 委托给 NPCSelector 消除重复代码。无候选 NPC 时设置 `Action.dynamic_possibility = 0` 让投骰必失败，复用失败路径。

## 涉及文件
- [`model/npc_document.gd`](model/npc_document.gd) — 新增 `appear_days: Array[int]`（空数组=始终可用）
- [`core/npc_availability_manager.gd`](core/npc_availability_manager.gd) — **新建**：`NPCAvailabilityManager`，静态 `is_available(npc_doc, day) → bool`
- [`core/npc_selector.gd`](core/npc_selector.gd) — **新建**：`NPCSelector`，静态 `select_by_place/random/related`，内部调用 `NPCAvailabilityManager`
- [`core/operators/pick_npc_operator.gd`](core/operators/pick_npc_operator.gd) — 三种 `_pick_xxx()` 委托给 `NPCSelector`；无候选时 `context["current_action"].dynamic_possibility = 0`
- [`core/operators/pick_npc_by_place_operator.gd`](core/operators/pick_npc_by_place_operator.gd) — 委托给 `NPCSelector.select_by_place()`；无候选时同上
- [`ui/action_button.gd`](ui/action_button.gd) — 执行顺序重排：cost → `action_results.init(context["current_action"]=action)` → 读 `dynamic_possibility` → 投骰 → `operate()`。sub-action 路径同理
- [`core/_export_dependency_anchor.gd`](core/_export_dependency_anchor.gd) — 新增两个 preload

## 数据流

### 非 sub-action 路径
```
action_button._on_button_pressed()
  Step 1: Cost ops (init+operate)
  Step 2: action_results.init(context["current_action"]=action)
           └─ PickNpcOperator.init() → NPCSelector → NPCAvailabilityManager.is_available(doc, TimeService.current_day)
                ├─ 可用 → context["npc_target"] = tag
                └─ 不可用 → action.dynamic_possibility = 0, context["npc_target"] = ""
  Step 3: effective_possibility = dynamic_pos_set ? dynamic_possibility : get_possibility_int()
  Step 4: 投骰 (0 → 必败 → failed_result.operate() 推送失败事件)
  Step 5: action_results.operate() (仅 tag 注入) → scan_events
```

### Sub-action 路径
```
action_button._on_sub_action_picked()
  Step 1: sub-action Cost ops
  Step 2: sub_action.action_results.init(context["current_action"]=sub_action)
  Step 3: effective_possibility = dynamic_pos_set ? dynamic_possibility : get_possibility_int()
  Step 4: 投骰
  Step 5: 父 operators.operate() → 时间消耗 → scan_events
```

## 核心规则
1. `appear_days` 值域 0~9（对应 `TimeService.current_day` = `_total_days_elapsed % 10`）
2. 空数组 = 始终可用（向后兼容，现有 NPC 不受影响）
3. `dynamic_possibility = 0` → 投骰必失败 → 走 `action.failed_result.operate()`（`PushEventOperator` 推送失败叙事）
4. `dynamic_possibility` 优先于配置值：`dynamic_pos_set ? dynamic_possibility : get_possibility_int()`
5. 选择阶段在 `init()` 完成，`operate()` 仅在成功路径注入 NPC tag 和 social tag
