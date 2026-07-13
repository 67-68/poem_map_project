# Remote Action Filter (异地行动过滤)

## 设计意图

统一管理「行动/子行动是否可在当前驻留地点执行」的判断逻辑，为 `ActionPanel`（主行动面板）和 `PickerTapeAttachment`（子行动选择器）提供单一真相源。

用户通过 CheckBox「显示异地行动」控制是否展示需要跨地点执行的行动：
- **默认未勾选**：主行动面板只展示至少有一个子行动在当前地点可用的父行动；子行动选择器中隐藏异地子行动
- **勾选后**：展示所有行动（不受地点限制）；异地的子行动以淡蓝色标记

## 核心类

- `core/remote_action_filter_manager.gd` — RefCounted 静态工具类，提供过滤判断方法 + 共享状态 `show_remote_actions`

## 状态模型

```
RemoteActionFilterManager.show_remote_actions: bool (static, default=false)
  → set_show_remote(value) → EventBus.remote_actions_filter_changed.emit(value)
  → ActionPanelManager 监听 → _rebuild_all_buttons()
  → PickerTapeAttachment 监听 → 同步 CheckBox + 刷新 item 显隐
```

## 过滤规则

| 方法 | 输入 | 返回 | 规则 |
|------|------|------|------|
| `is_local_action(action, place)` | Action + 当前地点 | bool | `required_place` 为空 → true；匹配当前地点 → true |
| `is_remote_action(action, place)` | Action + 当前地点 | bool | `required_place` 非空且不匹配 → true |
| `has_local_sub_actions(action, place)` | 父 Action + 当前地点 | bool | 无子行动 → true；遍历子行动，任一 `is_local_action` → true |

## 消费方

1. [`ActionPanelManager`](ui/action_panel_manager.gd) — `_rebuild_all_buttons()` 中，未勾选时调用 `has_local_sub_actions()` 过滤父行动按钮
2. [`PickerTapeAttachment`](ui/picker_tape_attachment.gd) — `initialize()` 和 CheckBox toggle 中，调用 `is_entity_remote()` 判断子行动是否异地
3. [`SceneActionPanel`](ui/action_button.gd) — 构建 picker data 时，调用 `is_remote_action()` 替代内联的地点校验

## CheckBox 生命周期

- ActionPanel 的 CheckBox 由 `ActionPanelManager` 在 `_ready()` 中动态创建，放在 `_container`（V）之前
- 不受 `_clear_container()` 影响（只清除 `SceneActionPanel` 实例）
- Era 切换 / `_rebuild_all_buttons()` 后 CheckBox 状态保留

## 相关文件

- `core/remote_action_filter_manager.gd` — 管理器（本模块核心）
- `ui/action_panel_manager.gd` — ActionPanel 过滤 + CheckBox
- `ui/picker_tape_attachment.gd` — Picker 过滤
- `ui/action_button.gd` — picker data 构建中使用 manager
- `core/eventbus.gd` — 新增 `remote_actions_filter_changed` 信号
