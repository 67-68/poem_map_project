# DSL Parser 文档

## 概述

这个DSL解析器用于解析CSV格式的事件数据，支持复杂的微语法(Micro-DSL)格式来定义游戏的随机事件系统。

## 支持的CSV字段

### 事件/选项行字段

| 字段 | 必填 | 格式说明 | 映射到 |
|------|------|----------|--------|
| row_type | 是 | 行类型：`random_event` / `option` | PDA 状态转移 |
| template | 否 | URN 模板，见下方说明 | 从已有资源 duplicate |
| uuid | 是 | 事件唯一标识符 | GameEntity.uuid |
| context | 否 | 触发标签/权重/背景 DSL | RandomEvent._target_tags / weight |
| requirements | 否 | 触发/选择条件 | BaseRequirements |
| title | 否 | 事件标题 | GameEntity.name |
| description | 否 | 事件描述 | GameEntity.description |
| results | 否 | 事件/选项结果操作符 | ChoiceResult |

### 旧式选项列（opt_X 系列）

| 列名 | 格式说明 | 映射到 |
|------|----------|--------|
| Opt_A_Text | 选项文本 | BaseOption.description |
| Opt_A_Req | 条件检查 | PropertyRequirement |
| Opt_A_Result | 结果操作 | ChoiceResult.operators |
| ... | ... | ... |

### Template URN 机制

`template` 字段允许一个 event 或 option 行**基于已有资源创建**，避免重复定义。

**格式**：标准的 URN 字符串，如 `urn:random-event:some_existing_event`

**流程**：
1. 通过 `URN.get_resource_through_urn()` 获取模板资源
2. `.duplicate()` 深拷贝
3. 将拷贝的 uuid 替换为当前行的 uuid
4. CSV 行中的其他字段**覆盖**模板中的对应值

**使用场景**：
- 多个事件共享相同的 context/requirements/results 结构，只改个别字段
- Option 行复用已有事件的配置作为基底

**示例**：
```csv
random_event,urn:random-event:base_banquet_event,evt_farewell_01,"tag:action:social:banquet","prop:money:>30","践行宴","好友即将远行，你设宴践行...","prop:money:-30,prop:friendship:+10"
```

这个事件会从 `base_banquet_event` 模板中 clone 所有字段，然后用 CSV 行中的值覆盖。

**失败回退**：如果 template URN 解析失败（资源不存在、类型不匹配等），自动回退到创建全新的 RandomEvent 对象，不影响整体解析。

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

#### 标志位触发
```
flag:bool:has:flag_id              # 标志位为真
flag:bool:not_has:flag_id          # 标志位为假
flag:str:is:flag_id:value          # 字符串等于指定值
flag:str:is_not:flag_id:value      # 字符串不等于指定值
flag:int:>flag_id:value            # 整数大于指定值
flag:int:<flag_id:value            # 整数小于指定值
```

示例：
```
flag:bool:has:flag_player_has_key              # 玩家有钥匙
flag:bool:not_has:flag_game_completed          # 游戏未完成
flag:str:is:flag_player_name:张三              # 玩家姓名是张三
flag:int:>flag_score:100                      # 分数大于100
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

#### 标志位操作
```
flag:bool:add:flag_id                      # 设置布尔标志为true
flag:bool:remove:flag_id                   # 设置布尔标志为false
flag:bool:old_flag->new_flag              # 替换布尔标志
flag:str:set:flag_id:content              # 设置字符串标志
flag:int:add:flag_id:value                # 增加整数标志
flag:int:set:flag_id:value                # 设置整数标志
```

示例：
```
flag:bool:add:flag_player_has_key          # 获得钥匙
flag:bool:remove:flag_game_over           # 移除游戏结束标志
flag:bool:flag_old_status->flag_new_status  # 替换状态
flag:str:set:flag_player_name:李四         # 设置姓名
flag:int:add:flag_score:50                # 增加分数
flag:int:set:flag_health:100              # 设置健康值
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
