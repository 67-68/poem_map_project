# DSL CSV 表格结构指南

## 概述

本文档详细说明了使用 DSL 定义游戏事件的 CSV 表格结构。该系统基于 **PDA（下推自动机）** 解析行层级，用缩进/深度表示事件和选项的嵌套关系，不再使用旧式的平面 `Opt_X_*` 列。

> **核心理念**：每一行就是一个独立的数据单元，行与行之间的父子关系由 `depth`（缩进深度）决定。
> depth 0 = 事件根节点，depth 1+ = 选项子节点。
> 旧式 `Opt_X_Text/Opt_X_Req/Opt_X_Result` 列仍然被兼容解析（fallback），但**不推荐使用**。

---

## 完整表头结构

CSV 文件的第一行必须包含以下字段（按顺序）：

```
row_type | template | uuid | context | requirements | title | description | results | emotion_config
```

> **注意**：CSV 本身用逗号分隔，但 `context`、`requirements`、`results` 等字段内部使用 DSL 语法（管道符 `|` 或逗号分隔键值对）。
> 字段名中的 `|` 是视觉分隔符，实际 CSV 表头是：`row_type,template,uuid,context,requirements,title,description,results`

### 字段总览

| 字段 | 必需 | 描述 |
|------|------|------|
| `row_type` | 是 | 行类型：`random_event`（事件）或 `option`（选项）；支持 `>` 前缀表示深度（如 `>option`） |
| `template` | 否 | 模板 URN，从已有事件拷贝内容再覆盖 |
| `uuid` | 是（事件）/ 否（选项） | 全局唯一标识符，选项可选 |
| `context` | 否 | DSL 上下文：trigger_tags、weight、background、custom_params 等 |
| `requirements` | 否 | DSL 条件表达式 |
| `title` | 否 | 显示标题 |
| `description` | 否 | 描述文本 |
| `results` | 否 | DSL 结果操作符 |
| `emotion_config` | 否 | 情绪配置（仅 event 级别解析，option 行会忽略并 warn） |

---

## 字段详细说明

### 基础事件字段

#### row_type (必需)
- **类型**: `String`（枚举，支持 `>` 深度前缀）
- **描述**: 行的角色类型，决定解析器如何处理该行。支持使用 `>` 前缀表示深度层级。
- **可选值**:
  - `random_event` — 这是一个事件根节点（depth 0）
  - `option` — 这是一个选项子节点（depth 1+）
- **深度前缀语法**: 可以在值前加 `>` 表示层级深度
  - `option` = depth 0（不推荐用于 root，但合法）
  - `>option` = depth 1
  - `>>option` = depth 2
  - `>>>option` = depth 3
- **示例**: `random_event`, `option`, `>option`, `>>option`
- **约束**: 不区分大小写，但建议全小写；`>` 前缀必须在类型名称之前

#### template (可选)
- **类型**: `String`（URN 格式）
- **描述**: 模板 URN，指向一个已有的事件资源。解析器会：
  1. 通过 `URN.get_resource_through_urn()` 获取模板资源
  2. 调用 `.duplicate()` 深拷贝
  3. 将拷贝的 UUID 替换为当前行的 UUID
  4. 当前行 CSV 字段的值会**覆盖**模板中对应的值
- **格式**: `urn:<type>:<resource_id>`
- **示例**: `urn:random-event:test_event_pool_2_meet_the_poor`
- **注意**:
  - 如果 template 解析失败（资源不存在或类型不匹配），解析器会**降级**为新建空事件
  - template 字段为空时，直接新建事件
  - 详情见 [`parser/README.md`](../parser/README.md) 的 "Template URN 机制" 章节

#### uuid (事件必需，选项可选)
- **类型**: `String` (GUID)
- **描述**: 事件的全局唯一标识符
- **示例**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- **约束**: 
  - 对于 `random_event` 行，uuid 不能为空
  - 对于 `option` 行，uuid 可选，不指定则自动生成
  - 在整个系统中必须唯一

#### context (可选)
- **类型**: `String`（DSL 上下文语法）
- **描述**: 包含事件/选项的上下文信息，如触发标签、权重、背景、自定义参数等
- **格式**: 逗号分隔的键值对
  ```
  trigger_tags=<tag_syntax>,weight=<float>,background=<string>,custom_params=<json>
  ```
- **字段说明**:
  - `trigger_tags` — 触发标签，格式见下文
  - `weight` — 事件权重，影响随机池中的出现概率
  - `background` — 背景图片资源名
  - `custom_params` — JSON 格式的自定义参数（可选）
- **示例**: 
  - `trigger_tags=actor:status:temporary:drunk,weight=15.5,background=bg_rural_poor`
  - `trigger_tags=action:intent:study:poetry`
- **注意**: 字段内不要有多余空格

##### 触发标签格式 (trigger_tags)

触发标签系统使用分层命名空间：

- **四段式（推荐）**: `domain:category:type:specific`
  - 示例: `actor:status:temporary:drunk`, `city:econ:level:prosperous`
- **三段式（兼容）**: `domain:category:value`
  - 示例: `actor:status:drunk`, `city:econ:prosperous`
- **多个标签**: 用逗号分隔
  - 示例: `actor:status:temporary:drunk,city:econ:level:prosperous`

**支持的 Domain**:
| Domain | 描述 |
|--------|------|
| `actor` | 人物相关标签 |
| `city` | 城市相关标签 |
| `action` | 行动相关标签 |
| `intel` | 情报/剧情相关标签 |

> 旧数据的三段式标签会被 `TagManager.normalize_3part_depreciated_tag()` 自动归一化处理。

#### requirements (可选)
- **类型**: `String`（DSL 条件格式）
- **描述**: 事件触发的额外条件，多个条件用逗号分隔（AND 逻辑）
- **格式**:
  - 属性条件: `prop:<property_name>:<operator><value>`
    - 示例: `prop:money:>50`, `prop:health:<30`
  - 特性条件: `trait:has:<trait_name>` 或 `trait:not_has:<trait_name>`
    - 示例: `trait:has:official`, `trait:not_has:corrupt`
  - 标志位条件: `flag:<type>:<operator>:<value>`
    - 示例: `flag:bool:has:flag_player_has_key`, `flag:str:is:flag_player_title:官员`
  - DeepSeek 条件（特殊）: `deepseek:<prompt>`
    - 示例: `deepseek:判断玩家是否在京兆府任职`
- **多条件组合**: `prop:money:>50,trait:has:official,flag:bool:has:flag_has_key`
- **注意**: options 行的 requirements 控制选项的**可用性**（不可用则禁用/隐藏）

#### title (可选)
- **类型**: `String`
- **描述**: 事件的显示标题
- **示例**: `长安酒馆奇遇`, `市场诗会`
- **建议**: 简洁明了，通常不超过 20 个字符

#### description (可选)
- **类型**: `String`
- **描述**: 事件的详细描述文本
- **示例**: `你在长安的一家酒馆中遇到了一位神秘的诗人，他似乎喝醉了，但眼中却闪烁着智慧的光芒。`
- **建议**: 描述生动，为玩家提供情境代入感

#### results (可选，主要用在选项行)
- **类型**: `String`（DSL 结果格式）
- **描述**: 选择该选项后执行的结果操作符。对于 `random_event` 行，该字段通常为空。
- **格式**: 多个操作符用逗号分隔
  - 属性操作: `prop:<property_name>:<value>`（支持 +/- 符号）
    - 示例: `prop:money:-100`, `prop:literary_fame:+15`
  - 特性操作: `trait:add:<trait_name>` 或 `trait:remove:<trait_name>`
    - 示例: `trait:add:corrupt`, `trait:remove:weak`
  - 标志位操作:
    - 布尔: `flag:bool:add:<flag_id>`, `flag:bool:remove:<flag_id>`, `flag:bool:<old>-><new>`
    - 字符串: `flag:str:set:<flag_id>:<content>`
    - 整数: `flag:int:add:<flag_id>:<value>`, `flag:int:set:<flag_id>:<value>`
  - DeepSeek 生成: `deepseek:<prompt>`
    - 示例: `deepseek:生成一段关于科举落榜的诗句`
- **示例**: `prop:money:-100,trait:add:corrupt,flag:bool:add:flag_bribed`

#### emotion_config (可选，仅 event 级别)
- **类型**: `String`（DSL 情绪配置格式）
- **描述**: 情绪的配置系统，用于配置条件→意象的映射关系。**目前仅 `random_event` 行解析此字段**，`option` 行会忽略并发出警告（虽然未来 option 可能也有自己的 config）。
- **格式**: 多个配置用分号 `;` 分隔
  ```
  <imaginary_name> <- <conditions>
  ```
  - `<imaginary_name>` — 目标意象名称
  - `<conditions>` — 触发条件，支持 `|`（OR）和 `&`（AND）组合
  - 条件格式: `emotion:<emotion_name>:<operator><value>`
- **示例**:
  - `sorrow <- emotion:sorrow:>10`
  - `joy <- emotion:joy:>20 | emotion:surprise:>5`
  - `anger <- emotion:anger:>15&emotion:frustration:>8`
- **注意**: 旧版 CSV 使用 `opt_X_emotion_config` 列（旧式 fallback 路径），新 PDA 行直接用 `emotion_config` 列

---

## 行层级系统（PDA 核心）

### 深度值推导规则

解析器通过以下两种方式推导行深度（优先级：`>` 前缀 > 缩进空格）：

#### 方式一：`row_type` 列中的 `>` 前缀（推荐）
在 `row_type` 值前加 `>` 字符表示深度层级，解析器会自动提取 `>` 数量作为 depth 值：

| `row_type` 值 | 推导深度 | 角色 |
|---------------|---------|------|
| `random_event` | depth 0 | 事件根节点 |
| `option` | depth 0 | 顶层选项（一般不这样用） |
| `>option` | depth 1 | 一级选项 |
| `>>option` | depth 2 | 二级选项（子选项） |
| `>>>option` | depth 3 | 三级选项 |

#### 方式二：缩进空格（传统方式）
通过行首缩进空格数推导深度，适用于没有 `>` 前缀的传统格式：

| 缩进前导空格 | 推导深度 | 角色 |
|-------------|---------|------|
| 0 个空格 | depth 0 | 事件根节点 (`random_event`) |
| 2 个空格 | depth 1 | 一级选项 (`option`) |
| 4 个空格 | depth 2 | 二级选项 (子选项) |
| 6 个空格 | depth 3 | 三级选项 |
| ... | ... | ... |

### 层级约束

- depth 0 的行，`row_type` 通常是 `random_event`
- depth > 0 的行，`row_type` 通常是 `option`
- 每个事件可以有任意数量的选项（不再限于 6 个）
- 选项可以嵌套（子选项）
- 连续多个同 depth 的 option 行，通过 PDA 的 `while stack.size() > depth` 自然归为同一父事件的多个独立选项

### 表头行特殊处理

- 表头行（第一行）的字段内容如果是 `row_type`、`template`、`uuid` 等已知表头字段，则视为表头
- 如果第一行的 `row_type` 字段包含 `row_type` 关键词，视为新式表头
- 否则视为旧式表头，触发向后兼容解析

---

## 向后兼容（旧式表头）

旧式 `Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_X_*` 表头仍然被支持。

**检测逻辑**：如果第一行的 `row_type` 字段不是已知的 `row_type` 关键词，则进入兼容模式。

**兼容模式行为**：
1. 为每行自动生成 UUID
2. 将 `Event_ID` 映射到 `context` 中的标识
3. 将 `Trigger_Tags` 映射到 `context` 的 `trigger_tags=`
4. 从平面的 `Opt_X_Text/Opt_X_Req/Opt_X_Result` 列中提取选项数据
5. 选项数量受限于 CSV 中定义的列数

> **建议**：新文件使用新式 PDA 表头。旧文件在修改时迁移到新格式。

---

## 完整示例解析

### 示例 1: 简单事件（新式表头）

```csv
row_type,template,uuid,context,requirements,title,description,results
random_event,,a1b2c3d4-e5f6-7890-abcd-ef1234567890,trigger_tags=action:intent:study:poetry,,简单诗会,参加一个简单的诗会活动,,
  option,,,,,参与,,prop:literary_fame:+10
```

**解析**:
- depth 0: 事件 `简单诗会`，触发标签 `action:intent:study:poetry`
- depth 1: 选项 `参与`，无门槛，文学名声 +10
- 注意选项行前面的**两个空格**表示 depth 1

### 示例 2: 使用模板的事件

```csv
row_type,template,uuid,context,requirements,title,description,results
random_event,urn:random-event:test_event_pool_2_meet_the_poor,b2c3d4e5-f6a7-8901-bcde-f23456789012,trigger_tags=actor:status:temporary:drunk,prop:money:>50,,长安酒馆奇遇,你在长安的酒馆中遇到了一个神秘人。,
  option,,,,,塞钱贿赂,prop:money:>100,prop:money:-100,trait:add:corrupt
  option,,,,,与之对诗,prop:literary_fame:>20,prop:literary_fame:+15
```

**解析**:
- 事件通过 `urn:random-event:test_event_pool_2_meet_the_poor` 作为模板
- 模板中的内容（标题、描述、选项等）会被复制过来
- CSV 中的字段会**覆盖**模板中的对应值
  - 这里 `context`、`title`、`description` 覆盖了模板的对应字段
  - UUID 被替换为 `b2c3d4e5-...`
- 两个选项是在 CSV 行中**新增**的，不会替换模板的选项（它们会被合并）

### 示例 3: 多选项事件 + 复杂 context

```csv
row_type,template,uuid,context,requirements,title,description,results
random_event,,c3d4e5f6-a7b8-9012-cdef-345678901234,trigger_tags=action:travel:mode:road,weight=8.0,background=bg_mountain,prop:health:>30,山贼拦路,在山路上遇到了山贼。,
  option,,,,,武力反抗,prop:strength:>40,prop:health:-20,prop:prestige:+10,trait:add:brave
  option,,,,,交钱保命,prop:money:>50,prop:money:-50
  option,,,,,智取脱身,prop:intel:>35,prop:intel:+10,prop:prestige:+15
  option,,,,,呼救求助,trait:has:connected,prop:money:-20
```

**解析**:
- context 中包含多个字段：`trigger_tags`、`weight`、`background`，用逗号分隔
- 4 个选项，每个有不同的条件和结果
- 每个选项行前有 2 个空格缩进

### 示例 4: 包含标志位的事件

```csv
row_type,template,uuid,context,requirements,title,description,results
random_event,,d4e5f6a7-b8c9-0123-defa-456789012345,trigger_tags=action:enter:location:palace,flag:bool:has:flag_player_visited_palace,再次进宫,你再次来到皇宫。,
  option,,,,,贿赂守卫,prop:money:>50,prop:money:-50,flag:bool:flag_has_low_reputation->flag_has_high_reputation
  option,,,,,直接拜访,flag:str:is:flag_player_title:官员,prop:prestige:+20
```

**解析**:
- 事件要求玩家已访问过皇宫（标志位条件）
- 选项 A: 贿赂守卫，将低声誉标志替换为高声誉标志
- 选项 B: 直接拜访，要求玩家称号为"官员"

### 示例 5: 使用 emotion_config 的事件

```csv
row_type,template,uuid,context,requirements,title,description,results,emotion_config
random_event,,e5f6a7b8-c9d0-1234-efab-567890123456,trigger_tags=actor:status:sad,weight=12.0,,雨夜思乡,窗外下着雨，你独坐房中，心中涌起思乡之情。,,sorrow <- emotion:sorrow:>10;homesick <- emotion:sorrow:>20&emotion:loneliness:>5
  option,,,,,,借酒浇愁,,prop:health:-10,prop:money:-20
  option,,,,,,写诗抒怀,,prop:literary_fame:+15
```

**解析**:
- `emotion_config` 定义了两个情绪-意象映射：
  - `sorrow <- emotion:sorrow:>10` — 当 sorrow > 10 时触发 sorrow 意象
  - `homesick <- emotion:sorrow:>20&emotion:loneliness:>5` — 当 sorrow > 20 且 loneliness > 5 时触发 homesick 意象
- 选项行没有 `emotion_config`（写了也会被忽略并 warn）

### 示例 6: 使用 `>` 深度前缀（简写格式）

```csv
row_type,template,uuid,context,requirements,title,description,results
random_event,,f6a7b8c9-d0e1-2345-fabc-678901234567,trigger_tags=action:travel:mode:road,weight=10.0,,山间偶遇,你在山间小路上遇到了一个采药的老者。,
>option,,,,,,虚心请教,,prop:wisdom:+10
>option,,,,,,购买草药,prop:money:>30,prop:money:-30,prop:health:+15
>option,,,,,,匆匆赶路,,,
```

**解析**:
- `>option` 中的 `>` 表示 depth 1（等同于前面加两个空格缩进）
- 连续三个 `>option` 行都是同一事件的独立选项
- 比起缩进空格，`>` 前缀在视觉上更清晰，尤其适合短行

---

## 标志位数据结构

标志位数据使用**单独**的 CSV 文件管理，通过 `csv_cloud_loader.gd` 加载。

### 标志位 CSV 文件

**必需字段**:
- `flag_id` — 标志位唯一标识符
- `type` — 标志位类型（`str`、`int`、`bool`）
- `default_value` — 默认值

**示例**:
```csv
flag_id,type,default_value
flag_player_name,str,张三
flag_score,int,0
flag_has_key,bool,false
flag_game_completed,bool,FALSE
```

**布尔值支持格式**:
- `true` / `false`
- `t` / `f`（简写）
- `1` / `0`
- `yes` / `no`
- `TRUE` / `FALSE`（不区分大小写）

**标志位类型说明**:
| 类型 | 描述 |
|------|------|
| `bool` | 布尔标志，用于表示开关状态 |
| `str` | 字符串标志，用于存储文本信息 |
| `int` | 整数标志，用于存储数值信息 |

---

## CSV 格式规范

### 文件编码
- **推荐**: UTF-8
- **注意**: 确保中文字符能正确显示

### 分隔符
- **标准**: 逗号 `,`
- **注意**: 如果字段内容中包含逗号，需要用双引号包裹

### 引号处理
- **规则**: 字段内容包含逗号、换行符或引号时，必须用双引号包裹
- **示例**: `title,"复杂,多变的标题",description`

### 空字段处理
- **规则**: 不需要填写的可选字段留空即可
- **示例**: `random_event,,uuid-001,trigger_tags=action:study,,简单事件,,`

### 缩进规则
- 选项行的缩进使用**空格**（建议 2 个空格 = 1 级 depth）
- 不要使用 Tab 缩进
- depth 0 的行不要有前导空格（表头行除外）

### 换行符
- **推荐**: Unix 风格 `\n`
- **兼容**: 系统通常会自动处理 Windows 风格 `\r\n`

---

## 字段依赖关系

### 必需字段组合
- **最小有效事件**:
  - `row_type` = `random_event`
  - `uuid` 非空
  - `context.trigger_tags` 非空
  - 至少一个 `option` 子行

### 选项字段依赖
- 如果设置了 `requirements`，选项在条件不满足时被禁用（但仍显示）
- 如果设置了 `results`，必须确保结果操作符语法正确
- `requirements` 和 `results` 可以独立设置

### 条件字段依赖
- `requirements` 中的属性名必须在游戏属性系统中存在
- `trait` 相关的条件和操作中，特性名必须在特性系统中定义
- `background` 引用的图片资源必须存在于资源库中
- `template` 引用的 URN 必须指向一个已加载的 `RandomEvent` 资源

---

## 数据验证规则

### uuid 验证
- 不能为空（对于 `random_event` 行）
- 格式不强制但建议使用 GUID 格式
- 在整个系统中必须唯一

### trigger_tags 验证
- 不能为空
- 每个标签必须符合四段式格式 `domain:category:type:specific` 或三段式格式 `domain:category:value`
- domain 必须是预定义的值（`actor`/`city`/`action`/`intel`）
- 四段式是推荐格式，三段式向后兼容

### requirements 验证
- 属性条件格式: `prop:<property_name>:<operator><value>`
- 特性条件格式: `trait:has:<trait_name>` 或 `trait:not_has:<trait_name>`
- value 必须是有效的数值

### weight 验证
- 必须是有效的浮点数
- 建议范围: 1.0–50.0
- 不能为负数

### template 验证
- 必须符合 `urn:<type>:<resource_id>` 格式
- 引用的资源必须存在且类型匹配
- 如果验证失败，解析器降级为新建空事件并记录警告

### 选项验证
- 选项行需要缩进正确（2 空格 = 1 级 depth）
- 选项文本不能为空（如果要显示该选项）
- 选项条件和结果必须符合 DSL 语法

---

## Template URN 机制详解

### 工作流程

```
CSV 行含有 template 字段?
  ├── 是 → URN.get_resource_through_urn(template)
  │         ├── 成功 → resource.duplicate() → 替换 UUID → CSV 字段覆盖
  │         └── 失败 → 记录 warn，新建空事件
  └── 否 → 新建空事件
```

### 覆盖规则

1. Template 先通过 URN 获取资源，调用 `.duplicate()` 深拷贝
2. 拷贝的 UUID 被替换为 CSV 行中的 `uuid`
3. CSV 行中**非空**的字段会覆盖模板中对应字段的值
4. 选项合并策略：模板中的选项 + CSV 行中新增的选项

### 时序约束

由于 template 解析依赖 `URN.get_resource_through_urn()`，而该函数在**编辑器模式**下通过 `.tres` registry 文件查找资源，**必须在 CSV 同步开始前确保 registry 文件已创建**。

`csv_cloud_loader.gd` 中 `DATA_MANIFEST` 的排列顺序很重要：
- `trait` 和 `flag` 表（不依赖 template）应排在前面
- `random_event` 表（可能依赖 template）应排在后面
- 每次保存 `.tres` 后会自动刷新 registry

> **如果你乱改 `DATA_MANIFEST` 的顺序，可能导致 template 解析时找不到引用的资源，系统会静默降级为新建空事件。这不是 bug，是时序约束，改之前想清楚 😨。**

---

## 常见错误示例

### 错误 1: 缩进不正确

```csv
# 错误 - 选项行没有缩进
row_type,uuid,context,title
random_event,uuid-001,trigger_tags=action:study,简单事件
option,,,参与  # ← 这不会被识别为子行
```

```csv
# 正确
row_type,uuid,context,title
random_event,uuid-001,trigger_tags=action:study,简单事件
  option,,,参与  # ← 两个空格缩进
```

### 错误 2: template URN 格式错误

```csv
# 错误
random_event,random-event:test_event,,,
```

```csv
# 正确
random_event,urn:random-event:test_event_pool_2_meet_the_poor,,,
```

### 错误 3: uuid 为空（事件行）

```csv
# 错误 - random_event 行 uuid 为空
random_event,,,trigger_tags=action:study,标题
```

```csv
# 正确
random_event,,uuid-001,trigger_tags=action:study,标题
```

### 错误 4: context 语法错误

```csv
# 错误 - context 内有多余空格
random_event,,uuid-001,"trigger_tags = action:study , weight = 10.0"
```

```csv
# 正确
random_event,,uuid-001,trigger_tags=action:study,weight=10.0
```

### 错误 5: 旧式表头与新式解析器混用

```csv
# 旧式表头（OK 的，会被兼容）
Event_ID,Trigger_Tags,requirements,Title,Desc,background,weight,Opt_A_Text,Opt_A_Req,Opt_A_Result
evt_01,action:study,,简单事件,,,10.0,参与,,prop:literary_fame:+10
```

```csv
# 新式表头（推荐）
row_type,template,uuid,context,requirements,title,description,results
random_event,,uuid-001,trigger_tags=action:study,weight=10.0,,简单事件,,prop:literary_fame:+10
```

---

## 文件组织与批量处理

### 文件组织
- 按事件类型分类到不同 CSV 文件
- 每个文件包含相关主题的事件
- 文件名使用描述性名称：`combat_events.csv`、`social_events.csv`

### 版本控制
- 将 CSV 文件纳入版本控制
- 使用有意义的 commit message
- 定期备份重要数据

### 测试验证
- 使用 DSLParser 验证 CSV 数据
- 检查日志输出中的警告和错误（尤其是 template 解析失败的情况）
- 验证生成的事件对象是否正确

### 性能优化
- 避免单个 CSV 文件过大（建议 <1000 行）
- 合理设置事件权重，避免权重计算过于复杂
- 定期清理不再使用的事件
- template 字段引用的资源不要形成循环依赖

---

## 工具支持

### 解析器使用

```gdscript
# 从 CSV Cloud Loader 获取数据
var csv_data = CSVCloudLoader.load_csv("res://data/csv_random_events/events.csv")

# 解析事件（PDA 自动推导层级）
var events = DSLParser.parse_csv_data(csv_data)

# 验证结果
for event in events:
    if DSLParser.validate_event(event):
        print("事件验证通过: ", event.uuid)
    else:
        print("事件验证失败: ", event.uuid)
```

### 关键文件位置

| 文件 | 用途 |
|------|------|
| `parser/dsl_parser.gd` | DSL 解析器（PDA 实现） |
| `parser/micro_dsl_parser.gd` | 微型 DSL 解析器（条件/结果语法） |
| `parser/README.md` | 解析器技术文档 |
| `core/csv_cloud_loader.gd` | CSV 云加载器（加载→解析→保存→registry 管线） |
| `model/urn.gd` | URN 解析与资源查找 |
| `model/random_event.gd` | RandomEvent 模型类 |

### 示例文件位置
- CSV 示例: `tests/dsl_events_example.csv`
- 解析器测试: `tests/`（见项目测试目录）

---

## 扩展字段

如果需要在现有字段之外添加自定义数据：

1. 在 CSV 表头中添加新字段（追加到末尾，或使用 `custom_params` 在 context 中承载）
2. 如果使用 `custom_params`，在 context 字段中以 JSON 格式传入
3. 如果添加永久字段，需要在 `DSLParser.parse_random_event()` 和 `DSLParser.parse_option_row()` 中添加对应的解析逻辑
4. 在 `RandomEvent` 模型类中添加对应的属性
5. 更新相关的验证和处理逻辑

---

## 总结

DSL CSV 表格结构通过 **PDA 行层级系统**取代了旧式的平面列结构，带来了几个关键改进：

1. **选项数量无上限** — 不再受 `Opt_A` ~ `Opt_F` 的列限制
2. **支持嵌套** — 选项可以包含子选项
3. **Template 复用** — 通过 URN 引用其他事件减少重复数据
4. **清晰的数据边界** — `context`、`requirements`、`results` 各司其职
5. **向后兼容** — 旧式 `Event_ID,Trigger_Tags,Opt_X_*` 文件仍可正常加载

> **简洁的数据结构 + 清晰的语义 + 务实的兼容性 = 高效的 DSL 工作流** 🤓☝️

如果你还在用手写 `Opt_A_Text,Opt_A_Req,Opt_A_Result,Opt_B_Text,...` 的 CSV，该醒醒了 😭。新式 PDA 行结构让你多快好省，还不快来写 `random_event` 行？
