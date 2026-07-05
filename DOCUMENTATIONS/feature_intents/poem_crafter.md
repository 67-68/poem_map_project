# 诗词意象匹配 — 功能意图

**状态**: 🔴 执行中（V7: 意象系统扁平化 — 删除 ImaginaryConcept 中间层）

---

## 意图摘要（<200字）

删除 `ImaginaryConcept` 抽象概念层和 `Imaginary.concepts` 标签数组。诗词创作流程简化为：玩家收集 `Imaginary`（uuid + name），选 3 个直接匹配食谱的 `required_fragments`（imaginary uuid 列表）。删除 Tier/Level 系统、合并坍缩机制、打油诗 fallback。失败时消耗 3 个 Imaginary。食谱索引 key 为 imaginary uuid 排序拼接。

---

## 核心玩法

### 匹配流程（V7）

```
玩家选 3 个 Imaginary (uuid_A, uuid_B, uuid_C)
                │
                ▼
    ┌───────────────────────┐
    │ 构建 Imaginary Set:    │
    │ {A.uuid, B.uuid, C.uuid} │
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────────────────┐
    │ 在食谱索引中查找精确匹配             │
    │ recipe_map[sorted_key] → Poem?     │
    └───────────────────────────────────┘
                │
         ┌───────┴───────┐
         ▼               ▼
     精确匹配          不匹配
         │               │
         ▼               ▼
     ✅ 创作成功       ❌ 失败
     完整诗词          惩罚文案
     消耗 3 Imaginary   消耗 3 Imaginary
```

### 精确匹配规则

- 玩家选中 3 个 Imaginary 的 uuid Set 必须**完全等于**食谱的 `required_fragments` Set（无序比较）
- `required_fragments` 存储的是 **imaginary uuid**（如 `"snow"`, `"buyi"`, `"qianli"`），不是 concept uuid
- 全类型盲搜（遍历所有已加载食谱）

### 删除的系统

| 删除项 | 说明 |
|--------|------|
| `ImaginaryConcept` 类 | 中间抽象层，32 个 .tres 文件 |
| `Imaginary.concepts` 数组 | 不再有 tag 关联 |
| 合并坍缩 (merge/collapse) | 不再有碎片合并到概念 |
| `ImaginaryComprehender._derive_concept_groups` | 不再有分组推导 |
| `ImaginaryComprehender.can_merge/merge_category` | 不再有合并逻辑 |
| Tier 系统 | `current_tier` 字段删除，收益公式不再依赖 tier |
| 打油诗 fallback | 去掉 2/3 子集匹配 |
| `OrbitDetail` (detail_imaginary.gd) | 轨道碎片节点不再需要 |
| SubViewport 概念轨道可视化 | PoemCrafter 改为简单列表选择 |
| `imaginary_has_level` DSL | 删除 |
| `ImaginaryConcept` 相关测试 | test_imaginary_comprehender_v2 / test_imagery_tier_system / imaginary_label |

| 保留项 | 说明 |
|--------|------|
| `Imaginary` 类 | uuid + name，无 concepts 数组 |
| `ImaginaryComprehender.consume_concepts` | 改为直接删除 3 个 Imaginary |
| `FragmentMatcher` | 仅精确 Set 匹配 imaginary uuid |
| 管道乘数 | 保留，从食谱 specific_topic 获取 |
| `imaginary_level_reward` DSL + operator | 保留 |
| `ImaginarySoundListener` | 只走 T1 音效 |
| `AbstractConcept` UI 节点 | 解绑 ImaginaryConcept，改为可配置 |
| `PoemDemands` UI | 引用改为查 Imaginary |

### 诗词上限检查

- **检查时机**：点击「开始创作」按钮时
- 检测 `PlayerState.created_poems` 中是否有未使用的诗词
- 有则拒绝创作并提示

### 重复 Imaginary 处理

- 重复收集同一 Imaginary uuid → `talent +3`

---

## 收益公式

### 简化后收益（无 Tier/Level）

```
base_secular = 2 × 10.0          # 固定 20
base_history = 2 × 20.0          # 固定 40
base_secular 经管道乘数可能为负（亏钱赚声望）
```

### 管道乘数（从匹配食谱的 specific_topic 获取）

| 管道 | base_secular | base_history |
|------|-------------|-------------|
| SECULAR (GAN_YE, YING_ZHI) | ×1.5 | ×1.0 |
| BROADCAST (DENG_GAO, HUAI_GU, JI_LV, SHAN_SHUI) | ×0 | ×1.2 |

---

## 食谱数据模型

### 食谱文件（imaginary uuid）

| 文件 | specific_topic | required_fragments（imaginary uuid） |
|------|---------------|--------------------------------------|
| `poem_tian_cheng.tres` | GAN_YE | `ink_stone`, `qianli`, `starving_bone` |
| `poem_weizuo_cheng.tres` | GAN_YE | `buyi`, `qianli`, `ghost_fire` |
| `poem_zheng_jianyi.tres` | GAN_YE | `famine`, `cold_blade`, `thatched_grass` |
| `poem_fengxue_ye.tres` | DENG_GAO | `cold_moon`, `snow`, `falling_leaf` |

### 食谱索引结构

```
Database.recipe_index: Dictionary[String, Poem]
  key = "ink_stone|qianli|starving_bone"  # required_fragments 排序后 | 拼接
  value = Poem resource
```

---

## 数据流（V7）

```
┌─────────────────────────────────────────────────────┐
│              食谱加载（Database._init）                │
│                                                      │
│  poem_recipes/*.tres                                 │
│    │                                                 │
│    ├─ 读取 required_fragments（imaginary uuid）       │
│    ├─ 排序拼接 → recipe_key                          │
│    └─ recipe_index[recipe_key] = Poem resource       │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│              PoemCrafter 用户操作                      │
│                                                      │
│  选 3 个 Imaginary (uuid_A, uuid_B, uuid_C)           │
│    │                                                 │
│    └─→ PoemCraftingCalculator.calculate_poem_grade() │
│          │                                           │
│          ├─ 1. 构建 imaginary_set = {A, B, C}        │
│          ├─ 2. 在 recipe_index 中精确查找            │
│          │     ├─ 命中 → 收益计算                    │
│          │     └─ 不命中 → 失败 消耗 3 Imaginary      │
│          ├─ 3. recipe.specific_topic → 管道乘数       │
│          └─ 4. 生成 Operators (money/literary_fame)  │
└─────────────────────────────────────────────────────┘
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`core/model/imaginary.gd`](core/model/imaginary.gd:1) | **修改** | 删除 `concepts` 数组字段 |
| [`core/model/imaginary_concept.gd`](core/model/imaginary_concept.gd:1) | **删除** | 类定义删除 |
| [`data/1_core_rules/imaginaries/*.tres`](data/1_core_rules/imaginaries/environment__snow.tres:1) | **删除** | 32 个 ImaginaryConcept 静态定义文件 |
| [`data/1_core_rules/poem_recipes/*.tres`](data/1_core_rules/poem_recipes/poem_tian_cheng.tres:1) | **修改** | required_fragments 从 concept uuid 改为 imaginary uuid |
| [`core/imaginary_comprehender.gd`](core/imaginary_comprehender.gd:1) | **简化** | 删除分组/合并/坍缩；consume_concepts 改为直接删 Imaginary |
| [`core/fragment_matcher.gd`](core/fragment_matcher.gd:1) | **简化** | 仅精确匹配 imaginary uuid，删向后兼容接口和 collect_player_tags |
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd:1) | **重构** | 输入 Imaginary 数组，删 tier 计算 |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd:1) | **重构** | 删除 SubViewport 渲染；selected_imaginaries→Array[Imaginary]；简单列表选择 |
| [`ui/poem_uis/detail_imaginary.gd`](ui/poem_uis/detail_imaginary.gd:1) | **删除** | OrbitDetail 不再需要 |
| [`ui/poem_uis/abstract_concept.gd`](ui/poem_uis/abstract_concept.gd:1) | **修改** | 解除 ImaginaryConcept 强绑定，改为可配置 |
| [`ui/poem_demands.gd`](ui/poem_demands.gd:1) | **修改** | concept 引用改为查 Imaginary |
| [`core/imaginary_sound_listener.gd`](core/imaginary_sound_listener.gd:1) | **修改** | diff 基于 Imaginary，只走 T1 音效 |
| [`core/operators/lianju_score_operator.gd`](core/operators/lianju_score_operator.gd:1) | **修改** | ImaginaryConcept→Imaginary |
| [`core/player_state.gd`](core/player_state.gd:1) | **修改** | 删 ImaginaryConcept preload，简化 _on_request_add_imaginary |
| [`core/database.gd`](core/database.gd:1) | **修改** | 删 imaginaries 字典，清理 feihualing_imageries |
| [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd:1) | **修改** | 删 imaginary_has_level 解析和注册 |
| [`data/3_actions_pool/events/_random_events.csv`](data/3_actions_pool/events/_random_events.csv:37) | **修改** | 删 imaginary_has_level 条件 |
| [`core/_class_registry.gd`](core/_class_registry.gd:32) | **修改** | 删 ImaginaryConcept 注册 |
| [`core/_export_dependency_anchor.gd`](core/_export_dependency_anchor.gd:58) | **修改** | 删 ImaginaryConcept preload |
| [`core/source_of_truth.gd`](core/source_of_truth.gd:52) | **修改** | 清理 imaginaries 注释 |
| [`tools/data/imaginary_definitions.json`](tools/data/imaginary_definitions.json:1) | **修改** | 删除 concepts 字段 |
| `tests/test_imaginary_comprehender_v2.gd` | **删除** | 依赖旧系统 |
| `tests/test_imagery_tier_system.gd` | **删除** | 依赖旧系统 |
| `tests/imaginary_label.gd` | **删除** | 依赖旧系统 |

---

## 状态转换

```
[玩家打开诗词面板]
    │
    ├─ 玩家从已拥有的 Imaginary 列表中选 3 个
    │
    └─ 点击「开始创作」
        │
        ├─ 已有未使用的诗词（上限检查）
        │   → ❌ 拒绝创作，提示
        │
        └─ PoemCraftingCalculator.calculate_poem_grade()
            │
            ├─ 精确匹配食谱
            │   └─ ✅ 创作成功
            │         ├─ 消耗 3 个 Imaginary
            │         ├─ Poem.new() → PlayerState.created_poems
            │         └─ push_event("poem_reveal")
            │
            └─ 无匹配 → ❌ 失败
                  ├─ 消耗 3 个 Imaginary
                  └─ 惩罚文案："意象散乱，强行拼凑..."
```

---

## 架构决策记录

| # | 决策 | 结论 |
|---|------|------|
| 1 | ImaginaryConcept 中间层 | **删除**，Imaginary 直接参与诗词匹配 |
| 2 | Imaginary.concepts 标签数组 | **删除**，不再有 tag 关联 |
| 3 | 合并坍缩机制 | **删除** |
| 4 | Tier 系统 | **删除**，收益公式固定 |
| 5 | 打油诗 fallback | **删除** |
| 6 | 食谱匹配方式 | 精确 Set 匹配 imaginary uuid |
| 7 | 失败消耗 | 消耗 3 个 Imaginary |
| 8 | 重复 Imaginary | talent +3 |
| 9 | imaginary_has_level DSL | **删除** |
| 10 | imaginary_level_reward | **保留** |
| 11 | 管道乘数 | 保留，从食谱 specific_topic 获取 |
