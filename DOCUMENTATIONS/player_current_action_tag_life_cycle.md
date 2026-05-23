根据代码分析，`current_action_tags` 的生命周期如下：

## 🎯 设计意图：临时标签

**理论上**，`current_action_tags` 是一个**临时标签池**，用于单次事件扫描，用完即弃。

## 🔄 实际生命周期流程

### 1. **设置点**（注入标签）
- **执行Action时**（<<ref_file file="/Users/lennon/Projects/poem_map_project/ui/scene_action_panel.gd" line="21" />）：
  ```gdscript
  PlayerState.current_action_tags.append_array(action.action_tags)
  EventManager.scan_events(0)
  ```
- **时间流逝时**（<<ref_file file="/Users/lennon/Projects/poem_map_project/core/model/time_operator.gd" lines="13-16" />）：
  ```gdscript
  PlayerState.current_action_tags = source_tags
  TimeService.advance_time(int(day))
  PlayerState.current_action_tags.clear()
  ```
- **死亡判定时**（<<ref_file file="/Users/lennon/Projects/poem_map_project/core/survival_manager.gd" line="26" />）：
  ```gdscript
  PlayerState.current_action_tags.append('actor:health:death:general')
  EventManager.scan_death_events()
  ```
- **制作诗词时**（<<ref_file file="/Users/lennon/Projects/poem_map_project/ui/poem_crafter.gd" line="127" />）：
  ```gdscript
  PlayerState.current_action_tags.append(tag)
  EventManager.scan_poem_events(imas)
  ```

### 2. **清除点**（释放标签）
- **事件扫描Filter后**（<<ref_file file="/Users/lennon/Projects/poem_map_project/core/model/action_tag_filter.gd" line="43" />）：
  ```gdscript
  PlayerState.current_action_tags.clear()
  ```
- **时间操作完成后**（<<ref_file file="/Users/lennon/Projects/poem_map_project/core/model/time_operator.gd" line="16" />）：
  ```gdscript
  PlayerState.current_action_tags.clear()
  ```

### 3. **保证清除的机制**
所有的`scan_xxx_events`方法都会调用`scan_events_from_tickets`，而这个方法会按顺序执行所有filters（包括`ActionTagFilter.filter`），确保标签在每次事件扫描后被清除。

## ⚠️ 潜在风险

**关键问题**：`current_action_tags`被声明为`@export var`（<<ref_file file="/Users/lennon/Projects/poem_map_project/core/player_state.gd" line="11" />）：

```gdscript
@export var current_action_tags: Array[String] = []
```

这意味着：
1. **序列化残留**：标签会被持久化到存档文件
2. **异常流程风险**：如果在设置标签后、filter执行前游戏崩溃/存档，下次加载时会有残留标签
3. **污染后续流程**：残留的标签会影响下一次事件扫描的结果

## 💡 建议

如果你想要彻底的临时性，应该：
- 移除`@export`，改为普通变量：`var current_action_tags: Array[String] = []`
- 或者在每次设置前显式`clear()`，确保不会累积

当前的设计虽然大部分情况下能正常工作，但存在**时序依赖的风险** 💀。如果某次事件扫描流程被中断，标签就会像幽灵一样一直存在下去 😨。