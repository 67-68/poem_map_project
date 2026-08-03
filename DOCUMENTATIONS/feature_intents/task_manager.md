# Task Manager 模块

## 涉及文件

| 文件 | 类型 | 说明 |
|------|------|------|
| [`core/model/task.gd`](core/model/task.gd) | 新增 | Task 数据模型（继承 GameEntity），INACTIVE/ACTIVE/COMPLETED 状态机 |
| [`core/task_manager.gd`](core/task_manager.gd) | 新增 | TaskManager Autoload，signal-driven 守卫扫描引擎 + 持久化 |
| [`core/operators/set_task_operator.gd`](core/operators/set_task_operator.gd) | 新增 | SetTaskOperator（4种模式：REPLACE_ROOT/CURRENT/APPEND/CHAIN_AFTER_PARENT）|
| [`core/operators/clear_task_operator.gd`](core/operators/clear_task_operator.gd) | 新增 | ClearTaskOperator |
| [`ui/task_container.gd`](ui/task_container.gd) | 新增 | TaskContainer UI 控件（4 个 LinkButton 全部支持 BELOW_OVERLAY hover + 闪烁动画 + task.name 经 tr() 翻译）|
| [`ui/task_container.tscn`](ui/task_container.tscn) | 修改 | 重命名 Task2→CurrentTask，挂载 task_container.gd 脚本 |
| [`core/eventbus.gd`](core/eventbus.gd) | 修改 | 新增 `task_completed(task)` + `task_state_changed()` 信号 |
| [`core/model/game_save_data.gd`](core/model/game_save_data.gd) | 修改 | 新增 `task_state: Dictionary` 字段 + to_dict/from_dict |
| [`project.godot`](project.godot) | 修改 | 注册 TaskManager Autoload |

## 设计意图

基于守卫条件（BaseRequirements）+ 完成奖励（BaseOperator[]）的任务树系统。属性/状态变化时自动检测守卫，通过后执行奖励。

## 核心概念

### 任务树结构（2层实际限制，理论支持N层）
```
Root（虚拟）
 ├─ ParentA ─chain_next→ ParentB ─chain_next→ ParentC
 │    ├─ Child1
 │    └─ Child2
```

### 生命周期
INACTIVE → ACTIVE（父激活时自动激活子）→ COMPLETED（requirements全通过 + children全完成 → 执行operators）

### 守卫检测触发时机
PlayerState.player_stat_changed / stay_place_changed / EventBus.on_trait_change / on_flag_change / imaginary_changed / event_confirmed

### SetTaskOperator 四种模式
REPLACE_ROOT / REPLACE_CURRENT / APPEND_TO_CHILDREN / CHAIN_AFTER_PARENT

### UI 四个显示字段（均经 tr() 翻译，均支持 hover）
- ParentTask：parent ≠ null 时显示父任务名，hover 展示详情
- CurrentTask：当前最深未完成任务，hover 展示详情
- TaskPrev：最近完成的任务（划掉效果），hover 展示详情
- TaskFuture：下一个兄弟 或 chain_next，hover 展示详情

### 完成闪烁动画
文字消失 + 背景变白同时发生（0.15s parallel），然后更新文字并恢复（0.15s parallel）

### 持久化
GameSaveData.task_state 存 root_task_uuids + 每task的uuid/status/parent/children/chain_next + last_completed_uuid
