# PROPS 系统设计文档

## 设计意图

PROPS 系统是玩家的核心属性系统，用于存储和管理玩家的持久状态。与情绪（EMOTION）系统的临时性不同，PROPS 代表玩家的长期属性，如财富、健康、声望等。

> **2025-06 大清理**：属性从 12+6 缩减至 6 个核心属性，废弃 fatigue/burnout/sick（并入 health）、progress/official_prestige（合并为 progress）、ambition/inspiration/drunk（删除），新增 TIME（每旬重置 10）。

## 核心概念

### 1. PROPS 枚举定义

PROPS 枚举定义在 [`model/enumerates.gd`](../model/enumerates.gd) 中，包含 6 个核心属性：

```gdscript
enum PROPS {
    MONEY,          # 金钱
    HEALTH,         # 健康（吸收 fatigue/burnout/sick 语义）
    TIME,           # 时间（每旬重置为 10，代表可支配时间资源）
    LITERARY_FAME,  # 文学声望
    PROGRESS,       # 仕途进度（合并 progress + official_prestige）
    TALENT          # 才华
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

### 3. 初始化机制

属性不再通过独立的 `tres_properties_registry.tres` 注册表文件加载，而是直接在 `PlayerState._ready()` 中通过 `SourceOfTruth.debug_dashboard_state.resources` 初始化：

```gdscript
func init_props():
    var resources = SourceOfTruth.debug_dashboard_state.resources
    append_stat(ENUMS.PROPS.MONEY, resources.money)
    append_stat(ENUMS.PROPS.HEALTH, resources.health)
    append_stat(ENUMS.PROPS.LITERARY_FAME, resources.literary_fame)
    append_stat(ENUMS.PROPS.TALENT, resources.talent)
    append_stat(ENUMS.PROPS.PROGRESS, resources.progress)
    append_stat(ENUMS.PROPS.TIME, 10)
```

## 数据流转

### 初始化流程

```
1. PlayerState._ready() 执行
   ↓
2. init_props() 从 SourceOfTruth.debug_dashboard_state.resources 读取初始值
   ↓
3. append_stat() 为每个枚举属性设置初始值
   - TIME 硬编码初始化为 10（每旬由 month_end_settlement 重置）
   - PROGRESS 从 resources.progress 读取（兼容旧字段名）
   ↓
4. 游戏运行时通过 change_stat/get_stat_val 操作属性
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
model/enumerates.gd              # PROPS 枚举定义（6 个属性）
├── core/model/property.gd       # Property 类定义
├── core/player_state.gd         # init_props() 初始化逻辑
├── core/source_of_truth.gd      # debug_dashboard_state 初始值
└── core/survival_manager.gd     # 每月结算管线（衰减/溢出）
```

## 属性对照表

| 新属性 | 旧属性（已废弃/合并） | 说明 |
|--------|----------------------|------|
| `MONEY` | `money` | 无变化 |
| `HEALTH` | `health` + `fatigue` + `burnout` + `sick` | 健康统一吸收疲劳、倦怠、疾病语义 |
| `LITERARY_FAME` | `literary_fame` | 无变化 |
| `TALENT` | `talent` | 无变化 |
| `PROGRESS` | `progress` + `official_prestige` | 仕途进度合并官职声望 |
| `TIME` | **新增** | 每旬重置为 10，代表可支配时间资源 |

### 已删除的属性

| 旧属性 | 删除原因 |
|--------|----------|
| `ambition` | 过度细分，无明确游戏机制支撑 |
| `inspiration` | 代币属性，移除后由事件直接控制 |
| `drunk` | 醉酒状态由情绪系统覆盖 |

## 如何添加新的 PROPS

### 步骤 1：在枚举中添加新属性

在 [`model/enumerates.gd`](../model/enumerates.gd) 的 `PROPS` 枚举中添加：

```gdscript
enum PROPS {
    MONEY,
    HEALTH,
    TIME,
    LITERARY_FAME,
    PROGRESS,
    TALENT,
    NEW_PROP  # 新属性
}
```

### 步骤 2：在 PlayerState 中初始化

在 [`core/player_state.gd`](../core/player_state.gd) 的 `init_props()` 中添加：

```gdscript
append_stat(ENUMS.PROPS.NEW_PROP, initial_value)
```

### 步骤 3：在 SourceOfTruth 中配置默认值（可选）

如果需要从调试面板设置初始值，在 `core/source_of_truth.gd` 的 `debug_dashboard_state.resources` 中添加对应字段。

### 步骤 4：在事件/CSV 中引用

在 Config JSON 的 `operator_dsl` 或 `result` 字段中使用新属性名（小写）：

```
result: "new_prop+5"
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

### TIME 属性特殊处理

`TIME` 是唯一具有固定重置逻辑的属性：

- 每旬开始时由 `month_end_settlement.gd` 重置为 10
- 代表玩家在当前旬内可进行的行动次数
- 不参与 SurvivalManager 的衰减/溢出管线

### 属性变更逻辑与上限 clamp

`PlayerState.append_stat()` 方法包含乘数逻辑 + hard_max clamp：

1. 检查各个 Trait 的 buffer_to_prop 和 buffer_to_region
2. 应用所有乘数后执行加法操作
3. **硬上限 clamp**：如果属性 `hard_max >= 0`，自动 `clamp(val, 0, hard_max)`

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
PlayerState.force_set_stat_val('health', 999)  # 不会 clamp
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

### 1. 精简属性集
- 6 个核心属性覆盖全部游戏机制，减少认知负担
- 删除过度细分的中间属性，避免数值膨胀

### 2. 强类型安全
- 枚举定义确保属性名称的一致性
- 编译时检查避免拼写错误

### 3. 可扩展性
- 添加新属性只需修改枚举 + PlayerState 初始化
- 不影响现有代码逻辑

### 4. 灵活的操作符
- 支持多种乘数系统（Trait 的 buffer_to_prop / buffer_to_region）
- 实现复杂的属性变化逻辑

## 注意事项

1. **命名一致性**：枚举名使用大写下划线（`LITERARY_FAME`），字符串键使用小写下划线（`literary_fame`）
2. **TIME 重置**：每旬由 month_end_settlement 自动重置为 10，不要在事件中手动修改 TIME
3. **PROGRESS 兼容**：`init_props()` 从 `resources.progress` 读取初始值，保持 SourceOfTruth 字段名兼容
4. **初始化时机**：属性在 PlayerState._ready() 时设置初始值
5. **性能考虑**：属性变更会触发信号，频繁变更可能影响性能
6. **数据持久化**：Property 资源中的 val 值在运行时修改，需要考虑存档机制

## 与其他系统的关系

### 与 EMOTION 系统的区别
- **PROPS**：持久属性，长期存储（如金钱、健康、声望）
- **EMOTION**：临时状态，短期变化（如悲伤、狂傲）

### 与 TRAIT 系统的交互
- Trait 可以通过 buffer_to_prop 影响 PROPS 的变化
- PROPS 的值可能影响 TRAIT 的获得或失去条件

### 与 SurvivalManager 的关系
- 每月结算管线对 PROPS 执行衰减和溢出处理
- TIME 不参与结算管线（独立重置）

## 上限机制详解

### hard_max（硬上限）

- **定义位置**：每个 Property 实例的 `hard_max` 字段
- **执行位置**：[`PlayerState.append_stat()`](../core/player_state.gd) 和 `set_stat_val()`
- **行为**：任何通过 `append_stat` / `set_stat_val` 的修改都会被 clamp 到 `[0, hard_max]`
- **绕过方式**：调用 `force_set_stat_val()` 可跳过 hard_max 检查
- **默认值**：`-1` 表示无限制

### soft_max（软上限）

- **定义位置**：每个 Property 实例的 `soft_max` 字段
- **用途**：供 [`SurvivalManager`](../core/survival_manager.gd) 在结算管线中参考
- **行为**：属性超过 soft_max 时触发溢出逻辑
- **默认值**：`-1` 表示无软上限

### decay_threshold（衰减阈值）

- **定义位置**：每个 Property 实例的 `decay_threshold` 字段
- **用途**：供 `SurvivalManager` 在结算管线中使用
- **行为**：若当前值 > threshold，扣减 decay_val；否则清零
- **默认值**：`-1` 表示无衰减

### 当前各属性配置

| 属性 | hard_max | soft_max | decay_threshold | 说明 |
|------|----------|----------|-----------------|------|
| `money` | -1 | -1 | -1 | 无上限 |
| `health` | -1 | -1 | -1 | 无上限（吸收 fatigue/burnout/sick） |
| `time` | -1 | -1 | -1 | 每旬重置，不参与衰减 |
| `literary_fame` | -1 | -1 | -1 | 无上限 |
| `progress` | -1 | -1 | -1 | 无上限 |
| `talent` | -1 | -1 | -1 | 无上限 |

> 当前所有 6 个属性均为无上限（`hard_max=-1`）。如后续需要限制某个属性（如 talent 上限 100），只需在 Property 实例中设置 `hard_max=100`，PlayerState 自动 clamp。

## 未来扩展

### 可能的增强功能
1. **属性上限** — 如需限制（如 talent 上限 100），在对应的 Property 实例中设置 `hard_max` 即可，PlayerState 自动 clamp
2. **属性衰减**：某些属性随时间自然变化（如健康衰减）
3. **属性依赖**：属性之间存在依赖关系（如健康影响才华）
4. **动态属性**：运行时动态添加/移除属性
5. **属性历史**：记录属性变化历史用于调试和回放
