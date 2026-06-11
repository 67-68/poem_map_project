# Lock → Reserve 两阶段过渡模式

## 问题描述

有些游戏流程需要"锁住"某个行动，迫使玩家执行它；在某个故事节点之后再"释放"——但该行动仍然需要每回合保证出现（reserve），只是不再阻止其他行动。

## 架构

### 数据结构

| 机制 | 数据结构 | 持久性 | 作用 |
|------|---------|--------|------|
| `_locked_in_actions` | `Dictionary[action_id → xun_duration]` | 跨回合 | 锁定行动，自动预留每回合 |
| `_reserved_action_ids` | `Array[String]` | 本回合 | 即时预留，pick 后清空 |

### 两阶段流程

```
Phase 1（初始）:
  LockActionsOperator.operate()
    ├── ActionManager.lock_action(BAI_YE)
    │   └── _locked_in_actions["bai_ye"] = -1
    │   └── reserve_action("bai_ye")  # 本回合立即生效
    └── EventBus.selected_actions_change.emit([bai_ye_only])
        └── ActionMap: 禁用所有按钮，只启用 bai_ye ✅

事件链: event_intro_745 → event_ambition_start → event_first_blood_right_prime

Phase 2（event_ambition_start 之后）:
  RefreshActionPanelOperator.operate()
    └── EventBus.request_refresh_action_panel.emit()
        └── SceneActionScroll.refresh()
            ├── get_available_scene_actions()
            │   └── _locked_in_actions 自动预留 bai_ye ✅
            ├── pick_top_actions() → [bai_ye + 5 others]
            └── selected_actions_change.emit([all 6])
                └── ActionMap: 启用全部 6 个按钮 ✅
```

### 关键文件

| 文件 | 作用 |
|------|------|
| [`core/action_manager.gd`](../core/action_manager.gd) | 核心数据结构和锁定/预留逻辑 |
| [`core/operators/lock_actions_operator.gd`](../core/operators/lock_actions_operator.gd) | Phase 1 锁定操作符 |
| [`core/operators/refresh_action_panel_operator.gd`](../core/operators/refresh_action_panel_operator.gd) | Phase 2 触发 UI 刷新 |
| [`ui/scene_action_scroll.gd`](../ui/scene_action_scroll.gd) | 行动面板刷新入口 |
| [`world/action_map.gd`](../world/action_map.gd) | 大地图按钮启用/禁用逻辑 |
| [`core/eventbus.gd`](../core/eventbus.gd) | 信号总线（含 `request_refresh_action_panel`） |

### Signal 流转

```
RefreshActionPanelOperator
  └── EventBus.request_refresh_action_panel
      └── SceneActionScroll.refresh()
          ├── ActionManager.get_available_scene_actions()
          │   └── _locked_in → auto-reserve ✅
          ├── ActionManager.pick_top_actions()
          └── EventBus.selected_actions_change (all 6)
              └── ActionMap._on_selected_actions_changed
                  └── 启用所有匹配按钮 ✅
```

## 注意事项

1. **不要同时用 `LockActionsOperator` + `RefreshActionPanelOperator` 在同一事件中**。如果需要在锁定的同时刷新 UI，它们会互相覆盖。
2. **`RefreshActionPanelOperator` 只修复 UI，不修改 ActionManager 数据**。它依赖 `_locked_in_actions` 已在之前的事件操作符中正确设置。
3. **Phase 2 中 bai_ye 仍然在 `_locked_in_actions` 中**。这意味着它每回合自动预留（占 1/6 槽位），且如果有冲突操作符（如 `BlockActionOperator`），lock 的优先级高于 block。
4. **如果你需要完全取消 lock 语义**（从 `_locked_in_actions` 移除），需要在 `event_ambition_start.tres` 中使用 `UnlockActionsOperator` + 一个新的持久化预留机制（如 `_always_reserved_actions`），不能仅靠 `RefreshActionPanelOperator`。
