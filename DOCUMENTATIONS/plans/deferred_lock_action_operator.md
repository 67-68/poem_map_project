# DeferredLockActionOperator 架构方案

## 需求

创建一个 `DeferredLockActionOperator`，提供一个 operator 列表，每次点击 action 消费一个，全部使用完成后锁定 action 1 旬（自动解锁）。

## 架构决策

### 数据流

```
EventOption.choice_result.operators[]
  └─ DeferredLockActionOperator.operate()
       ├─ 创建 Generator Resource
       └─ 挂载到 Action.generator

SceneActionPanel._on_button_pressed()
  ├─ action.action_results → r.operate()
  ├─ action.generator.execute_next()   ← 每次点击消费一个
  │    └─ 耗尽 → ActionManager.lock_action(action_type, 1)
  │             → action.generator = null
  └─ EventManager.scan_events()
```

### 关键设计

1. **Generator Resource**（`core/model/generator.gd`）：
   - 独立 Resource，包含 operators 列表、计数器 flag ID、action_type、uuid、name
   - `execute_next()` → 消费下一个 operator，返回 bool（true=还有剩余）
   - `is_consumed()` → 检查是否耗尽
   - 用 `PlayerState.flags` 中的 int flag 做步骤计数器（持久化兼容）
   - 耗尽时自动移除计数器 flag

2. **Action.generator 单插槽**（`core/model/action.gd`）：
   - `var generator: Generator = null`
   - 非 Array，每次只能有一个活跃 generator
   - 新的 generator 覆盖旧的（带 warn log）

3. **虚拟 Flag 注册**（`core/player_state.gd`）：
   - `register_virtual_flag(flag_id, type)` → 运行时在 `Database.flags` 创建 Flag 对象
   - 绕过 `_validate_flag_type()` 的静态校验

4. **锁定机制**（`ActionManager.lock_action()`）：
   - duration=1 → 锁 1 旬后自动解锁（`process_xun_tick()` 递减计数器）
   - 锁定不阻止 generator 消费（generator 在耗尽瞬间就已清空）

### 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `core/model/generator.gd` | **新建** | Generator Resource 类 |
| `core/model/action.gd` | **修改** | 添加 `var generator: Generator = null` |
| `core/player_state.gd` | **修改** | 添加 `register_virtual_flag()` |
| `core/operators/deferred_lock_action_operator.gd` | **新建** | Operator 类，创建并挂载 Generator |
| `ui/scene_action_panel.gd` | **修改** | 在 `_on_button_pressed()` 中添加消费逻辑 |

### 使用示例（CSV/配置）

```csv
# 在 EventOption 的 choice_result 中配置 operator
operator_type,sub_operators,counter_flag_id,action_type,generator_uuid,generator_name
DeferredLockActionOperator,"[SetFlagOperator:flag_a,SetFlagOperator:flag_b]","gen_travel_meet_dufu",3,"gen-uuid-001","旅途中遇见杜甫"
```

其中 `action_type=3` 对应 `ENUMS.ACTION_TYPE.TRAVEL`。
