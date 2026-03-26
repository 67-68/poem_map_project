# DSL Parser 文档

## 概述

这个DSL解析器用于解析CSV格式的事件数据，支持复杂的微语法(Micro-DSL)格式来定义游戏的随机事件系统。

## 支持的CSV字段

| 字段类别 | 列名 | 格式说明 | 映射到 |
|---------|------|----------|--------|
| 元数据 | Event_ID | 事件唯一标识符 | BaseEvent.id |
| 关联标签 | Trigger_Tags | `domain:subcategory:specific_attribute` | RandomEvent._target_tags |
| 触发条件 | requirements | 属性和特性条件 | ComplexRequirements |
| 表现层 | Title | 事件标题 | UI显示 |
| 表现层 | Desc | 事件描述 | UI显示 |
| 选项A | Opt_A_Text | 选项文本 | EventOption.description |
| 选项A门槛 | Opt_A_Req | 条件检查 | PropertyRequirement |
| 选项A结果 | Opt_A_Result | 结果操作 | ChoiceResult.operators |
| ... | ... | ... | ... |

## Micro-DSL 语法

### 1. 触发标签格式
```
domain:subcategory:specific_attribute
```

示例：
```
actor:status:drunk          # 人物状态-醉酒
city:econ:prosperous        # 城市经济-繁华
action:study:poetry         # 行动意图-学习-诗歌
intel:event:anlushan_rebel  # 情报/剧情锁-事件-安禄山谋反
```

多个标签用逗号分隔：
```
actor:status:drunk,city:econ:prosperous,action:study:poetry
```

### 2. 触发条件格式

#### 属性触发
```
prop:property_name:>value   # 大于
prop:property_name:<value   # 小于
```

示例：
```
prop:money:>50              # 金钱大于50
prop:literary_fame:<30      # 文学名声小于30
```

#### 特性触发
```
trait:has:trait_name        # 拥有特性
trait:not_has:trait_name    # 不拥有特性
```

示例：
```
trait:has:official          # 拥有官员特性
trait:not_has:criminal      # 不拥有罪犯特性
```

#### 多个条件
用逗号分隔，自动使用AND逻辑：
```
prop:money:>50,prop:literary_fame:>30,trait:has:official
```

### 3. 结果操作符格式

#### 属性修改
```
prop:property_name:+value   # 增加
prop:property_name:-value   # 减少
```

示例：
```
prop:money:+100             # 增加100金钱
prop:health:-20             # 减少20健康
```

#### 特性操作
```
trait:add:trait_name        # 添加特性
trait:remove:trait_name     # 移除特性
```

示例：
```
trait:add:corrupt           # 添加腐败特性
trait:remove:sick           # 移除疾病特性
```

#### 多个操作
用逗号分隔：
```
prop:money:-100,trait:add:corrupt,prop:prestige:+50
```

## 使用方法

### 基本解析
```gdscript
var csv_row = {
    "Event_ID": "evt_changan_01",
    "Trigger_Tags": "actor:status:drunk,city:econ:prosperous",
    "requirements": "prop:money:>50",
    "Title": "长安酒馆奇遇",
    "Desc": "你在酒馆遇到了神秘诗人...",
    "Opt_A_Text": "塞钱贿赂",
    "Opt_A_Req": "prop:money:>100",
    "Opt_A_Result": "prop:money:-100,trait:add:corrupt"
}

var event = DSLParser.parse(csv_row)
```

### 批量解析
```gdscript
var csv_data = [row1, row2, row3, ...]
var events = DSLParser.parse_csv_data(csv_data)
```

### 验证事件
```gdscript
if DSLParser.validate_event(event):
    print("事件有效")
```

## 错误处理

解析器包含完善的错误处理机制：

- **必需字段缺失**：Event_ID字段缺失时会返回null并记录错误
- **格式错误**：无效的DSL格式会记录警告并跳过相关部分
- **类型错误**：无法转换的数值会使用默认值

## 扩展性

### 添加新的操作符类型
在`MicroDSLParser.parse_consequence_operators()`中添加新的类型处理：

```gdscript
elif type == "new_type":
    var operator = parse_new_type_operator(action, value)
    if operator:
        operators.append(operator)
```

### 添加新的需求类型
在`DSLParser.parse_single_requirement()`中添加新的需求处理：

```gdscript
elif req_str.begins_with('new_req:'):
    return parse_new_requirement(req_str)
```

## 注意事项

1. **特性系统**：当前特性需求的实现是简化的，可能需要根据实际游戏系统进行扩展
2. **属性映射**：属性名称需要与游戏中的属性系统保持一致
3. **枚举值**：某些操作符使用枚举值，确保与游戏系统中的枚举定义匹配
4. **性能**：批量解析大量数据时注意性能，建议分批处理

## 示例完整事件

```csv
Event_ID,Trigger_Tags,requirements,Title,Desc,Opt_A_Text,Opt_A_Req,Opt_A_Result,Opt_B_Text,Opt_B_Req,Opt_B_Result
evt_changan_01,"actor:status:drunk,city:econ:prosperous,action:study:poetry","prop:money:>50,trait:has:official","长安酒馆奇遇","你在长安的一家酒馆中遇到了一位神秘的诗人...","塞钱贿赂","prop:money:>100","prop:money:-100,trait:add:corrupt","拂袖而去","trait:has:proud","prop:prestige:+50"
```

这个CSV行会被解析为一个完整的RandomEvent对象，包含所有必要的触发条件、选项和结果。
