# SurvivalManager — 生存结算系统

## 文件
- `core/survival_manager.gd` — 核心生存结算管线
- `core/month_end_settlement.gd` — 月末结算 + 属性实时染色
- `data/3_actions_pool/decided_events/event_money_lower_0_innkeeper.tres` — 旬末没钱事件

## 时序

由 TimeService.on_xun_tick 触发 _process_single_xun_settlement()，管线顺序（不可更改）：
1. aggregate_trait_effect() — trait 持续效果、疾病进展
1.3. _process_imaginary_effects() — Imaginary 生命周期结算
1.5. _sync_health_ap_traits() — 健康→AP 阶梯同步（必须在 aggregate 之后，确保中毒等扣血 trait 已生效）
1.7. _apply_xun_base_inspiration() — 🆕 每旬基础兴获取（+3 inspiration，soft_max=50 溢出减半）
1.8. _apply_npc_inner_circle_bonus() — 🆕 NPC inner_circle 每旬属性加成（势/兴/望）
2. _cost_survival() — 基础生存扣除（-5 money）+ AP 刷新（健康联动）
3. _update_heartbeat_sfx() / death_judgement() — 濒死判定
4. operate_state_transistors() — 状态转换 / 旷达切换
5. ActionManager.process_xun_tick() — Lock/Block 到期清理
6. EventBus.xun_settlement_completed — UI 刷新信号
7. call_deferred("_post_xun_money_deduct") — 延迟扣除 30 money → **若 money < 0 触发 event_money_lower_0_innkeeper**

## NPC inner_circle 每旬加成 (🆕 1.8)

### 触发条件

遍历所有 `person_state == "inner_circle"` 的 NPC，累加他们的 shi(势)/xing(兴)/wang(望) 属性加成。

### 数据模型

NPCDocument 有 6 个 String 字段（存 named_amount key）：

| 字段 | 示例值 | 含义 |
|------|--------|------|
| `shi_addition` | `"m_momentum_gain"` | 每旬增加的势 |
| `shi_upper_limit` | `"m_momentum_upper_limit"` | 势的动态软上限 |
| `xing_addition` | `"s_inspiration_gain"` | 每旬增加的兴 |
| `xing_upper_limit` | `"s_inspiration_upper_limit"` | 兴的动态软上限 |
| `wang_addition` | `"s_prestige_gain"` | 每旬增加的望 |
| `wang_upper_limit` | `"s_prestige_upper_limit"` | 望的动态软上限 |

空字符串 = 该 NPC 不贡献该属性加成。

### 算法（方案A — 累积 + 溢出减半）

```
for 势/兴/望:
  cumulative_upper = Σ 所有 inner_circle NPC 的 upper_limit
  cumulative_add   = Σ 所有 inner_circle NPC 的 addition
  if cumulative_add == 0: continue
  new_val = current_val + cumulative_add
  if new_val > cumulative_upper:
    overflow = new_val - cumulative_upper
    new_val = cumulative_upper + overflow × 0.5
  PlayerState.set_stat_val(prop, new_val)
```

### named_amounts 条目

见 `tools/data/named_amounts.json` 第三部分 `=== 🧑‍🤝‍🧑 NPC inner_circle 每旬加成 ===`：

- momentum_gain / momentum_upper_limit — s/m/l 三档
- inspiration_gain / inspiration_upper_limit — s/m/l 三档
- prestige_upper_limit — s/m/l 三档（prestige_gain 复用既有条目）

### 管线位置

在 `_sync_health_ap_traits()` 之后（确保 AP 系统已就绪）、`_cost_survival()` 之前（加成先于生存扣除）。这保证「朋友助力 → 环境侵蚀」的叙事顺序。

## 每旬基础兴获取 (🆕 1.7)

### 设计意图

兴（inspiration）的基础自然恢复：每旬 +3。上限逻辑与 望 完全对齐（无硬上限，纯 soft_max + 溢出减半）：
- `inspiration.tres` 中 `hard_max = -1`, `soft_max = 50`
- 每旬 `_apply_xun_base_inspiration()` 执行 `append_stat(INSPIRATION, +3)`，若超过 soft_max 则溢出减半
- NPC inner_circle 的 `xing_upper_limit` 在其自己的 `_apply_npc_inner_circle_bonus()` 中叠加处理

### 管线位置

在 `_sync_health_ap_traits()` (1.5) 之后、`_apply_npc_inner_circle_bonus()` (1.8) 之前。
叙事顺序：「健康状态确定 → 自身灵感微发 → 友人激发助兴 → 生存消耗」。

### named_amounts 条目

`tools/data/named_amounts.json` 新增：
- `s_xing_gain = 3`
- `m_xing_gain = 6`
- `l_xing_gain = 10`

### 登高加兴 (resource_converters.csv)

三个登高行动的 success DSL 添加兴获取：
- 曲江池 (l_success_rate, 最简单) → `s_xing_gain` (3)
- 乐游原 (m_success_rate) → `m_xing_gain` (6)
- 少陵原 (m_success_rate, +roll_imaginary) → `l_xing_gain` (10)

## 旬末没钱事件

- **触发条件**：`_post_xun_money_deduct()` 执行后 `money < 0`
- **事件 uuid**：`event_money_lower_0_innkeeper`
- **事件名**：流落街头
- **选项**：单选项「咬牙撑过去」→ `HEALTH -20`
- **设计意图**：旬末大额扣费后才检测，而非日常小额扣费时触发。没钱了没有选择权，强制叙事 + 健康惩罚。

## 🆕 NPC 濒死救助

### 触发条件

在 [`death_judgement()`](core/survival_manager.gd:344) 中，当 `health ≤ 0` 时，**优先于现有三层濒死兜底系统**，按以下条件判定：

1. `flag_npc_rescued_this_life < 1`（尚未被救助过，一次性）
2. 存在 `person_state ≥ "know_about"` 的 NPC（通过 [`RelationFlagManager.get_known_targets()`](core/relation_flag_manager.gd:361) 查询）
3. 50% 随机概率（`randf() < 0.5`）

### 救助效果

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 随机选一名已知 NPC | `known_npcs[randi() % known_npcs.size()]` |
| 2 | `force_set_prop(HEALTH, current + xs_health_gain)` | 恢复 5 点健康（`xs_health_gain = 5`） |
| 3 | `set_flag("flag_npc_rescued_this_life", 1, "int")` | 标记已救助，下次濒死直接跳过 |
| 4 | `EventBus.push_event("event_npc_rescue_survival", {...})` | 推送救援叙事事件到纸带栈 |
| 5 | `return` | **提前退出**，不进入后续濒死兜底/死亡逻辑 |

### 事件

- **uuid**：`event_npc_rescue_survival`
- **文件**：[`data/3_actions_pool/decided_events/event_npc_rescue_survival.tres`](data/3_actions_pool/decided_events/event_npc_rescue_survival.tres)
- **标题**：`{rescuer_name}相救` — 通过 [`Util.tr_and_resolve()`](core/util.gd:399) 从 context 动态插值 NPC 翻译名
- **正文**：`在性命攸关之际，{rescuer_name}察觉到了你的近况，伸出了援手...`
- **选项**：单选项「大恩不言谢」，无后果（heal 已在 `death_judgement()` 中同步完成）

### 与旧濒死兜底的关系

```
health ≤ 0
  ├─ 🆕 NPC 救助（flag_rescued < 1 且 50% 概率）→ heal + push_event → return
  └─ 救助未触发 / 已救助过 → 现有三层濒死兜底（era=="755_backhome" 三次续命）
       └─ count >= 3 或 非 backhome → scan_death_events()
```

### 设计意图

给玩家一次「人情」的体验——泛泛之交在危难时刻伸出援手，体现唐代士人之间的江湖情谊。但只有一次机会（`flag_npc_rescued_this_life`），避免无限续命。50% 概率增加不确定性，不是每次濒死都有人救。

## 🆕 755_backhome 三次濒死事件链

仅在 `era == "755_backhome"` 时生效。`death_judgement()` 将 health≤0 截获后：

1. `flag_near_death_count` 自增，强制回血 `health=1`
2. 同一旬的 `operate_state_transistors()` 检测 flag 匹配对应 state_transistor → `request_event_key` 推送濒死叙事事件
3. 第 4 次濒死时 `flag_near_death_count >= 3` → 不再续命，走 `scan_death_events()` 真正死亡

### 三次濒死叙事

| 次数 | count | state_transistor | 事件 uuid | 事件名 | 效果 |
|------|-------|-----------------|-----------|--------|------|
| 第 1 次 | 1 | [`near_death_burn_manuscript_trans`](data/1_core_rules/state_transistors/near_death_burn_manuscript_trans.tres:35) | `near_death_burn_manuscript` | 焚稿求生 | 有诗稿: +15 健康; 无诗稿: +10 健康 |
| 第 2 次 | 2 | [`near_death_sing_crazy_trans`](data/1_core_rules/state_transistors/near_death_sing_crazy_trans.tres:35) | `near_death_sing_crazy` | 对雪长啸 | +10 健康 + `near_death_mind_broken` trait |
| 第 3 次 | 3 | [`near_death_nothing_to_burn_trans`](data/1_core_rules/state_transistors/near_death_nothing_to_burn_trans.tres:35) | `near_death_nothing_to_burn` | 無物可燒 | 纯叙事（无后果） |

### 防重复机制

每个 state_transistor 同时要求 `flag_near_death_rescued_N == 0`，触发后立即设 `flag_near_death_rescued_N = 1`。确保同一濒死次数不会重复推送事件。

### 事件文件

- `data/4_eras/755_backhome/near_death_burn_manuscript.tres`
- `data/4_eras/755_backhome/near_death_sing_crazy.tres`
- `data/4_eras/755_backhome/near_death_nothing_to_burn.tres`

### 翻译

见 `data/1_core_rules/translations/_dynamic_events.csv` 中 `TRES_NEAR_DEATH_*` 条目。

## 关键机制

### 延迟扣除 (call_deferred)
- 每旬末尾延迟扣除 30 money
- day 29 时 on_month_tick 快照先执行，扣除在后 → -30 计入下月 delta
- 染色系统每旬初清零，仅反映当旬属性变化

### 健康→AP 阶梯系统

通过 [`HEALTH_AP_TIERS`](core/survival_manager.gd:13) const dict 数组配置，作为唯一真相源：

| 健康 | AP 上限 | 特质 | display_char |
|------|---------|------|-------------|
| ≤ 30 | 5 | `terminal_illness`（病入膏肓） | 病 |
| ≤ 59（即 < 60） | 8 | `exhaustion_initial`（疲态初显） | 疲 |
| ≥ 60 | 10（默认） | 无 | — |

消费方通过静态查询接口获取数据：
- `SurvivalManager.get_current_ap_cap()` → `int` — [`_cost_survival()`](core/survival_manager.gd:55) AP 刷新、[`time_control_panel`](world/time_control_panel.gd:1) 圆点上限
- `SurvivalManager.get_active_ap_hint()` → `String` — [`action_hint_builder`](core/action_hint_builder.gd:1) hover 提示文本
- `SurvivalManager.get_active_ap_hint_color()` → `String` — hover 提示颜色

新增阶梯只需在 `HEALTH_AP_TIERS` 数组中插入一条，所有消费方自动生效。

### 属性实时染色
- MonthEndSettlement 监听 player_stat_changed
- 比较当前值 vs 月度快照，增长绿 / 衰减红 / 无变化恢复默认
- 每旬初由 _on_xun_color_reset() 清空，不再依赖月初清空

### 月末结算 UI 状态机

月末结算事件通过 `EventBus.push_event(is_settlement=true)` 推入纸带栈顶，
使用专用 [`SettlementTapeEntry`](ui/settlement_tape_entry.gd) 组件渲染。

**状态转换：**

```
[awaiting_choice] ──点击"合上考评"──▶ [chosen]
       │                                    │
       │ emit option_selected(PopEvent)       │ 追加「既决：合上考评」烙印
       │ NarrativeOverlay → EventUI.mark_chosen
       │                                    │
       ▼                                    ▼
  _confirm_btn.pressed (CONNECT_ONE_SHOT)  按钮隐藏 + 信号不可再触发
  NarrativeOverlay._is_settlement=true     BlurManager.hide_picker_blur()
       │                                    _is_settlement = false
       ▼
  Director.on_option_selected → PopEventOperator.pop_to_event()
```

**关键约束：**

- `SettlementTapeEntry` 自主管理 UI 状态转换（[`mark_chosen()`](ui/settlement_tape_entry.gd:152)），不依赖 [`EventUI.mark_chosen()`](characters/event_ui.gd:241) 中硬编码的 `MarginContainer/VBox` 节点路径
- [`EventUI.mark_chosen()`](characters/event_ui.gd:249-260) 检测 `entry_type == "settlement"` 后委托给 `entry.mark_chosen(choice_text)` 处理
- `_confirm_btn.pressed` 使用 `CONNECT_ONE_SHOT` 纵深防御，即使 mark_chosen 未覆盖仍无法二次触发
- 第一次点击 → 按钮变烙印 + PopEventOperator 弹出结算事件 → 纸带回归上层事件
