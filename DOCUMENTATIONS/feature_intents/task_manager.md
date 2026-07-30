# Task Manager 模块

## 涉及文件

| 文件 | 类型 | 说明 |
|------|------|------|
| [`core/model/task.gd`](core/model/task.gd) | 新增 | Task 数据模型（继承 GameEntity） |
| [`core/task_manager.gd`](core/task_manager.gd) | 新增 | TaskManager Autoload |
| [`core/operators/set_task_operator.gd`](core/operators/set_task_operator.gd) | 新增 | SetTaskOperator（4种模式） |
| [`core/operators/clear_task_operator.gd`](core/operators/clear_task_operator.gd) | 新增 | ClearTaskOperator |
| [`core/eventbus.gd`](core/eventbus.gd:180) | 修改 | 新增 `task_completed(task)` 信号 |
| [`project.godot`](project.godot:54) | 修改 | 注册 TaskManager Autoload |

## 设计意图

提供一个基于守卫条件（`BaseRequirements`）+ 完成奖励（`BaseOperator[]`）的任务树系统。任务在玩家属性/状态变化时自动检测守卫条件，条件满足后自动执行奖励并标记完成。

## 核心概念

### 任务树结构（2层实际限制，理论支持N层）

```
Root（虚拟，不存在）
 ├─ ParentA ──chain_next──→ ParentB ──chain_next──→ ParentC
 │    ├─ Child1（必须先完成）
 │    └─ Child2
```

### 任务生命周期状态

```
INACTIVE → ACTIVE（父任务激活时自动激活子任务）
ACTIVE → COMPLETED（所有requirements通过 + children全完成 → 执行operators）
COMPLETED → 终态
```

### 守卫检测触发时机

TaskManager 连接以下信号，任意信号触发时扫描所有 ACTIVE 任务：

- `PlayerState.player_stat_changed`
- `PlayerState.stay_place_changed`
- `EventBus.on_trait_change`
- `EventBus.on_flag_change`
- `EventBus.imaginary_changed`
- `EventBus.event_confirmed`（事件结果落地后）

### SetTaskOperator 四种模式

| 模式 | 行为 | DSL用法 |
|------|------|---------|
| `REPLACE_ROOT` | 清除整棵任务树，新Task成为唯一根节点 | `set_task(task=X;mode=REPLACE_ROOT)` |
| `REPLACE_CURRENT` | 新Task顶替当前最深层活跃节点 | `set_task(task=X;mode=REPLACE_CURRENT)` |
| `APPEND_TO_CHILDREN` | 新Task追加到当前父节点的children末尾 | `set_task(task=X;mode=APPEND_TO_CHILDREN)` |
| `CHAIN_AFTER_PARENT` | 新Task追加到当前节点的根级祖先所在父队列末尾 | `set_task(task=X;mode=CHAIN_AFTER_PARENT)` |

### 完成逻辑

1. 找到当前最深层叶子节点（children全COMPLETED的ACTIVE任务）
2. 检测 `requirements` 是否全部通过（`req.compare(PlayerState)`）
3. 通过 → 按序执行 `operators` → 标记 `COMPLETED`
4. 向上递归检查父任务
5. 根级任务完成时激活 `chain_next`

## 技术架构（≤100字）

Task extends GameEntity（.tres序列化），运行时引用由TaskManager Autoload管理。SetTaskOperator/ClearTaskOperator通过TaskManager.set_task()/clear_task()修改树状态。守卫扫描是signal-driven的递归找叶子→检测→完成→向上冒泡。
