# player_observer — 资源消耗观测系统

## 相关文件

| 文件 | 角色 |
|------|------|
| [`core/player_observer.gd`](../../core/player_observer.gd) | 新 autoload，监听信号、分桶存储 |
| [`core/player_state.gd`](../../core/player_state.gd) | 新增 cost context 栈方法 |
| [`ui/main_action_button.gd`](../../ui/main_action_button.gd) | 父 action cost 前 push/pop context |
| [`core/sub_action_executor.gd`](../../core/sub_action_executor.gd) | 子 action cost 前 push/pop context |
| [`project.godot`](../../project.godot) | autoload 注册 |

## 想要实现的效果

追踪每一次行动消耗的资源，按身份（action uuid 或 topic）分桶存储，支持双向查询：
- 从 identity 查消耗了什么资源（`consumption_by_identity`）
- 从资源查被哪些 topic 消耗了多少（`resource_to_topic`）

## 数据结构

```
consumption_by_identity: { identity: { prop: abs_delta } }
resource_to_topic:       { prop: { topic: abs_delta } }
```

## 状态转换

1. **无 cost 场景**：不推 context → `get_current_cost_context()` 返回空 → PlayerObserver 忽略所有变更
2. **父 action（无子行动）**：`push(action.uuid)` → cost 执行 → `pop()`
3. **子 action，有 topic**：`push(sub_action.topic)` → cost 执行 → `pop()`
4. **子 action，无 topic**：`push(sub_action.uuid)` → cost 执行 → `pop()`

## 注入点

- `MainActionButton._on_clicked()` — cost archetype init/operate 前后
- `SubActionExecutor.execute()` — cost archetype init 前 push，operate 后 pop

## 核心架构

PlayerObserver 作为 autoload，在 `_ready()` 中延迟连接 `PlayerState.before_property_change`。仅记录 `delta < 0` 且有活跃 context 的变更。`consumption_by_identity` 和 `resource_to_topic` 各自独立累加，不互斥。
