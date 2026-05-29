# DSL 功能和使用文档

## 概述

本项目使用自定义DSL（Domain Specific Language）来描述游戏事件、条件和结果，主要用于从CSV数据批量解析游戏事件。DSL系统分为三个层次：

- **NamedDSLParser**: 核心解析器，负责解析 `func_name(param=val, ...)` 格式的命名参数表达式
- **MicroDSLParser**: 微型解析器，将高层次的 DSL 操作（如 `prop_gt`、`trait_has`）映射为具体的游戏对象
- **DSLParser**: 高级解析器，负责从 CSV 行数据解析完整的事件结构

## 核心组件

### 1. NamedDSLParser（新增）

**文件位置**: [`parser/named_dsl_parser.gd`](parser/named_dsl_parser.gd)

**职责**: 解析 `func_name(param=val, ...)` 格式的命名参数 DSL 表达式

**核心方法**:
- `parse_single(expr: String) -> ParseResult` - 解析单个函数调用表达式
- `split_expressions(data: String) -> PackedStringArray` - 按顶级逗号分割多个表达式（处理括号嵌套）
- `get_str_param(result, key, default) -> String` - 安全获取字符串参数
- `get_int_param(result, key, default) -> int` - 安全获取整数参数
- `get_bool_param(result, key, default) -> bool` - 安全获取布尔参数

### 2. MicroDSLParser

**文件位置**: [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd)

**职责**: 将 DSL 函数调用映射为游戏对象（条件/操作符）

**主要方法**:
- `parse_tags(data: String) -> Array[String]` - 解析触发标签
- `parse_property_requirement(data: String) -> PropertyRequirement` - 解析属性条件
- `parse_trait_requirement(data: String) -> BaseRequirements` - 解析特性条件
- `parse_flag_requirement(data: String) -> FlagRequirement` - 解析标志位条件
- `parse_consequence_operators(data: String) -> Array[BaseOperator]` - 解析结果操作符

### 3. DSLParser

**文件位置**: [`parser/dsl_parser.gd`](parser/dsl_parser.gd)

**职责**: 从 CSV 数据行解析完整的 RandomEvent 对象

---

## DSL 语法详解（新语法）

### 语法规则

所有 DSL 表达式使用统一的**命名参数函数调用**格式：

```
函数名(参数名=值, 参数名=值, ...)
```

- **函数名**: 编码了操作类型 + 动作（如 `prop_gt` = 属性大于检查）
- **参数名**: 固定名称（如 `name`、`val`、`from`、`to`）
- **值**: 不需要引号包裹字符串，自动识别类型

### 值类型自动识别

| 写法 | 解析类型 | 说明 |
|------|---------|------|
| `val=50` | int | 纯数字 |
| `val=3.14` | float | 带小数点 |
| `name=money` | String | 非数字/布尔 → 自动字符串 |
| `val=true`, `val=false` | bool | 布尔关键字 |
| `name="张三"` | String | 双引号强制字符串（可选，边缘情况用） |

> 💡 **推荐写法**: 字符串值不要加引号，如 `name=money` 而非 `name="money"`

### 多表达式组合

多个表达式用逗号分隔，逗号**只在括号外层**时才是分隔符：

```
prop_gt(name=money, val=50), trait_has(name=official)
```

---

### 1. 触发标签（Tags）

**格式不变**: `domain:category:type:specific`（4段式）

标签不属于函数调用语法，保持原有冒号分割格式。

**示例**:
```
actor:status:temporary:drunk           # 人物状态-临时状态-醉酒
city:econ:level:prosperous             # 城市经济-繁荣程度-繁华
action:intent:study:poetry             # 行动意图-学习类型-诗歌
intel:story_lock:event:anlushan_rebel  # 情报-剧情锁-事件类型-安禄山谋反
```

**多标签**: 逗号分隔
```
actor:status:temporary:drunk,city:econ:level:prosperous
```

---

### 2. 触发条件（Requirements）

#### 2.1 属性条件

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `prop_gt` | name, val | 属性大于 | `prop_gt(name=money, val=50)` |
| `prop_lt` | name, val | 属性小于 | `prop_lt(name=health, val=60)` |

#### 2.2 特性条件

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `trait_has` | name | 拥有特性 | `trait_has(name=official)` |
| `trait_not_has` | name | 不拥有特性 | `trait_not_has(name=corrupt)` |

#### 2.3 标志位条件

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `flag_bool_has` | name | 布尔标志为真 | `flag_bool_has(name=flag_visited_palace)` |
| `flag_bool_not_has` | name | 布尔标志为假 | `flag_bool_not_has(name=flag_game_completed)` |
| `flag_str_is` | name, val | 字符串标志等于 | `flag_str_is(name=player_name, val=张三)` |
| `flag_str_not` | name, val | 字符串标志不等于 | `flag_str_not(name=player_status, val=banned)` |
| `flag_int_gt` | name, val | 整数标志大于 | `flag_int_gt(name=flag_score, val=100)` |
| `flag_int_lt` | name, val | 整数标志小于 | `flag_int_lt(name=flag_health, val=10)` |

#### 2.4 复合条件

多个条件用逗号分隔，AND 逻辑组合：

```
prop_gt(name=money, val=50), trait_has(name=official)
prop_gt(name=literary_fame, val=30), prop_gt(name=money, val=100)
flag_bool_has(name=flag_visited_palace), prop_gt(name=money, val=100)
```

---

### 3. 结果操作符（Consequence Operators）

#### 3.1 属性操作符

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `prop_add` | name, val | 属性增加 | `prop_add(name=prestige, val=50)` |
| `prop_sub` | name, val | 属性减少 | `prop_sub(name=money, val=100)` |
| `prop_set` | name, val | 属性设置 | `prop_set(name=money, val=500)` |

#### 3.2 特性操作符

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `trait_add` | name | 添加特性 | `trait_add(name=corrupt)` |
| `trait_remove` | name | 移除特性 | `trait_remove(name=brave)` |

#### 3.3 情绪操作符

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `emo_add` | name, val | 情绪增加 | `emo_add(name=sorrow, val=10)` |
| `emo_sub` | name, val | 情绪减少 | `emo_sub(name=sorrow, val=5)` |
| `emo_set` | name, val | 情绪设置 | `emo_set(name=sorrow, val=50)` |

#### 3.4 标志位操作符

| 函数 | 参数 | 说明 | 示例 |
|------|------|------|------|
| `flag_bool_set` | name, val | 设置布尔标志 | `flag_bool_set(name=has_key, val=true)` |
| `flag_bool_replace` | from, to | 替换布尔标志 | `flag_bool_replace(from=old_status, to=new_status)` |
| `flag_str_set` | name, val | 设置字符串标志 | `flag_str_set(name=player_name, val=李四)` |
| `flag_str_append` | name, val | 追加字符串标志 | `flag_str_append(name=log, val=新事件)` |
| `flag_int_set` | name, val | 设置整数标志 | `flag_int_set(name=score, val=100)` |
| `flag_int_append` | name, val | 追加整数标志 | `flag_int_append(name=score, val=50)` |

---

## CSV 数据结构

### 新格式表头（下推自动机）

```
depth,row_type,uuid,context,requirements,title,description,results
```

详见 [`new_csv_structure.md`](new_csv_structure.md)

### 旧格式表头（扁平结构）

```
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result,...
```

---

## 新旧语法对照表

### Conditions

| 旧语法（已弃用） | 新语法（推荐） |
|-----------------|---------------|
| `prop:money:>50` | `prop_gt(name=money, val=50)` |
| `prop:money:<100` | `prop_lt(name=money, val=100)` |
| `trait:has:official` | `trait_has(name=official)` |
| `trait:not_has:corrupt` | `trait_not_has(name=corrupt)` |
| `flag:bool:has:xxx` | `flag_bool_has(name=xxx)` |
| `flag:bool:not_has:xxx` | `flag_bool_not_has(name=xxx)` |
| `flag:str:is:xxx:张三` | `flag_str_is(name=xxx, val=张三)` |
| `flag:int:>:score:100` | `flag_int_gt(name=score, val=100)` |

### Consequences

| 旧语法（已弃用） | 新语法（推荐） |
|-----------------|---------------|
| `prop:money:-100` | `prop_sub(name=money, val=100)` |
| `prop:prestige:+50` | `prop_add(name=prestige, val=50)` |
| `trait:add:corrupt` | `trait_add(name=corrupt)` |
| `trait:remove:brave` | `trait_remove(name=brave)` |
| `emo:sorrow:+10` | `emo_add(name=sorrow, val=10)` |
| `flag:bool:add:xxx` | `flag_bool_set(name=xxx, val=true)` |
| `flag:bool:remove:xxx` | `flag_bool_set(name=xxx, val=false)` |
| `flag:bool:old->new` | `flag_bool_replace(from=old, to=new)` |
| `flag:str:set:name:李四` | `flag_str_set(name=name, val=李四)` |
| `flag:int:add:score:50` | `flag_int_append(name=score, val=50)` |
| `flag:int:set:health:100` | `flag_int_set(name=health, val=100)` |

---

## 完整示例

### 单事件 CSV

```csv
Event_ID: evt_changan_01
Trigger_Tags: actor:status:drunk,city:econ:prosperous
requirements: prop_gt(name=money, val=50), trait_has(name=official)
Title: 长安酒馆奇遇
Desc: 你在长安的一家酒馆中遇到了一位神秘的诗人。
Opt_A_Text: 塞钱贿赂
Opt_A_Req: prop_gt(name=money, val=100)
Opt_A_Result: prop_sub(name=money, val=100), trait_add(name=corrupt)
Opt_B_Text: 拂袖而去
Opt_B_Req: trait_has(name=proud)
Opt_B_Result: prop_add(name=prestige, val=50)
weight: 15.5
background: bg_rural_poor
```

### 批量解析示例代码

```gdscript
var csv_data = [
    {
        "Event_ID": "evt_changan_01",
        "Trigger_Tags": "actor:status:drunk,city:econ:prosperous",
        "requirements": "prop_gt(name=money, val=50)",
        "Title": "长安酒馆奇遇",
        "Desc": "你在长安的一家酒馆中遇到了一位神秘的诗人。",
        "Opt_A_Text": "塞钱贿赂",
        "Opt_A_Req": "prop_gt(name=money, val=100)",
        "Opt_A_Result": "prop_sub(name=money, val=100), trait_add(name=corrupt)",
        "Opt_B_Text": "拂袖而去",
        "Opt_B_Req": "trait_has(name=proud)",
        "Opt_B_Result": "prop_add(name=prestige, val=50)"
    },
    {
        "Event_ID": "evt_market_02",
        "Trigger_Tags": "action:study:poetry,city:econ:prosperous",
        "requirements": "prop_gt(name=literary_fame, val=30)",
        "Title": "市场诗会",
        "Desc": "市场上正在举行一场诗会，许多文人墨客聚集于此。",
        "Opt_A_Text": "参与诗会",
        "Opt_A_Req": "prop_gt(name=literary_fame, val=20)",
        "Opt_A_Result": "prop_add(name=literary_fame, val=10), prop_sub(name=money, val=20)",
        "Opt_B_Text": "默默观察",
        "Opt_B_Result": "prop_add(name=literary_fame, val=5)"
    }
]

var events = DSLParser.parse_csv_data(csv_data)
print("批量解析完成，共解析 %d 个事件" % events.size())
```

---

## 错误处理和验证

### 解析错误处理

系统使用 `Logging` 模块记录解析过程中的警告和错误：

```gdscript
Logging.err("属性需求缺少 name 参数")
Logging.warn("⚠ 旧语法已弃用，请迁移到新语法: %s" % old_syntax_str)
```

### 旧语法兼容

旧冒号分割语法（如 `prop:money:>50`）不受支持。

---

## 最佳实践

### 1. 标签设计

- **保持语义清晰**: 使用有意义的domain和category
- **四段式标准**: `domain:category:type:specific`

### 2. DSL 编写

- **字符串不加引号**: `name=money` 而非 `name="money"`
- **命名参数顺序不限**: `prop_gt(val=50, name=money)` 与 `prop_gt(name=money, val=50)` 等价
- **多表达式用逗号分隔**: 注意逗号只在括号外层时才是分隔符
- **type:action 语义编码在函数名中**: 看到 `prop_gt` 就知道是属性大于检查，无需拆字符串推断

### 3. 条件设计

- **简单优先**: 优先使用简单的条件，避免复杂的嵌套
- **合理权重**: 使用权重字段控制事件出现频率

---

## 设计理念 🤓☝️

**为什么从冒号分割迁移到命名参数函数调用？**

1. **消灭位置依赖**: 旧语法 `flag:int:>:flag_score:100` 中第 4 段是 flag_id 还是 value 全靠数冒号。新语法 `flag_int_gt(name=flag_score, val=100)` 参数名即文档。

2. **消灭类型推断**: 旧语法靠字符串前缀 `prop:` / `trait:` / `flag:` 推断类型。新语法函数名自带类型信息（`flag_bool_*` vs `flag_int_*`）。

3. **消灭段数不一致**: 旧语法中 flag 系有 4 段、5 段变长格式。新语法统一为固定参数名。

4. **CSV 友好**: 字符串值不加引号，`name=money` 直接写，不再需要 `""money""` 嵌套引用地狱 💀。

## 相关文件

**核心解析器**:
- [`parser/named_dsl_parser.gd`](parser/named_dsl_parser.gd) - 核心命名参数解析器（新增）
- [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) - 微型解析器（重写）
- [`parser/dsl_parser.gd`](parser/dsl_parser.gd) - 主解析器
- [`parser/example_usage.gd`](parser/example_usage.gd) - 使用示例

**数据模型**:
- `model/random_event.gd` - 随机事件模型
- `model/event/event_option.gd` - 标准事件选项
- `model/choice_result.gd` - 选择结果

**条件系统**:
- `core/model/requirement_operator.gd` - 条件操作符枚举
- `core/requirements/flag_requirement.gd` - 标志位需求
- `core/property_requirement.gd` - 属性需求

**操作符系统**:
- `core/model/base_operator.gd` - 基础操作符类
- `core/model/property_operator.gd` - 属性操作符
- `core/model/trait_operator.gd` - 特性操作符
- `core/operators/flag_operator.gd` - 标志位操作符
