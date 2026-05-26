# DSL CSV 表格结构指南

## 概述

本文档详细说明了使用DSL定义游戏事件的CSV表格结构。CSV表格通过简单的文本格式描述复杂的游戏事件，包括触发条件、选项、结果等。

## 完整表头结构

```
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,
Opt_A_Text,Opt_A_Req,Opt_A_Result,
Opt_B_Text,Opt_B_Req,Opt_B_Result,
Opt_C_Text,Opt_C_Req,Opt_C_Result,
Opt_D_Text,Opt_D_Req,Opt_D_Result,
Opt_E_Text,Opt_E_Req,Opt_E_Result,
Opt_F_Text,Opt_F_Req,Opt_F_Result
```

## 字段详细说明

### 基础事件字段

#### Event_ID (必需)
- **类型**: String
- **描述**: 事件的唯一标识符，用于在系统中引用该事件
- **格式**: 建议使用 `evt_场景_编号` 的格式
- **示例**: `evt_changan_wine_01`, `evt_market_poetry_02`
- **约束**: 必须唯一，不能为空

#### Trigger_Tags (必需)
- **类型**: String
- **描述**: 事件触发标签，用于事件匹配系统
- **格式**: 多个标签用逗号分隔
  - **四段式（推荐）**: `domain:category:type:specific`
  - **三段式（兼容）**: `domain:category:value`
- **示例**: 
  - 四段式: `actor:status:temporary:drunk,city:econ:level:prosperous,action:intent:study:poetry`
  - 三段式: `actor:status:drunk,city:econ:prosperous,action:study:poetry`
- **支持的Domain**:
  - `actor` - 人物相关标签
  - `city` - 城市相关标签
  - `action` - 行动相关标签
  - `intel` - 情报/剧情相关标签
- **注意**: 
  - 新数据建议使用四段式格式
  - 三段式格式仍被引擎兼容
  - 引擎会自动处理格式转换

#### requirements (可选)
- **类型**: String
- **描述**: 事件触发的额外条件，多个条件用逗号分隔（AND逻辑）
- **格式**:
  - 属性条件: `prop:property_name:>value` 或 `prop:property_name:<value`
  - 特性条件: `trait:has:trait_name` 或 `trait:not_has:trait_name`
  - 标志位条件: `flag:type:operator:value`
- **示例**: `prop:money:>50,trait:has:official,flag:bool:has:flag_player_has_key`
- **支持的属性**: money, literary_fame, official_prestige, health, etc.
- **支持的标志位类型**: bool, str, int

#### Title (可选)
- **类型**: String
- **描述**: 事件的显示标题
- **示例**: `长安酒馆奇遇`, `市场诗会`
- **建议**: 简洁明了，通常不超过20个字符

#### Desc (可选)
- **类型**: String
- **描述**: 事件的详细描述文本
- **示例**: `你在长安的一家酒馆中遇到了一位神秘的诗人，他似乎喝醉了，但眼中却闪烁着智慧的光芒。`
- **建议**: 描述生动，为玩家提供情境代入感

#### background (可选)
- **类型**: String
- **描述**: 事件背景图片的资源名
- **示例**: `bg_rural_poor`, `bg_market`, `bg_temple`
- **注意**: 资源必须存在于项目的背景图片资源库中

#### weight (可选)
- **类型**: Float
- **描述**: 事件的权重值，影响事件在随机池中的出现概率
- **示例**: `15.5`, `10.0`, `20.0`
- **范围**: 通常为1.0-50.0，数值越大出现概率越高
- **默认值**: 如果不设置，系统会使用默认权重

### 选项字段

每个事件支持最多6个选项（A-F），每个选项包含3个子字段：

#### Opt_X_Text (必需，要显示选项则必填)
- **类型**: String
- **描述**: 选项的显示文本
- **示例**: `塞钱贿赂`, `拂袖而去`, `与之对诗`
- **建议**: 简洁有力，体现选项的特点

#### Opt_X_Req (可选)
- **类型**: String
- **描述**: 选项的触发条件，不满足条件的选项会被禁用
- **格式**: 与事件requirements字段相同
- **示例**: `prop:money:>100`, `trait:has:proud`
- **注意**: 如果条件不满足，选项仍会显示但呈禁用状态

#### Opt_X_Result (可选)
- **类型**: String
- **描述**: 选择该选项后执行的结果操作符
- **格式**: 多个操作符用逗号分隔
  - 属性操作: `prop:property_name:value` (支持+/-符号)
  - 特性操作: `trait:add:trait_name` 或 `trait:remove:trait_name`
  - 标志位操作: `flag:type:action:value`
- **示例**: `prop:money:-100,trait:add:corrupt,flag:bool:add:flag_bribed`
- **支持的操作**:
  - 属性修改: `prop:money:+50`, `prop:health:-20`
  - 特性添加: `trait:add:brave`, `trait:add:corrupt`
  - 特性移除: `trait:remove:weak`, `trait:remove:fearful`
  - 标志位布尔: `flag:bool:add:flag_id`, `flag:bool:remove:flag_id`, `flag:bool:old->new`
  - 标志位字符串: `flag:str:set:flag_id:content`
  - 标志位整数: `flag:int:add:flag_id:value`, `flag:int:set:flag_id:value`

## 标志位数据结构

### 标志位CSV文件

标志位数据使用单独的CSV文件管理，通过 `csv_cloud_loader.gd` 加载。

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

**标志位类型说明**:
- `bool`: 布尔标志，用于表示开关状态
- `str`: 字符串标志，用于存储文本信息
- `int`: 整数标志，用于存储数值信息

## 完整示例解析

### 示例1: 简单事件（四段式）

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result
evt_simple_01,action:intent:study:poetry,,简单诗会,参加一个简单的诗会活动,,10.0,参与,,prop:literary_fame:+10
```

**解析**:
- 事件ID: evt_simple_01
- 触发标签: 学习诗歌时触发（四段式: action:intent:study:poetry）
- 无额外条件
- 标题: 简单诗会
- 一个选项: 参与，无门槛，文学名声+10

### 示例2: 复杂事件（四段式）

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result,Opt_B_Text,Opt_B_Req,Opt_B_Result,Opt_C_Text,Opt_C_Req,Opt_C_Result
evt_complex_01,actor:status:temporary:drunk,city:econ:level:prosperous,prop:money:>50,trait:has:official,长安酒馆奇遇,你在长安的一家酒馆中遇到了一位神秘的诗人。,bg_rural_poor,15.5,塞钱贿赂,prop:money:>100,prop:money:-100,trait:add:corrupt,拂袖而去,trait:has:proud,prop:prestige:+50,与之对诗,prop:literary_fame:>20,prop:literary_fame:+15,prop:money:-30
```

**解析**:
- 事件ID: evt_complex_01
- 触发标签: 人物临时醉酒状态 AND 城市经济繁华（四段式）
- 触发条件: 金钱>50 AND 拥有官员特性
- 权重: 15.5
- 选项A: 塞钱贿赂（需要金钱>100）→ 金钱-100，获得腐败特性
- 选项B: 拂袖而去（需要骄傲特性）→ 声望+50
- 选项C: 与之对诗（需要文学名声>20）→ 文学名声+15，金钱-30

### 示例3: 多选项事件（四段式）

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result,Opt_B_Text,Opt_B_Req,Opt_B_Result,Opt_C_Text,Opt_C_Req,Opt_C_Result,Opt_D_Text,Opt_D_Req,Opt_D_Result
evt_multi_01,action:travel:mode:road,city:safety:level:dangerous,prop:health:>30,山贼拦路,在山路上遇到了山贼。,bg_mountain,8.0,武力反抗,prop:strength:>40,prop:health:-20,prop:prestige:+10,trait:add:brave,交钱保命,prop:money:>50,prop:money:-50,prop:health:-5,智取脱身,prop:intel:>35,prop:intel:+10,prop:prestige:+15,呼救求助,trait:has:connected,prop:money:-20,prop:safety:+25
```

**解析**:
- 4个选项，每个选项有不同的触发条件和结果
- 触发标签: 道路旅行模式 AND 城市危险程度（四段式）
- 选项A: 武力反抗（需要力量>40）→ 健康-20，声望+10，获得勇敢特性
- 选项B: 交钱保命（需要金钱>50）→ 金钱-50，健康-5
- 选项C: 智取脱身（需要智力>35）→ 智力+10，声望+15
- 选项D: 呼救求助（需要人脉特性）→ 金钱-20，安全+25
- 可以在选项结果中混合使用属性、特性、标志位操作

### 示例4: 向后兼容示例（三段式）

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result
evt_legacy_01,action:study:poetry,,传统诗会,参加一个传统的诗会活动,,10.0,参与,,prop:literary_fame:+10
```

**解析**:
- 使用三段式标签格式（向后兼容）
- 引擎会自动通过 `TagManager.normalize_3part_depreciated_tag()` 处理
- 新数据建议使用四段式格式

### 示例5: 包含标志位的事件

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result,Opt_B_Text,Opt_B_Req,Opt_B_Result
evt_flag_01,action:enter:location:palace,flag:bool:has:flag_player_visited_palace,再次进宫,你再次来到皇宫，这次似乎有不同的机会。,bg_palace,12.5,贿赂守卫,prop:money:>50,prop:money:-50,flag:bool:flag_has_low_reputation->flag_has_high_reputation,直接拜访,flag:str:is:flag_player_title:官员,prop:prestige:+20
```

**解析**:
- 事件ID: evt_flag_01
- 触发标签: 进入皇宫位置（四段式: action:enter:location:palace）
- 触发条件: 玩家已访问皇宫标志位（flag:bool:has:flag_player_visited_palace）
- 选项A: 贿赂守卫（需要金钱>50）→ 金钱-50，将低声誉标志替换为高声誉标志
- 选项B: 直接拜访（需要玩家标题是官员）→ 声望+20
- 演示了标志位替换操作的使用

## CSV格式规范

### 文件编码
- **推荐**: UTF-8
- **注意**: 确保中文字符能正确显示

### 分隔符
- **标准**: 逗号(,)
- **注意**: 如果字段内容中包含逗号，需要用引号包裹

### 引号处理
- **规则**: 字段内容包含逗号、换行符或引号时，必须用双引号包裹
- **示例**: `Title,"复杂,多变的标题",Desc`

### 空字段处理
- **规则**: 不需要填写的可选字段留空即可
- **示例**: `evt_01,action:study,,,简单事件,,,参与,,,`

### 换行符
- **推荐**: Unix风格 (\n)
- **兼容**: 系统通常会自动处理Windows风格 (\r\n)

## 字段依赖关系

### 必需字段组合
最小有效事件必须包含:
- Event_ID
- Trigger_Tags
- 至少一个选项的 Opt_X_Text

### 选项字段依赖
- 如果设置了 Opt_X_Req，必须设置对应的 Opt_X_Text
- 如果设置了 Opt_X_Result，必须设置对应的 Opt_X_Text
- Opt_X_Req 和 Opt_X_Result 可以独立设置

### 条件字段依赖
- requirements 中的属性名必须在游戏属性系统中存在
- trait 相关的条件和操作中，特性名必须在特性系统中定义
- background 引用的图片资源必须存在于资源库中

## 数据验证规则

### Event_ID 验证
- 不能为空
- 不能包含特殊字符（除了下划线）
- 在整个CSV文件中必须唯一

### Trigger_Tags 验证
- 不能为空
- 每个标签必须符合四段式格式 `domain:category:type:specific` 或三段式格式 `domain:category:value`
- domain必须是预定义的值（actor/city/action/intel）
- 四段式是推荐格式，三段式向后兼容
- 引擎会自动处理格式转换和验证

### requirements 验证
- 属性条件格式: `prop:property_name:>value` 或 `prop:property_name:<value`
- 特性条件格式: `trait:has:trait_name` 或 `trait:not_has:trait_name`
- value必须是有效的数值

### weight 验证
- 必须是有效的浮点数
- 建议范围: 1.0-50.0
- 不能为负数

### 选项验证
- 选项文本不能为空（如果要显示该选项）
- 选项条件和结果必须符合DSL语法
- 选项结果中的属性名必须有效

## 常见错误示例

### 错误1: 标签格式错误
```csv
# 错误 - 缺少domain结构
Trigger_Tags: drunk,prosperous

# 错误 - 格式混乱
Trigger_Tags: actor:drunk,city:prosperous:level

# 正确 - 四段式（推荐）
Trigger_Tags: actor:status:temporary:drunk,city:econ:level:prosperous

# 正确 - 三段式（兼容）
Trigger_Tags: actor:status:drunk,city:econ:prosperous
```

### 错误2: 条件语法错误
```csv
# 错误
requirements: money>50

# 正确
requirements: prop:money:>50
```

### 错误3: 缺少必需字段
```csv
# 错误
,Trigger_Tags,Title

# 正确
Event_ID,Trigger_Tags,Title
evt_01,action:study,简单事件
```

### 错误4: 选项字段不匹配
```csv
# 错误
Opt_A_Text,Opt_A_Req
选项A,prop:money:>100

# 正确
Opt_A_Text,Opt_A_Req,Opt_A_Result
选项A,prop:money:>100,prop:money:-50
```

## 批量处理建议

### 文件组织
- 按事件类型分类到不同CSV文件
- 每个文件包含相关主题的事件
- 文件名使用描述性名称：`combat_events.csv`, `social_events.csv`

### 版本控制
- 将CSV文件纳入版本控制
- 使用有意义的commit message
- 定期备份重要数据

### 测试验证
- 使用提供的解析器测试CSV数据
- 检查日志输出中的警告和错误
- 验证生成的事件对象是否正确

### 性能优化
- 避免单个CSV文件过大（建议<1000行）
- 合理设置事件权重，避免权重计算过于复杂
- 定期清理不再使用的事件

## 工具支持

### 解析器使用
```gdscript
# 读取CSV文件
var csv_data = CSVCloudLoader.load_csv("res://data/csv_random_events/events.csv")

# 解析事件
var events = DSLParser.parse_csv_data(csv_data)

# 验证结果
for event in events:
    if DSLParser.validate_event(event):
        print("事件验证通过: ", event.uuid)
    else:
        print("事件验证失败: ", event.uuid)
```

### 示例文件位置
- CSV示例: `data/csv_random_events/dsl_events_example.csv`
- 解析器: `parser/dsl_parser.gd`
- 微型解析器: `parser/micro_dsl_parser.gd`

## 扩展字段

如果需要添加自定义字段，可以：

1. 在CSV表头中添加新字段
2. 在 `DSLParser.parse()` 方法中添加对应的解析逻辑
3. 在事件模型类中添加对应的属性
4. 更新相关的验证和处理逻辑

## 总结

DSL CSV表格结构提供了一个简洁而强大的方式来定义游戏事件。通过合理的字段组织和数据验证，可以确保事件数据的正确性和一致性。建议在创建CSV文件时遵循本文档的规范，并使用提供的工具进行验证和测试。

记住：**简洁的数据结构 + 清晰的语义 = 高效的工作流** 🤓☝️

如果你是Jeff Dean，你会说这是"优雅的数据驱动设计"。但在你的小团队里，这就是"实用且高效"的工作方式 💀。