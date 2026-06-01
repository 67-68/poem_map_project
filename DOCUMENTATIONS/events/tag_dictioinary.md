# Tag 词典 (Tag Dictionary)

## 概述

本文档定义大唐世界观下最核心的 **五维 Tag 词典**。所有 Tag 拼装必须严格限制在以下词汇的排列组合中，禁止凭空发明新词。

这是与 [`tag_idempotent_creation.md`](tag_idempotent_creation.md)（本体论/规约层）配套的**词汇参考层**。

> **契约即自由：** 严格限定的词库防止拼写错误和近义词泛滥。所有 Tag 应通过 Linter 强校验，不在词表中的词直接阻断编译。

---

## 五维分面法

每个事件的 `Trigger_Tags` 是从以下 5 个维度按需挑选拼装的数组。**不是每一维度都必须有一个 Tag。**

---

### 第一维：ACTION（动因面 — 业务入口）

**定义：** 玩家到底按下了什么按钮？事件的 Trigger。

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
| | `watch_dance` | 观舞 |
| | `listen_music` | 听曲 |
| | `whore` | 狎妓 |
| `WORK` | `take_exam` | 科举 |
| | `govern` | 理政 |
| | `bribe` | 行贿 |
| `CREATE` | `deepseek` | 冥想/整理思绪 |
| | `write_poem` | 赋诗 |

---

### 第二维：ACTOR（状态面 — 本体前置）

**定义：** 主角当前是什么生理/心理状态？必须与底层 Prop 和 Emotion 强绑定。

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

---

### 第三维：SOCIAL/ENV（环境/时局面 — 外部底色）

**定义：** 大唐的宏观环境。老天爷和朝廷在干嘛？

| 二级分类 | 三级分类 (Type) | 含义 |
|---------|----------------|------|
| `NATURE` | `spring_blossom` | 春暖花开 |
| | `autumn_wind` | 秋风肃杀 |
| | `snow_storm` | 风雪 |
| | `night_moon` | 月夜 |
| `POLITICS` | `corrupt` | 权臣当道 |
| | `prosper` | 开元盛世 |
| | `inquisition` | 文字狱/党争 |
| `SOCIETY` | `famine` | 灾荒饿殍 |
| | `war_ruin` | 安史战乱 |
| | `festival` | 上元佳节 |

---

### 第四维：VIBE（审美/意境面 — 灵魂产出）

**定义：** 事件的文学调性。直接决定掉落什么属性的意象。

| 三级类型 (Type) | 含义 | 对应意象方向 |
|----------------|------|-------------|
| `zen` | 空山/古刹/禅意 | 禅意类意象 |
| `tao` | 求仙/丹药/羽化 | 求仙类意象 |
| `history` | 废垒/夕阳/沧桑怀古 | 怀古类意象 |
| `martial` | 边塞/侠客/金戈铁马 | 武/健类意象 |
| `sensual` | 软舞/西域/纸醉金迷 | 俗/艳类意象 |
| `elegant` | 古琴/清谈/士大夫 | 雅类意象 |
| `macabre` | 白骨/鬼火/极致凄厉 | 凄厉类意象 |

---

### 第五维：TARGET（对象面 — 实体交互）

**定义：** 事件与哪个具体的组织、人或物品发生的交互？必须是纯粹的名词。

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

---

## 工程学应用 (The Contract)

这套词表类似关系型数据库的 Schema 约束。编写 CSV 的 `Trigger_Tags` 时，像拼积木一样从词典中抽卡。

### 复合示例

**场景：** 中秋夜，在长安没钱买酒，在破庙里和清流名士苦中作乐，狂傲地作诗。

```csv
Trigger_Tags: [ACTION_SOCIAL_BANQUET, ACTOR_FINANCE_BROKE, ACTOR_EMOTION_ARROGANCE, SOCIAL_NATURE_NIGHT_MOON, VIBE_THEME_ELEGANT, TARGET_FACTION_QINGLIU]
```

底层逻辑扫描这组标签：
1. 这是个没钱的局 → 限制某些烧钱选项
2. 玩家处于狂傲状态 → 解锁拍桌子骂娘的选项
3. 结算时往死里给 `ELEGANT` 和 `ARROGANCE` 相关的意象

---

## 词典演进规则

除非游戏机制发生拓扑级改变，否则这套词典足够覆盖初唐到晚唐的全周期。

**扩张条件（必须同时满足）：**
1. 现有词表无法描述新增的游戏机制
2. 书面记录扩张理由
3. 更新本文档的词典表
4. 更新 Linter 规则
5. 添加至少 3 个能证明该新值有用的案例

---

## 相关文档

- [Tag 幂等性创建原则](./tag_idempotent_creation.md) — Tag 的创建规约和 SOP
- [Tag 格式演进历史](./tag_pattern_confliction.md) — 格式定义层
- [场景动作与玩家 Tag 过滤](./scene_action_and_player_tag_filter.md) — 运行时匹配机制
- [玩家当前动作 Tag 生命周期](./player_current_action_tag_life_cycle.md) — 生命周期层
