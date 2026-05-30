# DSL Parser 文档

## 概述

这个 DSL 解析器用于解析 CSV 格式的事件数据，支持命名参数微语法 (Micro-DSL) 格式来定义游戏的随机事件系统。

### 语法版本

| 版本 | 状态 | 说明 |
|------|------|------|
| **新语法** (v2) | ✅ **当前唯一支持的语法** | 函数调用格式：`func_name(param=val, ...)` |
| 旧语法 (v1) | ❌ 已移除 | 冒号分割格式：`prop:money:>50` |

> **旧语法（冒号分割格式）已于 2025.10 完全移除**，不再向后兼容。所有 DSL 数据必须使用新语法。

---

## 支持的 CSV 字段

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
random_event,urn:random-event:base_banquet_event,evt_farewell_01,"tag:action:social:banquet","prop_gt(name=money, val=30)","践行宴","好友即将远行，你设宴践行...","prop_sub(name=money, val=30), prop_add(name=friendship, val=10)"
```

**失败回退**：如果 template URN 解析失败（资源不存在、类型不匹配等），自动回退到创建全新的 RandomEvent 对象，不影响整体解析。

---

## Micro-DSL 语法（新语法 v2）

新语法采用**函数调用格式**：`func_name(param1=val1, param2=val2, ...)`

- 函数名编码了 **type** + **action**（如 `prop_gt`、`trait_has`、`flag_bool_set`）
- 参数使用**命名参数**，位置无关
- 字符串值用双引号包裹（可选），数字/布尔值裸写
- 多个表达式用逗号分隔（逗号**不在括号内**的才是分隔符）

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

| 函数 | 说明 | 参数 |
|------|------|------|
| `prop_gt(name=, val=)` | 属性值大于 | name: 属性名, val: 数值 |
| `prop_lt(name=, val=)` | 属性值小于 | name: 属性名, val: 数值 |

示例：
```
prop_gt(name=money, val=50)          # 金钱大于50
prop_lt(name=literary_fame, val=30)  # 文学名声小于30
```

#### 特性触发

| 函数 | 说明 | 参数 |
|------|------|------|
| `trait_has(name=)` | 拥有特性 | name: 特性名 |
| `trait_not_has(name=)` | 不拥有特性 | name: 特性名 |

示例：
```
trait_has(name=official)       # 拥有官员特性
trait_not_has(name=criminal)   # 不拥有罪犯特性
```

#### 标志位触发

| 函数 | 说明 | 参数 |
|------|------|------|
| `flag_bool_has(name=)` | bool flag 存在且为 true | name: flag_id |
| `flag_bool_not_has(name=)` | bool flag 不存在或为 false | name: flag_id |
| `flag_int_gt(name=, val=)` | int flag 值大于 | name: flag_id, val: 数值 |
| `flag_int_lt(name=, val=)` | int flag 值小于 | name: flag_id, val: 数值 |
| `flag_str_is(name=)` | str flag 值非空 | name: flag_id |
| `flag_str_is_not(name=)` | str flag 值为空 | name: flag_id |

示例：
```
flag_bool_has(name=flag_visited_changan)    # 已访问长安
flag_int_gt(name=flag_relation_with_libai, val=10)  # 与李白的关系值 > 10
flag_str_is(name=flag_player_title)          # 有称号
```

#### 多个条件

用逗号分隔，自动使用 AND 逻辑：
```
prop_gt(name=money, val=50), prop_gt(name=literary_fame, val=30), trait_has(name=official)
```

### 3. 概率分支操作符

#### 随机分支

| 函数 | 说明 | 参数 |
|------|------|------|
| `random(val=, success=, fail=, success_hint=, failed_hint=)` | 概率分支，按 `val%` 概率执行 success，否则执行 fail | val: 触发概率 (0-99), success: 成功时执行的 operator, fail: 失败时执行的 operator, success_hint: 成功提示, failed_hint: 失败提示 |

`random()` 是一个**容器操作符**，它根据概率值决定执行哪个子操作符。`success` 和 `fail` 参数的值本身是操作符表达式，解析器会递归解析。

示例：
```
random(val=80, success=prop_add(name="money", val=100), fail=prop_sub(name=reputation, val=5))
random(val=30, success=trait_add(name=promoted), fail=trait_add(name=demoted), success_hint="恭喜高升！", failed_hint="仕途不顺...")
```

注意：`success` 和 `fail` 参数**只能接受单个操作符**，不支持逗号分隔的多个操作符。如果需要多个操作，可以考虑用 `ConditionalOperator` 组合或分层设计。

### 4. 结果操作符格式

#### 属性修改

| 函数 | 说明 | 参数 |
|------|------|------|
| `prop_add(name=, val=)` | 属性增加 | name: 属性名, val: 数值 |
| `prop_sub(name=, val=)` | 属性减少 | name: 属性名, val: 数值 |

示例：
```
prop_add(name=money, val=100)       # 增加100金钱
prop_sub(name=health, val=20)       # 减少20健康
```

#### 特性操作

| 函数 | 说明 | 参数 |
|------|------|------|
| `trait_add(name=)` | 添加特性 | name: 特性名 |
| `trait_remove(name=)` | 移除特性 | name: 特性名 |

示例：
```
trait_add(name=corrupt)      # 添加腐败特性
trait_remove(name=sick)      # 移除疾病特性
```

#### 标志位操作

| 函数 | 说明 | 参数 |
|------|------|------|
| `flag_bool_set(name=, val=)` | 设置 bool flag | name: flag_id, val: true/false |
| `flag_bool_replace(from=, to=)` | 替换 bool flag 名称 | from: 旧 flag_id, to: 新 flag_id |
| `flag_str_set(name=, val=)` | 设置 str flag | name: flag_id, val: 字符串值 |
| `flag_int_set(name=, val=)` | 设置 int flag | name: flag_id, val: 数值 |
| `flag_int_append(name=, val=)` | int flag 增加 | name: flag_id, val: 数值 |

示例：
```
flag_bool_set(name=flag_has_key, val=true)           # 获得钥匙
flag_bool_set(name=flag_game_over, val=false)        # 移除游戏结束标志
flag_bool_replace(from=flag_old_status, to=flag_new_status)  # 替换状态
flag_str_set(name=flag_player_name, val="李四")       # 设置姓名
flag_int_append(name=flag_score, val=50)             # 增加分数
flag_int_set(name=flag_health, val=100)              # 设置健康值
```

#### 多个操作

用逗号分隔：
```
prop_sub(name=money, val=100), trait_add(name=corrupt), prop_add(name=prestige, val=50)
```

---

## 使用方法

### 基本解析
```gdscript
var csv_row = {
    "uuid": "evt_changan_01",
    "trigger_tags": "actor:status:drunk,city:econ:prosperous",
    "requirements": "prop_gt(name=money, val=50)",
    "title": "长安酒馆奇遇",
    "description": "你在酒馆遇到了神秘诗人..."
}
```

### 通过 PDA 下推自动机解析（带选项）
```gdscript
var csv_data: Array[Dictionary] = [
    {
        "row_type": "random_event",
        "uuid": "evt_changan_01",
        "requirements": "prop_gt(name=money, val=50), trait_has(name=official)",
        "title": "长安酒馆奇遇",
        "description": "你在长安的一家酒馆中遇到了一位神秘的诗人..."
    },
    {
        "row_type": ">option",
        "title": "塞钱贿赂",
        "results": "prop_sub(name=money, val=100), trait_add(name=corrupt)"
    },
    {
        "row_type": ">option",
        "title": "拂袖而去",
        "results": "prop_add(name=prestige, val=50)"
    }
]

var events = DSLParser.parse_csv_data(csv_data, "random_event")
```

### 批量解析
```gdscript
var events = DSLParser.parse_csv_data(csv_data, "random_event")
for event in events:
    print("- 事件: %s, 选项数: %d" % [event.uuid, event.options.size()])
```

---

## 错误处理

解析器包含完善的错误处理机制：

- **必需字段缺失**：uuid 字段缺失时会返回 null 并记录错误
- **格式错误**：无效的 DSL 格式会记录警告并跳过相关部分
- **类型错误**：无法转换的数值会使用默认值

---

## 扩展性

### 添加新的操作符类型

在 `[]MicroDSLParser.parse_consequence_operators()` 中添加新的类型处理：

```gdscript
# 新操作符无需特殊处理，NamedDSLParser 自动解析 func_name + params
# 在 parse_consequence_operators 中根据 func_name 分发即可
```

### 添加新的需求类型

在 `[]DSLParser.parse_single_requirement()` 中添加新的需求处理：

```gdscript
elif req_str.begins_with('new_type_'):
    return parse_new_requirement(req_str)
```

---

## 架构说明

### 解析器分层

```
┌─────────────────────────────────────────────────┐
│                  DSLParser                       │
│  ├─ parse_csv_data() — PDA 下推自动机           │
│  ├─ parse_random_event() — 事件行解析           │
│  ├─ parse_requirements() — 复合条件解析         │
│  └─ parse_choice_result() — 结果操作符解析      │
├─────────────────────────────────────────────────┤
│              MicroDSLParser                     │
│  ├─ parse_property_requirement()                │
│  ├─ parse_trait_requirement()                   │
│  ├─ parse_flag_requirement()                    │
│  └─ parse_consequence_operators()               │
├─────────────────────────────────────────────────┤
│              NamedDSLParser                     │
│  ├─ split_expressions() — 括号感知逗号分割      │
│  └─ parse_single() — 命名参数解析              │
└─────────────────────────────────────────────────┘
```

### 下推自动机 (PDA)

DSL Parser 使用下推自动机解析层级 CSV 数据：

- `depth=0` → 顶层事件 (`random_event`)
- `depth=1` → 选项子行 (`option`)，挂载到栈顶事件
- `row_type` 前置 `>` 表示层级（如 `>option` 等价于 depth=1）

---

## 注意事项

1. **特性系统**：当前特性需求的实现是简化的，可能需要根据实际游戏系统进行扩展
2. **属性映射**：属性名称需要与游戏中的属性系统保持一致
3. **枚举值**：某些操作符使用枚举值，确保与游戏系统中的枚举定义匹配
4. **类型数组**：`parse_csv_data()` 的第一个参数要求 `Array[Dictionary]`，调用时必须显式声明类型，避免 Godot 4 类型数组入参不匹配
5. **性能**：批量解析大量数据时注意性能，建议分批处理

---

## 完整示例

```csv
uuid,trigger_tags,requirements,title,description,results
evt_changan_01,"actor:status:drunk,city:econ:prosperous","prop_gt(name=money, val=50), trait_has(name=official)","长安酒馆奇遇","你在长安的酒馆中遇到了一位神秘的诗人...",""
```

对应的选项子行（PDA 解析）：
```csv
row_type,uuid,trigger_tags,requirements,title,description,results
random_event,evt_changan_01,"actor:status:drunk,city:econ:prosperous","prop_gt(name=money, val=50), trait_has(name=official)","长安酒馆奇遇","你在长安的酒馆中遇到了一位神秘的诗人...",""
>option,,,,"塞钱贿赂","","prop_sub(name=money, val=100), trait_add(name=corrupt)"
>option,,,,"拂袖而去","","prop_add(name=prestige, val=50)"
```
