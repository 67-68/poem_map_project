# Action System (行动系统)

## 时间消耗系统（day_consumed）

### 设计意图

- Action 不再通过 `action_results` 嵌入 `TimeOperator` 来表达时间消耗，改用独立字段 `day_consumed: float`。
- 子行动若不填 `day_consumed`（=0），自动继承父行动的 `day_consumed`。若填了正数值，则覆盖父行动。
- 时间消耗计算 = `base_day + sum(trait.time_penalty)`，trait 通过 `PlayerState.get_active_time_penalties()` 统一聚合。
- `sprained_ankle`（崴脚）的 `time_penalty=1` 在 `data/1_core_rules/traits/_traits.csv` 中配置，不再有 if 硬编码判断。

### 相关文件

- `core/model/action.gd` — `day_consumed` 字段
- `core/model/trait.gd` — `time_penalty` 字段
- `core/player_state.gd` — `get_active_time_penalties()`
- `core/action_manager.gd` — `get_action_day_cost()` / `effective_day_consumed()` / `format_time_detail()`
- `core/action_hint_builder.gd` — 时间行展示（time span / 精确天数 + 时间不足提示）
- `ui/action_button.gd` — 执行时调用 `get_action_day_cost()` 扣除时间
- `parser/dsl_parser.gd` — `parse_trait()` 解析 `time_penalty` 列

### 各行动 day_consumed 映射

| 父行动 | day_consumed | 子行动 | day_consumed |
|--------|-------------|--------|-------------|
| bai_ye | 3 | (无) | — |
| deng_gao | 5 | qujiangchi / leyouyuan / shaolingyuan | 0（继承5）|
| du_zhuo | 1 | heyaojiu | **2**（父1+额外1）|
| | | xiaozhuo / fangjian_tingwen | 0（继承1）|
| fang_shi | 4 | 全部 5 个子行动 | 0（继承4）|
| jiao_you | 2 | tongyou_changan / recite_poem | 0（继承2）|
| feng_zhao | 0 | — | — |

### ActionHintBuilder 时间展示

- **主按钮 hover**（`build_action_hint`）：
  - 无子行动：`⏱ 耗时 3天（+1, 由于 崴脚）`
  - 有子行动（span）：`⏱ 耗时 1天 ～ 2天`（展示子行动 effective_day 的 min/max）
- **子行动 picker hover**（`build_sub_action_preview`）：
  - `⏱ 耗时 2天` — 时间充足时
  - `[color=#cc6666]⏱ 耗时 2天 — 时间不足（剩余1天）[/color]` — 时间不够时

### Picker 双轨制拦截（灰化 vs 隐藏）

子行动 Picker 构建时（[`ui/action_button.gd`](ui/action_button.gd) `_on_button_pressed`），对每个 sub-action 执行两阶段检查：

#### Phase 1: HIDE（完全隐藏）

以下类型的 `aciton_requirements` 不满足时，该子行动**完全不出现在 Picker 中**（无法当场改善的条件）：

| Requirement / Operator | 判定依据 |
|------------------------|---------|
| `TraitRequirement` | 玩家是否有某个 trait（二态，无法当场获得） |
| `PoemRequirement` | 玩家是否有符合条件的 Poem trait |
| `FlagRequirement` | 内部叙事锁标志位 |
| `NarrativeLockRequirement` | 叙事级硬锁（永远返回 false） |
| `ConsumeRandomLeverageOperator` | `is_viable()` — 是否有任何把柄可用 |
| `PoemRewardOperator` | `is_viable()` — 是否有任何 Poem trait 可用 |

#### Phase 2: GRAY（灰化锁定）

以下条件不满足时，子行动**保留在 Picker 中但灰化**（可见但不可选择，点击时弹出 toast 告知原因）：

| 条件类型 | 灰化原因示例 |
|----------|------------|
| `PropertyRequirement` | 「条件不满足：需要「50(富裕)」」 |
| `EmotionRequirement` | 「条件不满足：需要情绪: 狂傲(≥30)」 |
| `PropRangeRequirement` | 「条件不满足：需要「200(小康)」」 |
| 时间消耗 | 「条件不满足：时间不足（剩余2天，需要5天）」 |

#### 灰化视觉效果

- `SubActionButton` 通过 entity meta（`_is_locked` / `_locked_reason`）读取锁定状态，调用基类 `SceneActionPanel.set_locked(reason)` 灰化
- 灰化态：`modulate = Color(0.4, 0.4, 0.4, 0.6)`，hover 叙事层前置 `🔒 {原因}`
- 点击灰化卡片时通过 [`SubActionButton._on_clicked()`](ui/sub_action_button.gd) 拦截，发射 `EventBus.request_toast` 告知原因，不写入 VolatileState
- 锁定原因由 [`MainActionButton`](ui/main_action_button.gd) 在构建 picker 数据时注入 entity meta（`_is_locked` / `_locked_reason`）
- **右侧 NpcActionButton 锁定态展示**：点击锁定按钮时，[`PickerTapeAttachment._on_sub_button_toggled()`](ui/picker_tape_attachment.gd) 调用 [`NpcActionButton.set_action_data_for_locked()`](ui/npc_action_button.gd)，将右侧按钮标题改为 🔒 锁因文案，整体灰化，清空四模块 label
- **初始化跳过锁定**：[`PickerTapeAttachment._get_first_visible_button()`](ui/picker_tape_attachment.gd) 只返回 `visible && !_is_locked` 的按钮，避免初始化时选中锁定的子行动
- **锁定态点击顺序**：[`NpcActionButton._on_default_pressed()`](ui/npc_action_button.gd) 锁定检查前置到 empty UUID 检查之前，确保即使 VolatileState 为空，点击右侧按钮也会 toast 锁因

#### 主按钮拦截

- 主按钮仍通过 `check_action_validity()` 返回无效时灰化（最小天数也不够时拦截）。
- 主按钮灰化由 `SceneActionPanel.set_locked()` + `_is_locked` 控制，与 PickerItem 的机制独立但视觉一致。

### Operator 静态 Viability 检查

| Operator | 方法 | 判定逻辑 |
|----------|------|---------|
| `ConsumeRandomLeverageOperator` | `static func is_viable() -> bool` | 遍历所有 `ENUMS.RELATION_TARGET`，调用 `RelationFlagManager.has_leverage()` |
| `PoemRewardOperator` | `static func is_viable() -> bool` | 遍历 `PlayerState.get_traits()`，检查是否存在 `Poem` 实例 |

这两个方法在 `operate()` 中也复用，作为防御层：即使 requirement 漏配，operator 执行时也不会报错。

### 相关文件

- [`picker_item.gd`](picker_item.gd) — 灰化锁定 UI 机制（`_is_locked` / `set_locked` / `set_unlocked` / toast 拦截）
- [`ui/action_button.gd`](ui/action_button.gd) — 双轨制构建逻辑（Phase 1 HIDE / Phase 2 GRAY）
- [`core/operators/consume_random_leverage_operator.gd`](core/operators/consume_random_leverage_operator.gd) — `static is_viable()`
- [`core/operators/poem_reward_operator.gd`](core/operators/poem_reward_operator.gd) — `static is_viable()`

---

## 坊市子行动 Archetype（搬砖 / 以身试药 / 卖字 / 风骨卖字）

这四个行动是 `action_fangshi`（坊市）的 sub_actions，定义在 [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) 中。

### 设计意图

- **子行动 vs 独立行动**：子行动不是主行动（如拜谒/登高）的平级实体，而是挂在坊市 Action 的 `sub_actions` 列表下的子 Action。玩家先选坊市 → 弹出 Picker → 选具体子行动。
- **成功/失败对子模式（方案 B）**：以身试药、卖字、风骨卖字各拆分为 `xxx_success` / `xxx_failure` 两个独立 archetype，parent 均为空，不继承任何已有 archetype。搬砖为确定性行动，只有成功 archetype。
- **概率不进入 archetype**：成功/失败的概率由 Action 运行时字段 `possibility` 控制，archetype 仅定义成本和结果 DSL。`possibility` 需要在生成 .tres 文件后在 Godot 编辑器中手动配置。

### 数值映射（来自 named_amounts.json）

| Archetype | 消耗 | 成功收益 | 失败收益 |
|-----------|------|----------|----------|
| banzhuan | m_health_cost(-30) | l_money_gain(50) | 无（确定性） |
| shiyao_success | s_health_cost(-15) | xl_money_gain(80) | — |
| shiyao_failure | m_health_cost(-30) | — | poisoned + m_talent_gain(5) |
| maizi_success | s_health_cost(-15) + m_fame_cost(-5) | l_money_gain(50) | — |
| maizi_failure | s_health_cost(-15) | — | l_money_gain(50) + m_fame_cost(-5) |
| fgmaizi_success | s_health_cost(-15) | l_money_gain(50) + m_fame_gain(5) | — |
| fgmaizi_failure | s_health_cost(-15) | — | s_money_gain(15) + s_fame_gain(2) |

### 约束

- `poisoned` trait 已在 `model/enumerates.gd` TRAITS 枚举中注册，并在 `data/1_core_rules/traits/_traits.csv` 中配置（prop_sub health 15/旬，2旬到期自动移除）。
- 所有新 archetype 的 `era: ""`（无时代限制）、`universal_requirement: ""`（成本在 result 中以 prop_sub 表达）。

## 交游子行动：宣读诗词

挂载在 `action_jiaoyou`（交游）下，使用 PoemRewardOperator（fame 模式）弹出诗词选择，以诗换名声。

### 设计意图

- 成本 `prop_sub(literary_fame, m_fame_cost=-5)` 放在 archetype `universal_result`，所有匹配事件 + fallback 统一引用同一 archetype 确保路径完整。
- `action_results` 仅放 PoemRewardOperator（异步 picker），不重复扣成本。
- `aciton_requirements` 挂 `PoemRequirement(accepted_poem_types=[])`：无诗词时从 Picker 中隐藏。

| Archetype | 消耗 | 收益（由 PoemRewardOperator 产出）|
|-----------|------|------|
| recite_poem_success | literary_fame -5（m_fame_cost）| literary_fame（L1→少量 L2→中等 L3→大量，概率升级）|

### 相关文件
- `data/3_actions_pool/actions/jiao_you/jiaoyou_recite_poem.tres` — sub-action 定义
- `data/1_core_rules/events/fallback/jiaoyou_recite_poem_fallback.tres` — fallback「席间诵读」
- `data/1_core_rules/events/fallback/jiaoyou_recite_poem_failed_fallback.tres` — 失败 fallback（占位，100% 不触发）

## 坊市子行动：卖诗

挂载在 `action_fangshi`（坊市）下，使用 PoemRewardOperator（money 模式）弹出诗词选择，将诗卖与平康坊歌女传唱换钱。

### 设计意图

- 与宣读诗词同模式：成本在 archetype `universal_result`，收益由 PoemRewardOperator 产出。
- **money 模式升一级**：L1→中等 L2→大量 L3→巨额（而非基础版的 L1→少量 L2→中等 L3→大量）。
- 语义修正：卖诗是卖给平康坊，让歌女传唱，非随便卖字。

| Archetype | 消耗 | 收益 |
|-----------|------|------|
| sell_poem_success | literary_fame -5（m_fame_cost）| money（L1→中等 L2→大量 L3→巨额，概率升级）|

### 相关文件
- `data/3_actions_pool/actions/fang_shi/fangshi_sell_poem.tres` — sub-action 定义
- `data/1_core_rules/events/fallback/fangshi_sell_poem_fallback.tres` — fallback「歌女传唱」
- `data/1_core_rules/events/fallback/fangshi_sell_poem_failed_fallback.tres` — 失败 fallback（占位）
- `core/operators/poem_reward_operator.gd` — V10.1 新增 money 升一级、extra_large SIZE_DISPLAY、describe_preview()

## 拜谒子行动（要挟 / 携诗拜谒 / 广发行卷 / 普通拜谒 / 入幕）

这五个子行动挂载在 `action_baiye`（拜谒）下，定义在 [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) 中。

### 设计意图

- 与坊市/交游子行动同模式：先选拜谒 → 弹出 Picker → 选具体拜谒方式。
- **要挟**：利用 ConsumeRandomLeverageOperator 从所有 RELATION_TARGET 中随机消费一个把柄，获得大钱。**60% 成功率**（`ms_success_rate`），40% 失败时把柄照常消耗并获重伤 trait。
- **携诗拜谒**：复用 PoemRewardOperator（baiye 模式），选诗换 progress。额外金钱成本放 archetype `universal_result`。
- **广发行卷**：消耗巨额钱，解锁社交节点（UnlockSocialNodePlaceholderOperator 占位）。
- **普通拜谒**：消耗小钱 + 1天，随机人物好感 +10（AdvancePlotPlaceholderOperator）。
- **入幕**：零消耗、零产出、零天数的纯叙事行动。投刺谒见，入其幕府随侍左右。fallback 事件提示玩家「无处入幕」。作为入幕系统的入口占位符存在。

### 数值映射（来自 named_amounts.json）

| Archetype | 状态 | 消耗 | 收益 |
|-----------|------|------|------|
| baiye_threaten_success | 成功(60%) | 随机一个把柄 | l_money_gain(+50) → ConsumeRandomLeverageOperator |
| baiye_threaten_failure | 失败(40%) | 随机一个把柄 | severe_injury trait |
| baiye_poem_visit_success | 成功(100%) | m_money_cost(-30) | progress → PoemRewardOperator(baiye) |
| baiye_mass_distribution_success | 成功(100%) | xxl_money_cost(-150) | 解锁社交节点（占位） |
| baiye_normal_success | 成功(100%) | s_money_cost(-15) + 1天 | 随机人物好感 +10 |
| baiye_touzeng_success | 成功(100%) | — | — |

### 重伤 Trait（severe_injury）效果

| 效果 | 机制 |
|------|------|
| 每旬 health -15 | CSV `trait_effect_operations: prop_sub(name=health; val=15)` |
| 所有行动 AP +1 | CSV `time_penalty: 1`（由 get_active_time_penalties 聚合） |
| 远游/登高额外 +5 AP | action_manager.gd 硬编码 |
| 3 旬自动移除 | survival_manager.gd SEVERE_INJURY_DURATION_XUN=3 |

### 相关文件
- `data/3_actions_pool/actions/bai_ye/baiye_threaten.tres` — sub-action「要挟」
- `data/3_actions_pool/actions/bai_ye/baiye_poem_visit.tres` — sub-action「携诗拜谒」
- `data/3_actions_pool/actions/bai_ye/baiye_mass_distribution.tres` — sub-action「广发行卷」
- `data/3_actions_pool/actions/bai_ye/baiye_normal.tres` — sub-action「普通拜谒」
- `data/1_core_rules/events/fallback/baiye_threaten_fallback.tres` — fallback「密信要挟」
- `data/1_core_rules/events/fallback/baiye_poem_visit_fallback.tres` — fallback「携诗叩门」
- `data/1_core_rules/events/fallback/baiye_mass_distribution_fallback.tres` — fallback「泥牛入海」
- `data/1_core_rules/events/fallback/baiye_normal_fallback.tres` — fallback「无处投刺」
- `data/3_actions_pool/actions/bai_ye/baiye_touzeng.tres` — sub-action「入幕」
- `data/1_core_rules/archetypes/baiye_touzeng_success.tres` — archetype「入幕成功」（空）
- `data/1_core_rules/events/fallback/baiye_touzeng_fallback.tres` — fallback「无处入幕」
- `core/operators/consume_random_leverage_operator.gd` — 消耗随机把柄
- `core/operators/advance_plot_placeholder_operator.gd` — 推进剧情（占位）
- `core/operators/unlock_social_node_placeholder_operator.gd` — 解锁社交节点（占位）

## 登高子行动 Archetype（曲江池 / 乐游原 / 少陵原）

这三个子行动挂载在 `action_denggao`（登高/远游）下，定义在 [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) 中。

### 设计意图

- 与坊市子行动同模式：先选登高 → 弹出 Picker → 选具体登高地点。
- 曲江池无失败 variant（确定性，对应 l_success_rate=100%）。
- 所有 archetype 的 `parent: ""`，与 denggao 父 archetype 及其他任何 archetype 无继承关系。
- 概率仅标注在 `possibility` 字段，运行时由 Action 系统处理，archetype 不做路由。

### 数值映射

| Archetype | 成功收益 | 失败收益 |
|-----------|----------|----------|
| qujiangchi_success | m_health_recovery(+30) | 无（确定性） |
| leyouyuan_success | l_health_recovery(+50) | — |
| leyouyuan_failure | — | health+15 + sprained_ankle trait |
| shaolingyuan_success | m_health_recovery(+30) + m_talent_gain(+5) | — |
| shaolingyuan_failure | — | s_talent_cost(-2) |

### 约束

- `sprained_ankle` trait 已在 `model/enumerates.gd` TRAITS 枚举中注册，并在 `data/1_core_rules/traits/_traits.csv` 中配置（`time_penalty=1`，每次行动额外多耗 1 天，2 旬到期自动移除）。
- 所有新 archetype 的 `era: ""`（无时代限制）、`universal_requirement: ""`（成本在 archetype universal_result 中以 prop_sub 表达）。

## 独酌子行动（喝药酒 / 小酌一口）

这两个子行动挂载在 `data/3_actions_pool/actions/du_zhuo.tres` 下，定义在 `data/3_actions_pool/actions/du_zhuo/` 目录中。

### 设计意图

- 与坊市/登高子行动同模式：先选「闲居」→ 弹出 Picker → 选喝药酒或小酌一口。
- 均为确定性行动（`l_success_rate=100%`），不拆 success/failure variant。
- 属性变化通过 archetype DSL 定义在 `tools/data/event_archetypes.json` 中，由 `RandomEvent.init()` 在事件进入时注入每个 option 的 `choice_result`。
- 时间消耗通过 Action `day_consumed` 字段统一控制：父行动 1 天，喝药酒 2 天（父1+额外1），小酌/坊间听闻继承父行动 1 天。

### Archetype DSL

| Archetype | universal_result |
|-----------|-----------------|
| `heyaojiu_success` | `prop_sub(name=money; val=xs_money_cost)|trait_remove(name=poisoned)|prop_add(name=health; val=xs_health_gain)` |
| `xiaozhuo_success` | `prop_sub(name=money; val=xs_money_cost)|prop_add(name=health; val=xs_health_gain)` |

### 数值映射（来自 named_amounts.json）

| 子行动 | day_consumed | 金钱 | 健康 |
|--------|-------------|------|------|
| 喝药酒 | 2（父1+额外1）| `s_money_cost` = -15 | `xs_health_gain` = +5 |
| 小酌一口 | 0（继承父1）| `xs_money_cost` = -5 | `xs_health_gain` = +5 |

### 约束

- `poisoned` trait 已在 `model/enumerates.gd` TRAITS 枚举中注册为 `POISONED`（index 189）。
- 新增枚举 `ACTION_DUZHUO_HEYAOJIU`（index 44）和 `ACTION_DUZHUO_XIAOZHUO`（index 45）。
- `PropertyOperator.ranked_value` 新增 `extra_small` 选项（用于非 DSL 场景）。
- Fallback 事件 `archetype_id` 指向 `heyaojiu_success` / `xiaozhuo_success`。
- `micro_dsl_parser.gd` 中 `time_add(day=N)` DSL 指令保留用于事件渲染路径（非 action 直接触发）。

## 相关文件
- `core/model/action.gd` — Action 数据模型（含 sub_actions / possibility / failed_result / day_consumed 字段）
- `core/model/scene_action.gd` — SceneAction（含 main_tag）
- `ui/action_button.gd` — 行动按钮 UI 与点击处理 + 时间消耗
- `core/model/action_tag_filter.gd` — 事件标签过滤器
- `core/event_manager.gd` — 事件扫描与抽奖
- `characters/narrative_overlay.gd` — 叙事纸带渲染（含 Picker 呈堂）+ ActionPanel 互斥可见性切换
- `ui/action_panel_manager.gd` — 🆕 行动面板管理器（替代 SceneActionScroll）：按钮构建/Era过滤/锁状态同步
- `characters/narrative_director.gd` — 叙事状态机（管理 picker 栈）

## 设计意图

### Sub-Action 系统
- Action 可携带 `sub_actions: Array[String]`（Action UUID 字符串数组，运行时通过 `Database.get_action(uuid)` 解析为 Action 资源）
- 点击带 sub_actions 的 Action 时，先弹出 Picker 让玩家选择子行动
- 选中后：执行父 Action 的 operators → 以 AND 模式进行事件扫描
- **事件匹配使用子 action 的 tags 和 fallback**，而非父 action：
  - 子 action 是 SceneAction：用其 `main_tag` 作为事件桶 key，`action_tags` 进 `current_action_tags`
  - 子 action 是普通 Action：`main_tag` 传空串（全量桶），所有 `action_tags` 进 `current_action_tags`，靠 ActionTagFilter AND 模式做多 tag 交集过滤
  - `fallback_event_uuid` 始终取自子 action
- Picker 在 operators 之前弹出，sub-action 选择影响后续事件匹配

### Possibility 抽奖系统
- Action（含父 action 和 sub-action）可携带 `possibility: String`（archetype，来自 `tools/data/named_amounts.json`，默认 `"l_success_rate"`=100%）
- **父 action 抽奖**：点击 Action 时，在 sub-action Picker 弹出 **之前** 进行抽奖。`randi() % 101 > get_possibility_int()` 时执行 `failed_result.operate()` 并 return
- **Sub-action 抽奖**：玩家从 Picker 中选择子行动后，在 [`_on_sub_action_picked()`](ui/action_button.gd) 中对子 action 独立投骰：
  - `get_possibility_int() >= 100`：跳过投骰，确定性成功
  - `roll > threshold`：执行 `sub_action.failed_result.operate()`（含 PushEventOperator 推送失败事件），设置 `_sub_failed = true`
  - `roll <= threshold`：执行 `sub_action.action_results`（如存在）
  - 失败时 **跳过** `EventManager.scan_events()`，因为 `failed_result` 中的 PushEventOperator 已推送事件
  - 成功时正常调用 `scan_events()`，匹配不到事件时触发 sub-action 的 `fallback_event_uuid`
- `generator > possibility`：有 active generator 时跳过抽奖
- 可用 archetype：`s_success_rate=50` / `m_success_rate=80` / `l_success_rate=100`

### failed_result
- `failed_result: ChoiceResult` — 抽奖未中签时的兜底结果
- 默认值为空 ChoiceResult（无操作）
- 可通过编辑器配置为 PushEventOperator 等，用于触发失败叙事

### Fallback 事件（scan_events 池空时的兜底叙事）
- `fallback_event_uuid` 指向 `data/1_core_rules/events/fallback/` 下的事件 — 当事件扫描池空时触发
- **语义约定**：fallback 事件代表"一次正常但无特殊事件发生的行动"，**不是**"失败/无人问津"。应使用 success archetype（有收益），叙事基调为平和/成功
- Sub-action 成功路径（PASS）调用 `scan_events()`，若池空则 fallback 承担叙事
- Sub-action 失败路径（FAIL）由 `failed_result.operate()` 中的 PushEventOperator 直接推送 `_failed_fallback` 事件，不经过 scan_events
- 当前 fallback 事件及对应 archetype：

| Fallback UUID | Archetype | 叙事基调 |
|---|---|---|
| `fangshi_maizi_fallback` | `maizi_success` | 正常卖字交易 |
| `fangshi_shiyao_fallback` | `shiyao_success` | 正常试药换钱 |
| `fangshi_fgmaizi_fallback` | `fgmaizi_success` | 正常风骨卖字 |
| `fangshi_banzhuan_fallback` | `banzhuan_success` | 正常搬砖（确定性） |
| `denggao_qujiangchi_fallback` | `qujiangchi_success` | 正常登曲江池 |
| `denggao_leyouyuan_fallback` | `leyouyuan_success` | 正常登乐游原 |
| `denggao_shaolingyuan_fallback` | `shaolingyuan_success` | 正常登少陵原 |
| `duzhuo_heyaojiu_fallback` | — | 正常喝药酒祛毒 |
| `duzhuo_xiaozhuo_fallback` | — | 正常小酌怡情 |
| `jiaoyou_recite_poem_fallback` | `recite_poem_success` | 席间诵读，以诗换名 |
| `fangshi_sell_poem_fallback` | `sell_poem_success` | 歌女传唱，以诗换钱 |
| `baiye_threaten_fallback` | `baiye_threaten_success` | 密信要挟，换得银钱 |
| `baiye_poem_visit_fallback` | `baiye_poem_visit_success` | 携诗叩门，主家展卷 |
| `baiye_mass_distribution_fallback` | `baiye_mass_distribution_success` | 行卷如泥牛入海 |
| `baiye_normal_fallback` | `baiye_normal_success` | 无处投刺，坐等一日 |

- 对应的失败叙事在 `_failed_fallback` 变体中（如 `fangshi_maizi_failed_fallback`），由 possibility 失败路径的 PushEventOperator 直接推送

### Tag 匹配模式
- 默认 OR 模式：`current_action_tags` 中任一 tag 命中事件 `target_tags` 即通过
- Sub-action 触发 AND 模式（`context['tag_match_mode'] = 'all'`）：所有 `current_action_tags` 必须全部在事件 `target_tags` 中

### Sub-Action Picker Tooltip 预览
- 当玩家 hover 子行动 Picker 项时，tooltip 向量层顶部显示预览文本（由 `action_button._build_sub_action_preview()` 构建）：
  - `概率: {n}%成功，`
  - `⏱ 耗时 {n}天` — 时间充足 / `[color=#cc6666]⏱ 耗时 {n}天 — 时间不足[/color]`
  - `[成功效果]`: 遍历 `action_results` 的 `describe_preview()`，空则 fallback「成败未卜…」
  - `[失败效果]`: 遍历 `failed_result.operators` 的 `describe_preview()`，空则 fallback「后果难料…」
- 预览文本通过 `entity.set_meta("sub_action_preview", ...)` 从 `action_button` 传给 `picker_item`
- `picker_item._register_hover_popup()` 将预览前置插入 `vector_lines`，后接 archetype operators 描述

## HoverDisplayFlow — 统一 Hover 显示架构（v3.0）

`ui/hover_popup_manager.gd` 不再使用浮动 Popup，改用三种可插拔 FlowType 委托 `NarrativeOverlay` 面板呈现 hover 信息。

### FlowType 枚举

| FlowType | 触发场景 | Enter 动画 | Exit 动画 | 承载 UI |
|----------|---------|-----------|----------|---------|
| `SLIDE_FROM_RIGHT` | Action 按钮 hover | `TapeVisualizer.play_slide_in_from_right(0.3s)` → 整个 NarrativeOverlay 从右侧滑入 | 1s 后或行动开始时 `play_slide_to_right(0.3s)` 滑出 | `NarrativeOverlay.hover_container/hover_label` |
| `BELOW_OVERLAY` | Picker/EventBtn hover | `hover_container` 显形显示 | 0.15s 后或选项选择后 `hide_hover_text()` | `NarrativeOverlay.hover_container/hover_label` |
| `POPUP_LEGACY` | Ambition HUD | 原有浮动 popup（CanvasLayer 四象限定位） | `popup.visible = false` | `CanvasLayer + Control` |

### 架构

- `hover_popup_manager.gd`: `HoverBinding` 状态机不变，`SHOWING/IDLE` entry/exit 委托 `HoverDisplayDelegate` 子类
- 委托子类：`SlideFromRightDelegate` / `BelowOverlayDelegate` / `PopupLegacyDelegate`
- `narrative_overlay.gd`: 暴露 `show_hover_text(narrative, vector)` / `hide_hover_text()` 接口，操作 `HoverContainer`（tscn 内置 `HSeparator` + `Label`）
- `tape_visualizer.gd`: `play_slide_in_from_right(duration)` / `play_slide_to_right(duration)`
- 竞态：`SceneActionPanel._on_button_pressed()` / `NarrativeOverlay._on_event_ready_to_play()` / `PickerTapeAttachment._on_card_clicked()` 均调用 `HoverPopupManager.dismiss_all()`

### 消费方注册方式

```gdscript
# SLIDE_FROM_RIGHT — action hover
HoverPopupManager.register(self, {"narrative": hint["narrative"], "vector": hint["vector"]},
    0.2, 1.0, HoverPopupManager.FlowType.SLIDE_FROM_RIGHT)

# BELOW_OVERLAY — picker/event hover
HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text},
    0.2, 0.15, HoverPopupManager.FlowType.BELOW_OVERLAY)

# POPUP_LEGACY — ambition hover (行为不变)
HoverPopupManager.register(_ambition_btn, ambition_hud, 0.2, 0.15,
    HoverPopupManager.FlowType.POPUP_LEGACY)
```

## ActionHintBuilder — 行动提示文本统一构建器

静态工具类 `core/action_hint_builder.gd`，将所有 Action hover 提示文本的格式化逻辑集中到一处，消除重复。

### 设计意图

- **单一真相源**：所有 `describe_preview()` 遍历、operator 格式化、叙事层/向量层聚合、时间消耗行均由此类负责，UI 控件（action_button、picker_item、event_btn）仅调用接口，不自行拼写文本。
- **两套接口覆盖两种场景**：主行动 hover（`build_action_hint` 输入一个 Action）和子行动 picker hover（`build_sub_action_preview` 输入 success/fail archetype operators + parent_day_consumed）。
- **统一 hover 显示管道**：所有 hover 文本（锁定原因、success_hint、operator 预览、时间行）均通过 HoverPopupManager + NarrativeOverlay HoverContainer 呈现，不再使用原生 tooltip_text 或独立浮动 popup。
- **动态刷新**：`set_locked`/`set_unlocked` 触发 HoverPopup 注销+重建，hover 时永远拿到最新状态。

### 接口

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| `build_action_hint(action, is_locked)` | Action + 锁定标志 | `{narrative, vector}` | 主行动按钮 hover popup（含 time span） |
| `build_operator_preview(operators)` | Array[BaseOperator] | Array[String] | 单列 operator 转 "• {desc}" 行 |
| `build_choice_result_preview(result)` | ChoiceResult | Array[String] | ChoiceResult 解包后委托 build_operator_preview |
| `build_sub_action_preview(action, success_ops, fail_ops, parent_day_consumed)` | Action + archetype operators + 父 day_consumed | String | 子行动 picker tooltip（含时间行 + 时间不足提示） |

### 文件

- `core/action_hint_builder.gd` — 静态构建器（本模块）
- `ui/action_button.gd` — 消费方：主按钮 hover（SLIDE_FROM_RIGHT）、sub-action picker 预览
- `picker_item.gd` — 消费方：picker 项 hover（BELOW_OVERLAY）
- `characters/event_btn.gd` — 消费方：事件选项 hover（BELOW_OVERLAY）
- `ui/hover_popup_manager.gd` — 统一显示管道（v3.0 FlowType 架构）
- `characters/narrative_overlay.gd` — hover 文本渲染（HoverContainer/HoverLabel）
- `characters/tape_visualizer.gd` — 右侧滑入/滑出动画

## 重复行动疲惫系统（Repeated Action Fatigue）

### 设计意图

连续两次执行同一类型的行动时，第二次行动会受到 20% 的效益惩罚：
- 获得属性（val > 0）：减少 20%（×0.8）
- 消耗属性（val < 0）：增加 20%（×1.2）

这促使玩家在重复行动与切换行动之间做策略抉择。

### 状态模型

- `PlayerState.last_action_tags: Array[String]` — 持久状态，存上一次执行完成的 action 的识别 tag 集合
- `PlayerState._is_repeated_action: bool` — 瞬态快照，仅在当前 action 的 operators 执行期间有效
- `PlayerState.is_action_repeated(tags) -> bool` — 纯函数，检查给定 tags 是否与 last_action_tags 有交集

### 识别 Tag 匹配规则

- SceneAction：识别 tags = [main_tag] + action_tags
- 普通 Action：识别 tags = action_tags
- 交集匹配：当前 tags 集合 ∩ last_action_tags 非空 ⇒ 重复行动

### 生命周期

1. **Hover Preview 阶段**：`ActionHintBuilder` 读取 `last_action_tags`，临时设置 `_is_repeated_action` 调用 `describe_preview()`，展示调整后数值如「金钱 ↑↑↑：+40（原+50，重复行动-20%）」
2. **执行前**：`action_button._on_button_pressed()` / `_on_sub_action_picked()` 调用 `is_action_repeated()` 设置瞬态 `_is_repeated_action`
3. **执行中**：`PropertyOperator.operate()` 读 `_is_repeated_action` 决定是否乘倍率
4. **执行后**：更新 `last_action_tags` 为当前 action 的识别 tags

### Sub-action 两阶段处理

- Picker 选择：父 action 的 operators 未执行，不更新 `last_action_tags`
- `_on_sub_action_picked()`：在父+子 operators 执行前计算 `_is_repeated_action`（使用子 action 的识别 tags），执行后更新 `last_action_tags`

### 相关文件

- `core/player_state.gd` — `last_action_tags` + `_is_repeated_action` + `is_action_repeated()`
- `core/model/property_operator.gd` — `operate()` 倍率应用 + `describe_preview()` 调整后展示
- `core/action_hint_builder.gd` — `_check_repeated()` + hover preview 时临时设 `_is_repeated_action`
- `ui/action_button.gd` — `_on_button_pressed()` / `_on_sub_action_picked()` 中快照计算 + tags 更新

---

## DeferConfig 行动延迟系统

### 设计意图

让行动点击后不立即执行，而是经过 N 旬的等待（defer）过程，每旬消耗资源+时间，到期后才进行事件扫描。
玩家可以中途取消 defer 回到正常状态。

### 核心状态机

```
点击行动 → defer_config.xun_defered 非空 → start_defer → 按钮变蓝
                                                           │
          ┌────────────────────────────────────────────────┤
          │                                         每旬 tick
          │  remaining > 1 且有 event_picked_per_xun  → push_event(picked_uuid)（插队展示）
          │                                             │
          │                                       资源不足 → 中断 + push failed_fallback
          │                                             │
          │                                       到期 remaining_xun=0 → scan_events(main_tag)
          │
手动点击 → cancel_defer → 按钮恢复白色（回到待命）
```

### 视觉优先级（不可变）

| 优先级 | 颜色 | 触发条件 | modulate |
|--------|------|----------|----------|
| 1 🔴 | 淡红 | deferring + is_defer_failing (资源即将不足) | `Color(1.0, 0.5, 0.5, 0.85)` |
| 2 ⬛ | 灰 | _is_locked (非 defer 原因) | `Color(0.4, 0.4, 0.4, 0.6)` |
| 3 🔵 | 淡蓝 | deferring + 资源充足 | `Color(0.5, 0.6, 1.0, 0.85)` |
| 4 ⬜ | 白 | 正常 | `Color.WHITE` |

- 红色态不持久存储，每次属性变动通过 `is_defer_failing()` 实时计算（调用 `check_archetype_property_costs`）
- 点击红色/蓝色按钮均触发 `cancel_defer()` → toast "已取消等待"

### 数据流

```
Action.defer_config (配置)
  ├─ xun_defered: String              → NamedDSLParser → int 旬数
  ├─ used_resource_archetype: String  → Database.action_archetypes[key].operators → PropertyOperator 执行
  ├─ ap_cost: String                  → NamedDSLParser → int AP/时间扣减
  ├─ failed_fallback: String          → EventBus.push_event (资源中断时)
  ├─ event_picked_per_xun: BaseEventPicker → 每旬触发事件（消耗前，最后一旬跳过）
  └─ defer_success_event: String      → defer 到期后精确推送

ActionManager._deferring_actions (运行时状态)
  key=action_id, val={
    remaining_xun,           # 剩余旬数
    used_resource_archetype, # 资源消耗 archetype key
    ap_cost,                 # 每旬时间扣减
    failed_fallback,         # 中断兜底事件 UUID
    defer_success_event,     # defer 到期精确事件 UUID
    main_tag,                # 到期扫描用 main_tag
    npc_target,              # defer 目标 NPC
    event_picked_per_xun,    # BaseEventPicker 实例（每旬触发）
  }
```

### Per-Xun 事件触发规则

- **触发时机**: 每旬资源检查通过后、消耗执行前
- **最后一旬**: 不触发 per_xun 事件（到期旬直接进入 success 逻辑）
- **推送方式**: `EventBus.push_event`（立即插队展示）
- **context**: `{action_id, npc_target}` → 传入 `BaseEventPicker.pick(_ctx)`，返回 UUID 后通过 `Database.resolve` 查找事件资源

### 相关文件

- `model/defer_config.gd` — DeferConfig 数据模型（含 failed_fallback / event_picked_per_xun）
- `model/base_event_picker.gd` — BaseEventPicker 数据模型（pick 方法返回事件 UUID）
- `core/action_manager.gd` — `_deferring_actions` 管理 + `start_defer`/`cancel_defer`/`is_deferring`/`is_defer_failing`/`get_defer_remaining` + `process_xun_tick` defer 处理
- `parser/dsl_parser.gd` — `_parse_converter_context()` context key `event_picked_per_xun`, `_build_action_from_row()` 创建 BaseEventPicker
- `ui/action_button.gd` — `_on_button_pressed` defer 分支 + `set_deferring`/`set_defer_failing` 视觉
- `ui/scene_action_scroll.gd` — `refresh`/`_refresh_locks_only` defer 状态渲染
- `core/action_hint_builder.gd` — hover 展示 defer 剩余旬数 + 每旬消耗 + 资源不足警告

---

## 驻留行动系统（驻留 / Zhuliu）

### 设计意图

「驻留」是一个独立的父行动（非任何已有行动的子行动），让玩家在长安三个区域（西市/平康坊/皇城）之间切换自己的驻留地点。驻留本身不产生任何消耗（仅消耗 1 天时间），不投骰（100% 成功），是 100% 确定性的行动。驻留地点的改变会触发的叙事通过 archetype + fallback 事件完成。

### 数据模型

| 字段 | 说明 |
|------|------|
| `GameSave.data.stay_place` | 持久化 String key：`"xishi"` / `"pingkangfang"` / `"huangcheng"` |
| `PlayerState.stay_place` | getter/setter 代理到 GameSave.data，发射 `stay_place_changed` 信号 |
| `ENUMS.place_to_cn(s)` | String key → 中文名 |
| `ENUMS.from_place_str(s)` | String key → `CHANGAN_PLACES` 枚举 |

### Operator

- [`core/operators/set_stay_place_operator.gd`](core/operators/set_stay_place_operator.gd) — `SetStayPlaceOperator`，继承 `BaseOperator`
  - `@export var place: String` — 目标地点 key
  - `operate()` → `PlayerState.stay_place = place`

### DSL 语法

```
set_stay_place(place=xishi)
set_stay_place(place=pingkangfang)
set_stay_place(place=huangcheng)
```

### Archetype

| Archetype | universal_result |
|-----------|-----------------|
| `zhuliu_xishi_success` | `set_stay_place(place=xishi)` |
| `zhuliu_pingkangfang_success` | `set_stay_place(place=pingkangfang)` |
| `zhuliu_huangcheng_success` | `set_stay_place(place=huangcheng)` |

### 行动树

```
zhu_liu (SceneAction, main_tag=ACTION_MAIN_ZHUILIU, day=1, icon=zhuliu_stamp.png)
├── zhu_liu_xishi (Action, fallback=zhu_liu_xishi_fallback)
├── zhu_liu_pingkangfang (Action, fallback=zhu_liu_pingkangfang_fallback)
└── zhu_liu_huangcheng (Action, fallback=zhu_liu_huangcheng_fallback)
```

### UI

- `LeftPlayerPanel` 的 `PlaceLabel` 监听 `stay_place_changed`，显示 `"驻留 · 西市"` / `"驻留 · 平康坊"` / `"驻留 · 皇城"`
- 右侧行动按钮的 description 保持静态文本

### 相关文件

- [`core/operators/set_stay_place_operator.gd`](core/operators/set_stay_place_operator.gd) — Operator
- [`core/player_state.gd`](core/player_state.gd) — `stay_place` property + signal
- [`core/model/game_save_data.gd`](core/model/game_save_data.gd) — 持久化字段
- [`model/enumerates.gd`](model/enumerates.gd) — 枚举 + 转换方法
- [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) — DSL 注册
- [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) — archetype 定义
- [`data/3_actions_pool/actions/zhu_liu.tres`](data/3_actions_pool/actions/zhu_liu.tres) — 父行动
- `data/3_actions_pool/actions/zhu_liu/` — 3 个子行动
- `data/1_core_rules/events/fallback/` — 3 个 fallback 事件
- [`ui/left_player_panel.gd`](ui/left_player_panel.gd) — PlaceLabel 刷新

---

## Sub-Action 地点过滤系统 (Place-Based Filtering)

### 设计意图

长安三层地点（[`CHANGAN_PLACES`](model/enumerates.gd#L70-L74)）限制子行动可用性：
- **西市 (XISHI)**：底层/地下 — 搬砖、试药、卖字、暗巷刺探、喝药酒
- **平康坊 (PINGKANGFANG)**：中层社交 — 卖诗、宣读诗词、坊间买醉、赴宴雅集、举办宴席
- **皇城 (HUANGCHENG)**：顶层权贵 — 全部拜谒子行动（要挟/携诗/行卷/普通）
- 出游登高（曲江池/乐游原/少陵原）、小酌一口 → 无地点要求，哪里都可用

### 地点 → 子行动映射

| 子行动 | `_required_place` | 理由 |
|--------|:--:|------|
| 搬砖 (banzhuan) | 西市 | 底层苦力 |
| 试药 (shiyao) | 西市 | 暗巷地下神医 |
| 卖字 (maizi) | 西市 | 底层卖字 |
| 风骨卖字 (fgmaizi) | 西市 | 底层卖字 |
| 暗巷刺探 (leverage_farm) | 西市 | 暗巷=S级底层 |
| 喝药酒 (heyaojiu) | 西市 | 底层独酌 |
| 卖诗 (sell_poem) | 平康坊 | 歌女传唱 |
| 宣读诗词 (recite_poem) | 平康坊 | 席间诵读 |
| 坊间买醉 (tavern_gacha) | 平康坊 | 交游酒楼 |
| 赴宴雅集 (intro_gacha) | 平康坊 | 上层社交 |
| 举办宴席 (hold_feast) | 平康坊 | 社交宴会 |
| 要挟 (threaten) | 皇城 | 拜谒权贵+把柄 |
| 携诗拜谒 (poem_visit) | 皇城 | 携诗叩门 |
| 广发行卷 (mass_distribution) | 皇城 | 行卷投递 |
| 普通拜谒 (normal) | 皇城 | 普通拜谒 |
| 曲江池/乐游原/少陵原 | — | 出游不限 |
| 小酌一口 (xiaozhuo) | — | 居家行为 |

### 数据模型

- [`Action.required_place`](core/model/action.gd) — `@export var required_place: String = ""`，空字符串表示无地点要求；合法值 `"xishi"` / `"pingkangfang"` / `"huangcheng"`
- [`Action.get_required_place_name()`](core/model/action.gd) — 返回中文地点名（"西市"/"平康坊"/"皇城"/""）
- `PlayerState.stay_place` — 玩家当前所在长安地点

### 过滤与显示流程

```
action_button 构建 picker data
  └─ sub_action.required_place 非空 && != _stay_place_to_str(PlayerState.stay_place)
       └─ entity.set_meta("_place_mismatch", true)
       └─ entity.set_meta("_required_place_name", "皇城")
       └─ entity.set_meta("_required_place", "huangcheng")
  → push_picker → PickerTapeAttachment.initialize
       └─ 遍历 entity，检测 _place_mismatch：
            ├─ has mismatch → 显示 CheckBox「显示异地行动」+ 默认隐藏异地 item
            └─ no mismatch → 隐藏 CheckBox
```

### CheckBox 行为

- 仅存在 ≥1 个 `_place_mismatch` 的 item 时显示
- 默认不勾选 → 异地 item `visible = false`
- 勾选后 → 异地 item `visible = true`，`modulate = Color(0.6, 0.7, 1.0, 0.9)` 淡蓝色
- 异地 item 不走灰化锁定（`_is_locked` 始终 false），可正常点击

### 异地点击处理

- [`SubActionExecutor.execute()`](core/sub_action_executor.gd) 检测 `state.selected_entity_place_mismatch`：
  - `PlayerState.append_stat("_time", -1)` + `TimeService.advance_time(1)` — 消耗 1 天前往目标地点（同时扣时间池+推进日历）
  - `PlayerState.stay_place = state.selected_entity_required_place` — 切换当前地点
  - 之后继续正常 sub-action 执行流程（possibility 投骰 → operators → scan_events）

### 异地行动时间校验

- 前置校验（[`MainActionButton`](ui/main_action_button.gd) 构建 picker data + [`ActionManager.check_action_validity()`](core/action_manager.gd)）需计入异地旅行 +1 天惩罚
- [`ActionManager.get_action_day_cost()`](core/action_manager.gd) 接受可选参数 `remote_penalty_days: int = 0`：
  - `remote_penalty_days=0`：纯行动时间（默认）
  - `remote_penalty_days=1`：行动时间 + 异地旅行 1 天（用于前置校验）
- 实际执行时，旅行时间在 [`SubActionExecutor.execute()`](core/sub_action_executor.gd) 中独立扣除，子行动自身时间通过 `get_action_day_cost(action, parent_day, 0)` 计算

### Hint 提示

- [`ActionHintBuilder.build_sub_action_preview`](core/action_hint_builder.gd) 在子行动 hover 预览中追加：
  - `📍 自动消耗1天前往{皇城/西市/平康坊}`（淡蓝色 `[color=#88aaff]`）

### 信号链路

```
EventBus.push_picker(data, on_selected, ui_constructor, on_filter_toggled)
  → NarrativeDirector._on_push_picker → entry["on_filter_toggled"]
  → NarrativeOverlay._on_picker_ready → event_ui.append_picker_attachment(..., on_filter_toggled)
  → EventUI.append_picker_attachment → attachment.initialize(data, ui_constructor, on_filter_toggled)
  → PickerTapeAttachment._on_filter_checkbox_toggled (内部遍历染色) + callback.call(toggled_on)
```

### 相关文件

- [`core/model/action.gd`](core/model/action.gd) — `required_place` 字段（String） + `get_required_place_name()`
- [`core/player_state.gd`](core/player_state.gd) — `stay_place` 玩家当前位置
- [`ui/action_button.gd`](ui/action_button.gd) — picker 构建地点校验 + `_on_sub_action_picked` 异地处理
- [`ui/picker_tape_attachment.gd`](ui/picker_tape_attachment.gd) — CheckBox 过滤/染色 + 回调注入
- [`ui/picker_tape_attachment.tscn`](ui/picker_tape_attachment.tscn) — CheckBox 节点「显示异地行动」
- [`core/action_hint_builder.gd`](core/action_hint_builder.gd) — `📍 自动消耗1天前往某地` 提示行
- [`core/eventbus.gd`](core/eventbus.gd) — `push_picker` 信号新增 `on_filter_toggled` 参数
- [`characters/narrative_director.gd`](characters/narrative_director.gd) — 路由 `on_filter_toggled`
- [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) — 传递 `on_filter_toggled`
- [`characters/event_ui.gd`](characters/event_ui.gd) — `append_picker_attachment` 透传

---

## lead_to_event 快速通道

### 设计意图

Action 字段 [`lead_to_event: String`](core/model/action.gd) 用于子 Action 上。当 sub-action 在 Picker 中被选中并成功执行时，若 `lead_to_event` 非空，**跳过全部执行管线**（cost / possibility 投骰 / action_results / day_consumed / scan_events / 意象获取），直接以 `EventBus.push_event` 推送指定事件。

锁定 / HIDE / GRAY 判定完全保留——`lead_to_event` 仅在被成功选中后生效。

### 拦截位置

在 [`SubActionExecutor.execute()`](core/sub_action_executor.gd) 中，sub_action 解析完成后、重复行动检测之前：

```
sub_action = Database.get_action(selected_uuid)
  → lead_to_event 非空？
    → EventBus.push_event(lead_to_event, {}) + state.clear() + return
    → 否 → 正常管线
```

### 绕过清单

| 管线步骤 | 是否绕过 |
|----------|----------|
| Picker HIDE（TraitRequirement/FlagRequirement/NarrativeLock） | ❌ 正常 |
| Picker GRAY（PropertyRequirement/PoemRequirement/时间不足） | ❌ 正常 |
| 异地行动地点校验 | ❌ 正常 |
| NpcActionButton 锁定 | ❌ 正常 |
| cost archetype | ✅ 跳过 |
| possibility 投骰 | ✅ 跳过 |
| action_results.operate() | ✅ 跳过 |
| day_consumed 时间消耗 | ✅ 跳过 |
| scan_events | ✅ 跳过 |
| 意象获取 _try_imaginary_grant | ✅ 跳过 |
| 重复行动检测 | ✅ 跳过 |
| defer 启动 | ✅ 跳过 |

### 相关文件

- [`core/sub_action_executor.gd`](core/sub_action_executor.gd) — `execute()` 中快速通道拦截
- [`core/model/action.gd`](core/model/action.gd) — `lead_to_event` 字段声明

---

## 面板刷新信号分工（v3.1 — 2025-07-16）

### 问题背景

`request_refresh_action_panel` 曾身兼两职：既在非事件路径（白名单变化/聚焦退出/预留/DSL）被 emit，
也被消费方误用作「行动完成了」的探测器。实际上行动执行完成后 **没有任何代码 emit 它**，
tutorial 的 `_on_action_executed` 全靠白名单变化的副作用碰巧触发。

### 信号分工

| 信号 | 职责 | emit 时机 | listen 方 |
|------|------|----------|----------|
| `request_refresh_action_panel` | 非事件路径 UI 同步 | 白名单变化、聚焦退出、预留行动、DSL `RefreshActionPanelOperator` | `action_panel_manager._on_refresh_panel`、`right_info_panel._refresh_rumors`、`tutorial._on_state_check` |
| `event_confirmed` | 事件路径 UI 恢复 + 阶段推进 | `narrative_director.on_option_selected()` / `on_interrupt_pressed()` | `action_panel_manager._on_event_confirmed`（仅调 `_on_refresh_locks_only`）、`tutorial._on_event_confirmed`（阶段推进，**独占**）、`game_state.event_popup_queue` |
| `request_refresh_action_locks` | 属性变动增量更新 | `action_manager.reevaluate_all_locks()` | `action_panel_manager._on_refresh_locks_only` |

### 消费方行为

- **`action_panel_manager`**：`event_confirmed` → 仅 `_on_refresh_locks_only()`（不重建按钮，旬初才是全重建时机）；`request_refresh_action_panel` → 保留原逻辑（tutorial 白名单非空时全重建，否则仅锁刷新）
- **`tutorial_controller`**：`_on_event_confirmed` 独占 `event_confirmed` 做阶段推进；`_on_state_check`（原 `_on_action_executed`）仅监听 `request_refresh_action_panel` 做非事件路径状态检测。⚠️ **`_on_state_check` 不可同时监听 `event_confirmed`**，否则同一帧内 `_on_event_confirmed` 推进状态后被 `_on_state_check` 误判导致白名单/事件双重触发
- **`right_info_panel`**：仅监听 `request_refresh_action_panel` — 谣言刷新月级频率足够，不必每次事件确认都刷

### 相关文件

- [`core/eventbus.gd`](core/eventbus.gd) — 信号定义 + 注释
- [`ui/action_panel_manager.gd`](ui/action_panel_manager.gd) — `_connect_signals()` + `_on_event_confirmed()`
- [`core/tutorial_controller.gd`](core/tutorial_controller.gd) — `_connect_tutorial_signals()` / `_disconnect_tutorial_signals()` / `_on_state_check()`
