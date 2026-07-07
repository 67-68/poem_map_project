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
