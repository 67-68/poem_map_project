## 当前架构理解

你的事件系统流程：
1. `EventBtn` 被点击 → 发射 `option_made(ChoiceResult)` 信号
2. `ChoiceResult.operate()` 执行所有 operators
3. `EventOperator` 通过 `EventBus.request_event_key.emit()` 触发新事件

---

## 实现方案对比

### 方案 1：使用 EventOperator

**实现方式**：在选项的 `ChoiceResult.operators` 数组中添加 `EventOperator`，设置 `event_key` 为目标事件的 UUID。

```gdscript
# 在 .tres 文件中
[sub_resource type="Resource" id="Resource_xyz"]
script = ExtResource("4_ri2ju")  # EventOperator
event_key = "target_event_uuid"
```

或者e在代码中：
```gdscript
var event_op = EventOperator.new()
event_op.event_key = "target_event_uuid"
choice_result.operators.append(event_op)
```

**优点**：
- ✅ 符合现有架构，Operator 模式已经很成熟
- ✅ 可以和其他 operator（属性修改、时间跳跃等）组合使用
- ✅ 可配置性强，无需改代码
- ✅ 调用链清晰，易于调试

**缺点**：
- ❌ 需要了解 Operator 概念
- ❌ 在 Godot 编辑器中配置可能稍显繁琐

**工时预估**：5-10 分钟（配置一个事件链）

**反悔成本**：极低，删除 operator 即可

**实际应用情况**：已广泛使用，见 <ref_file file="/Users/lennon/Projects/poem_map_project/data/tres_decisions/update_to_rank8_official.tres" />