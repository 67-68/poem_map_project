# 意象获取事件标准规范 (Imagery Gain Event Standard)

## 概述

意象（Imaginary）是玩家拼凑诗句的"手牌/战利品"。本文档定义**意象（Imagery）在游戏事件中的获取机制**——即意象的 `basic_imaginaries` 数组如何被添加内容、通过什么途径触发。

---

## 数据结构

每个 `ImaginaryTag` 包含一个 `basic_imaginaries: Array[Dictionary]`，存储玩家获得该意象的记录：

```gdscript
# core/model/imaginary.gd
@export var basic_imaginaries: Array[Dictionary] = []
```

### entry 结构

```gdscript
{
    "blueprint_id": String,   # 意象的 blueprint ID，如 "emotion:despair"
    "contexts": Array[String] # 叙事上下文标签，如 ["farewell", "with_libai"]
}
```

---

## 现有意象获取途径

### 途径 1：通过 EventBus 信号 (基础设施层)

系统提供了一个信号用于添加意象：

```gdscript
# core/eventbus.gd
signal request_add_imaginary(tag: String)
```

发送方式：
```gdscript
EventBus.request_add_imaginary.emit("emotion:despair")
```

> **注意：** 当前该信号暂未连接任何监听器。如需启用，需要在合适的管理器节点中连接并实现添加逻辑。

### 途径 2：通过 CustomEventOption 的动态初始化

在 `CustomEventOption.init()` 中通过 `ImaginaryOperator` 操作意象等级：

```gdscript
# 在 CustomEventOption 的自定义类型中
func upgrade_random_imagery():
    var active_imaginaries = Database.get_active_imaginaries()
    if not active_imaginaries:
        description = '怎么连imagery都没有啊。浪费了这一次的机会'
        return
    
    var random_imaginary = active_imaginaries.keys()[randi() % active_imaginaries.size()]
    description = '将要升级Imaginary: %s' % random_imaginary.name
    
    var operator = ImaginaryOperator.new()
    operator.imaginary_name = random_imaginary
    operator.operation = "upgrade_1"
    
    choice_result = ChoiceResult.new()
    choice_result.operators.append(operator)
```

详见 [`event_option_system.md`](event_option_system.md) 的 CustomEventOption 章节。

### 途径 3：通过 ImaginaryOperator

`ImaginaryOperator` 直接操作意象等级（升级/降级），可在事件选项的 `ChoiceResult` 中配置：

```gdscript
# core/operators/imaginary_operator.gd
@export var imaginary_name: String    # 两段式 ID，如 "emotion:despair"
@export_enum("upgrade_1", "downgrade_1") var operation: String

func operate():
    var ima = Database.imaginaries.get(imaginary_name) as ImaginaryTag
    match operation:
        'upgrade_1':
            if not ima.current_level == 3: ima.current_level += 1
        'downgrade_1':
            if not ima.current_level == 0: ima.current_level -= 1
```

---

## 意象等级晋升机制

每个意象有累积计数（`basic_imaginaries.size()`），达到阈值自动升级：

| 等级 | 条件 | 效果 |
|------|------|------|
| **Level 1** | `basic_imaginaries.size() < l2_threshold` | 默认 |
| **Level 2** | `l2_threshold <= basic_imaginaries.size() <= l3_threshold` | 可用作诗词创作 |
| **Level 3** | `basic_imaginaries.size() > l3_threshold` | 高质量意象，解锁传奇诗词 |

### 消耗循环

每次诗词创作后（见 [`ui/poem_crafter.gd:166-171`](../../ui/poem_crafter.gd:166)）：

| 变化 | 值 |
|------|-----|
| 阈值提升 | `l3_threshold += 3`（让下次升级更困难） |
| 等级重置 | `current_level = 1`（重新积累） |
| 结构保留 | `basic_imaginaries` 数组保持不变 |

---

## 创建意象获取事件的完整步骤

### Step 1：确认意象蓝图

确认 `ImaginaryTag` 资源是否存在。如果不存在，先创建：

| 字段 | 值示例 |
|------|--------|
| `uuid` | `emotion:despair` |
| `name` | 断肠 |
| `l3_threshold` | 4（默认） |

### Step 2：确定获取方式

根据事件叙事，选择添加方式：

| 方式 | 适用场景 | 实现路径 |
|------|---------|---------|
| 信号触发 | 需要在事件展示时自动添加 | 连接 `request_add_imaginary` 并实现 handler |
| ImaginaryOperator | 选项结算时升级已有意象 | 在选项的 `ChoiceResult` 中添加 operator |
| CustomEventOption | 动态计算添加哪个意象 | 实现 `custom_type` 分支 |

### Step 3：配置事件选项

在事件选项的 `ChoiceResult` 中添加 `ImaginaryOperator`：

```gdscript
# 在 .tres 文件中或代码中
var op = ImaginaryOperator.new()
op.imaginary_name = "emotion:despair"
op.operation = "upgrade_1"
choice_result.operators.append(op)
```

### Step 4：配置 Tag 匹配

使用 [大唐 Tag 本体论与五维宪法](../events/tag_dictioinary.md) 为事件配置 `Trigger_Tags`，确保事件能在合适的时机被触发。

### Step 5：验证

1. 事件是否能被正确触发（通过 Tag 匹配）
2. ImaginaryOperator 是否能正确修改意象等级
3. `basic_imaginaries` 结构是否符合预期
4. 意象等级是否按阈值更新

---

## 创建清单 (Checklist)

- [ ] `ImaginaryTag` 蓝图资源已存在（uuid + name + l3_threshold）
- [ ] 确定了意象获取方式（信号 / operator / custom option）
- [ ] 事件选项的 `ChoiceResult` 包含正确的 operator
- [ ] 事件已配置正确的 `Trigger_Tags`
- [ ] `basic_imaginaries` 的 entry 结构 `{"blueprint_id": String, "contexts": Array}` 正确
- [ ] 意象消耗逻辑已在 `PoemCrafter` 中处理（阈值提升 + 等级重置）

---

## 常见错误

| 错误 | 症状 | 修复 |
|------|------|------|
| `imaginary_name` 拼写错误 | `ImaginaryOperator` 输出 err "can not found imagery" | 确认 `Database.imaginaries` 中存在该 key |
| 意象等级未提升 | `current_level` 无变化 | 检查 `operation` 是否为 `upgrade_1`，以及等级是否已到 3 |
| `request_add_imaginary` 无效果 | 信号发出但意象无变化 | 确认信号已被连接（connect）并有 handler 实现 |
| Tag 匹配不到事件 | 事件永远不会被拉起 | 检查 `Trigger_Tags` 是否在词典范围内 |

---

## 相关文档

| 文档 | 内容 |
|------|------|
| [Imaginary 系统技术报告](../imaginary/imaginary_system_report.md) | 完整系统架构 |
| [情绪-意象系统设计](../imaginary/emotion_imaginary_system.md) | 情绪与意象的关联设计 |
| [事件选项系统](./event_option_system.md) | CustomEventOption 和 ChoiceResult |
| [大唐 Tag 本体论与五维宪法](../events/tag_dictioinary.md) | 事件 Tag 规范 |
| [ImaginaryOperator](../../core/operators/imaginary_operator.gd) | 意象操作符源码 |
| [ImaginaryTag 模型](../../core/model/imaginary.gd) | 意象数据结构源码 |
