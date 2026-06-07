# Event Option 系统文档

## 1. 选项类型

### 1. BaseOption (基础选项)

**文件位置**: `model/event/base_option.gd`

**核心属性**:
- `uuid: String` — 唯一标识
- `description: String` — 按钮文本

**说明**: 所有选项的基类，提供最基础的属性。

---

### 2. EventOption (标准事件选项)

**文件位置**: `model/event/event_option.gd`

**核心属性**:
- `description: String` — 按钮文本（支持模板插值 `{@context_key}`）
- `choice_result: ChoiceResult` — 选择该选项后的结果执行链
- `requirement: BaseRequirements` — 选项可用性守卫条件
- `custom_context_params: Dictionary` — 自定义上下文参数

**说明**: 最常用的选项类型。支持条件守卫和模板文本解析。

---

### 3. CustomEventOption (自定义选项)

**文件位置**: `model/event/custom_event_option.gd`

**用途**: 需要自定义初始化逻辑的特殊选项。

**属性**:
- `custom_type: String` — 自定义类型标识
- `choice_result: ChoiceResult`

**使用示例**:
```gdscript
# 创建自定义选项
var option = CustomEventOption.new()
option.custom_type = "upgrade_random_imagery"
option.description = "提升随机的意象等级"
option.choice_result = your_choice_result
```

**扩展指南**: 添加新的自定义类型：
1. 在 `@export_enum` 中添加新类型字符串
2. 在 `init()` 的 match 语句中添加对应的分支
3. 实现具体的处理函数

---

### 4. ComplexEventOption (复杂事件选项)

**文件位置**: `model/event/complex_event_option.gd`

**用途**: 支持禁用状态和二次确认的复杂选项。

**属性**:
- `double_check: bool` — 是否需要二次确认
- `double_check_reason: String` — 二次确认提示
- `is_disabled: bool` — **@deprecated** 请使用 `NarrativeLockRequirement` 替代
- `disabled_reason: String` — **@deprecated** 同上，用 `NarrativeLockRequirement.failed_hint` 替代

**说明**:
`is_disabled` / `disabled_reason` 已废弃，改为在 `requirement` 字段中放入 `NarrativeLockRequirement`。
`ComplexEventOption.init()` 自动做桥接转换，旧资源不受影响。

**使用场景**:
- 危险操作需要确认
- 叙事锁定选项（玩家可点击查看原因）

---

### 5. PropertyOption (属性检查选项)

**文件位置**: `model/event/property_option.gd`

**用途**: 专门用于检查单个属性条件的选项。

**属性**:
- `_property_name: ENUMS.PROPS` - 属性名称（枚举）
- `requirements: PropertyRequirement` - 属性要求
- `choice_result: ChoiceResult` - 选择结果

**特点**:
- 自动处理属性名称的枚举转换
- 专门的属性要求检查

---

## 2. 完整工作流程

### 2.1 事件触发流程

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

### 2.2 选项初始化时机

**关键代码位置**: `characters/event_btn.gd`

```gdscript
func _init_option(data: BaseOption):
    # 🔑 关键：在这里调用初始化
    # 选项作为 Resource 没有 _ready() 生命周期
    # 在按钮创建时初始化确保每次显示都是最新状态
```

**设计理由**:
- 选项作为 Resource 没有 `_ready()` 生命周期
- 在按钮创建时初始化确保每次显示都是最新状态
- 支持动态计算选项内容和结果

---

## 3. 统一验证管线 (Unified Validation Pipeline)

**核心设计原则**: 所有"这个选项能不能用"的判断，统一走 `requirement.compare(PlayerState)` 一条路。

### 3.1 管线拓扑

```
EventBtn._init_option(data)
    │
    ├─ data.requirement == null → 通过验证，连接 confirmed()
    │
    └─ data.requirement != null
         └─ requirement.compare(PlayerState)
              ├─ true  → 通过验证，连接 confirmed()
              ├─ null  → 属性未找到，Logging.err + 返回
              └─ false → 禁用按钮，原因见 requirement.get_failed_hint()
                         连接 disable_btn（点击后变灰 + Toast 提示）
```

### 3.2 验证结果

所有 Requirement 子类共同遵守以下契约：

| 接口 | 返回 | 说明 |
|------|------|------|
| `compare(PlayerState)` | `bool` 或 `null` | 条件判定。`true`=通过, `false`=失败, `null`=配置错误 |
| `failed_hint` | `@export var String` | 可替换的失败提示文案（CSV / .tres 中直接配置） |
| `get_failed_hint()` | `String` | 返回失败提示。默认返回 `failed_hint`，子类可重写提供动态文案 |

### 3.3 支持的检查类型

| Requirement 类型 | 文件路径 | 说明 |
|-----------------|---------|------|
| `PropertyRequirement` | `core/property_requirement.gd` | 属性检查 (money > 100) |
| `FlagRequirement` | `core/requirements/flag_requirement.gd` | 标志位检查 |
| `TraitRequirement` | `core/requirements/trait_requirement.gd` | 特征检查 (has/not_has) |
| `PropRangeRequirement` | `core/requirements/range_requirement.gd` | 属性范围检查 |
| `EmotionRequirement` | `core/requirements/emotion_requirement.gd` | 情绪值检查 |
| `ImaginaryLevelRequirement` | `core/requirements/imaginary_level_requirement.gd` | 意象等级检查 |
| `PoemRequirement` | `core/requirements/poem_requirement.gd` | 诗词检查 |
| `ComplexRequirements` | `core/model/multiple_requiremenets.gd` | AND/OR 复合条件 |
| `NarrativeLockRequirement` | `core/requirements/narrative_lock_requirement.gd` | **叙事锁** — 替代 is_disabled |

### 3.4 NarrativeLockRequirement (叙事锁)

**用途**: 替代 `ComplexEventOption.is_disabled` 硬编码。把"叙事禁用"也变成一种 Requirement，
统一到验证管线中。

**配置方式**: 在 EventOption 的 `requirement` 字段中放入 `NarrativeLockRequirement` 实例，
设置 `failed_hint` 为锁定原因。

```gdscript
# 手动创建
var lock = NarrativeLockRequirement.new()
lock.failed_hint = "你现在不能这样做"
option.requirement = lock

# 或通过 ComplexEventOption 的 is_disabled 桥接（旧用法依旧可用）
option.is_disabled = true
option.disabled_reason = "你现在不能这样做"
```

**行为**: `compare()` 永远返回 `false`（无条件锁定）。
点击按钮时变灰并弹出 Toast 显示 `failed_hint`。

**扩展**: 未来可通过添加 `lock_flag_id` / `lock_flag_value` 实现条件锁（只在特定叙事状态下锁定）。

---

## 4. 结果执行机制

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

---

## 5. 使用指南

### 5.1 创建标准选项

```gdscript
# 在事件资源文件中直接配置
[resource]
script = ExtResource("event_option.gd")
description = "接受邀请"
choice_result = SubResource("choice_result")
requirements = SubResource("requirements")
```

### 5.2 使用自定义选项

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

### 5.3 添加新的自定义类型

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

### 5.4 使用复杂选项

```gdscript
var option = ComplexEventOption.new()
option.description = "危险操作"
option.is_disabled = false
option.double_check = true
option.double_check_reason = "确定要执行此操作吗？"
option.choice_result = your_choice_result
```

### 5.5 使用叙事锁

```gdscript
var option = EventOption.new()
option.description = "被锁住的选项"

# 方式 A：直接使用 NarrativeLockRequirement（推荐）
var lock = NarrativeLockRequirement.new()
lock.failed_hint = "剧情尚未推进到这一步"
option.requirement = lock

# 方式 B：结合其他 requirement
var complex = ComplexRequirements.new()
complex.current_operator = REQ_OPERATOR.LOGIC.AND
complex.operators = [
    NarrativeLockRequirement.new(),  # 叙事锁
    PropRequirement.new(),           # 属性要求
]
lock.failed_hint = "门锁着"
# 两个条件都满足才能解锁
```

---

## 6. Q&A

### Q: 选项的 requirements 在哪里检查？

**A**: 在 `EventBtn._init_option()` 中通过统一验证管线检查。无论是 `PropertyRequirement`（属性不够）
还是 `NarrativeLockRequirement`（叙事锁定），都走 `requirement.compare(PlayerState)` 一条路。
不满足时按钮变灰，点击显示 `get_failed_hint()` 的提示。

### Q: `is_disabled` 和 `NarrativeLockRequirement` 的关系？

**A**: `is_disabled` 已废弃，功能由 `NarrativeLockRequirement` 替代。
`ComplexEventOption.init()` 会自动将 `is_disabled=true` 桥接为 `NarrativeLockRequirement`，
旧资源无需改动即可正常工作。

### Q: `failed_hint` 从哪里来？

**A**: `failed_hint` 是 `BaseRequirements` 的 `@export` 属性，所有 Requirement 子类都继承它。
可以在 CSV / `.tres` / Inspector 中直接配置。`get_failed_hint()` 默认返回 `failed_hint`，
子类可重写提供动态文案。

### Q: 为什么不用 `_ready()` 方法？

**A**: `BaseOption` 继承自 `Resource`，而 `Resource` 在 Godot 中没有 `_ready()` 生命周期方法。`_ready()` 是 `Node` 的方法，只有场景树中的节点才会调用。因此我们使用 `init()` 方法在按钮创建时手动调用初始化。

---

## 7. 调试技巧

**添加日志跟踪初始化**:
```gdscript
func init():
    Logging.info("Initializing option with type: %s" % custom_type)
    match custom_type:
        'upgrade_random_imagery': 
            Logging.debug("Executing upgrade_random_imagery")
            upgrade_random_imagery()
```
