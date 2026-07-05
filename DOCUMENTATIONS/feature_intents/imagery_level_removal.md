# 意象/诗词等级系统删除 — 功能意图

**状态**: ✅ 已完成（2026.07.01）— 被 V7 ImaginaryConcept 全量删除取代

---

## 意图摘要（<200字）

删除 `ImaginaryConcept.current_level` 和 `Poem.poem_level` 字段及所有依赖逻辑。诗词收益公式中 level 因子写死为 2。重复收集同一 Imaginary 碎片时转为 `talent` 属性增益（+3）。Collapse 合并门槛降为 1 个碎片即可，从 N 个碎片中随机抽取 1 个消耗，其余保留。`current_tier` 保留（仅 1/2，无 0）。删除 `ImaginaryLevelRequirement`、`ImaginaryOperator`、`ImaginarySetLevelOperator`。

> ⚠️ 本任务已被后续的 V7「意象系统扁平化」重构完全取代。V7 更进一步删除了 ImaginaryConcept 类本身和 Tier 系统。详见 [`poem_crafter.md`](DOCUMENTATIONS/feature_intents/poem_crafter.md)。

---

## 核心玩法变化

| 旧行为 | 新行为 |
|--------|--------|
| 收集 ≥2 同 concept 碎片 → 全部消耗，level = min(count,2) | 收集 ≥1 同 concept 碎片 → 随机选 1 个消耗，其余保留，无 level 概念 |
| 重复收集同一 Imaginary → 创建新碎片（可累加） | 重复收集同一 Imaginary → 转 `talent +3` |
| 诗词收益公式：`base = poem_level × 10/20 × 管道乘数` | 诗词收益公式：`base = 2 × 10/20 × 管道乘数`（level 写死为 2） |
| `ImaginaryLevelRequirement` 检查任意意象 level ≥ N | 删除，不再作为事件门槛 |
| `LianjuScoreOperator` 按 level (1/2/3) 评分 | 按 tier (1/2) 评分：T1=0, T2=20 |
| `ImaginaryLevelRewardOperator` 按 level (1/2/3) 给 fame | 按 tier (1/2) 给 fame |

---

## 涉及文件（完整改动清单）

### Layer 0: 数据模型

| 文件 | 改动 |
|------|------|
| [`core/model/imaginary_concept.gd`](core/model/imaginary_concept.gd) | 删 `current_level`、`level_changed` 信号、`l3_threshold`；`current_tier` 改为 1-2 无 0；`l2_threshold` 改为 2 |
| [`core/model/poem.gd`](core/model/poem.gd) | 删 `poem_level` 字段和 `_init` 参数 |
| [`core/model/poem_record.gd`](core/model/poem_record.gd) | 删 `poem_level` 字段 |
| [`core/model/poem_taste.gd`](core/model/poem_taste.gd) | 删 `lowest_poem_level` 字段 |

### Layer 1: 核心逻辑

| 文件 | 改动 |
|------|------|
| [`core/imaginary_comprehender.gd`](core/imaginary_comprehender.gd) | `merge_category()`：随机选 1 个 Imaginary 消耗，不设 level，设 tier；`consume_concepts()`：删 level 重置 |
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd) | 删 `poem_level` 结果字段，写死 `max_level=2`，删 `_calculate_health_cost` 中 level 引用 |
| [`core/player_state.gd`](core/player_state.gd) | `_on_request_add_imaginary()`：重复检测 → `talent +3`；`init_imaginaries()`：删 level 初始化 |

### Layer 2: 算子层

| 文件 | 改动 |
|------|------|
| [`core/operators/imaginary_operator.gd`](core/operators/imaginary_operator.gd) | **删除** |
| [`core/operators/imaginary_set_level_operator.gd`](core/operators/imaginary_set_level_operator.gd) | **删除** |
| [`core/operators/imaginary_level_reward_operator.gd`](core/operators/imaginary_level_reward_operator.gd) | 改为基于 `current_tier` 给奖励 |
| [`core/operators/lianju_score_operator.gd`](core/operators/lianju_score_operator.gd) | 删 level 过滤和评分，改为 tier：T1=0, T2=20 |
| [`core/operators/trait_choose_operator.gd`](core/operators/trait_choose_operator.gd) | 删 `poem_level` 和 `lowest_poem_level` 检查 |

### Layer 3: 需求检查

| 文件 | 改动 |
|------|------|
| [`core/requirements/poem_requirement.gd`](core/requirements/poem_requirement.gd) | 删 `lowest_poem_level` 字段和检查逻辑 |
| [`core/requirements/imaginary_level_requirement.gd`](core/requirements/imaginary_level_requirement.gd) | **删除** |

### Layer 4: 监听器

| 文件 | 改动 |
|------|------|
| [`core/imaginary_sound_listener.gd`](core/imaginary_sound_listener.gd) | 改为监听 `tier_changed` 信号替代 level 变化 |

### Layer 5: UI

| 文件 | 改动 |
|------|------|
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd) | 删 level 显示行，Poem 构造删 `poem_level` 参数 |
| [`ui/poem_uis/detail_imaginary.gd`](ui/poem_uis/detail_imaginary.gd) | 删 level 显示 |

### Layer 6: Data .tres

| 文件 | 改动 |
|------|------|
| `data/1_core_rules/poem_recipes/poem_*.tres` (4 files) | 删 `poem_level = N` 行 |
| `data/2_characters/poem_tastes/*.tres` (3 files) | 删 `lowest_poem_level = N` 行 |
| `data/1_core_rules/event_options/poem_type_choose_zhuoliu.tres` | 删 `lowest_poem_level` |
| `data/1_core_rules/events/fallback/poem_reveal.tres` | 删 `@poem_level` 引用 |
| `data/4_eras/755_backhome/near_death_burn_manuscript.tres` | 删 `lowest_poem_level` |
| `data/4_eras/745_ambition/baiye/real_appearance/bai_ye_real_appearance_fallback.tres` | 删 `lowest_poem_level` (2 处) |

### Layer 7: 测试

| 文件 | 改动 |
|------|------|
| `tests/test_imagery_tier_system.gd` | 删所有 `current_level` 断言 |
| `tests/test_imaginary_comprehender_v2.gd` | 删所有 `current_level` 断言 |
| `tests/test_poem_crafting_comprehensive.gd` | 删 `poem_level` 测试用例 |
| `tests/test_poem_requirement.gd` | 删 `lowest_poem_level` 测试 |
| `tests/test_poem_crafting_fragment.gd` | 更新 level 引用 |
| `tests/imaginary_label.gd` | 删 level 显示 |

---

## 架构决策

- **tier 不再有 0 值**：未坍缩的 concept 不暴露给外部，只有坍缩后的 tier∈{1,2}
- **Collapse 随机抽取**：从 N 个碎片中 `randi() % N` 选 1 消耗，其余保留供其他 concept 使用
- **重复意象转 talent**：在 `_on_request_add_imaginary` 入口处检测 `imaginaries_detail.has()`，而非在 collapse 层面
- **level 写死为 2**：简化收益公式，未来如需差异化可通过 tier 或管道乘数实现
- **删除 ImaginaryLevelRequirement**：不再支持"意象达到某等级"作为事件门槛，如有需要可用 tier 检查替代
