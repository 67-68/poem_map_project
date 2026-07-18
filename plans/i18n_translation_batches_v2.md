# i18n English Translation — 15-Batch Context Plan (v2)

## 文件

`data/1_core_rules/translations/_dynamic_events.csv`

## 翻译范围与不翻译范围

| 行范围 | 行数 | 翻译? |
|--------|------|-------|
| 2–871 | 870 | ✅ |
| 872–1595 | — | ❌ (EVT_ 叙事事件) |
| 1596–2108 | 513 | ✅ |
| 2109–2176 | — | ❌ |
| 2177–2343 | 167 | ✅ |
| 2344–2557 | — | ❌ |
| 2558–2918 | 361 | ✅ |
| **合计翻译** | **1911** | |

## 全局翻译铁律（所有 15 批次通用，写入每个批次文件头部）

1. **保留所有标记原文不动**：`{param}`、`{@keyword}`、`[br]`、`[color=#xxx]...[/color]`、`[font_size=N][b]...[/b][/font_size]`、`[i]...[/i]`、`[glitch level=N]...[/glitch]`、`[shake rate=N level=N]...[/shake]`、`[center]...[/center]`、`\n`
2. **保留 `%d`、`%s`、`%.1f`、`%%` 等 C 风格格式说明符**
3. **保留所有 BBCode 标签**
4. **只输出第 3 列（en）**，不修改 keys/zh/ja
5. **目标风格**：自然流畅英文，非文言英译。唐代氛围但不用生僻词。
6. **CSV 输出格式**：按原行顺序输出 `keys,zh,en,ja`，en 列填入翻译，ja 列留空

## 15 批次划分

| 批次 | 行范围 | 行数 | 域 | 主要内容 |
|------|--------|------|-----|----------|
| B01 | 2–141 | 140 | A | ACT_ 行动名/描述 + CHAR_NAME + CODE_ACTION 地点/提示/管理 |
| B02 | 142–281 | 140 | A | CODE_ 音频/BBcode/Buff/Linter/Chain/Fengxian/CSV Loader/Database/Scanner |
| B03 | 282–421 | 140 | A | CODE_ Dump/Emotion/Enum/EventBtn/EventChain/Example/Faction/Focus/GameData/Generate/Idea/Leverage |
| B04 | 422–561 | 140 | A | CODE_ Linter/MainAction/Modifier/MonthEnd/Narrative/Note/NpcAction/Picker/Player/PoemCrafter |
| B05 | 562–701 | 140 | A | CODE_ PoemReward/Property/Requirements/Runtime/Schema/Settlement/Social/Survival |
| B06 | 702–871 | 170 | A | CODE_ Time/TombStone/Trait/Tutorial/URN/Vtest |
| B07 | 1596–1847 | 252 | B+C | FEIHUALING/LIANJU + PROPERTY_NAME + TRAIT_ + TRES_ 时代/抱负/属性/疾病/回落 |
| B08 | 1848–2108 | 261 | C+D | TRES_ 回落叙事（续）+ 理念 + 灵感渐变 |
| B09 | 2177–2343 | 167 | E+F | TRES_ 联句/李白/右相/势/钱渐变/濒死/笔记/NPC/诗词/声望/仕途 |
| B10 | 2558–2795 | 238 | F+G | TRES_ 教程对话 + 右相府叙事 + 浊流/自责叙事 |
| B11 | 2796–2918 | 123 | H | UI_ 界面标签（全部） |

Wait — 用户要求 15 批次，11 批不够。需要更细粒度。

| 批次 | 行范围 | 行数 | 域 | 主要内容 |
|------|--------|------|-----|----------|
| B01 | 2–141 | 140 | A | ACT_ 行动名+描述、CHAR_NAME、CODE_ACTION 地点/按钮/提示/管理 |
| B02 | 142–281 | 140 | A | CODE_ 音频/BBcode/Buff/BusinessLinter/Camera/Chain/Complex/CreateFengxian/CSVLoader/Database/Scanner |
| B03 | 282–421 | 140 | A | CODE_ Dump/Emotion/Enum/EventBtn/EventChain/EventUI/Example/Faction/Focus/GameData/GameSave/Generate/Glitch/IdeaBtn/Idea/Item/Leverage |
| B04 | 422–561 | 140 | A | CODE_ Linter/MainAction/Modifier/MonthEnd/MultipleReq/Narrative/Note/NpcAction/NpcFaction/Option/Person/Pick/PickNpc/PlayerState/PoemCrafter |
| B05 | 562–701 | 140 | A | CODE_ PoemCrafting/PoemReward/PoemSlot/Property/PropertyReq/PushInterrupt/RandomPick/RangeReq/Remote/RightInfo/Roll/Runtime/Schema/Settlement/SetStay/Shatter/Simple/Smooth/Social |
| B06 | 702–871 | 170 | A | CODE_ TimeBreath/TimeControl/TimeOp/TimeService/TombStone/Trait/Tutorial/UnlockSocial/URN/Vtest |
| B07 | 1596–1747 | 152 | B+C | FEIHUALING/LIANJU + PROPERTY_NAME + TRAIT_ 名称 + TRES_ 时代/抱负/属性值渐变 |
| B08 | 1748–1897 | 150 | C | TRES_ 拜谒/长安漫步/登高/疾病描述/独酌/科举/回乡回落叙事 |
| B09 | 1898–2047 | 150 | C+D | TRES_ 死亡/社交/科举/右相/官职/引荐/流落/威胁/坊市/奉先/奉召/归家/健康/宴席回落 |
| B10 | 2048–2108 | 61 | D | TRES_ 理念描述 + 灵感渐变 |
| B11 | 2177–2259 | 83 | E | TRES_ 暗巷/联句/李白/右相/势渐变/金钱渐变/濒死 |
| B12 | 2260–2343 | 84 | E | TRES_ 笔记/NPC文档/出城/唱和/同乡/诗词/声望/仕途/PROVIDER_MANIA |
| B13 | 2558–2717 | 160 | F | TRES_ 渔阳鼙鼓/时间/吐蕃/教程出游+对饮+下山+理念+道长+迷雾+无灵感+评诗+驻留 |
| B14 | 2718–2875 | 158 | F+G | TRES_ 右相府叙事/郑虔/浊流钻营/自责 + UI_ 行动按钮/抱负/存档/理念/物品选择/玩家面板/笔记 |
| B15 | 2876–2918 | 43 | G | UI_ NPC动作/选择器/诗词/属性/社交/菜单/墓碑 |

That gives me...

B10 is only 61 lines, B11 is 83, B12 is 84, B15 is 43. Still unbalanced.

Let me rebalance:

B01: 2-141 (140)
B02: 142-281 (140)
B03: 282-421 (140)
B04: 422-561 (140)
B05: 562-701 (140)
B06: 702-871 (170)
B07: 1596-1797 (202) - 属性/特质/时代/抱负/属性渐变 + 部分回落
B08: 1798-1997 (200) - 登高回落 + 疾病 + 独酌 + 科举 + 坊市
B09: 1998-2108 (111) + 2177-2259 (83) = 194 - 试药 + 坊市 + 奉先 + 奉召 + 科举 + 归家 + 健康 + 宴席 + 理念 + 暗巷 + 联句 + 李白 + 右相
B10: 2260-2343 (84) + 2558-2657 (100) = 184 - 笔记 + NPC + 出城 + 唱和 + 同乡 + 诗词 + 声望 + 仕途 + 教程开始
B11: 2658-2795 (138) - 教程继续 + 右相府叙事 + 浊流钻营 + 自责
B12: 2796-2918 (123) - UI_ 全部标签

That's only 12. Still not 15.

OK let me just force 15 batches by making them smaller:

B01: 2-121 (120)
B02: 122-241 (120)  
B03: 242-361 (120)
B04: 362-481 (120)
B05: 482-601 (120)
B06: 602-721 (120)
B07: 722-871 (150)
B08: 1596-1797 (202)
B09: 1798-1997 (200)
B10: 1998-2108 (111)
B11: 2177-2343 (167)
B12: 2558-2757 (200)
B13: 2758-2918 (161)

That's 13. I need to split B12 and B13.

B12: 2558-2687 (130) 
B13: 2688-2815 (128)
B14: 2816-2918 (103)

That's 14. One more split...

B10: 1998-2108 (111) → already small
B11: 2177-2343 (167) → split into B11: 2177-2259 (83) and B12: 2260-2343 (84)

That gives:

B01: 2-121 (120)
B02: 122-241 (120)
B03: 242-361 (120)
B04: 362-481 (120)
B05: 482-601 (120)
B06: 602-721 (120)
B07: 722-871 (150)
B08: 1596-1797 (202)
B09: 1798-1997 (200)
B10: 1998-2108 (111)
B11: 2177-2259 (83)
B12: 2260-2343 (84)
B13: 2558-2687 (130)
B14: 2688-2815 (128)
B15: 2816-2918 (103)

15 batches! Let me finalize this. Actually this is too much detail for the plan file. Let me just write the batches clearly and start creating the actual batch context files.

I think the most practical approach is to create the 15 batch files under `plans/i18n_batches/` directory, each containing the actual CSV lines to translate with their context headers. Then delegate them.

But wait - creating 15 files + delegating 15 tasks is going to take a lot of rounds. Let me think about how to be efficient.

Actually, the user said I should first define the context, then delegate to sub-agents. So my job is:
1. Create the batch context files (I can write them all at once ideally)
2. Delegate to sub-agents

Let me write one comprehensive plan file and then start generating batch files. I'll batch the writes as much as possible.

Actually, I think the most efficient approach for this architect mode is:
1. Update the plan file with the 15-batch structure ✓
2. Create each batch file with the full context and CSV lines
3. Use `new_task` to delegate each batch one at a time (or in parallel groups)

But `new_task` can only be called alone (not alongside other tools). So I'll need 15 separate turns to delegate.

Wait, let me re-read the instructions. "CRITICAL: This tool MUST be called alone. Do NOT call this tool alongside other tools in the same message turn."

So I need to do: write batch files first, then delegate one at a time.

Let me first update the plan file properly with the 15-batch structure, then create the batch files.

Actually, this is going to take forever. Let me think about a more practical approach.

The user said: "你首先定下这些翻译内容的上下文，然后切分他们成为 15 个左右的上下文交给子agent"

So: I define context + split into ~15 batches + delegate. Each batch gets a context header explaining what kind of text it is.

Let me write a single comprehensive batch file with all 15 contexts clearly separated, then use that as the source material for delegation. Each delegation will reference a specific batch number and line range from this master file.

Let me write the master batch definition file, then start delegating.<｜end▁of▁thinking｜>

<｜｜DSML｜｜tool_calls>
<｜｜DSML｜｜invoke name="write_to_file">
<｜｜DSML｜｜parameter name="content" string="true"># i18n English Translation — 15 批次上下文总表

## 源文件
`data/1_core_rules/translations/_dynamic_events.csv`（2918行，4列：keys,zh,en,ja）

## 全局铁律（写入每个子 Agent 的 prompt）
1. 只输出 CSV 第3列(en)的翻译结果，不修改 keys/zh/ja
2. 保留所有 `{param}`, `{@keyword}`, `[br]`, `[glitch]`, BBCode, `%d`, `%s`, `\n` 原样不动
3. 目标风格：自然流畅英文（非文言英译，非翻译腔），保持唐代氛围但不过度华丽
4. 输出格式：每行一个翻译，按输入顺序，如 `"translated text here"`
5. 若某行的 zh 列为空，en 列也留空

## 翻译范围总览
- ✅ 行 2–871（870行, CODE_ 系统/UI 字符串）
- ❌ 行 872–1595（EVT_ 叙事，跳过）
- ✅ 行 1596–2108（513行, 属性/特质/回落叙事/理念）
- ❌ 行 2109–2176（跳过）
- ✅ 行 2177–2343（167行, NPC社交/渐变文本）
- ❌ 行 2344–2557（跳过）
- ✅ 行 2558–2918（361行, 教程对话/UI标签）
- **合计翻译: 1911 行**

---

## 15 批次定义

### B01 — CODE_ 行动/地点/提示/管理（行 2–121, 120行）
**域**: 系统 UI · 行动元数据
**内容**: 行动名称（ACT_*_NAME）、行动描述（ACT_*_DESC）、角色名（CHAR_NAME_*）、地点标签（CODE_ACTION_*）、行动按钮提示（CODE_ACTION_BUTTON_*）、行动提示格式化器（CODE_ACTION_HINT_FORMATTER_*）、行动管理器消息（CODE_ACTION_MANAGER_*）
**风格**: 按钮标签需简洁；提示文本需自然友好；管理消息需清晰直接
**特殊**: 大量 `%d`, `%s`, `%%` 格式符；`⏱`, `⏳`, `📍`, `⚠` emoji 保留不动

### B02 — CODE_ 运算符/音频/BBcode/Buff/Linter（行 122–241, 120行）
**域**: 系统内部 · 运算符与数据流
**内容**: 引荐/把柄运算符（CODE_ADD_RANDOM_*）、情节推进占位（CODE_ADVANCE_PLOT_*）、情绪运算符（CODE_ALL_EMO_*, CODE_EMOTION_*）、抱负HUD/配置（CODE_AMBITION_*）、音频管理（CODE_AUDIO_*）、BBcode格式化（CODE_BBCODE_*）、Buff运算符（CODE_BUFF_*）、业务规则检查（CODE_BUSINESS_LINTER_*）、链执行器（CODE_CHAIN_EXECUTOR_*）、奉先事件创建（CODE_CREATE_FENGXIAN_*）
**风格**: 部分为开发者日志/调试信息，部分为玩家可见文本。玩家可见部分需自然；日志类保持清晰但可不翻译

### B03 — CODE_ CSV加载/数据库/事件UI/理念/人脉（行 242–421, 180行）
**域**: 系统 · 数据层 + UI 组件
**内容**: CSV云端加载器（CODE_CSV_CLOUD_LOADER_*）、数据库（CODE_DATABASE_*）、数据扫描（CODE_DATA_SCANNER_*）、决策卷轴（CODE_DECISION_SCROLL_*）、转储特质提示（CODE_DUMP_TRAIT_HINTS_*）、情绪运算符/需求（CODE_EMOTION_*）、枚举地点（CODE_ENUMERATES_*）、事件按钮（CODE_EVENT_BTN_*）、事件链（CODE_EVENT_CHAIN_*）、事件UI（CODE_EVENT_UI_*）、示例用法（CODE_EXAMPLE_USAGE_*）、阵营（CODE_FACTION_*）、聚焦对话（CODE_FOCUS_CHAT_*）、游戏数据面板（CODE_GAME_DATA_PANEL_*）、存档（CODE_GAME_SAVE_*）、测试诗事件（CODE_GENERATE_TEST_POEM_*）、Glitch预处理器（CODE_GLITCH_*）、理念（CODE_IDEA_*）、物品选择器（CODE_ITEM_PICKER_*）、左侧玩家面板（CODE_LEFT_PLAYER_PANEL_*）、把柄添加（CODE_LEVERAGE_ADD_*）

### B04 — CODE_ 联句/检查/主行动/修饰符/月末/叙事/笔记（行 422–561, 140行）
**域**: 系统 · 游戏逻辑 + 叙事组件
**内容**: 联句计分（CODE_LIANJU_SCORE_*）、链接检查（CODE_LINKER_LINTER_*）、代码检查控制台（CODE_LINTER_CONSOLE_*）、主动作按钮（CODE_MAIN_ACTION_BUTTON_*）、修饰符配置（CODE_MODIFIER_CONFIG_*）、月末结算（CODE_MONTH_END_SETTLEMENT_*）、多重需求（CODE_MULTIPLE_REQUIREMENETS_*）、叙事覆盖（CODE_NARRATIVE_OVERLAY_*）、笔记管理（CODE_NOTE_MANAGER_*）、NPC行动按钮（CODE_NPC_ACTION_BUTTON_*）、NPC阵营需求（CODE_NPC_FACTION_REQUIREMENT_*）、NPC阶层需求（CODE_NPC_TIER_REQUIREMENT_*）、选项按钮（CODE_OPTION_BTNS_*）、人物状态（CODE_PERSON_STATE_*）、选择器（CODE_PICKER_*）、人选（CODE_PICK_NPC_*）、玩家状态（CODE_PLAYER_STATE_*）、诗词创作器（CODE_POEM_CRAFTER_*）

### B05 — CODE_ 诗词/属性/需求/探针/结算/社交（行 562–701, 140行）
**域**: 系统 · 诗词系统 + 属性 + 运行时
**内容**: 诗词评分计算（CODE_POEM_CRAFTING_CALCULATOR_*）、诗词奖励（CODE_POEM_REWARD_OPERATOR_*）、诗词槽（CODE_POEM_SLOT_*）、属性状态（CODE_PROPERTY_*）、属性运算符（CODE_PROPERTY_OPERATOR_*）、属性需求（CODE_PROPERTY_REQUIREMENT_*）、中断推送（CODE_PUSH_INTERRUPT_*）、随机选择（CODE_RANDOM_PICK_*）、范围需求（CODE_RANGE_REQUIREMENT_*）、远程行动过滤（CODE_REMOTE_ACTION_*）、OR连接（CODE_REQ_JOIN_OR）、右侧信息面板（CODE_RIGHT_INFO_PANEL_*）、随机意象（CODE_ROLL_IMAGINARY_*）、运行时探针（CODE_RUNTIME_PROBE_*）、Schema检查（CODE_SCHEMA_LINTER_*）、结算纸带（CODE_SETTLEMENT_TAPE_*）、设置随机人物状态（CODE_SET_RANDOM_PERSON_STATE_*）、驻留地点（CODE_SET_STAY_PLACE_*）、粉碎效果（CODE_SHATTEREFFECT_*）、简单运算符预览（CODE_SIMPLE_OPERATOR_*）、平滑滚动（CODE_SMOOTH_SCROLL_*）、社交行动（CODE_SOCIAL_ACTION_*）、社交关系页（CODE_SOCIAL_CONNECTION_PAGE_*）

### B06 — CODE_ 风格/生存/时间/墓碑/特质/教程/URN（行 702–871, 170行）
**域**: 系统 · 时间 + UI 效果
**内容**: 风格策略（CODE_STYLE_STRATEGY_*）、子行动按钮（CODE_SUB_ACTION_*）、生存管理（CODE_SURVIVAL_MANAGER_*）、时间呼吸UI（CODE_TIME_BREATH_UI_*）、时间控制面板（CODE_TIME_CONTROL_PANEL_*）、时间运算符（CODE_TIME_OPERATOR_*）、时间服务（CODE_TIME_SERVICE_*年号/季节）、墓碑屏幕（CODE_TOMB_STONE_SCREEN_*）、特质展示（CODE_TRAIT_DEMONSTRATOR_*）、特质提示格式化（CODE_TRAIT_HINT_FORMATTER_*）、特质运算符（CODE_TRAIT_OPERATOR_*）、特质需求（CODE_TRAIT_REQUIREMENT_*）、教程控制器（CODE_TUTORIAL_CONTROLLER_*）、解锁社交节点（CODE_UNLOCK_SOCIAL_*）、URN工具（CODE_URN_*）、视觉测试（CODE_VTEST_*）

### B07 — 属性/特质/时代/抱负/属性渐变/回落后半（行 1596–1797, 202行）
**域**: 游戏数据 · 核心属性系统
**内容**: FEIHUALING/LIANJU 结果文本、PROPERTY_NAME_*（属性显示名：醉健兴名钱望才仕）、TRAIT_* 名称（冻伤/疲态/逢迎/狂客/钻营/右相门生/心智破损/中毒/重伤/崴脚/身强体壮/病入膏肓）、TRES_ 时代名称+描述（青年漫游/入世功名/旷达/回奉先）、抱负描述（致君尧舜上/衣锦还乡/陋室通天）、属性描述（城府/定力/才华/健/兴/势/钱/望）、属性渐变文本（gain/loss/perception各3-4级递进）
**风格**: 属性名用单个英文词；渐变文本需有递进感和文学性；抱负描述庄严有温度

### B08 — 回落叙事1：拜谒/长安漫步/登高/疾病/独酌/科举/回乡（行 1798–1997, 200行）
**域**: 游戏叙事 · 行动回落
**内容**: 拜谒回落（BAIYE_*_FALLBACK）、长安城市漫步叙事（CHANGAN_WALK_*）、登高回落（DENGGAO_*_FALLBACK）、疾病名称+描述（DISEASE_* 冻伤/肺痨/风寒/呕心沥血/失意/谵狂）、独酌叙事（DRUNKEN_*）、独酌回落（DUZHUO_*_FALLBACK）、科举结束叙事（END_OF_EXAM_*）、抱负开始（EVENT_AMBITION_START_*）、回乡叙事（EVENT_BACKHOME_START_*）
**风格**: 文学性自然英文，短小精悍（1-3句），唐代氛围

### B09 — 回落叙事2：科举/右相/官职/坊市/奉先/归家/宴席/理念（行 1998–2108, 111行）
**域**: 游戏叙事 · 关键事件链
**内容**: 坊市回落（FANGSHI_*_FALLBACK）、奉先村叙事（FENGXIAN_*）、奉召回落（FENG_ZHAO_*）、科举考试叙事（FOCUSED_CHAT_EXAM_*）、归家叙事（GAN_LU_*）、健康渐变文本（HEALTH_*）、宴席回落（HOLD_FEAST_*）、理念描述（IDEA_* 草莽落拓/沉郁顿挫/赤子白衣/清流风骨/五陵年少/折节干谒）、灵感渐变（INSPIRATION_*）

### B10 — NPC社交/渐变文本：联句/李白/右相/势/钱/濒死（行 2177–2259, 83行）
**域**: 游戏叙事 · NPC交互 + 属性渐变
**内容**: 暗巷回落（LEVERAGE_FARM_*）、联句叙事（LIANJU_*）、李白品酒（LIBAI_TASTE_*）、右相承诺叙事（LILINFU_PROMISE_*）、势渐变文本（MOMENTUM_* gain/loss/perception）、金钱渐变文本（MONEY_* gain/loss/perception）、濒死焚稿叙事（NEAR_DEATH_*）

### B11 — 笔记/NPC/诗词/声望/仕途（行 2260–2343, 84行）
**域**: 游戏叙事 · 教程笔记 + 诗词系统
**内容**: 笔记系统（NOTE_* 接受理念/坊市出游/解毒）、NPC文档名（NPC_DOC_*）、出城叙事（OUT_OF_THE_CITY_*）、宴席唱和（PARTY_SUBJECTIVE_*）、同乡来访（PLOT_PROMPT_*）、诗词模板（POEM_* 风雪夜归人/天成/望岳/韦左丞/郑谏义）、诗人名、声望渐变（PRESTIGE_*）、仕途渐变（PROGRESS_*）、狂态示例（PROVIDER_MANIA_*）

### B12 — 教程对话前半（行 2558–2687, 130行）
**域**: 教程 · 泰山新手引导
**内容**: 渔阳鼙鼓结局（THE_END_*）、时间渐变（TIME_*）、吐蕃（TUBO_*）、教程出游（TUT_CHUYOU_* 山间漫步/往上看/东麓/北岩/南溪/西峰）、教程延迟完成（TUT_DEFER_* 云开雾散/道士不悦/等待开始）、教程对话（TUT_DIALOGUE_* 山中偶遇/少年意气/志在四方/身强体壮/岁月如梭）、教程共饮（TUT_DRINK_TOGETHER_*）、教程最终揭示（TUT_FINAL_REVEAL_*）、教程告别（TUT_GOODBYE_*）
**风格**: mentor-student对话。道人：wise, calm, occasionally playful；杜甫：eager, youthful, respectful

### B13 — 教程对话后半 + 右相府/浊流叙事（行 2688–2795, 108行）
**域**: 教程 + 叙事碎片
**内容**: 教程理念提示（TUT_IDEA_HINT_*）、教程理念解锁（TUT_IDEA_UNLOCK_*）、教程交游（TUT_JIAOYOU_*）、教程望山（TUT_LOOKUP_MOUNTAIN_*）、教程遇道士（TUT_MEET_TAOIST_*）、教程迷雾（TUT_MOVE_AWAY_*）、教程无灵感（TUT_NO_INSPIRATION_*）、教程评诗（TUT_POEM_REVIEW_*）、教程驻留（TUT_RESIDE_*）、教程回道人（TUT_RETURN_TAOIST_*）、教程道人名、教程天地苍茫（TUT_VAST_WORLD_*）、升官（UPDATE_TO_RANK8_*）、右相府叙事（YOUXIANGFU_*）、郑虔诗歌交换（ZHENGQIAN_POEM_EXCHANGE_*）、浊流钻营叙事（ZHUOLIU_ZUANYING_*）

### B14 — 浊流/自责叙事 + UI标签前半（行 2758–2885, 128行）
**域**: 叙事碎片 + UI界面
**内容**: 浊流钻营代笔/情报/贫困/对账/冬至叙事（ZHUOLIU_ZUANYING_*）、自责叙事（ZIZE_* 冻尸/当玉/家书/故友/酒保/青年书生）、UI行动按钮（UI_ACTION_BUTTON_*）、UI抱负HUD（UI_AMBITION_HUD_*）、UI竹简（UI_BAMBOO_SLIP_*）、UI确认对话框（UI_CONFIRMATION_DIALOG_*）、UI存档面板（UI_GAME_DATA_PANEL_*）、UI理念按钮+页面（UI_IDEA_BTN_*, UI_IDEA_PAGE_*）、UI物品选择（UI_ITEM_PICKER_*）、UI左侧玩家面板（UI_LEFT_PLAYER_PANEL_*）、UI行动按钮（UI_MAIN_ACTION_BUTTON_*, UI_MAIN_PAGE_*）、UI叙事覆盖（UI_NARRATIVE_OVERLAY_*）、UI笔记页面（UI_NOTE_PAGE_*）

### B15 — UI标签后半（行 2816–2918, 103行）
**域**: UI 界面
**内容**: UI NPC行动按钮（UI_NPC_ACTION_BUTTON_*）、UI覆盖行动按钮（UI_OVERRIDE_ACTION_BUTTON_*）、UI选择器项（UI_PICKER_ITEM_*）、UI选择器纸带（UI_PICKER_TAPE_*）、UI诗词创作器（UI_POEM_CRAFTER_*）、UI诗词需求（UI_POEM_DEMAND_*）、UI诗词槽（UI_POEM_SLOT_*）、UI诗词开始（UI_POEM_START_*）、UI属性标签（UI_PROP_LABEL_*）、UI右侧信息面板（UI_RIGHT_INFO_PANEL_*）、UI小行动按钮（UI_SMALLER_ACTION_BUTTON_*）、UI小属性标签（UI_SMALLER_PROP_LABEL_*）、UI社交页（UI_SOCIAL_CONNECTION_PAGE_*）、UI系统菜单（UI_SYSTEM_MENU_*）、UI时间控制（UI_TIME_CONTROL_PANEL_*）、UI墓碑（UI_TOMB_STONE_SCREEN_*）、UI特质展示（UI_TRAIT_DEMONSTRATOR_*）、UI养疴（UI_YANG_KE_*）
