# PROPS 系统设计文档

## 设计意图

PROPS 系统是玩家的核心属性系统，用于存储和管理玩家的持久状态。与情绪（EMOTION）系统的临时性不同，PROPS 代表玩家的长期属性，如官职、声望、财富等。

这个系统通过资源注册表（ResourceRegistry）模式实现数据的集中管理和加载，确保所有属性在游戏启动时正确初始化。

## 核心概念

### 1. PROPS 枚举定义

PROPS 枚举定义在 `model/enumerates.gd` 中，包含 9 个核心属性：

```gdscript
enum PROPS {
    OFFICIAL_PRESTIGE,  # 官职声望
    LITERARY_FAME,      # 文学声望
    TALENT,             # 才华
    MONEY,              # 金钱
    HEALTH,             # 健康
    FATIGUE,            # 疲劳（影响才华产出效率）
    DRUNK,              # 醉酒（双刃剑：降低理性，但可能提供意象获取折扣）
    SICK,               # 病痛（疲劳阈值强制睡觉）
    INSPIRATION         # 灵感（代币/Buffer，用于兑换意象）
}
```

### 2. Property 资源类（单一类型）

所有 PROPS 共享同一个 `Property` 类，通过 `.tres` 中的配置区分行为，定义在 [`core/model/property.gd`](../core/model/property.gd)：

```gdscript
class_name Property extends GameEntity
    @export var val: int = 0                          # 当前值
    @export var hard_max: int = -1                    # 硬上限（-1 = 无限制），PlayerState 自动 clamp
    @export var soft_max: int = -1                    # 软上限（-1 = 无限制），SurvivalManager 参考触发溢出
    @export var decay_threshold: int = -1             # 衰减阈值（-1 = 无衰减），SurvivalManager 参考触发衰减
    @export var staged_perceptions: Array[PropStagedPerceptionData] = []  # 阶段性描述
```

> 不再区分 `InvolatileEmotionProp` / `UnboundedProperty` 子类 — 全部收敛到单一 `Property`。
> 通过 `hard_max=100` + `soft_max=90` 等配置值来模拟原"有上限属性"的行为。

### 3. 资源注册表

所有 Property 资源通过 `tres_properties_registry.tres` 注册，由 Database 统一加载。

## 数据流转

### 初始化流程

```
1. Database._init() 执行
   ↓
2. 加载 tres_properties_registry.tres
   properties = Util.create_dict_from_registry(load("res://data/tres_properties_registry.tres"))
   ↓
3. 注册表加载各个 .tres 文件
   - drunk.tres
   - emotion.tres
   - fatigue.tres
   - health.tres
   - inspiration.tres
   - literary_fame.tres
   - money.tres
   - official_prestige.tres
   - sick.tres
   - talent.tres
   ↓
4. 创建 Property 实例并存入 Database.properties 字典
   ↓
5. PlayerState._ready() 初始化特定属性值
   change_stat('official_prestige', 14)
   change_stat('literary_fame', 50)
   change_stat('talent', 50)
   ↓
6. 游戏运行时通过 change_stat/get_stat_val 操作属性
```

### 运行时操作

#### 修改属性值
```gdscript
PlayerState.change_stat('money', 100)  # 使用字符串键
PlayerState.change_stat(ENUMS.PROPS.MONEY, 100)  # 使用枚举值
```

#### 获取属性值
```gdscript
var money = PlayerState.get_stat_val('money')
var talent = PlayerState.get_stat_val(ENUMS.PROPS.TALENT)
```

## 文件结构

```
model/enumerates.gd                    # PROPS 枚举定义
├── core/model/property.gd             # Property 类定义
├── data/tres_properties_registry.tres # 属性注册表
└── data/tres_properties/
    ├── drunk.tres                     # 各个属性的资源文件
    ├── emotion.tres
    ├── fatigue.tres
    ├── health.tres
    ├── inspiration.tres
    ├── literary_fame.tres
    ├── money.tres
    ├── official_prestige.tres
    ├── sick.tres
    └── talent.tres
```

## 如何添加新的 PROPS

### 步骤 1：在枚举中添加新属性

在 `model/enumerates.gd` 的 `PROPS` 枚举中添加：

```gdscript
enum PROPS {
    # ... 现有属性
    NEW_PROP  # 新属性
}
```

### 步骤 2：在注册表中注册

在 `data/tres_properties_registry.tres` 的 `resources` 字典中添加：

```gdscript
resources = {
    # ... 现有属性
    "new_prop": "res://data/tres_properties/new_prop.tres"
}
```

### 步骤 3：创建属性资源文件

在 `data/tres_properties/` 目录创建 `new_prop.tres`：

```gdscript
[gd_resource type="Resource" script_class="Property" load_steps=2 format=3 uid="uid://..."]

[ext_resource type="Script" uid="uid://b3m5anke7kjyi" path="res://core/model/property.gd" id="1_l3cyt"]

[resource]
script = ExtResource("1_l3cyt")
uuid = "new_prop"
name = "new_prop"
hard_max = 100       # 硬上限（-1 = 无限制）
soft_max = 90        # 软上限（-1 = 无限制）
decay_threshold = 25 # 衰减阈值（-1 = 无衰减）
metadata/_custom_type_script = "uid://b3m5anke7kjyi"
```

### 步骤 4：配置上限值

根据属性类型设置不同的上限策略：

| 场景 | hard_max | soft_max | decay_threshold | 示例属性 |
|------|----------|----------|-----------------|----------|
| **有上限（0-100）** | 100 | 90 | 25 或 90 | fatigue, drunk, burnout, sick, inspiration |
| **无上限** | -1 | -1 | -1 | money, health, official_prestige, literary_fame, talent |

- `hard_max` 由 [`PlayerState.append_stat()`](../core/player_state.gd:112) 和 [`set_stat_val()`](../core/player_state.gd:142) 自动 clamp
- `hard_max` 可通过 [`force_set_stat_val()`](../core/player_state.gd:157) 绕过（用于 debug / 特殊场景）
- `soft_max` 和 `decay_threshold` 由 [`SurvivalManager`](../core/survival_manager.gd) 在结算管线中引用

### 步骤 5：（可选）在 PlayerState 中初始化

如果需要在游戏开始时设置初始值，在 `core/player_state.gd` 的 `_ready()` 中添加：

```gdscript
func _ready():
    # ... 现有初始化
    change_stat('new_prop', initial_value)
```

## 技术细节

### 字符串键转换

系统支持通过枚举值或字符串键访问属性：

```gdscript
static func to_prop_str(item) -> String:
    var name = PROPS.keys().get(item)
    if name:
        name = name.to_lower()
        return name
    Logging.err("Invalid prop tag: " + str(item))
    return "default_storable_item"
```

### 属性变更逻辑与上限 clamp

`PlayerState.append_stat()` 方法包含乘数逻辑 + hard_max clamp：

1. 检查各个 Trait 的 buffer_to_prop 和 buffer_to_region
2. 应用所有乘数后执行加法操作
5. **硬上限 clamp**：如果属性 `hard_max >= 0`，自动 `clamp(val, 0, hard_max)`

```gdscript
func append_stat(stat_name, data):
    # ... 乘数逻辑 ...
    stat.val += amount_to_change
    if stat.hard_max >= 0 and stat.val > stat.hard_max:
        stat.val = stat.hard_max
    player_stat_changed.emit(stat_name)
```

`set_stat_val()` 也包含同样的 hard_max clamp + 最小值 0 clamp。

**强制设值（跳过 hard_max）**：

```gdscript
PlayerState.force_set_stat_val('drunk', 999)  # 不会 clamp
```

### 阶段性感知

Property 支持根据数值显示不同的描述文本：

```gdscript
func get_staged_perception_text() -> String:
    for perception in staged_perceptions:
        if perception.stage_val <= val:
            return perception.perception_text
    
    for perception in default_staged_perception:
        if perception.stage_val <= val:
            return perception.perception_text
            
    return "未知状态"
```

## 系统优势

### 1. 集中管理
- 所有属性通过注册表统一管理
- 避免散落在各个文件中的硬编码

### 2. 强类型安全
- 枚举定义确保属性名称的一致性
- 编译时检查避免拼写错误

### 3. 可扩展性
- 添加新属性只需修改注册表
- 不影响现有代码逻辑

### 4. 灵活的操作符
- 支持多种乘数系统（Trait 的 buffer_to_prop / buffer_to_region）
- 实现复杂的属性变化逻辑

## 注意事项

1. **命名一致性**：枚举名使用大写下划线，资源文件使用小写下划线
2. **UID 唯一性**：每个 .tres 文件需要唯一的 UID
3. **初始化时机**：属性在 Database._init() 时加载，在 PlayerState._ready() 时设置初始值
4. **性能考虑**：属性变更会触发信号，频繁变更可能影响性能
5. **数据持久化**：Property 资源中的 val 值在运行时修改，需要考虑存档机制

## 与其他系统的关系

### 与 EMOTION 系统的区别
- **PROPS**：持久属性，长期存储（如金钱、健康）
- **EMOTION**：临时状态，短期变化（如悲伤、狂傲）

### 与 TRAIT 系统的交互
- Trait 可以通过 buffer_to_prop 影响 PROPS 的变化
- PROPS 的值可能影响 TRAIT 的获得或失去条件

### 与 IMAGINARY 系统的关系
- INSPIRATION 是一种特殊的 PROP，用于兑换意象
- 其他 PROPS（如 DRUNK）可能影响意象获得的成本

## 上限机制详解

### hard_max（硬上限）

- **定义位置**：每个 `.tres` 文件中的 `hard_max` 字段
- **执行位置**：[`PlayerState.append_stat()`](../core/player_state.gd:112) 和 [`set_stat_val()`](../core/player_state.gd:142)
- **行为**：任何通过 `append_stat` / `set_stat_val` 的修改都会被 clamp 到 `[0, hard_max]`
- **绕过方式**：调用 [`force_set_stat_val()`](../core/player_state.gd:157) 可跳过 hard_max 检查
- **默认值**：`-1` 表示无限制

### soft_max（软上限）

- **定义位置**：每个 `.tres` 文件中的 `soft_max` 字段
- **用途**：供 [`SurvivalManager`](../core/survival_manager.gd) 在结算管线中参考
- **行为**：`_process_fatigue_accumulation()` 使用 soft_max 作为溢出触发阈值
  - 如 drunk >= soft_max → 溢出到 fatigue，然后复位到 `soft_max - 1`
- **默认值**：`-1` 表示无软上限（兜底 `100`）

### decay_threshold（衰减阈值）

- **定义位置**：每个 `.tres` 文件中的 `decay_threshold` 字段
- **用途**：供 `SurvivalManager._decay_volatile_emotions()` 使用
- **行为**：`decay(prop, threshold, decay_val)`：若当前值 > threshold，扣减 decay_val；否则清零
- **默认值**：`-1` 表示无衰减（兜底 `25`）

### 当前各属性配置

| 属性 | hard_max | soft_max | decay_threshold |
|------|----------|----------|-----------------|
| `drunk` | 100 | 90 | 25 |
| `fatigue` | 100 | 90 | 90 |
| `burnout` | 100 | 90 | -1 |
| `sick` | 100 | 90 | -1 |
| `inspiration` | 100 | 90 | 25 |
| `money` | -1 | -1 | -1 |
| `health` | -1 | -1 | -1 |
| `official_prestige` | -1 | -1 | -1 |
| `literary_fame` | -1 | -1 | -1 |
| `talent` | -1 | -1 | -1 |

## 未来扩展

### 可能的增强功能
1. ~~属性上限~~ ✅ **已实现**（hard_max + soft_max 双上限机制）
2. **属性衰减**：某些属性随时间自然变化（如疲劳恢复）（部分通过 decay_threshold 实现）
3. **属性依赖**：属性之间存在依赖关系（如健康影响才华）
4. **动态属性**：运行时动态添加/移除属性
5. **属性历史**：记录属性变化历史用于调试和回放
