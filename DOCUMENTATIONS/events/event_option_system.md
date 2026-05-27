# Event Option 系统文档

## 概述

Event Option 系统是游戏事件系统中用于处理玩家选择的组件系统。每个事件可以包含多个选项，玩家通过选择不同的选项来触发不同的游戏结果。系统采用面向对象设计，支持多种选项类型和灵活的扩展机制。

## 架构设计

### 类层次结构

```
Resource (Godot 基类)
    └── BaseOption (基础选项类)
            ├── EventOption (标准事件选项)
            ├── CustomEventOption (自定义事件选项)
            ├── ComplexEventOption (复杂事件选项)
            └── PropertyOption (属性检查选项)
```

### 核心组件

#### 1. BaseOption (基础选项类)

**文件位置**: `model/event/base_option.gd`

**职责**: 所有选项类型的基类，定义通用接口和生命周期方法。

**核心方法**:
```gdscript
func init():
    # 子类可以重写这个方法来初始化选项逻辑
    pass
```

**设计原理**: 
- 继承自 `Resource` 而非 `Node`，因为选项是数据结构而非场景对象
- `init()` 方法在选项被创建为 UI 按钮时调用，替代了 `Node._ready()` 的功能
- 提供虚函数模式，允许子类自定义初始化逻辑

#### 2. EventOption (标准事件选项)

**文件位置**: `model/event/event_option.gd`

**用途**: 最常用的选项类型，用于大多数事件的静态选项。

**属性**:
- `description: String` - 按钮显示文本
- `choice_result: ChoiceResult` - 选择后执行的结果
- `requirements: BaseRequirements` - 选项的触发条件

**使用场景**: 
- 固定描述的选项
- 固定结果的选项
- 需要条件判断的选项

**示例**:
```gdscript
var option = EventOption.new()
option.description = "接受邀请"
option.choice_result = parse_choice_result("money+10,reputation+5")
option.requirements = parse_requirements("prop:money>=100")
```

#### 3. CustomEventOption (自定义事件选项)

**文件位置**: `model/event/custom_event_option.gd`

**用途**: 处理特殊逻辑的选项，支持动态计算描述和结果。

**属性**:
- `custom_type: String` - 自定义类型枚举
- 继承 BaseOption 的所有属性

**当前支持的类型**:
- `upgrade_random_imagery` - 随机升级一个 Imaginary

**工作流程**:
1. 选项被创建为按钮时调用 `init()`
2. `init()` 根据 `custom_type` 执行对应的逻辑
3. 动态设置 `description` 和 `choice_result`

**实现示例**:
```gdscript
func init():
    match custom_type:
        'upgrade_random_imagery': upgrade_random_imagery()

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

**扩展指南**: 添加新的自定义类型：
1. 在 `@export_enum` 中添加新类型字符串
2. 在 `init()` 的 match 语句中添加对应的分支
3. 实现具体的处理函数

#### 4. ComplexEventOption (复杂事件选项)

**文件位置**: `model/event/complex_event_option.gd`

**用途**: 支持禁用状态和二次确认的复杂选项。

**扩展属性**:
- `is_disabled: bool` - 是否禁用选项
- `disabled_reason: String` - 禁用原因提示
- `double_check: bool` - 是否需要二次确认
- `double_check_reason: String` - 二次确认提示

**使用场景**:
- 危险操作需要确认
- 临时禁用的选项
- 需要额外提示的选项

#### 5. PropertyOption (属性检查选项)

**文件位置**: `model/event/property_option.gd`

**用途**: 专门用于检查单个属性条件的选项。

**属性**:
- `_property_name: ENUMS.PROPS` - 属性名称（枚举）
- `requirements: PropertyRequirement` - 属性要求
- `choice_result: ChoiceResult` - 选择结果

**特点**:
- 自动处理属性名称的枚举转换
- 专门的属性要求检查

## 完整工作流程

### 1. 事件触发流程

```
EventManager.scan_events()
    ↓
roll_events() - 权重随机抽取
    ↓
EventBus.request_event_key.emit(event_key)
    ↓
NarrativeOverlay.apply_narrative(event)
    ↓
OptionBtns.apply_btns(event.options, callback)
    ↓
EventBtn._init(option) - 为每个选项创建按钮
    ↓
option.init() - 调用选项初始化
    ↓
玩家点击按钮
    ↓
EventBtn.confirmed()
    ↓
option_made.emit(choice_result)
    ↓
NarrativeOverlay._on_option_selected()
    ↓
ConsequenceExecuter.execute_result(choice_result)
    ↓
choice_result.operate()
    ↓
执行所有操作符
```

### 2. 选项初始化时机

**关键代码位置**: `characters/event_btn.gd`

```gdscript
func _init(data: BaseOption):
    data.init()  # 🔑 关键：在这里调用初始化
    option = data
    # ... UI 设置
```

**设计理由**:
- 选项作为 Resource 没有 `_ready()` 生命周期
- 在按钮创建时初始化确保每次显示都是最新状态
- 支持动态计算选项内容和结果

### 3. 条件检查机制

**检查时机**: 在 `EventBtn._init()` 中

```gdscript
if data.requirements:
    var pass_prop = data.requirements.compare(PlayerState)
    if not pass_prop:
        disabled = true
        text = "[%s]%s" % [data.requirements.failed_hint, text]
```

**支持的检查类型**:
- 属性检查 (prop:money>=100)
- 特征检查 (trait:brave)
- 复合条件检查 (AND/OR 逻辑)

### 4. 结果执行机制

**核心类**: `ChoiceResult`

**文件位置**: `model/choice_result.gd`

**执行流程**:
```gdscript
func operate():
    for op in operators:
        op.operate()
```

**操作符类型**:
- `PropertyOperator` - 修改属性
- `ImaginaryOperator` - 操作 Imaginary
- `EventOperator` - 触发新事件
- 其他自定义操作符

## 使用指南

### 创建标准选项

```gdscript
# 在事件资源文件中直接配置
[resource]
script = ExtResource("event_option.gd")
description = "接受邀请"
choice_result = SubResource("choice_result")
requirements = SubResource("requirements")
```

### 使用自定义选项

```gdscript
# 1. 创建 CustomEventOption 资源
[sub_resource type="Resource" id="custom_option"]
script = ExtResource("custom_event_option.gd")
custom_type = "upgrade_random_imagery"

# 2. 在事件中使用
[resource]
script = ExtResource("random_event.gd")
options = Array[Object]([SubResource("custom_option")])
```

### 添加新的自定义类型

1. 在 `CustomEventOption` 中添加类型枚举：
```gdscript
@export_enum(
    'upgrade_random_imagery',
    'your_new_type'  # 添加新类型
) var custom_type: String
```

2. 在 `init()` 中添加处理分支：
```gdscript
func init():
    match custom_type:
        'upgrade_random_imagery': upgrade_random_imagery()
        'your_new_type': your_custom_function()
```

3. 实现处理函数：
```gdscript
func your_custom_function():
    # 动态计算 description
    description = "根据当前状态生成的描述"
    
    # 动态创建 choice_result
    choice_result = ChoiceResult.new()
    var operator = YourOperator.new()
    # 配置 operator
    choice_result.operators.append(operator)
```

### 使用复杂选项

```gdscript
var option = ComplexEventOption.new()
option.description = "危险操作"
option.is_disabled = false
option.double_check = true
option.double_check_reason = "确定要执行此操作吗？"
option.choice_result = your_choice_result
```

## 最佳实践

### 1. 何时使用自定义选项

**使用 CustomEventOption 的场景**:
- 需要根据游戏状态动态生成选项描述
- 选项结果需要运行时计算
- 需要访问数据库或复杂逻辑
- 选项内容随机变化

**使用标准 EventOption 的场景**:
- 固定的描述和结果
- 简单的条件检查
- 静态配置即可满足需求

### 2. 性能考虑

**避免在 init() 中执行耗时操作**:
```gdscript
func init():
    # ❌ 避免这种
    for i in range(10000):
        heavy_calculation()
    
    # ✅ 推荐：预先计算或缓存
    if _cached_result:
        description = _cached_result
    else:
        _cached_result = calculate_once()
        description = _cached_result
```

### 3. 错误处理

**在 init() 中添加边界检查**:
```gdscript
func upgrade_random_imagery():
    var active_imaginaries = Database.get_active_imaginaries()
    if not active_imaginaries:
        description = '怎么连imagery都没有啊。浪费了这一次的机会'
        return  # 安全返回
```

### 4. 调试技巧

**添加日志跟踪初始化**:
```gdscript
func init():
    Logging.info("Initializing option with type: %s" % custom_type)
    match custom_type:
        'upgrade_random_imagery': 
            Logging.debug("Executing upgrade_random_imagery")
            upgrade_random_imagery()
```

## 常见问题

### Q: 为什么不用 _ready() 方法？

**A**: `BaseOption` 继承自 `Resource`，而 `Resource` 在 Godot 中没有 `_ready()` 生命周期方法。`_ready()` 是 `Node` 的方法，只有场景树中的节点才会调用。因此我们使用 `init()` 方法在按钮创建时手动调用初始化。

### Q: 选项的 requirements 在哪里检查？

**A**: 在 `EventBtn._init()` 中检查。当按钮创建时会立即检查条件，如果不满足则禁用按钮并显示失败提示。

### Q: 如何在选项中触发新事件？

**A**: 使用 `EventOperator`:
```gdscript
var operator = EventOperator.new()
operator.event_key = "some_event_key"
choice_result.operators.append(operator)
```

### Q: CustomEventOption 和动态生成选项有什么区别？

**A**: 
- `CustomEventOption` 是预定义的特殊逻辑，通过 `custom_type` 区分
- 动态生成选项是在运行时完全创建新的选项实例
- 前者是配置化的扩展，后者是程序化的生成

## 相关文件

- **核心类**: 
  - `model/event/base_option.gd`
  - `model/event/event_option.gd`
  - `model/event/custom_event_option.gd`
  - `model/event/complex_event_option.gd`
  - `model/event/property_option.gd`

- **UI 组件**:
  - `characters/event_btn.gd`
  - `ui/option_btns.gd`
  - `characters/narrative_overlay.gd`

- **执行系统**:
  - `model/choice_result.gd`
  - `core/consequence_executer.gd`

- **事件管理**:
  - `core/event_manager.gd`
  - `core/eventbus.gd`

## 扩展阅读

- [事件系统架构](./event_result.md)
- [Imaginary 系统](./imaginary_system_report.md)
- [属性系统](./props_system.md)
