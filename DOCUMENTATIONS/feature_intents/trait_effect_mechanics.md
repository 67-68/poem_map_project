# poisoned + sprained_ankle + severe_injury 临时负面 Trait（数据驱动版）

> 🆕 重构日期：已迁移至 Trait.duration_xun + expiry_trait 统一到期逻辑

## 文件
- `core/model/trait.gd` — 新增 duration_xun、expiry_trait、conditional_time_penalties、narrative_murmur、ap_penalty
- `core/model/conditional_time_penalty.gd` — 条件化时间惩罚模型（含 add_to_all）
- `core/model/disease.gd` — progression_target/progression_xun 已上移至 Trait 基类
- `data/1_core_rules/traits/_traits.csv` — CSV 数据源（新增 duration_xun/conditional_time_penalty/narrative_murmur/ap_penalty 列）
- `core/survival_manager.gd` — aggregate_trait_effect() 统一到期逻辑，删除 TEMP_DEBUFFS/SEVERE_INJURY_DURATION_XUN
- `core/action_manager.gd` — get_action_day_cost() 用 conditional_time_penalties 数据驱动

## 过期/移除机制（统一化）

所有 trait 共享同一到期流程：`duration_xun > 0 → lasting_xun 达标 → remove_trait → 如果 expiry_trait 非空则 add_trait(expiry_trait)`

| Trait | duration_xun | expiry_trait | 替代原逻辑 |
|-------|-------------|--------------|-----------|
| poisoned | 2 | (空) | TEMP_DEBUFFS + TEMP_DEBUFF_DURATION_XUN |
| sprained_ankle | 2 | (空) | 同上 |
| severe_injury | 3 | (空) | SEVERE_INJURY_DURATION_XUN |
| disease_dongshang_frostbite | 3 | disease_dongshang_necrosis | Disease.progression |
| disease_fenghan_acute | 6 | disease_feilao_chronic | Disease.progression |
| disease_shiyi_depression | 6 | disease_zhanwang_mania | Disease.progression |

## 时间惩罚机制（条件化）

`conditional_time_penalty` DSL 格式：`action_tag_match/penalty_days/description/add_to_all`
多个用 `|` 分隔，`add_to_all=true` 时忽略 action_tag_match。

| Trait | conditional_time_penalty | 效果 |
|-------|------------------------|------|
| severe_injury | `/1/重伤行动不便/true\|denggao/5/重伤登高/false` | 所有行动+1天，登高再+5天 |
| sprained_ankle | 使用 time_penalty=1（add_to_all等效） | 所有行动+1天 |

## 叙事碎碎念

Trait.narrative_murmur 字段驱动，`_subconscious_murmur()` 遍历所有 trait 取第一个非空值。

| Trait | narrative_murmur |
|-------|-----------------|
| poisoned | 腹中隐隐作痛，这毒物怕不是那日试药留下的… |
| sprained_ankle | 脚踝还在隐隐发疼，走路得慢些。 |

## AP 惩罚

Trait.ap_penalty 字段驱动（负数表示扣减），`get_current_ap_cap()` 遍历聚合。

| Trait | ap_penalty |
|-------|-----------|
| disease_ouxinlixue | -2 |

---

## 🏷️ Trait 效果全量清单（按字段 → 消费方）

### ========== Trait 基类字段 ==========

| 字段 | 类型 | 消费方 | 效果 |
|------|------|--------|------|
| `trait_effect_operations` | `Array[PropertyOperator]` | [`survival_manager.gd:aggregate_trait_effect()`](core/survival_manager.gd:178) | 每旬结算时执行（如 `poisoned → health-15`） |
| `buffer_to_prop` | `DictMultiplyOperator` | [`player_state.gd:change_stat()`](core/player_state.gd:278) | 属性变化时倍率修正（如 `disease_fenghan_imaginary → health×1.5`） |
| `buffer_to_region` | `DictMultiplyOperator` | [`player_state.gd:change_stat()`](core/player_state.gd:280) | 按当前区域倍率修正 |
| `time_penalty` | `int` | [`player_state.gd:get_active_time_penalties()`](core/player_state.gd:490) → [`action_manager.gd:get_action_day_cost()`](core/action_manager.gd:781) | 全局行动天数惩罚（如 `sprained_ankle=+1天`） |
| `duration_xun` | `int` | [`survival_manager.gd:aggregate_trait_effect()`](core/survival_manager.gd:183) | 到期自动移除（>0 时 `lasting_xun` 达标触发） |
| `expiry_trait` | `String` | [`survival_manager.gd:aggregate_trait_effect()`](core/survival_manager.gd:186) | 到期后替换为目标 trait（空=直接删） |
| `conditional_time_penalties` | `Array[ConditionalTimePenalty]` | [`action_manager.gd:get_action_day_cost()`](core/action_manager.gd:785) | 匹配 action_tag 时追加天数 |
| `ap_penalty` | `int` | [`survival_manager.gd:get_current_ap_cap()`](core/survival_manager.gd:90) | 永久 AP 上限削减（负数累计） |
| `narrative_murmur` | `String` | [`narrative_overlay.gd:_subconscious_murmur()`](characters/narrative_overlay.gd:821) | 日常面板潜意识碎碎念文本 |
| `display_char` | `String` | [`trait_demonstrator.gd`](ui/trait_demonstrator.gd:15) | 阳刻印章展示字 |
| `topic` | `enum` | [`social_wall_panel.gd`](ui/social_wall_panel.gd:15) / [`trait_choose_operator.gd`](core/operators/trait_choose_operator.gd:56) / [`poem_requirement.gd`](core/requirements/poem_requirement.gd:20) | 类型路由（RELATION→社交面板，Poem→诗词选择/需求判定） |
| `lasting_xun` | `int` | [`survival_manager.gd`](core/survival_manager.gd:177) | 已持续旬数计数器 |

---

### ========== ConditionalTimePenalty（条件时间惩罚）==========

| 字段 | 消费方 | 效果 |
|------|--------|------|
| `action_tag_match` | [`action_manager.gd:get_action_day_cost()`](core/action_manager.gd:788) | 匹配 action 的 `main_tag` 或 `action_tags`（contains） |
| `penalty_days` | 同上 | 匹配时追加的天数 |
| `add_to_all` | 同上 | `true` 时跳过 tag 匹配，所有行动生效 |
| `description` | 同上（日志） | 日志标注 |

---

### ========== Disease 独有字段 ==========

| 字段 | 消费方 | 效果 |
|------|--------|------|
| `on_enter_event` | [`trait_operator.gd:operate()`](core/model/trait_operator.gd:57) | trait 获得时触发 `guarantee_next` 诊断事件 |
| `hijack_provider` | [`event.gd:Phase 0.5`](model/event.gd:161) | 疾病劫持事件选项（如狂症的 ManiaProvider） |

---

### ========== Imaginary 到期转化字段 ==========

| 字段 | 消费方 | 效果 |
|------|--------|------|
| `expiry_trait` | [`survival_manager.gd:_process_imaginary_effects()`](core/survival_manager.gd:228) | 到期时添加的 trait |
| `expiry_flag` | 同上 | 防叠层 flag，已有则跳过转化 |
| `level_effect_health` | 同上 | 持有期每旬扣健康（仅 Lv2 使用） |
| `level` | [`survival_manager.gd:get_current_ap_cap()`](core/survival_manager.gd:84) | Lv3 每持有一个 AP-1 |

---

### ========== 模块影响关系图 ==========

```
                CSV / .tres 数据层
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   Trait 字段    Imaginary 字段   Disease 字段
        │             │             │
        ├─────────────┴─────────────┤
        ▼                           ▼
  SurvivalManager              ActionManager
  ├ aggregate_trait_effect()   ├ get_action_day_cost()
  │  ├ lasting_xun 递增        │  ├ time_penalty 聚合
  │  ├ operate_continuous()    │  ├ conditional_time_penalties 匹配
  │  └ duration_xun 到期       │  └ severe_injury 远游（已删）
  ├ _process_imaginary()       │
  │  ├ level_effect_health     ├ format_time_detail()
  │  └ expiry_trait 转化       │  └ UI hint 文本
  ├ _sync_health_ap_traits()   │
  ├ get_current_ap_cap()       │
  │  ├ HEALTH_AP_TIERS         │
  │  ├ lv3 计数                │
  │  └ ap_penalty 聚合         │
  └ operate_state_transistors()│
     └ KuangdaState.current()  │
              │                │
    ┌─────────┼────────┐       │
    ▼         ▼        ▼       ▼
 PlayerState  TierDeterminer   NarrativeOverlay
 ├ change_stat()  ├ KuangdaState  ├ _subconscious_murmur()
 │  ├ buffer_to_prop  └ current() │  └ narrative_murmur
 │  └ buffer_to_region            │
 ├ get_active_time_penalties()    ├ SocialActionResolver
 │  └ time_penalty 字典           │  └ KuangdaState.current()
 ├ add_trait() → on_trait_change  │
 │  └ SocialWallPanel             ├ EventBus.on_trait_change
 │  └ LeftPlayerPanel             │  ├ LeftPlayerPanel rebuild
 └ has_trait()                    │  ├ SocialWallPanel refresh
    ├ TraitRequirement             │  └ NarrativeOverlay refresh
    ├ ConditionalRandomOperator    │
    └ TierDeterminer               └ TraitOperator.operate()
                                      └ Disease.on_enter_event
```

---

### 一句话总结

Trait 现在有 **13 个字段**（含继承），分布在 **9 个消费模块** 中。所有运行时行为（到期、惩罚、AP、叙事、诊断）均为字段驱动，不再有硬编码。新增 trait 只需改 CSV/`.tres`，零代码修改。

---

## 🆕 TraitDemonstrator Hover（左→右滑入动画）

### 文件
- `ui/trait_demonstrator.gd` — `set_trait()` / `set_trait_fallback()` 中注册 `HoverPopupManager`（`SLIDE_FROM_LEFT` 流）
- `ui/hover_popup_manager.gd` — 新增 `FlowType.SLIDE_FROM_LEFT` + `SlideFromLeftDelegate`
- `characters/tape_visualizer.gd` — 新增 `play_slide_in_from_left()` / `play_slide_to_left()`
- `core/action_hint_builder.gd` — 复用 `build_trait_hint()` 生成完整 hint 文本

### 行为
鼠标悬停 TraitDemonstrator 0.4s 后，NarrativeOverlay 从屏幕**左侧外**滑入（`TRANS_CUBIC` / `EASE_OUT`），hover_container 中展示 `ActionHintBuilder.build_trait_hint()` 的全部内容（名称、描述、效果清单、持续时间、hover_narrative）。鼠标离开 0.75s 后滑出到左侧外。

### 动画方向
与 action button 的 `SLIDE_FROM_RIGHT`（右→左）相反，Trait 在左侧面板，因此 hover 内容从**左→右**滑入，方向自然。
