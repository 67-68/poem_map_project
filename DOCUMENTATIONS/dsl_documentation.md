# DSL 功能和使用文档

## 概述

本项目使用自定义DSL（Domain Specific Language）来描述游戏事件、条件和结果，主要用于从CSV数据批量解析游戏事件。DSL系统分为两个层次：

- **DSLParser**: 高级解析器，负责从CSV行数据解析完整的事件结构
- **MicroDSLParser**: 微型解析器，负责解析具体的DSL语法（标签、条件、操作符等）

## 核心组件

### 1. DSLParser

**文件位置**: `parser/dsl_parser.gd`

**职责**: 从CSV数据行解析完整的RandomEvent对象

**主要方法**:
- `parse(row: Dictionary) -> RandomEvent` - 解析单行CSV数据
- `parse_csv_data(csv_data: Array[Dictionary]) -> Array[RandomEvent]` - 批量解析
- `parse_requirements(requirements_str: String) -> BaseRequirements` - 解析触发条件
- `parse_options(row: Dictionary) -> Array[BaseOption]` - 解析选项
- `validate_event(event: RandomEvent) -> bool` - 验证解析结果

### 2. MicroDSLParser

**文件位置**: `parser/micro_dsl_parser.gd`

**职责**: 解析DSL语法的基础元素

**主要方法**:
- `parse_tags(data: String) -> Array[String]` - 解析触发标签
- `parse_property_requirement(data: String) -> PropertyRequirement` - 解析属性条件
- `parse_trait_requirement(data: String) -> BaseRequirements` - 解析特性条件
- `parse_consequence_operators(data: String) -> Array[BaseOperator]` - 解析结果操作符

## DSL语法详解

### 1. 触发标签语法

**格式**: 
- **四段式（新版/目标）**: `domain:category:type:specific`

**说明**: 
- **四段式是当前规范目标**，建议新数据使用四段式
- 标签用于事件匹配和权重计算

**四段式示例**:
```
actor:status:temporary:drunk           # 人物状态-临时状态-醉酒
city:econ:level:prosperous            # 城市经济-繁荣程度-繁华
action:intent:study:poetry             # 行动意图-学习类型-诗歌
intel:story_lock:event:anlushan_rebel  # 情报-剧情锁-事件类型-安禄山谋反
```

**多标签格式**: 用逗号分隔
```
actor:status:temporary:drunk,city:econ:level:prosperous,action:intent:study:poetry
```

**支持的Domain**:
- `actor` - 人物相关
- `city` - 城市相关
- `action` - 行动相关
- `intel` - 情报/剧情相关

**四段式设计理念**:
- 第1段 (domain): 大分类域
- 第2段 (category): 子分类
- 第3段 (type): 类型分类（避免第三段承担过多语义）
- 第4段 (specific): 具体实例化/私人记忆/上下文（表现层细节）

### 2. 触发条件语法

#### 2.1 属性条件

**格式**: `prop:property_name:>value` 或 `prop:property_name:<value`

**支持的比较操作符**:
- `>` - 大于
- `<` - 小于

**示例**:
```
prop:money:>50              # 金钱大于50
prop:literary_fame:<30      # 文学名声小于30
prop:official_prestige:>100 # 官职声望大于100
```

#### 2.2 特性条件

**格式**: `trait:has:trait_name` 或 `trait:not_has:trait_name`

**支持的操作符**:
- `has` - 拥有特性
- `not_has` - 不拥有特性

**示例**:
```
trait:has:official      # 拥有官员特性
trait:not_has:corrupt   # 不拥有腐败特性
trait:has:proud         # 拥有骄傲特性
```

#### 2.3 标志位条件

**格式**: `flag:type:operator:value`

**支持的类型**:
- `bool` - 布尔标志位
- `str` - 字符串标志位
- `int` - 整数标志位

**布尔标志位操作符**:
- `has` - 标志位为真
- `not_has` - 标志位为假

**字符串标志位操作符**:
- `is` - 等于指定值
- `is_not` - 不等于指定值

**整数标志位操作符**:
- `>` - 大于指定值
- `<` - 小于指定值

**示例**:
```
flag:bool:has:flag_player_visited_palace      # 玩家已访问皇宫
flag:bool:not_has:flag_game_completed         # 游戏未完成
flag:str:is:flag_player_name:张三              # 玩家姓名是张三
flag:str:is_not:flag_player_status            # 玩家状态不是指定值
flag:int:>flag_score:100                      # 分数大于100
flag:int:<flag_health:10                      # 健康值小于10
```

**注意**: 标志位的 `flag_id` 需要在 CSV 数据中预先定义和加载。

#### 2.4 复合条件

**格式**: 用逗号分隔多个条件，系统使用AND逻辑组合

**示例**:
```
prop:money:>50,trait:has:official
prop:literary_fame:>30,prop:money:>100
flag:bool:has:flag_player_visited_palace,prop:money:>100
flag:str:is:flag_player_name:张三,trait:has:official
```

### 3. 结果操作符语法

**格式**: `type:action:value`，多个操作符用逗号分隔

#### 3.1 属性操作符

**格式**: `prop:property_name:value`

**示例**:
```
prop:money:-100            # 金钱减少100
prop:prestige:+50          # 声望增加50
prop:literary_fame:+10     # 文学名声增加10
prop:money:-20,prop:literary_fame:+5  # 多个属性修改 # 这里的基本格式没有做特殊处理，单纯是使用逗号连了一下
```

#### 3.2 特性操作符

**格式**: `trait:action:trait_name`

**支持的操作**:
- `add` - 添加特性
- `remove` - 移除特性

**示例**:
```
trait:add:corrupt          # 添加腐败特性
trait:remove:brave         # 移除勇敢特性
trait:add:official         # 添加官员特性
```

#### 3.3 标志位操作符

**格式**: `flag:type:action:value`

**支持的类型**:
- `bool` - 布尔标志位
- `str` - 字符串标志位
- `int` - 整数标志位

**布尔标志位操作**:
- `add` - 设置为 true
- `remove` - 设置为 false
- `replace` - 替换（格式特殊：`flag:bool:{old_flag}->{new_flag}`）

**字符串标志位操作**:
- `set` - 设置字符串值（格式：`flag:str:set:flag_id:content`）

**整数标志位操作**:
- `add` - 增加数值（格式：`flag:int:add:flag_id:value`）
- `set` - 设置数值（格式：`flag:int:set:flag_id:value`）

**示例**:
```
flag:bool:add:flag_player_has_key              # 获得钥匙标志
flag:bool:remove:flag_game_over                # 移除游戏结束标志
flag:bool:flag_has_old_status->flag_has_new_status  # 替换状态标志
flag:str:set:flag_player_name:李四             # 设置玩家姓名为李四
flag:int:add:flag_score:50                     # 分数增加50
flag:int:set:flag_health:100                   # 设置健康值为100
```

**标志位替换操作说明**:
- `flag:bool:flag_a->flag_b` 会将 `flag_a` 设为 false，`flag_b` 设为 true
- 系统会校验两个标志位都是 bool 类型，否则操作失败

## CSV数据结构

### 必需字段

- `Event_ID` - 事件唯一标识符
- `Trigger_Tags` - 触发标签（逗号分隔）

### 可选字段

- `requirements` - 触发条件（逗号分隔）
- `Title` - 事件标题
- `Desc` - 事件描述
- `weight` - 事件权重（浮点数）
- `background` - 背景图片资源名

## 标志位数据结构

### 标志位CSV数据

标志位数据使用单独的CSV文件进行管理，通过 `csv_cloud_loader.gd` 加载。

**必需字段**:
- `flag_id` - 标志位唯一标识符
- `type` - 标志位类型（`str`, `int`, `bool`）
- `default_value` - 默认值

**示例**:
```csv
flag_id, type, default_value
flag_player_name, str, 张三
flag_score, int, 0
flag_has_key, bool, false
flag_game_completed, bool, FALSE
```

**布尔值支持格式**:
- `true` / `false`
- `t` / `f` (简写)
- `1` / `0`
- `yes` / `no`
- `TRUE` / `FALSE` (不区分大小写)

### 选项字段

支持多个选项（A-F），每个选项包含：

- `Opt_X_Text` - 选项文本（必需）
- `Opt_X_Req` - 选项触发条件（可选）
- `Opt_X_Result` - 选项结果（可选）

**示例**:
```
Opt_A_Text: 塞钱贿赂
Opt_A_Req: prop:money:>100
Opt_A_Result: prop:money:-100,trait:add:corrupt,flag:bool:add:flag_bribed

Opt_B_Text: 拂袖而去
Opt_B_Req: trait:has:proud
Opt_B_Result: prop:prestige:+50,flag:bool:flag_has_low_reputation->flag_has_high_reputation
```

## 完整示例

### 单个事件CSV数据

```csv
Event_ID: evt_changan_01
Trigger_Tags: actor:status:drunk,city:econ:prosperous,action:study:poetry
requirements: prop:money:>50,trait:has:official
Title: 长安酒馆奇遇
Desc: 你在长安的一家酒馆中遇到了一位神秘的诗人，他似乎喝醉了，但眼中却闪烁着智慧的光芒。
Opt_A_Text: 塞钱贿赂
Opt_A_Req: prop:money:>100
Opt_A_Result: prop:money:-100,trait:add:corrupt
Opt_B_Text: 拂袖而去
Opt_B_Req: trait:has:proud
Opt_B_Result: prop:prestige:+50
weight: 15.5
background: bg_rural_poor
```

### 批量解析示例代码

```gdscript
var csv_data = [
    {
        "Event_ID": "evt_changan_01",
        "Trigger_Tags": "actor:status:drunk,city:econ:prosperous",
        "requirements": "prop:money:>50",
        "Title": "长安酒馆奇遇",
        "Desc": "你在长安的一家酒馆中遇到了一位神秘的诗人。",
        "Opt_A_Text": "塞钱贿赂",
        "Opt_A_Req": "prop:money:>100",
        "Opt_A_Result": "prop:money:-100,trait:add:corrupt",
        "Opt_B_Text": "拂袖而去",
        "Opt_B_Req": "trait:has:proud",
        "Opt_B_Result": "prop:prestige:+50"
    },
    {
        "Event_ID": "evt_market_02",
        "Trigger_Tags": "action:study:poetry,city:econ:prosperous",
        "requirements": "prop:literary_fame:>30",
        "Title": "市场诗会",
        "Desc": "市场上正在举行一场诗会，许多文人墨客聚集于此。",
        "Opt_A_Text": "参与诗会",
        "Opt_A_Req": "prop:literary_fame:>20",
        "Opt_A_Result": "prop:literary_fame:+10,prop:money:-20",
        "Opt_B_Text": "默默观察",
        "Opt_B_Result": "prop:literary_fame:+5"
    }
]

var events = DSLParser.parse_csv_data(csv_data)
print("批量解析完成，共解析 %d 个事件" % events.size())
```

## 事件系统工作流程

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

### 2. 标签匹配机制

**两层过滤系统**:

1. **第一层（地理维度）**: SceneAction必须在玩家当前位置有标签交集才能出现
2. **第二层（行为维度）**: 执行action后设置玩家标签，事件通过标签匹配触发，权重根据命中次数动态调整

**匹配逻辑**:
- 没有标签的全局事件永远放行
- 玩家无标签时，有专属标签的事件被略过
- 标签匹配：只要事件包含玩家任一标签就命中
- 首次命中权重x3，多次命中累加

## 错误处理和验证

### 解析错误处理

DSL解析器包含完善的错误处理机制：

- **标签格式验证**: 检查标签是否符合三段式/四段式格式
- **条件语法验证**: 检查条件和操作符的语法正确性
- **必需字段检查**: 确保Event_ID等必需字段存在
- **数据类型验证**: 确保数值字段能正确转换

### 日志输出

系统使用Logging模块记录解析过程中的警告和错误：

```gdscript
Logging.err("Event_ID is required")
Logging.warn("Trigger_Tags is empty for event: %s" % event_id)
Logging.warn("Unknown requirement type: %s" % req_str)
```

### 事件验证

`validate_event()` 方法会检查：
- 事件ID是否存在
- 选项数量是否合理
- 背景图片是否存在

## 最佳实践

### 1. 标签设计

- **保持语义清晰**: 使用有意义的domain和category
- **避免过度细分**: 标签应该用于事件匹配，不应该承担过多细节
- **考虑可扩展性**: 预留足够的命名空间

### 2. 条件设计

- **简单优先**: 优先使用简单的条件，避免复杂的嵌套
- **性能考虑**: 属性检查比特性检查更高效
- **合理权重**: 使用权重字段控制事件出现频率

### 3. 选项设计

- **提供多样性**: 每个事件至少提供2-3个选项
- **条件门槛**: 为选项设置合理的触发条件
- **结果平衡**: 确保不同选项的结果有明确的权衡

### 4. 数据维护

- **版本控制**: CSV数据文件应该纳入版本控制
- **批量工具**: 使用批量解析工具提高效率
- **测试验证**: 定期运行测试验证解析结果

## 扩展指南

### 添加新的条件类型

1. 在`MicroDSLParser`中添加新的解析方法
2. 在`DSLParser.parse_single_requirement()`中添加类型判断
3. 实现对应的需求类（继承自`BaseRequirements`）

### 添加新的操作符类型

1. 在`MicroDSLParser.parse_consequence_operators()`中添加类型处理
2. 实现对应的操作符类（继承自`BaseOperator`）
3. 在操作符工厂中注册新类型

### 扩展标签体系

1. 在`TagManager`中定义新的domain
2. 更新标签格式验证逻辑
3. 在文档中更新标签规范

## 相关文件

**核心解析器**:
- `parser/dsl_parser.gd` - 主解析器
- `parser/micro_dsl_parser.gd` - 微型解析器
- `parser/example_usage.gd` - 使用示例

**数据模型**:
- `core/model/decision.gd` - 决策模型
- `core/model/random_event.gd` - 随机事件模型
- `model/event/base_option.gd` - 基础选项类
- `model/event/event_option.gd` - 标准事件选项
- `model/choice_result.gd` - 选择结果

**条件系统**:
- `core/model/base_requirement.gd` - 基础需求类
- `core/requirements/range_requirement.gd` - 范围需求
- `core/requirements/trait_requirement.gd` - 特性需求
- `core/property_requirement.gd` - 属性需求

**操作符系统**:
- `core/model/base_operator.gd` - 基础操作符类
- `core/model/property_operator.gd` - 属性操作符
- `core/model/trait_operator.gd` - 特性操作符
- `core/model/conditional_operator.gd` - 条件操作符

**相关文档**:
- `DOCUMENTATIONS/event_option_system.md` - 事件选项系统文档
- `DOCUMENTATIONS/tag_pattern_confliction.md` - 标签体系设计规范
- `DOCUMENTATIONS/scene_action_and_player_tag_filter.md` - 场景Action与玩家标签匹配机制

## 总结

DSL系统为项目提供了一种简洁、高效的方式来描述游戏事件。通过CSV数据和DSL语法，策划人员可以快速创建和管理大量游戏事件，而无需直接编写代码。系统的模块化设计使得扩展和维护变得容易，同时完善的错误处理机制确保了数据的健壮性。

**设计优势** 🤓☝️:
- **数据驱动**: 策划可以通过CSV直接编辑游戏内容
- **类型安全**: 强类型验证减少运行时错误
- **可扩展性**: 模块化设计支持添加新的条件和操作符
- **向后兼容**: 支持三段式和四段式标签格式
- **性能优化**: 标签匹配机制支持权重计算和缓存