# Action Button 继承链重构 & Picker 选择/执行解耦

## 设计意图

将 [`SceneActionPanel`](ui/action_button.gd) 从"巨型管线控制器"降级为"纯 UI 渲染基类"，拆分出三个子类各司其职。同时将 Picker 的子行动选择和执行解耦：左栏 Toggle 按钮仅改变选中状态，右栏确认按钮触发执行。

## 继承链

```
SceneActionPanel (action_button.gd) — 纯UI渲染基类，extends Button
├── MainActionButton (main_action_button.gd) — 父行动完整执行管线
├── SubActionButton (sub_action_button.gd) — Toggle Mode 选择器
└── NpcActionButton (npc_action_button.gd) — 确认执行按钮
```

## 核心类

### [`VolatileState`](core/volatile_state.gd)

新增 autoload（排在 `PlotController` 之后），内部类 [`VolatileActionState`](core/volatile_state.gd:18) 承载一整个 action 树的共享挥发性状态：

| 字段 | 写入方 | 读取方 |
|------|--------|--------|
| `selected_sub_action_uuid` | SubActionButton (toggle) | NpcActionButton |
| `selected_entity_place_mismatch` | SubActionButton | SubActionExecutor |
| `selected_entity_required_place` / `_name` | SubActionButton | SubActionExecutor |
| `pending_main_tag` / `pending_fallback` / `pending_tags` / `pending_results` / `pending_day_consumed` / `pending_outcome` | MainActionButton | SubActionExecutor |
| `pending_on_checkbox_toggled` | MainActionButton | PickerTapeAttachment |
| `did_auto_enable_remote` | MainActionButton | MainActionButton |

### [`SubActionExecutor`](core/sub_action_executor.gd)

静态类，从原 [`_on_sub_action_picked`](ui/action_button.gd) 提取的完整子行动执行管线：

```
execute(selected_uuid, state)
  → 异地移动（TimeService.advance_time(1) + stay_place 切换）
  → 查找 sub_action
  → 重复行动检测
  → cost archetype init/operate
  → action_results init
  → possibility 投骰
  → 时间消耗
  → 成功: scan_events + defer 启动
  → 失败: failed_result.operate()
  → 更新 last_action_tags
  → state.clear()
```

## 数据流

```
MainActionButton._on_clicked()
  → cost init/operate → possibility 投骰
  → 写入 VolatileState.action_state.pending_*
  → EventBus.push_picker(data, _on_sub_action_picked, null, on_checkbox_toggled)
  
PickerTapeAttachment.initialize()
  → 左栏: 动态创建 SubActionButton × N + ButtonGroup
  → 右栏: 动态创建 NpcActionButton × 1
  → NpcActionButton.execution_completed → item_selected

SubActionButton._on_clicked()
  → 写入 VolatileState.selected_sub_action_uuid + 异地信息

NpcActionButton._on_clicked()
  → 读取 VolatileState.selected_sub_action_uuid
  → SubActionExecutor.execute(uuid, state)
  → 发射 execution_completed → Picker 发射 item_selected

MainActionButton._on_sub_action_picked() → _pop_auto_remote_override()
```

## 变更文件清单

### 新建
- [`core/volatile_state.gd`](core/volatile_state.gd) — VolatileState autoload
- [`core/sub_action_executor.gd`](core/sub_action_executor.gd) — 静态子行动执行器
- [`ui/main_action_button.gd`](ui/main_action_button.gd) — 主行动按钮
- [`ui/main_action_button.tscn`](ui/main_action_button.tscn) — 外观与 action_button.tscn 完全一致
- [`ui/sub_action_button.gd`](ui/sub_action_button.gd) — 子行动选择器
- [`ui/npc_action_button.gd`](ui/npc_action_button.gd) — NPC 确认执行按钮

### 修改
- [`project.godot`](project.godot:49) — 注册 VolatileState autoload
- [`ui/action_button.gd`](ui/action_button.gd) — 降级为纯 UI 渲染基类
- [`ui/smaller_action_button.tscn`](ui/smaller_action_button.tscn:5) — 脚本指向 sub_action_button.gd
- [`ui/npc_action_button.tscn`](ui/npc_action_button.tscn:11) — 挂载 npc_action_button.gd 脚本
- [`ui/picker_tape_attachment.tscn`](ui/picker_tape_attachment.tscn) — 删除硬编码按钮实例
- [`ui/picker_tape_attachment.gd`](ui/picker_tape_attachment.gd) — 动态创建双栏按钮
- [`ui/action_panel_manager.gd`](ui/action_panel_manager.gd:154) — action_button.tscn → main_action_button.tscn

### 未修改
- [`ui/decision_scroll.gd`](ui/decision_scroll.gd:90) — 继续使用 action_button.tscn（基类足够处理 Decision）
- [`picker_item.gd`](picker_item.gd) / [`picker_item.tscn`](picker_item.tscn) — 保留但不再被 PickerTapeAttachment 使用
