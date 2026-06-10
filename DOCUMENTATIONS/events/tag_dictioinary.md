# 大唐 Tag 本体论与五维宪法

## 概述

本文档是大唐世界观下 **五维宪法** 的唯一权威文档。所有出现在游戏配置中的 `Trigger_Tags`，必须且只能从以下 5 张表中挑选拼装。**禁止凭空发明新词，禁止从其他来源引入枚举值。**

> **契约即自由：** 严格限定的词库防止拼写错误和近义词泛滥。所有 Tag 应通过 Linter 强校验，不在词表中的词直接阻断编译。

---

## 核心哲学：为什么要立宪法？

### OOP → ECS 的范式升级

**五维宪法**本质上是 **ECS / 数据库索引思维**：

> 把动作、状态、环境、意境、对象解耦成 **绝对正交的原子**。
> 你想表达"在酒馆看胡人打架"，不需要造缝合怪 Tag，只需从宪法词典里**抽卡**：
> - `ACTION_ENTERTAIN_DRINK`（喝酒 / 酒馆）
> - `ACTION_SOCIAL_BRAWL`（冲突）
> - `VIBE_THEME_MARTIAL`（武 / 健）

**只要五维表是锁死的，拼装出来的组合就是无穷的，而且绝对不会产生歧义。**

---

## 三大铁律 (The Three Iron Laws)

以下三条铁律是五维宪法的物理法则，任何 Tag 的创建与校验都必须严格遵守。

### 铁律一：绝对枚举律 (The Strict Enum Law)

> 所有出现在游戏配置里的 Tag，**必须且只能**是下表明确列出的枚举值。

- 任何策划想写一个 `ACTION_KICK_DOG`，Linter 直接爆红阻断：**"词典中无此词，请走宪法修正案流程！"**
- 禁止裸写任何不在五张表中的字符串作为 Tag

### 铁律二：维度纯洁律 (Dimensional Purity)

> 这是正交性的生命线。**每个维度只能表达自己分内的事。**

| 维度 | 允许的内容 | 禁止越权示例 | 正确做法 |
|------|-----------|------------|---------|
| `ACTION` | 纯动作 / 行为 | `ACTION_ANGRY_DRINK`（混入情绪） | `ACTION_ENTERTAIN_DRINK` + `ACTOR_EMOTION_ANGER` |
| `ACTOR` | 状态 / 情绪 / 生理 | `ACTOR_SICK_IN_AUTUMN`（混入环境） | `ACTOR_HEALTH_SICK` |
| `ENV` | 外部环境 / 时局 | `ENV_WAR_AND_SAD`（混入情绪） | `ENV_SOCIETY_WAR` |
| `VIBE` | 审美 / 意境 | `VIBE_ELEGANT_AND_DRUNK`（混入动作） | `VIBE_AESTHETIC_ELEGANT` |
| `TARGET` | 纯名词实体 | `TARGET_LIBAI_IS_ANGRY`（混入状态） | `TARGET_NPC_LIBAI` |

> 如果有人试图在一个维度里表达另一个维度的事，说明他没有理解宪法，打回去重构。

### 铁律三：最小跨度律 (Minimum Span Rule, 3-5 法则)

> 一个事件的 `Trigger_Tags` 数组，**至少包含 3 个标签，最多 5 个标签**（每个维度最多取 1 个）。

- **为什么最少 3 个？** 如果只挂 1 个 Tag（比如 `[ACTOR_HEALTH_SICK]`），匹配度太低，事件无法在足够丰富的情境下触发。3 个 Tag 保证了一个事件有足够的信息量来做出有意义的匹配。
- **为什么最多 5 个？** 五个维度各一个，已经覆盖了事件的全部侧面。超过 5 个意味着维度内有冗余，或者跨维度重复，违背 MECE 原则。
- **例外场景（需审批）：** 极少数特殊事件（如主线剧情关键节点）可申请少于 3 个 Tag（比如 1-2 个高权重 Tag），但需要架构师书面批准。

---

## 五维拼装规约 (SOP)

### 操作流程

```text
1.  面对 5 张宪法表
2.  从以下维度中**至少选 3 个，最多选 5 个**：
    ├─ ACTION（动因面）    → 玩家按下了什么按钮？
    ├─ ACTOR（状态面）     → 主角当前什么生理/心理状态？
    ├─ ENV（环境/时局面）  → 外部世界怎么了？
    ├─ VIBE（审美/意境面） → 事件的文学灵魂？
    └─ TARGET（对象面）    → 跟谁？（可选，但不计入最低 3 个的强制额度）
3.  检查每个选中的 Tag 是否满足维度纯洁律
4.  合成 Tag 数组格式: [ACTION_xxx, ACTOR_xxx, ENV_xxx, VIBE_xxx, TARGET_xxx]
5.  确保数组长度在 [3, 5] 区间
6.  运行 Linter 验证
```

### 维度对照表

| 维度 | 前缀 | 含义 | 强制级别 |
|------|------|------|---------|
| **动因面 (Action)** | `ACTION_` | 玩家在干嘛？ | **必须** |
| **状态面 (Actor State)** | `ACTOR_` | 主角当前什么状态？ | **必须** |
| **环境/时局面 (Environment)** | `ENV_` | 外部世界怎么了？ | 推荐 |
| **审美/意境面 (Vibe)** | `VIBE_` | 事件的文学灵魂？ | **必须** |
| **对象面 (Target)** | `TARGET_` | 跟谁/什么？ | 可选 |

> **注意：** 强制级别为"必须"的维度，如果事件在该维度上无显著特征，应使用该维度的"中性/通用"枚举值（如 `ACTOR_STATUS_NORMAL`），而不是直接省略。

---

## 五维宪法词典

### 第一维：ACTION（动因面 — 业务入口）

**定义：** 玩家到底按下了什么按钮？事件的 Trigger。

**纯洁性约束：** `ACTION` 内 **不得** 出现情绪词、状态词。例如 `ACTION_ANGRY_DRINK` 是越权行为，应拆为 `ACTION_ENTERTAIN_DRINK` + `ACTOR_EMOTION_ANGER`。

| 二级分类 | 三级分类 (Type) | 含义 |
|---------|----------------|------|
| `TRAVEL` | `roam` | 漫游 |
| | `exile` | 贬谪 |
| | `climb` | 登高 |
| | `boat` | 泛舟 |
| `SOCIAL` | `banquet` | 宴会 |
| | `visit` | 拜谒 |
| | `parting` | 送别 |
| | `brawl` | 冲突 |
| `ENTERTAIN` | `drink` | 饮酒 |
| | `watchdance` | 观舞 |
| | `listenmusic` | 听曲 |
| | `whore` | 狎妓 |
| `WORK` | `takeexam` | 科举 |
| | `govern` | 理政 |
| | `bribe` | 行贿 |
| `CREATE` | `deepseek` | 冥想/整理思绪 |
| | `writepoem` | 赋诗 |

**完整枚举值：**
- `ACTION_TRAVEL_ROAM`
- `ACTION_TRAVEL_EXILE`
- `ACTION_TRAVEL_CLIMB`
- `ACTION_TRAVEL_BOAT`
- `ACTION_SOCIAL_BANQUET`
- `ACTION_SOCIAL_VISIT`
- `ACTION_SOCIAL_PARTING`
- `ACTION_SOCIAL_BRAWL`
- `ACTION_ENTERTAIN_DRINK`
- `ACTION_ENTERTAIN_WATCHDANCE`
- `ACTION_ENTERTAIN_LISTENMUSIC`
- `ACTION_ENTERTAIN_WHORE`
- `ACTION_WORK_TAKEEXAM`
- `ACTION_WORK_GOVERN`
- `ACTION_WORK_BRIBE`
- `ACTION_CREATE_DEEPSEEK`
- `ACTION_CREATE_WRITEPOEM`

---

### 第二维：ACTOR（状态面 — 本体前置）

**定义：** 主角当前是什么生理/心理状态？必须与底层 Prop 和 Emotion 强绑定。

**纯洁性约束：** `ACTOR` 内 **不得** 出现动作词、环境词。例如 `ACTOR_SICK_IN_WINTER` 是越权行为，应拆为 `ACTOR_HEALTH_SICK` + `ENV_NATURE_SNOWSTORM`。

| 二级分类 | 三级分类 (Type) | 含义 |
|---------|----------------|------|
| `HEALTH` | `sick` | 病痛 |
| | `drunk` | 大醉 |
| | `exhausted` | 极度疲劳 |
| | `dying` | 濒死 |
| `EMOTION` | `sorrow` | 愁苦 |
| | `arrogance` | 狂傲 |
| | `anger` | 愤懑 |
| | `tranquility` | 旷达 |
| | `ambition` | 野心 |
| `FINANCE` | `broke` | 穷困潦倒 |
| | `wealthy` | 腰缠万贯 |
| `STATUS` | `wanted` | 被通缉 |
| | `demoted` | 遭贬斥 |
| | `normal` | 平常（中性态） |

**完整枚举值：**
- `ACTOR_HEALTH_SICK`
- `ACTOR_HEALTH_DRUNK`
- `ACTOR_HEALTH_EXHAUSTED`
- `ACTOR_HEALTH_DYING`
- `ACTOR_EMOTION_SORROW`
- `ACTOR_EMOTION_ARROGANCE`
- `ACTOR_EMOTION_ANGER`
- `ACTOR_EMOTION_TRANQUILITY`
- `ACTOR_EMOTION_AMBITION`
- `ACTOR_FINANCE_BROKE`
- `ACTOR_FINANCE_WEALTHY`
- `ACTOR_STATUS_WANTED`
- `ACTOR_STATUS_DEMOTED`
- `ACTOR_STATUS_NORMAL`

---

### 第三维：ENV（环境/时局面 — 外部底色）

> **字段变更：** 此前此维度称为 `SOCIAL` 或 `SOCIAL/ENV`。为符合维度纯洁律，现统一为 `ENV`，避免与 `ACTION_SOCIAL_*` 中的 "社交" 含义混淆。

**定义：** 大唐的宏观环境。老天爷和朝廷在干嘛？

**纯洁性约束：** `ENV` 内 **不得** 出现主角的内心感受、动作意图。例如 `ENV_FESTIVAL_AND_HAPPY` 是越权行为，应拆为 `ENV_SOCIETY_FESTIVAL` + `ACTOR_EMOTION_ARROGANCE`。

| 二级分类 | 三级分类 (Type) | 含义 |
|---------|----------------|------|
| `NATURE` | `springblossom` | 春暖花开 |
| | `autumnwind` | 秋风肃杀 |
| | `snowstorm` | 风雪 |
| | `nightmoon` | 月夜 |
| `POLITICS` | `corrupt` | 权臣当道 |
| | `prosper` | 开元盛世 |
| | `inquisition` | 文字狱/党争 |
| | `cloud` | 🆕 浮云蔽日/云天遮掩 |
| `SOCIETY` | `famine` | 灾荒饿殍 |
| | `war` | 安史战乱 |
| | `festival` | 上元佳节 |

**完整枚举值：**
- `ENV_NATURE_SPRINGBLOSSOM`
- `ENV_NATURE_AUTUMNWIND`
- `ENV_NATURE_SNOWSTORM`
- `ENV_NATURE_NIGHTMOON`
- `ENV_POLITICS_CORRUPT`
- `ENV_POLITICS_PROSPER`
- `ENV_POLITICS_CLOUD`
- `ENV_POLITICS_INQUISITION`
- `ENV_SOCIETY_FAMINE`
- `ENV_SOCIETY_WAR`
- `ENV_SOCIETY_FESTIVAL`

---

### 第四维：VIBE（审美/意境面 — 灵魂产出）

**定义：** 事件的文学调性。它是场景物理特征在精神层面的投影。

**纯洁性约束：** `VIBE` 内 **不得** 出现具体的动作或实体名词。例如 `VIBE_ELEGANT_QIN` 是越权行为（`qin` 是 `TARGET` 的事），应拆为 `VIBE_AESTHETIC_ELEGANT` + `TARGET_OBJECT_GUQIN`。

| 二级分类 | 三级分类 (Type) | 含义 | 对应意象方向 |
| --- | --- | --- | --- |
| `PHILOSOPHY` (哲思/出世) | `zen` | 空山/古刹/禅意 | 禅意类意象 |
|  | `tao` | 求仙/丹药/羽化 | 求仙类意象 |
| `AESTHETIC` (美学/入世) | `elegant` | 古琴/清谈/士大夫 | 雅类意象 |
|  | `sensual` | 软舞/西域/纸醉金迷 | 俗/艳类意象 |
| `THEME` (文学母题) | `history` | 废垒/夕阳/沧桑怀古 | 怀古类意象 |
|  | `martial` | 边塞/侠客/金戈铁马 | 武/健类意象 |
|  | `macabre` | 白骨/鬼火/极致凄厉 | 凄厉类意象 |

**完整枚举值：**
- `VIBE_PHILOSOPHY_ZEN`
- `VIBE_PHILOSOPHY_TAO`
- `VIBE_AESTHETIC_ELEGANT`
- `VIBE_AESTHETIC_SENSUAL`
- `VIBE_THEME_HISTORY`
- `VIBE_THEME_MARTIAL`
- `VIBE_THEME_MACABRE`

---

### 第五维：TARGET（对象面 — 实体交互）

**定义：** 事件与哪个具体的组织、人或物品发生的交互？**必须是纯粹的名词。**

**纯洁性约束：** `TARGET` 内 **不得** 出现任何状态描述词、时间词、地点词或形容词。例如 `TARGET_SAD_LIBAI` 是越权行为，应拆为 `TARGET_NPC_LIBAI` + `ACTOR_EMOTION_SORROW`。

| 二级分类 | 三级分类 (Type) | 含义 |
|---------|----------------|------|
| `FACTION` | `qingliu` | 清流 |
| | `zhuoliu` | 浊流 |
| | `royal` | 皇室 |
| | `military` | 藩镇 |
| `NPC` | `libai` | 李白 |
| | `dufu` | 杜甫 |
| | `wangwei` | 王维 |
| | `yangguifei` | 杨贵妃 |
| `OBJECT` | `guqin` | 古琴 |
| | `sword` | 剑 |
| | `wine` | 酒 |
| `MYTH` | `giantroc` | 🆕 大鹏（图腾，象征个人狂傲与一飞冲天） |
| `PLACE` | `jadestep` | 🆕 玉阶（政治地标，象征权力中枢与阶级跃升） |

**完整枚举值：**
- `TARGET_FACTION_QINGLIU`
- `TARGET_FACTION_ZHUOLIU`
- `TARGET_FACTION_ROYAL`
- `TARGET_FACTION_MILITARY`
- `TARGET_NPC_LIBAI`
- `TARGET_NPC_DUFU`
- `TARGET_NPC_WANGWEI`
- `TARGET_NPC_YANGGUIFEI`
- `TARGET_OBJECT_GUQIN`
- `TARGET_OBJECT_SWORD`
- `TARGET_OBJECT_WINE`
- `TARGET_MYTH_GIANTROC`  🆕
- `TARGET_PLACE_JADESTEP`  🆕

---

## 工程学应用

### 复合示例（满足最小跨度律）

**场景：** 中秋夜，在长安没钱买酒，在破庙里和清流名士苦中作乐，狂傲地作诗。

| 维度 | 选择 | 理由 |
|------|------|------|
| `ACTION` | `ACTION_SOCIAL_BANQUET` | 聚饮 |
| `ACTOR` | `ACTOR_EMOTION_ARROGANCE` | 狂傲状态 |
| `ENV` | `ENV_NATURE_NIGHTMOON` | 月夜 |
| `VIBE` | `VIBE_AESTHETIC_ELEGANT` | 文人雅集 |
| `TARGET` | `TARGET_FACTION_QINGLIU` | 清流 |

```csv
Trigger_Tags: [ACTION_SOCIAL_BANQUET, ACTOR_EMOTION_ARROGANCE, ENV_NATURE_NIGHTMOON, VIBE_AESTHETIC_ELEGANT, TARGET_FACTION_QINGLIU]
```

维度检查：
| 维度 | Tag | 合规？ |
|------|-----|-------|
| `ACTION` | `ACTION_SOCIAL_BANQUET` | ✅ 纯动作 |
| `ACTOR` | `ACTOR_EMOTION_ARROGANCE` | ✅ 纯状态 |
| `ENV` | `ENV_NATURE_NIGHTMOON` | ✅ 纯环境 |
| `VIBE` | `VIBE_AESTHETIC_ELEGANT` | ✅ 纯意境 |
| `TARGET` | `TARGET_FACTION_QINGLIU` | ✅ 纯名词 |

数组长度：**5**（满足 3-5 法则 ✅）

底层逻辑扫描这组标签：
1. 这是个狂欢的局 → 解锁社交类选项
2. 玩家处于狂傲状态 → 解锁拍桌子骂娘的选项
3. 月夜 + 清流 → 结算时给 `ELEGANT` 和诗意相关的意象

### 最小跨度示例（刚好 3 个）

**场景：** 单纯生病卧床。

```csv
Trigger_Tags: [ACTION_WORK_GOVERN, ACTOR_HEALTH_SICK, VIBE_PHILOSOPHY_ZEN]
```

| 维度 | Tag | 理由 |
|------|-----|------|
| `ACTION` | `ACTION_WORK_GOVERN` | 本在处理公务（或有此意图） |
| `ACTOR` | `ACTOR_HEALTH_SICK` | 突然病倒了 |
| `VIBE` | `VIBE_PHILOSOPHY_ZEN` | 病中独处，心绪空寂 |

数组长度：**3**（满足 3-5 法则 ✅）

### 五维交集匹配 (运行时)

五维宪法天然兼容前缀匹配机制。使用五维法后，事件触发逻辑高度立体且可复用：

**场景：** 玩家处于【秋天】(`ENV_NATURE_AUTUMNWIND`)，且【极度郁结】(`ACTOR_EMOTION_SORROW`)。他点击了【登高】按钮 (`ACTION_TRAVEL_CLIMB`)。

Event Manager 拿着这三个 Tag 扫事件库：

| 事件 | Tags | 匹配度 |
|------|------|--------|
| **事件 A：** 普通登高 | `[ACTION_TRAVEL_CLIMB]` | 命中 1 个（数量不足，跳过） |
| **事件 B：** 秋日登高思乡 | `[ACTION_TRAVEL_CLIMB, ENV_NATURE_AUTUMNWIND, VIBE_THEME_HISTORY]` | 命中 2 个 |
| **事件 C：** 绝境中的绝唱（极稀有） | `[ACTION_TRAVEL_CLIMB, ENV_NATURE_AUTUMNWIND, ACTOR_EMOTION_SORROW]` | 命中 **3 个**（完美契合）|

系统拉起事件 C，文本描述："秋风萧瑟，你满心郁结，登上高台，只觉天地苍茫，怆然而涕下。"结算时直接给予极品意象。

### 违规示例

```csv
Trigger_Tags: [ACTION_ENTERTAIN_DRINK, ACTOR_EMOTION_SORROW, ENV_SOCIETY_WAR, VIBE_THEME_MARTIAL, TARGET_FACTION_MILITARY, ACTOR_FINANCE_BROKE]
```
❌ **违规原因：** 数组长度 6，超过最大 5 的限制（`ACTOR` 取了 2 个，违反每维度最多 1 个）。

```csv
Trigger_Tags: [ACTION_SOCIAL_BRAWL]
```
❌ **违规原因：** 数组长度 1，不满足最少 3 个的要求。

---

## 运行时前缀匹配

五维宪法天然兼容前缀匹配机制（详见 [`scene_action_and_player_tag_filter.md`](scene_action_and_player_tag_filter.md)）。

**前缀匹配规则：** 短的 Tag 作为前缀去匹配长的 Tag，按冒号分段。

```text
ACTOR_HEALTH            → 匹配 ACTOR_HEALTH_SICK ✅
ACTOR_HEALTH_SICK       → 匹配 ACTOR_HEALTH_SICK ✅
ACTOR_HEALTHCARE        → 不匹配 ACTOR_HEALTH_SICK ❌（不是前缀）
```

**事件触发逻辑：** 系统扫描事件的 `Trigger_Tags` 数组，对数组中的每个 Tag 做前缀匹配。命中次数越多，权重越高（首次命中权重 x9，后续每次追加 x3）。

---

## Linter 规则

光有文档不够——必须通过自动化手段锁死规约。在现有 [Linter 系统](../../debuggers/) 中添加校验规则：

```text
规则 ID:     TAG_FIVE_FACET_CONSTITUTION
检查目标:    所有新增/修改的 Trigger_Tags 数组
校验逻辑:
  1. 按逗号 split 为多个 Tag
  2. 检查数组长度是否在 [3, 5] 区间（铁律三）
  3. 对数组中每个 Tag：
     a. 检查前缀是否合法（ACTION_ / ACTOR_ / ENV_ / VIBE_ / TARGET_）
     b. 检查该 Tag 是否在词典中有明确定义（铁律一）
     c. 检查维度纯洁性（铁律二）：
        - ACTION_ 开头的 Tag，检查其子分类是否属于动作类
        - ACTOR_ 开头的 Tag，检查其子分类是否属于状态/情绪类
        - 以此类推...
  4. 检查同一维度是否出现多个 Tag（铁律三的延伸：每个维度最多 1 个）
  5. 如果有 TARGET_ 维度，检查是否为纯名词（铁律二）
违规处理: push_error + 阻断事件注册
```

---

## 词典演进规则

除非游戏机制发生拓扑级改变，否则这套词典足够覆盖初唐到晚唐的全周期。

**扩张条件（必须同时满足）：**
1. 现有词表无法描述新增的游戏机制
2. 书面记录扩张理由
3. 更新本文档的词典表
4. 更新 Linter 规则
5. 添加至少 **3 个** 能证明该新值有用的案例

---

## 与现有系统的关系

```text
┌──────────────────────────────────────────────────────────────┐
│            本文 — 大唐 Tag 本体论与五维宪法                    │
│            定义「Tag 应该怎么造 + 有哪些合法枚举值」           │
├──────────────────────────────────────────────────────────────┤
│                    tag_pattern_confliction.md                  │
│                   (格式定义层)                                  │
│                   定义「字符串长什么样」(前缀匹配格式)           │
├──────────────────────────────────────────────────────────────┤
│          scene_action_and_player_tag_filter.md                 │
│                   (运行时匹配层)                                │
│                   定义「Tag 怎么用」(前缀匹配 + 权重累加)       │
├──────────────────────────────────────────────────────────────┤
│          player_current_action_tag_life_cycle.md               │
│                   (生命周期层)                                  │
│                   定义「Tag 怎么流动」(注入/清除)               │
└──────────────────────────────────────────────────────────────┘
```

---

## 注意事项

1. **不要过度分类：** 如果某个事件只出现一次，不值得为它新开一个枚举值。80% 的事件应该能用现有词表覆盖（20/80 原则）。
2. **前缀匹配的兼容性：** 五维法生成的 Tag 天然兼容前缀匹配机制。`ENV_NATURE` 即可匹配 `ENV_NATURE_AUTUMNWIND`。
3. **情绪获取顺理成章：** 当一个事件同时挂载了 `ACTION_TRAVEL_EXILE` 和 `ENV_SOCIETY_WAR`，系统自动根据这两个 Tag 推导出应该在 `on_enter` 时给玩家增加 `SORROW`。**标签本身就是数据的驱动力。**

---

## 相关文档

- [Tag 格式演进历史](./tag_pattern_confliction.md) — 格式定义层
- [场景动作与玩家 Tag 过滤](./scene_action_and_player_tag_filter.md) — 运行时匹配机制
- [玩家当前动作 Tag 生命周期](./player_current_action_tag_life_cycle.md) — 生命周期层
