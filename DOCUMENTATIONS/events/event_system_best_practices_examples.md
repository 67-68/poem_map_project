# 事件系统实际模式大全：换数据即用

> 基于当前代码库（[`data/random_events/random_events.csv`](../../data/random_events/random_events.csv) + 25 个 .tres 文件）逆向分析。
> 每个模式都附完整 CSV 片段 + .tres 结构 + 换数据指南。

---

## 目录

1. [模式 1：Hub & Spoke · 文化圈宴席（菜单式活动中心）](#模式-1hub--spoke--文化圈宴席菜单式活动中心)
2. [模式 2：三幕 Mini-Game · 飞花令（随机选题 + NPC 结算 + 玩家三选一）](#模式-2三幕-mini-game--飞花令随机选题--npc-结算--玩家三选一)
3. [模式 3：NPC 主导序列 · 联句（NPC 出题 → 玩家选择 → 自动计分 → 结果展示）](#模式-3npc-主导序列--联句npc-出题--玩家选择--自动计分--结果展示)
4. [模式 4：Provider + 模板 · 与宾客交互（动态生成 NPC 选项 + 子事件）](#模式-4provider--模板--与宾客交互动态生成-npc-选项--子事件)
5. [模式 5：中断优先级链 · 李白唱和（条件守卫 + 概率触发）](#模式-5中断优先级链--李白唱和条件守卫--概率触发)
6. [换数据速查表](#6-换数据速查表)

---

## 模式 1：Hub & Spoke · 文化圈宴席（菜单式活动中心）

### 适用场景

一个中心事件提供多个活动入口，玩家选择一个后 push 进入子系统，完成后 pop 回到中心。

### 真实代码（[`random_events.csv`](../../data/random_events/random_events.csv:22-28)）

```csv
# ── Hub 事件 ──
random_event,mid_of_wenhuaquan_party,,,在盛大讲话完毕之后,
  正式开场！你看见有人斗诗有人讲话，还有人在扫荡小食,
  "flag_int_reduce_if_above(name=flag_libai_changhe_request; threshold=0; amount=1)",
  ,
  "interrupt_event(flag_int_eq(name=flag_libai_changhe_request; val=1);
     push_event(event_key=libai_force_changhe)) |
   interrupt_event(flag_int_gt(name=flag_relation_with_libai; val=20)
     and flag_int_eq(name=flag_libai_changhe_request; val=0);
     random(val=99; success=push_event(event_key=request_libai_changhe)))",
  ,
  ,

>option,wenhuaquan_people_choice,,,走向熙熙攘攘的人群,
  ,push_event(event_key=mid_of_wenhuaquan_party_choose_people),,

>option,feihualing_option,,,参加飞花令,,push_event(event_key=feihualing_start),,

>option,lianju_option,,,参加联句,,push_event(event_key=lianju_intro),,

>option,art_appreciation_option,,,欣赏艺术,,
  "scan_and_push(tags=[""action:entertain:elegant"",""action:entertain:martial""], 
     weight_mult=0.0, fallback="""")",,
```

### 事件链图

```
mid_of_wenhuaquan_party (Hub)
  ├─ 选项：走向人群  → push mid_of_wenhuaquan_party_choose_people
  │                      └─ Provider(item_provider) → event_talk_guest/chat/changhe
  │                      └─ pop_event() 回到 Hub
  ├─ 选项：飞花令     → push feihualing_start → ... → pop_event() 回到 Hub
  ├─ 选项：联句       → push lianju_intro → ... → pop_event() 回到 Hub
  └─ 选项：欣赏艺术   → scan_and_push(随机场景行动)
```

### 换数据指南

| 要换什么 | 怎么换 |
|----------|--------|
| 菜单标题/描述 | 改 `mid_of_wenhuaquan_party` 的 `title` 和 `description` 列 |
| 活动入口 | 新增/删除 `>option` 行，`results` 列写 `push_event(event_key=你的子事件uuid)` |
| 返回机制 | 子事件最后一个选项的 `results` 写 `pop_event()` 即可回到 Hub |
| 中断守卫 | 在 Hub 的 `interruptions` 列加条件，参考[模式 5](#模式-5中断优先级链--李白唱和条件守卫--概率触发) |

### 关键约束

- Hub 的每个 `>option` 必须有对应 uuid
- 子事件必须保证最终回到 Hub（`pop_event()` 或 `pop_to_event(event_key)`）
- `weight=0.0` 或留空：这些事件由人工 push 触发，不走随机扫描

---

## 模式 2：三幕 Mini-Game · 飞花令（随机选题 + NPC 结算 + 玩家三选一）

### 适用场景

一个快速的、一圈定胜负的小游戏：系统随机出题 → NPC 后台自动结算 → 玩家做出有限选择。

### 真实代码（[`random_events.csv`](../../data/random_events/random_events.csv:31-38)）

```csv
# ── Act 1：入口 ──
random_event,feihualing_start,,,飞花令,宴席上有人提议玩飞花令，是否参与？,,,,,,

>option,feihualing_start_cancel,,,算了,,pop_event(),,

>option,feihualing_start_begin,,,来就来！,,push_event(event_key=feihualing_choose_word),,

# ── Act 2：随机选题（on_enter + provider）──
random_event,feihualing_choose_word,,,选择意象,你要吟咏什么主题？,
  "random_pick(datasource_name=""feihualing_imageries"",
     prop_from_result=""uuid"",key_stored_context=""feihualing_words"",
     select_count=4)",
  ,
  ,
  """item_provider(list_key=""""feihualing_words"""",
     display_datasource=""""imaginaries"""",
     display_prop=""""name"""",
     text_template=""""以「{item}」为题"""",
     target_event_key=""""feihualing_other_done"""",
     payload_key=""""feihualing_chosen_word"""",
     use_push_event=true)""",
  ,

# ── Act 3：NPC 结算 + 玩家三选一 ──
random_event,feihualing_other_done,,,飞花令,
  你选择了以「{@keyword}」为题吟咏。[br][br]{@imaginary_desc}[br][br]{@npc_report},
  "context_fetch(fetched_key=""feihualing_chosen_word"",
     datasource_name=""imaginaries"",
     prop_from_result=""name"",
     key_stored_context=""keyword""),
   context_fetch(fetched_key=""feihualing_chosen_word"",
     datasource_name=""imaginaries"",
     prop_from_result=""description"",
     key_stored_context=""imaginary_desc""),
   npc_batch_check(participants_key=""guests"",
     target_context_key=""npc_report"",
     check_prop=""TALENT"",
     text_template=""FEIHUALING"")",
  ,
  ,
  ,
  ,

>option,feihualing_other_done_imaginary,,
  imaginary_has_level(min_level=1),妙语连珠,妙语连珠,
  "imaginary_level_reward(l3_fame=50; l2_fame=20; l1_fame=0)",,

>option,feihualing_other_done_inspiration,,
  "prop_gt(name=inspiration; val=19)",灵感硬接,灵感硬接,
  "prop_sub(name=inspiration; val=20) |
   prop_add(name=literary_fame; val=15) |
   pop_event()",,

>option,feihualing_other_done_penalty,,,自罚三杯,自罚三杯,
  "prop_add(name=drunk; val=10) |
   prop_sub(name=literary_fame; val=5) |
   pop_event()",,
```

### 对应的 .tres 结构

[`feihualing_other_done.tres`](../../data/random_events/feihualing_other_done.tres) 的结构展示了三幕的核心编排：

```
RandomEvent
├── on_enter_result: ChoiceResult      ← Act 3 的 on_enter 自动结算
│   ├── ContextFetchOperator ×2       ← 查询玩家选的意象的 name 和 description
│   └── NpcBatchCheckOperator         ← 批量检定所有 NPC + 生成战报
└── options: Array[BaseOption]
    ├── EventOption (妙语连珠)
    │   ├── requirement: ImaginaryLevelRequirement
    │   └── choice_result: ImaginaryLevelRewardOperator
    ├── EventOption (灵感硬接)
    │   ├── requirement: PropertyRequirement(inspiration>19)
    │   └── choice_result: [PropertyOperator(-20), PropertyOperator(+15), PopEventOperator]
    └── EventOption (自罚三杯)
        └── choice_result: [PropertyOperator(+10), PropertyOperator(-5), PopEventOperator]
```

### 换数据指南

| 要换什么 | 修改位置 | 示例值 |
|----------|----------|--------|
| 随机选题池 | `datasource_name` 指向 Database 中的 Dictionary key | `feihualing_imageries` → `your_datasource` |
| 抽取数量 | `select_count` | 4 → 3 |
| 显示字段 | `display_datasource` + `display_prop` | `imaginaries` + `name` |
| NPC 检定属性 | `npc_batch_check` 的 `check_prop` | `TALENT` → `INTELLIGENCE` |
| 翻译键前缀 | `text_template` | `FEIHUALING` → `YOUR_GAME` |
| 玩家选项 | 修改三个 `>option` 的 requirements 和 results | 见上表 |
| 兜底选项 | 最后一个选项必须无条件（无 requirements） | `自罚三杯` 无 requirements |

### 需要的数据源

1. **选题池数据源**：在 [`Database`](../../core/database.gd) 中注册一个 `Dictionary[uuid: String → Resource]`，例如 `feihualing_imageries`
2. **NPC 文档**：每个 NPC 需在 [`NPCDocument`](../../model/npc_document.gd) 中定义 `TALENT` 属性
3. **翻译文本**：在翻译文件中定义 `{text_template}_SUCCESS` 和 `{text_template}_FAIL` 键，支持 `{npc_name}` 和 context 字段占位

---

## 模式 3：NPC 主导序列 · 联句（NPC 出题 → 玩家选择 → 自动计分 → 结果展示）

### 适用场景

NPC 先出题 → 展示 NPC 的结果 → 玩家选择意象 → 自动计分（含情绪匹配倍率）→ 跳转到结果页展示评分。适合需要复杂评分的子系统。

### 真实代码

**事件链（5 个事件，0 provider，不需要 CSV 声明，全在 .tres 中硬编码）**：

```
lianju_intro → lianju_npc_turn → lianju_show_poem → lianju_player_turn → lianju_result
                                                                              ↓
                                                                        pop_to_event(mid_of_wenhuaquan_party)
```

### 逐个事件详解

#### 1. [`lianju_intro.tres`](../../data/random_events/lianju_intro.tres) — 入口

```
RandomEvent
├── weight = 0.0 (不参与随机，由 hub push 触发)
├── options[0]: EventOption "开始联句"
│   └── choice_result: PushEventOperator(event_key="lianju_npc_turn")
```

#### 2. [`lianju_npc_turn.tres`](../../data/random_events/lianju_npc_turn.tres) — NPC 出题（最复杂的 on_enter）

```
RandomEvent
├── on_enter_result: ChoiceResult (5 个 operator 链式执行)
│   ├── RandomPickOperator              ← 从 imaginaries 随机选 1 个
│   │   ├── datasource_name = "imaginaries"
│   │   ├── select_count = 1
│   │   └── key_stored_context = "lianju_npc_imaginary"
│   ├── ContextFirstOperator            ← 展平数组为单值（数组→标量）
│   │   ├── source_key = "lianju_npc_imaginary"
│   │   └── target_key = "lianju_npc_imaginary"
│   ├── ContextFetchOperator            ← 取意象 name → context["lianju_npc_name"]
│   │   ├── fetched_key = "lianju_npc_imaginary"
│   │   ├── datasource_name = "imaginaries"
│   │   └── prop_from_result = "name"
│   ├── ContextFetchOperator            ← 取意象 description → context["lianju_npc_desc"]
│   │   ├── fetched_key = "lianju_npc_imaginary"
│   │   ├── datasource_name = "imaginaries"
│   │   └── prop_from_result = "description"
│   └── NpcBatchCheckOperator           ← NPC 批量检定 + 战报
│       ├── participants_key = "guests"
│       ├── check_prop = "TALENT"
│       └── text_template = "LIANJU"
├── description = "宾客以「{@lianju_npc_name}」为题，略作沉吟，开口吟道：[br][br]{@npc_couplet}"
│   # {@...} 是 context 变量替换，在 NarrativeOverlay 渲染时替换为 context 中的值
└── options[0]: EventOption "欣赏联句"
    └── choice_result: PushEventOperator(event_key="lianju_show_poem")
```

#### 3. [`lianju_show_poem.tres`](../../data/random_events/lianju_show_poem.tres) — 展示

```
RandomEvent
├── description = "{@npc_couplet}[br][br]——好一句「{@lianju_npc_name}」！现在轮到你对句了。"
└── options[0]: EventOption "轮到我了"
    └── choice_result: PushEventOperator(event_key="lianju_player_turn")
```

#### 4. [`lianju_player_turn.tres`](../../data/random_events/lianju_player_turn.tres) — 玩家选择（核心计分）

```
RandomEvent
├── options: Array[BaseOption]
│   ├── EventOption "对句"
│   │   └── choice_result: LianjuScoreOperator    ← 自定义 Operator
│   │       ├── l3_base_score = 30      ← L3 意象基础分
│   │       ├── l2_base_score = 20      ← L2 意象基础分
│   │       ├── l1_base_score = 10      ← L1 意象基础分
│   │       └── emotion_match_percent = 150  ← 情绪匹配倍率 150%
│   │       └── result_event_key = "lianju_result"  ← 计分后 push 到此事件
│   │
│   └── EventOption "认输"
│       ├── custom_context_params = {        ← 硬编码 context 值
│       │     "lianju_score": 0,
│       │     "lianju_picked_name": "认输",
│       │     "lianju_emotion_match": false,
│       │     "lianju_evaluation": "宴席上泛起一丝尴尬的沉默…"
│       │   }
│       └── choice_result: PushEventOperator(event_key="lianju_result")
```

#### 5. [`lianju_result.tres`](../../data/random_events/lianju_result.tres) — 结果

```
RandomEvent
├── description = "你以「{@lianju_picked_name}」对句，赢得 {@lianju_score} 文名！[br]{@lianju_evaluation}"
└── options[0]: EventOption "回到宴席"
    └── choice_result: PopToEventOperator(event_key="mid_of_wenhuaquan_party")
```

### [`LianjuScoreOperator`](../../core/operators/lianju_score_operator.gd) 计分逻辑

```gdscript
# 核心计分（简化版）
func operate():
    # 1. 打开 Picker，让玩家选意象
    EventBus.push_picker.emit(data, _on_imaginary_picked)

func _on_imaginary_picked(imaginary_picked):
    var level = imaginary_picked.current_level          # L1/L2/L3
    var base_score = match level:                       # 等级基础分
        3: l3_base_score  # 30
        2: l2_base_score  # 20
        1: l1_base_score  # 10
    
    # 2. 情绪匹配检查
    var dominant_emotion = PlayerState.get_dominant_emotion()
    if imaginary_picked.uuid.contains(dominant_emotion):
        multiplier = emotion_match_percent  # 150%
    
    _final_score = base_score * multiplier / 100
    
    # 3. 应用分数 + push 结果事件
    PlayerState.append_stat("literary_fame", _final_score)
    EventBus.push_event.emit(result_event_key, ctx)
```

### 换数据指南

| 要换什么 | 修改位置 |
|----------|----------|
| NPC 出题数据源 | `lianju_npc_turn` 的 `RandomPickOperator.datasource_name` |
| NPC 检定属性 | `NpcBatchCheckOperator.check_prop` |
| 基础分和倍率 | `LianjuScoreOperator` 的 `l3_base_score`/`l2_base_score`/`l1_base_score`/`emotion_match_percent` |
| 计分后跳转 | `LianjuScoreOperator.result_event_key` |
| 返回位置 | `PopToEventOperator.event_key` |
| 描述文本 | 每个事件的 `description` 列（支持 `{@context_key}` 变量替换） |

### 需要的数据源

1. **`imaginaries`**：Database 中注册的意象字典，每个意象需有 `uuid`, `name`, `description`, `current_level` 属性
2. **翻译键**：`LIANJU_SUCCESS` / `LIANJU_FAIL`
3. **自定义 Operator**（如需不同计分逻辑）：新建一个继承 `BaseOperator` 的类，参考 [`lianju_score_operator.gd`](../../core/operators/lianju_score_operator.gd)

---

## 模式 4：Provider + 模板 · 与宾客交互（动态生成 NPC 选项 + 子事件）

### 适用场景

Hub 中有一个"与宾客交谈"的选项，需要为列表中的每个 NPC 动态生成一个选项，点击后进入该 NPC 的子事件链。

### 真实数据流

```
mid_of_wenhuaquan_party 
  > opt "走向熙熙攘攘的人群"
    → push mid_of_wenhuaquan_party_choose_people
        → on_enter: item_provider 读取 context["guests"] 列表
        → 为每个 NPC 生成一个 EventOption "走向 {name}"
        → 点击后 push event_talk_guest (带 payload: target_npc=npc_id)
            → event_talk_guest 展示 3 个选项:
                1. "你好，{@target_npc}" → requirements: talk_count_{npc} >= 1
                2. "主动唱和" → push party_subjective_changhe
                3. "去看看其他活动" → pop_event() 回到 Hub
```

### CSV 代码

**Hub 中设置 NPC 列表**（[`random_events.csv`](../../data/random_events/random_events.csv:20)）：

```csv
>option,,guests=[libai;wangwei;zhengqian],,去,,,
  queue_event(event_key=start_of_wenhuaquan_party),,,
```

注意：`guests=[libai;wangwei;zhengqian]` 这个列表定义在 `>option` 行的 `context` 列中。分号 `;` 是数组分隔符。

**Provider 选项**（[`random_events.csv`](../../data/random_events/random_events.csv:29)）：

```csv
random_event,mid_of_wenhuaquan_party_choose_people,,,要选谁呢？,商务还是运动？,,,
  "item_provider(list_key=""guests"",
     text_template=""走向 {item}"",
     target_event_key=""event_talk_guest"",
     payload_key=""target_npc"",
     use_push_event=true)",,
```

### Provider 生成的选项

每个 NPC 会生成一个 EventOption，点击后执行 `PushEventOperator(event_key="event_talk_guest")`，同时 context 中设置了 `target_npc=npc_id`。

### [`event_talk_guest.tres`](../../data/random_events/event_talk_guest.tres) 模板事件

```
RandomEvent
├── name = "和宾客说话"
├── description = "要干什么呢？"
├── options: Array[BaseOption]
│   ├── EventOption "你好，{@target_npc}"
│   │   ├── requirement: FlagRequirement
│   │   │   ├── type = "int"
│   │   │   ├── value = 1
│   │   │   ├── operator = >=
│   │   │   ├── target_flag_id_from_context = "target_npc"
│   │   │   └── flag_id_prefix = "talk_count_"
│   │   │   # 等效于检查：talk_count_libai >= 1
│   │   └── choice_result: PushEventOperator(event_key="event_chat_guest")
│   │
│   ├── EventOption "主动唱和"
│   │   └── choice_result: PushEventOperator(event_key="party_subjective_changhe")
│   │
│   └── EventOption "去看看其他活动"
│       └── choice_result: PopEventOperator()  ← 回到 Hub
```

### 沉浸式唱和模板（[`party_subjective_changhe.tres`](../../data/random_events/party_subjective_changhe.tres)）

这个事件展示了如何通过 `on_enter` 自动查找 NPC 的品味数据并注入：

```
RandomEvent
├── on_enter_result: ChoiceResult
│   └── ContextFetchOperator           ← 自动查找 target_npc 的 taste
│       ├── fetched_key = "target_npc"
│       ├── datasource_name = "npc_document"
│       ├── prop_from_result = "taste_id"
│       ├── key_stored_context = "poem_taste"
│       └── urn_prefix = "poem_taste"  ← 自动补全为 urn:poem_taste:{taste_id}
├── options[0]: EventOption "唱和"
│   └── choice_result: TraitChooseOperator  ← 打开作诗界面
│       ├── poem_taste = <动态加载的 PoemTaste Resource>
│       └── key_to_get_poem_taste = "poem_taste"
└── options[1]: EventOption "回去"
    └── choice_result: PopEventOperator()
```

### 换数据指南

| 要换什么 | 修改位置 |
|----------|----------|
| NPC 列表 | 父选项的 `context` 列：`guests=[npc1;npc2;npc3]` |
| 选项文本模板 | Provider 的 `text_template`：`走向 {item}`（`{item}` 替换为列表元素） |
| 目标事件 | Provider 的 `target_event_key`：`event_talk_guest` |
| 追踪 NPC 访问 | `FlagOperator.flag_id_prefix`：`talk_count_` + `target_flag_id_from_context` |
| 返回 Hub | 子选项的 `PopEventOperator()` 或 `PopToEventOperator(event_key=hub_uuid)` |

### 关键约束

- `context` 中的数组用分号 `;` 分隔值，用等号 `=` 指定键
- Provider 的 `list_key` 必须匹配 context 中设置的 key
- `target_flag_id_from_context` + `flag_id_prefix` 组合实现动态 flag 检查（如 `talk_count_libai`、`talk_count_wangwei`）
- **Provider 依赖上游 context**：如果事件链从中间进入（不走正常流程），context 可能没有 `guests` 列表

---

## 模式 5：中断优先级链 · 李白唱和（条件守卫 + 概率触发）

### 适用场景

当玩家进入一个事件时，优先检查是否有**更紧急的剧情**需要插入。中断条件可以基于 Flag 值、随机概率、或复合条件。

### 真实代码（[`random_events.csv`](../../data/random_events/random_events.csv:24)）

```csv
# mid_of_wenhuaquan_party 的 interruptions 列：
interrupt_event(
  flag_int_eq(name=flag_libai_changhe_request; val=1);
  push_event(event_key=libai_force_changhe)
) |
interrupt_event(
  flag_int_gt(name=flag_relation_with_libai; val=20)
    and flag_int_eq(name=flag_libai_changhe_request; val=0);
  random(val=99; success=push_event(event_key=request_libai_changhe))
)
```

### 中断执行顺序

中断在 `on_enter` 之前执行。如果中断条件满足，中断事件被 push 到栈顶，替代当前事件展示。

```
Phase 1: check_interruption  ← 先检查中断
  ├─ 条件1: flag_libai_changhe_request == 1?
  │   └─ 是 → push libai_force_changhe（中断当前事件）
  ├─ 条件2: relation_with_libai > 20 AND changhe_request == 0?
  │   └─ 是 → random(99%) → push request_libai_changhe
  └─ 都不满足 → 正常展示 mid_of_wenhuaquan_party

Phase 2: on_enter  ← 中断 push 的事件先展示
Phase 3: options 展示
Phase 4: choice_result 执行
```

### 中断条件中的 Flag 生命周期

```csv
# 1. 玩家在 party 中遇到了李白 → request_libai_changhe 事件
>option,opt_accept,,,欣然应和,,
  "flag_int_set(name=flag_libai_changhe_request; val=5) | pop_event()",,

# 2. 回到 Hub → on_enter 每帧递减 flag
"flag_int_reduce_if_above(name=flag_libai_changhe_request; threshold=0; amount=1)"

# 3. 当 flag == 1 时（还剩 1 回合）→ 中断触发
# 4. libai_force_changhe 事件中：
"flag_int_set(name=flag_libai_changhe_request; val=0)"  ← 清零，防止循环中断
```

### 中断事件 [`libai_force_changhe.tres`](../../data/random_events/libai_force_changhe.tres) 结构

```
RandomEvent
├── on_enter: FlagOperator(flag_libai_changhe_request = 0)  ← 清零
├── 选项1: "和一首！"
│   ├── poem_taste via context
│   └── choice_result: pop_event()
├── 选项2: "拂袖而去"
│   └── choice_result: flag_int_append(name=relation_libai; val=-20) | pop_event()
```

### 换数据指南

| 要换什么 | 修改位置 |
|----------|----------|
| 中断条件 | `interrupt_event()` 的第一个参数：`flag_xxx==N` / `flag_xxx>N` / `prop_xxx>N` |
| 中断概率 | `random(val=N; success=...)` 的 val 参数 |
| 中断事件 | `push_event(event_key=你的事件uuid)` |
| 多条件 | 用 ` and ` 连接：`flag_a>5 and flag_b==0` |
| 循环预防 | 中断事件 on_enter 中必须修改触发条件（如清零 flag） |

### 重要陷阱

```
# ❌ 错误：中断条件依赖 event_result 改变的值
# event_result 在 check_interruption 之后执行，来不及影响中断
interrupt_event(flag_wine_count>0; random(20; push=evt_wine_interrupt))
event_result=flag_int_set(name=flag_wine_count; val=-1)

# ✅ 正确：用 flag_idle==0（空闲态）做守卫
interrupt_event(flag_idle==0; random(20; push=evt_wine_interrupt))
```

---

## 6. 换数据速查表

### 6.1 快速选择模式

| 你要做什么 | 用哪个模式 | 复杂度 |
|------------|-----------|--------|
| 一个活动中心，多个子活动 | [模式 1](#模式-1hub--spoke--文化圈宴席菜单式活动中心) | ⭐ |
| NPC 参与的小游戏（抽题+结算） | [模式 2](#模式-2三幕-mini-game--飞花令随机选题--npc-结算--玩家三选一) | ⭐⭐ |
| 玩家选意象+计分+结果展示 | [模式 3](#模式-3npc-主导序列--联句npc-出题--玩家选择--自动计分--结果展示) | ⭐⭐⭐ |
| 动态生成每个 NPC 的选项 | [模式 4](#模式-4provider--模板--与宾客交互动态生成-npc-选项--子事件) | ⭐⭐ |
| 特定条件下插入高优先级剧情 | [模式 5](#模式-5中断优先级链--李白唱和条件守卫--概率触发) | ⭐⭐ |

### 6.2 常用 Operator 速查

| Operator | 文件 | 作用 | 在哪用 |
|----------|------|------|--------|
| `RandomPickOperator` | [`core/operators/random_pick_operator.gd`](../../core/operators/random_pick_operator.gd) | 从数据源随机选 N 个 | `on_enter` |
| `ContextFetchOperator` | [`core/operators/context_fetch_operators.gd`](../../core/operators/context_fetch_operators.gd) | 根据 context 值查询外部数据源 | `on_enter` |
| `ContextFirstOperator` | [`core/operators/context_first_operator.gd`](../../core/operators/context_first_operator.gd) | 数组展平为单值 | `on_enter` |
| `NpcBatchCheckOperator` | [`core/operators/npc_batch_check_operator.gd`](../../core/operators/npc_batch_check_operator.gd) | 批量 NPC 检定+战报生成 | `on_enter` |
| `PushEventOperator` | [`core/operators/push_event_operator.gd`](../../core/operators/push_event_operator.gd) | 入栈事件 | `choice_result` |
| `PopEventOperator` | [`core/operators/pop_event_operator.gd`](../../core/operators/pop_event_operator.gd) | 出栈回退 | `choice_result` |
| `PopToEventOperator` | [`core/operators/pop_to_event_operator.gd`](../../core/operators/pop_to_event_operator.gd) | 出栈到指定事件 | `choice_result` |
| `FlagOperator` | [`core/operators/flag_operator.gd`](../../core/operators/flag_operator.gd) | Flag 读写 | `on_enter` / `choice_result` |
| `PropertyOperator` | [`core/model/property_operator.gd`](../../core/model/property_operator.gd) | 属性增减 | `choice_result` |
| `ItemProvider` | [`core/model/item_provider.gd`](../../core/model/item_provider.gd) | 动态选项生成 | 事件 `provider` 属性 |
| `LianjuScoreOperator` | [`core/operators/lianju_score_operator.gd`](../../core/operators/lianju_score_operator.gd) | 自定义计分 | `choice_result` |

### 6.3 新建子系统 Checklist

```
[ ] 1. 选择模式（1-5）
[ ] 2. 确定事件链（几个事件？顺序？push/pop 关系？）
[ ] 3. 确定数据源（需要哪些 Database 字典？）
[ ] 4. 创建 CSV 声明（row_type / uuid / context / results 列）
[ ] 5. 同步 .tres（运行 resources_registry_creator.gd）
[ ] 6. 如果有自定义计分逻辑 → 新建 BaseOperator 子类
[ ] 7. 如果需要 NPC 检定 → 添加翻译键 {PREFIX}_SUCCESS / {PREFIX}_FAIL
[ ] 8. 编辑中断条件（interruptions 列）
[ ] 9. 测试：从 Hub 进入子系统 → 执行完整流程 → pop 回到 Hub
[ ] 10. 保证每个分支都有兜底（无条件选项）
```

### 6.4 所有真实事件 UUID 速查

来自 [`random_events.csv`](../../data/random_events/random_events.csv) 的完整事件列表：

| UUID | 所属子系统 | 角色 |
|------|-----------|------|
| `test1` | 测试 | 基础测试事件 |
| `strange_poet` | 李白初遇链 | 链式 flag 故事 1 |
| `the_man_got_power` | 李白初遇链 | 链式 flag 故事 2 |
| `libai_unveilation` | 李白初遇链 | 链式 flag 故事 3 |
| `libai_after` | 李白初遇链 | 链式 flag 故事 4 |
| `libai_welcome_hejiu` | 饮酒 | StateTransistor 触发 |
| `drink_with_libai` | 饮酒 | 赠诗饮酒选项 |
| `welcome_to_wenhuaquan_party` | 宴席 Hub | 宴席入口 |
| `start_of_wenhuaquan_party` | 宴席 Hub | 宴席开场 |
| `mid_of_wenhuaquan_party` | 宴席 Hub | **主 Hub** |
| `mid_of_wenhuaquan_party_choose_people` | 宴席聊天 | Provider 选人 |
| `event_talk_guest` | 宴席聊天 | NPC 交谈模板 |
| `event_chat_guest` | 宴席聊天 | 聊天 |
| `event_changhe_guest` | 宴席聊天 | 唱和 |
| `party_subjective_changhe` | 宴席聊天 | 主动唱和 |
| `feihualing_start` | **飞花令** | 入口 |
| `feihualing_choose_word` | **飞花令** | 选题+Provider |
| `feihualing_other_done` | **飞花令** | 结算+三选一 |
| `request_libai_changhe` | 李白唱和 | 自愿唱和 |
| `libai_force_changhe` | 李白唱和 | 强制唱和（中断触发） |
| `lianju_intro` | **联句** | 入口 |
| `lianju_npc_turn` | **联句** | NPC 出题 |
| `lianju_show_poem` | **联句** | 展示 NPC 结果 |
| `lianju_player_turn` | **联句** | 玩家对句+计分 |
| `lianju_result` | **联句** | 结果+返回 |

---

> **核心哲学**：这些模式不是"最佳实践"，而是**已经跑通的代码**。复制粘贴 → 换数据 → 能跑。不要重造轮子，先看看轮子在哪。😭
