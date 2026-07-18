# i18n English Translation — Batch Context Plan

## 文件

`data/1_core_rules/translations/_dynamic_events.csv`

## 翻译范围

| 行范围 | 行数 | 说明 |
|--------|------|------|
| 2–871 | ~870 | CODE_ 系统/UI 内部字符串 |
| 1596–2108 | ~513 | TRES_ 数据资源（属性、特质、行动回落、疾病、理念、诗歌等） |
| 2177–2343 | ~167 | MOMENTUM/MONEY/PRESTIGE 渐变文本、LIANJU、NPC 交互回落 |
| 2558–2918 | ~361 | TUT_ 教程对话、UI_ 标签 |
| **合计** | **~1911** | |

## 排除行

- 872–1595（EVT_ 叙事事件，已有策划暂不译）
- 2109–2176（已排除）
- 2344–2557（已排除）

## 全局翻译规则（所有批次通用）

1. **保留所有标记原文不动**：`{param}`、`{@keyword}`、`[br]`、`[color=#xxx]...[/color]`、`[font_size=16][b]...[/b][/font_size]`、`[i]...[/i]`、`[glitch level=N]...[/glitch]`、`[shake rate=N level=N]...[/shake]`、`[center]...[/center]`、`\n`
2. **保留 `%d`、`%s`、`%.1f`、`%%` 等 C 风格格式说明符**
3. **保留所有 BBCode 标签**
4. **目标读者**：英语母语玩家，对中国唐代文化有基本兴趣但非专家
5. **风格**：自然流畅的英文，避免生硬直译，也避免过度华丽的翻译腔。叙事文本应有文学质感但不堆砌生僻词汇
6. **CSV 格式**：只填充第 3 列（en），保留第 4 列（ja）为空，不修改第 1 列（keys）和第 2 列（zh）

---

## 叙事域分类

### 域 A：CODE_ — 系统/UI 内字符串（行 2–871）

**上下文**：唐代诗词模拟 RPG 的 UI/UX 字符串。这些是按钮标签、提示信息、错误消息、格式化提示。出现在游戏界面上供玩家阅读。部分为开发者调试用，但统一按面向玩家的标准翻译。

**风格指引**：
- 按钮和标签：简洁、功能性清晰
- 提示和说明：自然友好
- 错误消息：直接但不生硬
- 保持中文原有的信息层级感

---

### 域 B：PROPERTY/TRAIT — 属性与特质名称及描述

**上下文**：杜甫模拟器中角色的核心属性（健/才/兴/望/钱/势/定/城府/仕/醉）和特质（冻伤、疲态、逢迎、狂客、钻营、右相门生等）的显示名称。这些属性反映唐代文人的身心状态。

**风格指引**：
- 属性名用单个英文词或极短词组
- 特质名保持简洁
- 描述文字用一两句自然英文
- 渐变文本（gain/loss/perception）应有递进感和文学性

---

### 域 C：TRES_ — 行动回落与叙事碎片

**上下文**：玩家执行各类行动（拜谒、登高、坊市卖字、闲居饮酒、交游赴宴等）后，成功或失败时的回落叙事描述。这些是唐代长安文人日常生活的生动剪影。

**子域**：
- C1：拜谒相关（BAIYE_*_FALLBACK）— 拜访权贵的成功/失败叙事
- C2：登高相关（DENGGAO_*_FALLBACK）— 登高望远的回落描述
- C3：坊市相关（FANGSHI_*_FALLBACK）— 市井谋生的回落描述
- C4：闲居相关（DUZHUO_*_FALLBACK）— 独自生活的回落描述
- C5：交游相关（JIAOYOU_*_FALLBACK / HOLD_FEAST / TAVERN_GACHA）— 社交行动的回落描述
- C6：疾病相关（DISEASE_*）— 疾病诊断与症状叙事
- C7：其他叙事碎片（ZIZE_*, FENGXIAN_*, CHANGAN_WALK_*, etc.）

**风格指引**：文学性自然英文，保留唐代氛围但不堆砌文言式英语。叙事短小精悍（通常 1-3 句），抓住瞬间的情感或场景。

---

### 域 D：TRES_ — 时代、抱负、理念描述

**上下文**：游戏中的时代（青年漫游、旷达时期等）、抱负（致君尧舜上、衣锦还乡等）和理念（草莽落拓、沉郁顿挫等）的描述文本。这些是游戏系统的核心世界观说明。

**风格指引**：庄严但有温度的说明文风格，帮助玩家理解杜甫的人生阶段和思想选择。

---

### 域 E：NPC/SOCIAL — NPC 交互与社交结果

**上下文**：与李白、王维、高适、郑虔等 NPC 互动的叙事描述，以及社交行动（交好、威胁、唱和、联句）的结果文本。这些是唐代文人圈的互动片段。

**风格指引**：对话感强，人物性格鲜明（李白豪放、王维淡泊、高适刚毅、郑虔执拗）。

---

### 域 F：TUT_ — 泰山教程对话

**上下文**：青年杜甫在泰山脚下遇到玄明道人的教程对话线。道人为导师角色，杜甫为学子。对话涵盖志向、时间、身体、创作等主题。风格是 mentor-student，温和而富有哲理。

**风格指引**：
- 道人：wise, calm, occasionally playful
- 杜甫：eager, youthful, respectful
- 保留对话的自然流动感

---

### 域 G：UI_ — 界面标签

**上下文**：游戏 UI 面板上的静态标签文本。按钮名、页面标题、存档信息等。

**风格指引**：极简，功能性，清楚传达 UI 元素的用途。

---

## 批次分配

共切分为 **100 个批次**，每批约 15–25 行。

### 批次索引

| 批次 | 域 | 行范围 | 行数 | 说明 |
|------|-----|--------|------|------|
| B001 | A | 2–21 | 20 | ACT_ 行动名称和描述（拜谒、登高、闲居、坊市） |
| B002 | A | 22–41 | 20 | ACT_ 行动名称和描述（交游、吉温、教程、郑虔、驻留） |
| B003 | A | 42–61 | 20 | CHAR_NAME、CODE_ACTION 地点名 |
| B004 | A | 62–81 | 20 | CODE_ACTION_HINT_FORMATTER 行动提示格式化 |
| B005 | A | 82–101 | 20 | CODE_ACTION_HINT_FORMATTER（续） |
| B006 | A | 102–121 | 20 | CODE_ACTION_MANAGER 行动管理 |
| B007 | A | 122–141 | 20 | CODE_ADD_RANDOM_*_OPERATOR 引荐/把柄 |
| B008 | A | 142–161 | 20 | CODE_AUDIO_MANAGER、CODE_BBCODE |
| B009 | A | 162–181 | 20 | CODE_BBCODE（续）、CODE_BUFF_OPERATOR |
| B010 | A | 182–201 | 20 | CODE_BUFF_OPERATOR（续）、CODE_BUSINESS_LINTER |
| B011 | A | 202–221 | 20 | CODE_CHAIN_EXECUTOR、CODE_CREATE_FENGXIAN_EVENTS |
| B012 | A | 222–241 | 20 | CODE_CREATE_FENGXIAN_EVENTS（续） |
| B013 | A | 242–261 | 20 | CODE_CSV_CLOUD_LOADER |
| B014 | A | 262–281 | 20 | CODE_DATABASE、CODE_DATA_SCANNER、CODE_DECISION_SCROLL |
| B015 | A | 282–301 | 20 | CODE_DUMP_TRAIT_HINTS、CODE_EMOTION_OPERATOR、CODE_ENUMERATES |
| B016 | A | 302–321 | 20 | CODE_EVENT_BTN、CODE_EVENT_CHAIN、CODE_EVENT_UI、CODE_EXAMPLE_USAGE |
| B017 | A | 322–341 | 20 | CODE_FACTION、CODE_FOCUS_CHAT、CODE_GAME_DATA_PANEL、CODE_GAME_SAVE |
| B018 | A | 342–361 | 20 | CODE_GENERATE_TEST_POEM、CODE_GLITCH、CODE_IDEA |
| B019 | A | 362–381 | 20 | CODE_IDEA_BTN、CODE_IDEA_PAGE |
| B020 | A | 382–401 | 20 | CODE_LEFT_PLAYER_PANEL、CODE_LEVERAGE_ADD_OPERATOR |
| B021 | A | 402–421 | 20 | CODE_LEVERAGE_ADD_OPERATOR（续）、CODE_LIANJU_SCORE、CODE_LINKER_LINTER、CODE_LINTER_CONSOLE |
| B022 | A | 422–441 | 20 | CODE_MAIN_ACTION_BUTTON、CODE_MODIFIER_CONFIG、CODE_MODIFIER_HINT |
| B023 | A | 442–461 | 20 | CODE_MONTH_END_SETTLEMENT |
| B024 | A | 462–481 | 20 | CODE_MONTH_END_SETTLEMENT（续）、CODE_MULTIPLE_REQUIREMENTS、CODE_NARRATIVE_OVERLAY |
| B025 | A | 482–501 | 20 | CODE_NARRATIVE_OVERLAY（续）、CODE_NOTE_MANAGER |
| B026 | A | 502–521 | 20 | CODE_NPC_ACTION_BUTTON、CODE_NPC_FACTION_REQUIREMENT、CODE_NPC_TIER_REQUIREMENT |
| B027 | A | 522–541 | 20 | CODE_OPTION_BTNS、CODE_PERSON_STATE、CODE_PICKER_*、CODE_PICK_NPC_*、CODE_PLAYER_STATE |
| B028 | A | 542–561 | 20 | CODE_POEM_CRAFTER |
| B029 | A | 562–581 | 20 | CODE_POEM_CRAFTER（续）、CODE_POEM_CRAFTING_CALCULATOR、CODE_POEM_REWARD_OPERATOR |
| B030 | A | 582–601 | 20 | CODE_POEM_REWARD_OPERATOR（续）、CODE_POEM_SLOT、CODE_PROPERTY、CODE_PROPERTY_OPERATOR、CODE_PROPERTY_REQUIREMENT |
| B031 | A | 602–621 | 20 | CODE_PUSH_INTERRUPT、CODE_RANDOM_PICK、CODE_RANGE_REQUIREMENT、CODE_REMOTE_ACTION、CODE_REQ_JOIN、CODE_RIGHT_INFO_PANEL |
| B032 | A | 622–641 | 20 | CODE_RIGHT_INFO_PANEL（续）、CODE_ROLL_IMAGINARY、CODE_RUNTIME_PROBE |
| B033 | A | 642–661 | 20 | CODE_SCHEMA_LINTER、CODE_SETTLEMENT_TAPE、CODE_SET_RANDOM_PERSON_STATE、CODE_SET_STAY_PLACE |
| B034 | A | 662–681 | 20 | CODE_SHATTEREFFECT、CODE_SIMPLE_OPERATOR、CODE_SMOOTH_SCROLL、CODE_SOCIAL_ACTION_RESOLVER、CODE_SOCIAL_CONNECTION_PAGE |
| B035 | A | 682–701 | 20 | CODE_SOCIAL_CONNECTION_PAGE（续）、CODE_STYLE_STRATEGY、CODE_SUB_ACTION、CODE_SURVIVAL_MANAGER |
| B036 | A | 702–721 | 20 | CODE_TIME_BREATH_UI、CODE_TIME_CONTROL_PANEL、CODE_TIME_OPERATOR、CODE_TIME_SERVICE |
| B037 | A | 722–741 | 20 | CODE_TIME_SERVICE（续） |
| B038 | A | 742–761 | 20 | CODE_TIME_SERVICE（续） |
| B039 | A | 762–781 | 20 | CODE_TIME_SERVICE（续） |
| B040 | A | 782–801 | 20 | CODE_TIME_SERVICE（续）、CODE_TOMB_STONE_SCREEN |
| B041 | A | 802–821 | 20 | CODE_TRAIT_DEMONSTRATOR、CODE_TRAIT_HINT_FORMATTER |
| B042 | A | 822–841 | 20 | CODE_TRAIT_OPERATOR、CODE_TRAIT_REQUIREMENT、CODE_TUTORIAL_CONTROLLER |
| B043 | A | 842–861 | 20 | CODE_UNLOCK_SOCIAL、CODE_URN、CODE_VTEST_GOLDEN_SHINE |
| B044 | A | 862–871 | 10 | CODE_VTEST_NARRATIVE_OVERLAY、CODE_VTEST_TRAIT_HINTS |
| B045 | B | 1596–1619 | 24 | FEIHUALING/LIANJU 结果、PROPERTY_NAME_*、TRAIT_ 名称 |
| B046 | B | 1620–1647 | 28 | TRAIT_ 名称（续）、TRES_ 时代名称、登高情绪回落名称 |
| B047 | B | 1648–1677 | 30 | TRES_ 登高回落名称（续）、TRES_ 酒馆/崩溃后叙事名称+描述 |
| B048 | B | 1678–1707 | 30 | TRES_ 崩溃后/抱负/城府描述 |
| B049 | B | 1708–1737 | 30 | TRES_ 回乡/拜谒回落叙事 |
| B050 | B | 1738–1767 | 30 | TRES_ 拜谒/长安漫步/定力描述 |
| B051 | B | 1768–1797 | 30 | TRES_ 定力渐变/打油诗/为官/抱负/登高回落 |
| B052 | B | 1798–1819 | 22 | TRES_ 登高回落（续）、疾病名称+描述 |
| B053 | B | 1820–1847 | 28 | TRES_ 疾病描述、坊间听闻/药酒/小酌回落 |
| B054 | B | 1848–1877 | 30 | TRES_ 独酌行动/科举结束/抱负开始/回乡/长安漫步 |
| B055 | B | 1878–1907 | 30 | TRES_ 长安漫步（续）、唱和/聊天/冷却/死亡 |
| B056 | B | 1908–1937 | 30 | TRES_ 社交交好/科举/右相府/获得官职/引荐 |
| B057 | B | 1938–1967 | 30 | TRES_ 流落街头/社交路由/对话/把柄/威胁 |
| B058 | B | 1968–1997 | 30 | TRES_ 威胁/坊市搬砖/坊市回落/卖字/卖诗 |
| B059 | B | 1998–2027 | 30 | TRES_ 试药/坊市行动/奉先村叙事 |
| B060 | B | 2028–2057 | 30 | TRES_ 奉先村（续）/奉召/科举/归家 |
| B061 | B | 2058–2087 | 30 | TRES_ 健康渐变/宴席回落/理念 |
| B062 | B | 2088–2108 | 21 | TRES_ 理念（续）、灵感渐变 |
| B063 | C5 | 2177–2207 | 31 | TRES_ 暗巷/联句/李白/右相叙事 |
| B064 | C5/D | 2208–2237 | 30 | TRES_ 右相府叙事、势渐变、金钱渐变 |
| B065 | D/E | 2238–2267 | 30 | TRES_ 金钱渐变（续）、濒死/思绪/笔记 |
| B066 | E | 2268–2297 | 30 | TRES_ 笔记（续）、NPC 文档、出城/唱和/同乡/诗词 |
| B067 | E | 2298–2327 | 30 | TRES_ 诗词/声望渐变 |
| B068 | E | 2328–2343 | 16 | TRES_ 仕途渐变、PROVIDER_MANIA |
| B069 | C6/C7 | 2558–2587 | 30 | TRES_ 渔阳鼙鼓/时间渐变/吐蕃/教程出游 |
| B070 | C7 | 2588–2617 | 30 | TRES_ 教程（续） |
| B071 | F | 2618–2647 | 30 | TRES_ 教程（续） |
| B072 | F | 2648–2677 | 30 | TRES_ 教程（续） |
| B073 | F | 2678–2707 | 30 | TRES_ 教程（续）、升官/右相府叙事 |
| B074 | C | 2708–2737 | 30 | TRES_ 右相府叙事/郑虔诗歌交换 |
| B075 | C/E | 2738–2767 | 30 | TRES_ 浊流钻营叙事 |
| B076 | C/E | 2768–2795 | 28 | TRES_ 浊流钻营/自责叙事 |
| B077 | G | 2796–2825 | 30 | UI_ 标签（行动按钮/抱负/存档/理念） |
| B078 | G | 2826–2855 | 30 | UI_ 标签（物品选择/玩家面板/叙事覆盖/笔记） |
| B079 | G | 2856–2885 | 30 | UI_ 标签（NPC行动按钮/选择器/诗词创作） |
| B080 | G | 2886–2918 | 33 | UI_ 标签（诗词需求/插槽/属性/信息面板/社交/菜单/墓碑） |
