# 事件系统构建 Sub-System 最佳实践

> 最后更新: 2026-06-16
> 基于飞花令（Feihualing）和联句（Lianju）两个已实现子系统的逆向工程

## 0. 因果前置事件原则 (Causal Precedent Principle)

**「只有你本来就是这样的人，做了这样的事，才会导致这个事件。」**

### 定义

因果前置事件是一类特殊的事件：触发条件必须包含 `trait_has`，明确要求玩家**已经**持有某个 trait。事件的叙事内容是这个 trait 导致的**自然结果**，而非随机遭遇。

与普通羞辱/困境事件的核心区别：

| 维度 | 普通事件 (如 duotai_humiliation) | 因果前置事件 (如 qingliu_fengying) |
|------|-------------------------------|----------------------------------|
| 触发条件 | 仅属性门槛 (`prop_gt`) | `trait_has` + 属性门槛 |
| 因果方向 | 世界 → 你（随机碾压） | 你 → 世界（自找的） |
| 叙事口吻 | 冷眼旁观结构性暴力 | 带着嘲讽——「这是你自己选的路」 |
| 玩家位置 | 受害者 | 共谋者 |
| failed_hint 修辞 | 简单因果（缺钱/缺人/缺胆） | **回溯句式**：「上次你...」「因为你之前...」 |
| 选项意义 | 如何回应羞辱 | 是否继续在这条路上走下去 |

### 实施规范

1. **`universal_requirement` 必须包含 `trait_has(name=xxx)`** —— 物理层保证只对有该 trait 的玩家触发
2. **每个场景的叙事种子必须携带「过去的因果锚」** —— 在 sandbox JSON 的 description 中自然带出「上次你...」的回溯
3. **failed_hint 的叙事强制要求**：每个被锁定选项的 tooltip 必须包含回溯句式，将锁的理由锚定在玩家自己的选择上，而非外部环境
4. **选项的 operator 设计**：逢迎（可选）路径的代价是**累积性的**——burnout、健康损耗、灵感侵蚀。狂客/钻营（锁定）路径展示「如果你当时选了另一条路」

### 示例

```text
场景: 平康坊闭门羹
因果锚: 你上次在韦府那副笑脸在圈子里传开了
触发条件: trait_has(name=kuangda_fengying) | prop_gt(name=ambition; val=30)

[狂客-锁] failed_hint: "你想拂袖而去——但老鸨嘴角那丝笑意在提醒你:
 上个月在韦府,你也是用这张脸陪着笑的。现在翻脸?太晚了。
 那些看见你弯腰的人,不会忘记你的姿态。"
 
[逢迎-可选] 继续写艳词 → burnout+10, inspiration-5, emo_add(SORROW)
```

### 反模式 (Anti-Pattern)

> ❌ 触发条件只有 `prop_gt(name=ambition)` 但叙事中有「你上次在XX场合的选择导致了今天的结果」——这是骗自己。没有 `trait_has` 就没有因果保证。

> ❌ failed_hint 不包含回溯句式，只描述当前处境（如「你没钱」「你不敢」）——这退化成了普通羞辱事件。


---

## 1. 事件生命周期：三层铁幕契约

任何事件的生命周期严格按照以下顺序执行，**不要打乱**：

```
Phase 0: on_enter（舞台置景）
    ↓
Phase 1: provider.init + provider.provide（动态选项生成）
    ↓
Phase 2: options.init（所有选项初始化）
    ↓
玩家选择选项
    ↓
choice_result.operate（执行结果）
```

### Phase 0 — `on_enter`（舞台置景）

- **职责**：构建当前事件的绝对上下文。所有前置计算、flag 初始化、数据注入必须在此时完成。玩家甚至还没看到 UI。
- **合法操作**：`FlagOperator(set/replace)`, `EmotionOperator`, `ContextFetchOperators`, `NpcBatchCheckOperator`, `RandomPickOperator`, `property_operator(add/sub)`
- **红线**：❌ `PushEventOperator` / `PopEventOperator`（那是 interruption 或 option results 的职责）
- **红线**：❌ 任何"因为玩家选了某个特定选项才应该发生"的后果操作
- **隐喻**：话剧开场前，场务把李白的酒杯摆好，把灯光打亮。观众还没入场

### Phase 1 — Provider（动态选项生成）

- 在 `on_enter` 执行完毕后，provider 用已构建好的 context 生成动态选项
- 目前只有 [`ItemProvider`](core/model/item_provider.gd:1)（遍历列表生成选项按钮）
- Provider 在 CSV 的 `provider` 列用 DSL 语法配置

### Phase 2 — Options Init（选项初始化）

- 所有选项（原生 + provider 产出的）统一初始化
- 每个 `EventOption` 解析自己的 `requirement`（决定是否可见/可用）和 `choice_result`
- `description` 中的 `{@keyword}` 占位符在此阶段被替换为 context 中的实际值

---

## 2. 事件栈操作模式

整个事件系统基于 **栈（Stack）架构**，类似浏览器的标签页/历史记录。

### 核心操作

| 操作 | DSL 语法 | 效果 | 类比 |
|------|----------|------|------|
| `push_event(key)` | `results` 列中用 `push_event(event_key=xxx)` | 推入新事件到栈顶，旧事件暂停 | 浏览器新开标签页 |
| `pop_event()` | `results` 列中用 `pop_event()` | 弹出当前事件，回到上一个事件 | 浏览器的「返回」 |
| `pop_to_event(key)` | `results` 列中用 `pop_to_event(event_key=xxx)` | 弹出到指定事件（可跳过中间层） | 返回主页 |
| `request_event_key()` | EventManager 内部 | 替换整个事件栈 | 浏览器跳转到新域名 |

### 典型栈操作流

```
宴席事件 (mid_of_wenhuaquan_party)
  |
  +-- [参加飞花令] -- push_event(feihualing_start)
  |     |
  |     +-- [来就来！] -- push_event(feihualing_choose_word)
  |     |     |
  |     |     +-- [选意象] -- push_event(feihualing_other_done)
  |     |           |
  |     |           +-- [完成] -- pop_event() 回到宴席
  |     |
  |     +-- [算了] -- pop_event() 回到宴席
  |
  +-- [参加联句] -- push_event(lianju_intro)
        |
        +-- [开始] -- push_event(lianju_npc_turn)
              |
              +-- [欣赏] -- push_event(lianju_show_poem)
                    |
                    +-- [轮到我了] -- push_event(lianju_player_turn)
                          |
                          +-- [对句] -- LianjuScoreOperator 评分
                          |     +-- push_event(lianju_result)
                          |           +-- [回到宴席] -- pop_to_event(mid_of_wenhuaquan_party)
                          |
                          +-- [认输] -- push_event(lianju_result)
                                +-- [回到宴席] -- pop_to_event(mid_of_wenhuaquan_party)
```

---

## 3. 两种 Sub-System 架构模式

### 模式 A：飞花令 —— 「扁平圈速决」

**特点**：一圈定胜负，用完即弃，不循环。

**事件链**：3 events + 1 ItemProvider

```
feihualing_start
  |  on_enter: 无
  |  options: [算了(pop), 来就来！(push->feihualing_choose_word)]
  v
feihualing_choose_word
  |  on_enter: RandomPickOperator(datasource="feihualing_imageries", select_count=4)
  |  provider: ItemProvider(list_key="feihualing_words", target="feihualing_other_done")
  |            → 生成4个选项按钮 "以「月」为题" "以「花」为题" ...
  v
feihualing_other_done
  |  on_enter: [
  |    ContextFetchOperators(fetched_key=chosen_word, → name→keyword, description→imaginary_desc),
  |    NpcBatchCheckOperator(participants=guests, check_prop=TALENT, template=FEIHUALING)
  |  ]
  |  options: [
  |    妙语连珠 (requirement: imaginary_has_level≥1) → imaginary_level_reward + pop
  |    灵感硬接 (requirement: inspiration>19) → prop_sub+prop_add+pop
  |    自罚三杯 (无requirement) → prop_add(drunk)+prop_sub(fame)+pop
  |  ]
```

**CSV 中的关键 DSL 写法（飞花令）**：

```csv
random_event,feihualing_start,,,飞花令,宴席上有人提议玩飞花令，是否参与？,,,,,,,
>option,feihualing_start_cancel,,,算了,,,pop_event(),,,,
>option,feihualing_start_begin,,,来就来！,,,push_event(event_key=feihualing_choose_word),,,,

random_event,feihualing_choose_word,,,选择意象,你要吟咏什么主题？,
  random_pick(datasource_name="feihualing_imageries",prop_from_result="uuid",key_stored_context="feihualing_words",select_count=4),,,
  item_provider(list_key="feihualing_words",display_datasource="imaginaries",display_prop="name",text_template="以「{item}」为题",target_event_key="feihualing_other_done",payload_key="feihualing_chosen_word",use_push_event=true),,,

random_event,feihualing_other_done,,,飞花令,你选择了以「{@keyword}」为题吟咏。,
  context_fetch(fetched_key="feihualing_chosen_word",datasource_name="imaginaries",prop_from_result="name",key_stored_context="keyword"),
  context_fetch(fetched_key="feihualing_chosen_word",datasource_name="imaginaries",prop_from_result="description",key_stored_context="imaginary_desc"),
  npc_batch_check(participants_key="guests",target_context_key="npc_report",check_prop="TALENT",text_template="FEIHUALING"),,,
>option,feihualing_other_done_imaginary,,imaginary_has_level(min_level=1),妙语连珠,妙语连珠,,imaginary_level_reward(l3_fame=50,l2_fame=20,l1_fame=0),,,
>option,feihualing_other_done_inspiration,,prop_gt(name=inspiration;val=19),灵感硬接,灵感硬接,,prop_sub(name=inspiration;val=20),prop_add(name=literary_fame;val=15),pop_event(),,,
>option,feihualing_other_done_penalty,,,自罚三杯,自罚三杯,,prop_add(name=drunk;val=10),prop_sub(name=literary_fame;val=5),pop_event(),,,
```

**关键模式总结**：

1. **`RandomPickOperator`** — 在 `on_enter` 阶段从数据源随机选候选内容，存入 context
2. **`ItemProvider`** — 将候选列表渲染为选项按钮，`display_datasource` + `display_prop` 做 display lookup
3. **`NpcBatchCheckOperator`** — 在 `on_enter` 阶段批量检定 NPC，生成战报文本注入 context
4. **`ContextFetchOperators`** — 用 context 中的 key 查数据库，提取属性继续注入 context
5. **返回值** — 所有选项的 result 末端都带 `pop_event()`，确保回到父事件
6. **无循环** — 一圈定胜负，不堆叠事件栈

### 模式 B：联句 —— 「链式多步博弈」

**特点**：NPC 出题 → 玩家选题 → 评分 → 展示结果，多步骤链式流转。

**事件链**：5 events（无 provider）

```
lianju_intro
  |  展示规则说明
  |  option: [开始联句 → push(lianju_npc_turn)]
  v
lianju_npc_turn
  |  on_enter: [
  |    RandomPickOperator(datasource="imaginaries", select_count=1, key="lianju_npc_imaginary"),
  |    ContextFetchOperators(fetched_key→name→lianju_npc_name, description→lianju_npc_desc),
  |    NpcBatchCheckOperator(participants=guests, check_prop=TALENT, template=LIANJU)
  |  ]
  |  option: [欣赏联句 → push(lianju_show_poem)]
  v
lianju_show_poem
  |  description: "{@npc_couplet}[br]——好一句「{@lianju_npc_name}」！"
  |  option: [轮到我了 → push(lianju_player_turn)]
  v
lianju_player_turn
  |  options: [
  |    对句 → LianjuScoreOperator（开 picker 选意象 → 评分 → push(lianju_result)）
  |    认输 → custom_context_params 设 score=0，push(lianju_result)
  |  ]
  v
lianju_result
  |  description: "你以「{@lianju_picked_name}」对句，赢得 {@lianju_score} 文名！"
  |  option: [回到宴席 → pop_to_event(mid_of_wenhuaquan_party)]
```

**CSV 中的关键 DSL 写法（联句）**：

```csv
random_event,lianju_intro,,,联句,联句规则：...,
>option,lianju_intro_start,,,,开始联句,,,push_event(event_key=lianju_npc_turn),,,

random_event,lianju_npc_turn,,,联句·宾先,宾客以「{@lianju_npc_name}」为题...,
  random_pick(datasource_name="imaginaries",prop_from_result="uuid",key_stored_context="lianju_npc_imaginary",select_count=1)
  context_fetch(fetched_key="lianju_npc_imaginary"...prop_from_result="name"...)
  context_fetch(fetched_key="lianju_npc_imaginary"...prop_from_result="description"...)
  npc_batch_check(participants_key="guests",target_context_key="npc_couplet",check_prop="TALENT",text_template="LIANJU"),,,
>option,lianju_npc_turn_show,,,,欣赏联句,,,push_event(event_key=lianju_show_poem),,,

random_event,lianju_player_turn,,,联句·我对,宾客以...轮到你一展诗才了！,
>option,lianju_player_turn_duiju,,,,对句,,,,,,
>option,lianju_player_turn_giveup,,,认输,,,push_event(event_key=lianju_result),,,
```

**关键模式总结**：

1. **链式传递** — Context 通过 `push_event` 的 `_captured_context` 机制自动传递；NPC 选好的意象名/战报在事件链中一路传递
2. **`LianjuScoreOperator`** — 硬编码评分逻辑（vs 飞花令的纯配置化）；打开 picker 让玩家选意象，计算 base_score × emotion_match 倍率，推结果事件
3. **`pop_to_event`** — 从深层子事件直接跳回根事件（宴席），而不是一层层 pop
4. **`custom_context_params`** — 认输选项通过它硬编码 context 值（score=0, evaluation=尴尬...）
5. **`{@...}` 占位符** — description 中动态引用 context 值，在 option init 阶段解析

---

## 4. 飞花令 vs 联句 —— 决策矩阵

| 决策维度 | 飞花令 | 联句 |
|----------|--------|------|
| **事件数量** | 3 events + 1 provider | 5 events |
| **Provider 使用** | ✅ ItemProvider | ❌ 硬编码（LianjuScoreOperator 开 picker） |
| **NPC 批量检定** | ✅ NpcBatchCheckOperator | ✅ NpcBatchCheckOperator |
| **玩家选内容** | ItemProvider 按钮列表 | LianjuScoreOperator 开 picker |
| **评分逻辑** | 配置化（DSL 运算符） | 硬编码（专属 Operator） |
| **回到父事件** | pop_event() | pop_to_event()（跳过多层） |
| **翻译文本** | dynamic_events.csv 中 FEIHUALING_SUCCESS/FAIL | dynamic_events.csv 中 LIANJU_SUCCESS/FAIL |
| **数据源** | feihualing_imageries（专用数据源） | imaginaries（全局意象库） |
| **Context 传递** | provider 的 payload_key → 后续事件 context_fetch | push_event 自动携带 context |
| **适合场景** | 速决战、资源回收、活跃气氛 | 高风险高回报、展示稀有藏品 |

---

## 5. CSV DSL 语法参考

### 列定义

| 列名 | 必填 | 用途 | 示例 |
|------|------|------|------|
| `row_type` | ✅ | 行类型，`random_event` 或 `>option`（`>` 越多层级越深） | `random_event` |
| `uuid` | ✅ | 事件唯一 ID | `feihualing_start` |
| `context` | ❌ | 触发标签、权重、背景、自定义参数 | `trigger_tags=[...]\|weight=15.5\|background=bg_rural_poor` |
| `requirements` | ❌ | 事件/选项触发条件 | `prop_gt(name=money;val=50),trait_has(name=official)` |
| `title` | ✅ | 事件名称/选项按钮文字 | `飞花令` |
| `description` | ❌ | 事件描述（支持 `{@key}` 插值） | `你选择了「{@keyword}」为题` |
| `on_enter` | ❌ | 事件级入场操作（舞台置景） | `context_fetch(...),npc_batch_check(...)` |
| `results` | ❌ | 选项选择后执行的操作 | `prop_add(...),pop_event()` |
| `interruptions` | ❌ | 前置中断序列 | `interrupt_event(flag_bool_has(name=x),push_event(...))` |
| `provider` | ❌ | 动态选项生成器 | `item_provider(list_key=...,text_template=...,...)` |
| `template` | ❌ | 模板 URN（从已有资源 duplicate） | `urn:event_option:poem_giving_option` |
| `emotion_config` | ❌ | 情绪配置（仅 event 可用） | |

### Requirements 语法

```
# 属性比较
prop_gt(name=money;val=50)
prop_lt(name=health;val=10)

# 特性检查
trait_has(name=official)
trait_not_has(name=corrupt)

# Flag 检查
flag_bool_has(name=chain_strange_poet_1)
flag_bool_not_has(name=sword)
flag_int_gt(name=flag_relation_with_libai;val=10)
flag_int_lt(name=flag_relation_with_libai;val=5)
flag_int_eq(name=flag_libai_changhe_request;val=1)

# 意象等级检查
imaginary_has_level(min_level=1)

# 多个条件 AND 组合（逗号分隔）
prop_gt(name=money;val=50),trait_has(name=official)
```

### Results / on_enter 语法

```
# 属性操作
prop_add(name=literary_fame;val=15)
prop_sub(name=money;val=100)
prop_set(name=inspiration;val=0)

# Flag 操作
flag_bool_set(name=chain_strange_poet_1;val=true)
flag_bool_replace(from=chain_strange_poet_1,to=chain_strange_poet_2)
flag_int_set(name=flag_libai_changhe_request;val=5)
flag_int_append(name=flag_relation_with_libai;val=-5)
flag_int_reduce_if_above(name=flag_libai_changhe_request,threshold=0,amount=1)

# Trait 操作
trait_add(name=corrupt)
trait_remove(name=corrupt)

# 事件栈操作
push_event(event_key=feihualing_start)
pop_event()
pop_to_event(event_key=mid_of_wenhuaquan_party)

# 意象奖励
imaginary_level_reward(l3_fame=50,l2_fame=20,l1_fame=0)

# Context 数据获取
context_fetch(fetched_key="feihualing_chosen_word",datasource_name="imaginaries",prop_from_result="name",key_stored_context="keyword")

# NPC 批量检定
npc_batch_check(participants_key="guests",target_context_key="npc_report",check_prop="TALENT",text_template="FEIHUALING")

# 随机选取
random_pick(datasource_name="feihualing_imageries",prop_from_result="uuid",key_stored_context="feihualing_words",select_count=4)

# 扫描事件池
scan_and_push(tags=["action:entertain:elegant","action:entertain:martial"],weight_mult=0.0,fallback="")
```

### Provider 语法

```
# 遍历列表生成选项按钮
item_provider(
  list_key="guests",                          # context 中的列表 key
  text_template="走向 {item}",                 # 按钮文字模板
  target_event_key="event_talk_guest",        # 点击后触发的事件
  payload_key="target_npc",                   # 传递给目标事件的 context key
  use_push_event=true,                        # 是否使用 push_event（默认 false 用 request_event）
  display_datasource="imaginaries",           # 可选：显示名查找的数据源
  display_prop="name"                         # 可选：显示名查找的属性
)
```

### Interruptions 语法

```
# 前置中断：检查条件，如果满足则执行操作
# 语法：interrupt_event(requirement, operator)
# 支持多个 interrupt_event() 逗号分隔，first-match-wins

interrupt_event(
  flag_int_eq(name=flag_libai_changhe_request;val=1),
  push_event(event_key=libai_force_changhe)
)

# 支持 AND 条件组合（用 " and " 语法，带空格）
interrupt_event(
  flag_int_gt(name=flag_relation_with_libai;val=20) and flag_int_eq(name=flag_libai_changhe_request;val=0),
  random(val=99,success=push_event(event_key=request_libai_changhe))
)
```

---

## 6. tres 资源文件结构

每个事件对应一个 `.tres` 文件，是 CSV 数据同步后的产物。

### tres 的基本骨架

```
[gd_resource type="Resource" script_class="RandomEvent" format=3]

[ext_resource type="Script" path="res://model/random_event.gd" id="1_xxx"]
[ext_resource type="Script" path="res://model/event/event_option.gd" id="2_xxx"]
[ext_resource type="Script" path="res://core/operators/push_event_operator.gd" id="3_xxx"]
...

[sub_resource type="Resource" id="Resource_xxx"]
script = ExtResource("3_xxx")
event_key = "feihualing_choose_word"

[sub_resource type="Resource" id="Resource_yyy"]
script = ExtResource("2_xxx")
choice_result = SubResource("Resource_xxx")
description = "来就来！"

[resource]
script = ExtResource("1_xxx")
options = Array(ExtResource("..."))([SubResource("Resource_yyy")])
uuid = "feihualing_start"
name = "飞花令"
description = "宴席上有人提议玩飞花令..."
```

### 关键规则

- **`ext_resource`** — 引用脚本类（`RandomEvent`, `EventOption`, `PushEventOperator` 等）
- **`sub_resource`** — 内联的子资源实例（每个 operator/option 都是一个 sub_resource）
- **`Array[ExtResource("...")]([...])`** — 类型化数组，第一个参数是元素类型的类脚本，第二个是元素列表
- **CSV 同步流程**：修改 CSV → 运行 MCP 同步工具 → 自动生成/更新 `.tres` 文件

---

## 7. 构建新 Sub-System 的决策流

```
你想构建一个新的 mini-game（如投壶、射覆、酒令...）
    |
    v
问题 1：需要几轮？
    |
    +-- 一圈定胜负 → 飞花令模式（扁平，3 events）
    |
    +-- 多步流转 → 联句模式（链式，5 events）
    |
    +-- 需要循环 → 需要新的 Operator（目前系统不支持自动循环）
    |
    v
问题 2：玩家需要从一堆内容中选一个吗？
    |
    +-- 是 → 用 ItemProvider（从 context 列表生成按钮）
    |
    +-- 否 → 硬编码选项（在 CSV 的 >option 行直接写）
    |
    +-- 需要选意象/资源 → 用 LianjuScoreOperator 的 picker 模式
    |
    v
问题 3：需要 NPC 参与检定吗？
    |
    +-- 是 → 在 on_enter 用 NpcBatchCheckOperator
    |
    +-- 否 → 跳过
    |
    v
问题 4：回到哪里？
    |
    +-- 回到上一层 → pop_event()
    |
    +-- 回到根事件（跳过中间层）→ pop_to_event(event_key=xxx)
    |
    v
问题 5：是否需要自定义 Operator？
    |
    +-- 纯配置 DSL 能搞定 → 只用 CSV + 已有 Operator
    |
    +-- 需要复杂逻辑（如联句评分）→ 写新的 BaseOperator 子类
```

---

## 8. 最重要的坑和规则

### 坑 1：`on_enter` 不能 push/pop 事件
> 🔴 **如果你在 on_enter 里放了 push_event，玩家甚至还没看到 UI，事件栈就变了**
> 正确做法：把 push_event 放在选项的 results 里

### 坑 2：Provider 是 Phase 1，on_enter 是 Phase 0
> 🔴 **provider.provide 在 on_enter 之后执行**
> 所以 on_enter 中算好的 context 可以被 provider 读取
> 但 provider 不能修改 on_enter 已经执行完毕的状态

### 坑 3：Context 传递机制
> - `push_event(key, context)` 会自动携带当前 context
> - `ItemProvider` 通过 `payload_key` 注入每个选项的自定义参数
> - `{@keyword}` 在 option.init 阶段解析，读取自 context
> - `custom_context_params` 在 on_enter 阶段 merge 进 context

### 坑 4：飞花令的 Provider 和 ContextFetchOperators 配合
> 飞花令的 `feihualing_choose_word` 用 `RandomPickOperator` 在 on_enter 随机选 4 个意象 uuid
> 存入 context `feihualing_words`
> `ItemProvider` 读取这个列表，生成 4 个按钮
> 每个按钮的 `payload_key="feihualing_chosen_word"` 传递给 `feihualing_other_done`
> `feihualing_other_done` 的 on_enter 用 `ContextFetchOperators` 查这个 uuid 对应的 name 和 description

### 坑 5：`pop_to_event` vs `pop_event`
> - 联句入口是 `lianju_intro`→`lianju_npc_turn`→`lianju_show_poem`→`lianju_player_turn`，深度 4 层
> - 如果每层都用 `pop_event()`，玩家需要点 4 次返回
> - 所以 `lianju_result` 用 `pop_to_event(event_key=mid_of_wenhuaquan_party)` 一步跳回

### 坑 6：Translation 在 @tool 模式下不自动加载
> Godot 4 的 `[locale]` 自动加载机制在 `@tool` 脚本中不生效
> 必须在 `Database._init()` 中显式调用 `TranslationServer.add_translation()` 注入翻译资源
> 翻译文本在 `data/translations/dynamic_events.csv` 中维护

### 坑 7：tres 文件中 `@tool` 模式的继承链问题
> `RandomEvent` 继承自 `BaseEvent` 继承自 `GameEntity`
> `@tool` 模式下类继承链可能未完全加载，`pre_event_interrupter_sequence` 属性可能不可达
> 代码通过 `_set()/_get()/_get_property_list()` 兜底，参考 [`model/random_event.gd`](model/random_event.gd:16)

---

## 9. 飞花令模式的「换数据就能用」模板

如果你要做一个新的"一圈定胜负"的 mini-game（如投壶、射覆），只需要：

1. **定义数据源** — 在你的 registry 中注册新的数据源（类似 `feihualing_imageries`）
2. **定义翻译文本** — 在 `dynamic_events.csv` 中添加 `YOURGAME_SUCCESS/FAIL`
3. **在 CSV 中复制飞花令的三事件结构**，改 uuid/名称/数据源名/翻译模板名
4. **MCP 同步** — 运行同步工具生成 tres 文件

## 10. 联句模式的「换数据就能用」模板

如果你要做一个新的"多步博弈"mini-game，只需要：

1. **如果评分逻辑不同** — 写一个新的 `BaseOperator` 子类（参考 [`LianjuScoreOperator`](core/operators/lianju_score_operator.gd:1)）
2. **如果评分逻辑相同** — 复用 `LianjuScoreOperator`，调参（`l3_base_score`, `emotion_match_percent`）
3. **在 CSV 中复制联句的五事件结构**，改 uuid/名称/翻译模板名
4. **MCP 同步** — 运行同步工具生成 tres 文件

---

## 附录：关键文件索引

| 文件 | 职责 |
|------|------|
| [`data/random_events/random_events.csv`](data/random_events/random_events.csv:1) | 所有随机事件的数据源（DSL） |
| [`core/event_manager.gd`](core/event_manager.gd:1) | 事件管理器：扫描、过滤、权重滚动 |
| [`core/eventbus.gd`](core/eventbus.gd:1) | 事件总线：所有信号定义 |
| [`model/event.gd`](model/event.gd:1) | BaseEvent：事件生命周期（on_enter, init, check_interruption） |
| [`model/random_event.gd`](model/random_event.gd:1) | RandomEvent：@tool 兼容，custom_context_params |
| [`model/event/base_option.gd`](model/event/base_option.gd:1) | BaseOption：基础选项 |
| [`model/event/event_option.gd`](model/event/event_option.gd:1) | EventOption：带 requirement + choice_result + 插值 |
| [`model/choice_result.gd`](model/choice_result.gd:1) | ChoiceResult：操作符容器（init + operate） |
| [`core/model/base_operator.gd`](core/model/base_operator.gd:1) | BaseOperator：所有操作符基类 |
| [`core/operators/push_event_operator.gd`](core/operators/push_event_operator.gd:1) | PushEventOperator |
| [`core/operators/pop_event_operator.gd`](core/operators/pop_event_operator.gd:1) | PopEventOperator |
| [`core/operators/pop_to_event_operator.gd`](core/operators/pop_to_event_operator.gd:1) | PopToEventOperator |
| [`core/operators/random_pick_operator.gd`](core/operators/random_pick_operator.gd:1) | RandomPickOperator |
| [`core/operators/context_fetch_operators.gd`](core/operators/context_fetch_operators.gd:1) | ContextFetchOperators |
| [`core/operators/npc_batch_check_operator.gd`](core/operators/npc_batch_check_operator.gd:1) | NpcBatchCheckOperator |
| [`core/operators/scan_and_push_operator.gd`](core/operators/scan_and_push_operator.gd:1) | ScanAndPushOperator |
| [`core/operators/lianju_score_operator.gd`](core/operators/lianju_score_operator.gd:1) | LianjuScoreOperator |
| [`core/model/item_provider.gd`](core/model/item_provider.gd:1) | ItemProvider：动态选项生成 |
| [`parser/dsl_parser.gd`](parser/dsl_parser.gd:1) | CSV DSL 解析器 |
| [`data/translations/dynamic_events.csv`](data/translations/dynamic_events.csv:1) | 翻译文本 |
| [`DOCUMENTATIONS/feature_intents/feihualing.md`](DOCUMENTATIONS/feature_intents/feihualing.md:1) | 飞花令功能意图文档 |
| [`DOCUMENTATIONS/feature_intents/lianju.md`](DOCUMENTATIONS/feature_intents/lianju.md:1) | 联句功能意图文档 |
