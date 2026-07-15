# Picker 重构 — SubActionPicker / ItemPicker 拆分

## 背景

`zhengqian_poem_exchange` NPC 行动执行时，`PoemRewardOperator` 调用 `EventBus.push_picker` 把选诗 Picker 推入栈，紧接着 `SubActionExecutor.scan_events` 又把 fallback 事件推入队列，造成**双推栈冲突**。用户看到 fallback 事件（空选项）后 POEM Picker 才出现，表现为"点击行动没有反馈"。

## 修复

### 信号拆分

合并信号 `EventBus.push_picker(data, on_selected, ui_constructor, on_filter_toggled)` 被拆分为两个独立信号：

| 信号 | 参数 | 用途 |
|------|------|------|
| `push_sub_action_picker(data, on_selected, ui_constructor, on_filter_toggled)` | 4 参数（不变） | MainActionButton 弹出子行动选择（双栏布局） |
| `push_item_picker(data, on_selected)` | 2 参数（简化） | Operator 弹出物品/诗词/意象选择（简易列表） |

### 新增 ItemPickerTapeAttachment

全新 `ui/item_picker_tape_attachment.gd` — 简易物品选择器：
- 单栏卡片列表（非 toggle，点选高亮）
- 确认按钮 + 不回答按钮
- 支持任意 `Resource` 类型（Poem / Trait / 等）
- emit `item_selected(item: Resource)` / `cancelled()`

### NarrativeDirector 拆分

- `picker_ready` → `sub_action_picker_ready` + `item_picker_ready`
- `_on_push_picker` → `_on_push_sub_action_picker` + `_on_push_item_picker`
- `_process_next` 分别处理 `sub_action_picker` / `item_picker` 类型

### SubActionExecutor 保护

`action_results` 含 `PoemRewardOperator` / `PoemTypeChooseOperator` / `ImaginaryLevelRewardOperator` / `LianjuScoreOperator` 时跳过 `scan_events`，防止双推栈冲突。

## 受影响文件

| 文件 | 操作 |
|------|------|
| `ui/picker_tape_attachment.gd` | class_name → SubActionPickerTapeAttachment |
| `ui/picker_tape_attachment.tscn` | node name 更新 |
| `ui/item_picker_tape_attachment.gd` | **新建** |
| `ui/item_picker_tape_attachment.tscn` | **新建** |
| `core/eventbus.gd` | push_picker → push_sub_action_picker + push_item_picker |
| `characters/narrative_director.gd` | 拆信号 + 拆处理 + 更新类型检查 |
| `characters/narrative_overlay.gd` | 拆 _on_picker_ready → 两个方法 |
| `characters/event_ui.gd` | append_picker_attachment → append_sub_action_picker_attachment + append_item_picker_attachment |
| `ui/main_action_button.gd` | push_picker → push_sub_action_picker |
| `core/operators/poem_reward_operator.gd` | push_picker → push_item_picker |
| `core/operators/trait_choose_operator.gd` | push_picker → push_item_picker |
| `core/operators/imaginary_level_reward_operator.gd` | push_picker → push_item_picker |
| `core/operators/lianju_score_operator.gd` | push_picker → push_item_picker |
| `core/sub_action_executor.gd` | 推栈 operator 时跳过 scan_events |
| `core/_export_dependency_anchor.gd` | 添加 item_picker 预加载 |
