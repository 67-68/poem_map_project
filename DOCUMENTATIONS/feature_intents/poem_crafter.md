# 诗词意象匹配 — 功能意图

**状态**: ✅ 已完成（V5: 精确集合匹配 + Tier 合并 + 打油诗; V5.1: PoemDemand 动态填充）

---

## 意图摘要（<200字）

诗词创作引擎 V5 重构。核心变化：(1) Poem Level = `max(三个Concept.level)`；(2) Tier 2/3 合并为 Tier 2；(3) FragmentMatcher 精确 Set 匹配——两段式 concept 无序集合完全等于食谱集；(4) 打油诗 fallback——2/3 命中时消耗概念 +literary_fame，无 Poem trait；(5) poem_type 按钮改纯展示，全类型盲搜；(6) 删除副作用 Trait 和虚伪反噬；(7) 食谱 required_fragments 直接使用两段式 concept uuid，不做四段提取。

---

## 核心玩法

### 匹配流程（V5）

```
玩家选 3 个 ImaginaryConcept（uuid_A, uuid_B, uuid_C）
                │
                ▼
    ┌───────────────────────┐
    │ 构建 concept Set:      │
    │ {A.uuid, B.uuid, C.uuid} │
    └───────────────────────┘
                │
                ▼
    ┌───────────────────────────────────┐
    │ 在食谱索引中查找精确匹配             │
    │ recipe_map[sorted_key] → Poem?     │
    └───────────────────────────────────┘
                │
        ┌───────┼───────┐
        ▼       ▼       ▼
    精确匹配  2/3匹配   <2匹配
        │       │       │
        ▼       ▼       ▼
    ✅ 创作   打油诗   ❌ 失败
    完整诗词  +literary  惩罚文案
             _fame      不消耗意象
```

### 精确匹配规则

- 玩家 concept Set 必须**完全等于**食谱的 required_concepts Set（无序比较）
- 匹配粒度：**两段式 concept uuid**，直接作为完整字符串比对
  - 例：食谱 `required_fragments = ["aesthetic:elegant", "emotion:ambition", "society:famine"]`
  - 玩家提交的 concept uuid 直接比对，不做任何字符串处理
- 全类型盲搜（不按 poem_type 过滤，遍历所有已加载食谱）

### 打油诗 fallback

| 属性 | 值 |
|------|-----|
| 触发条件 | 3 个 concept 中**恰好 2 个**命中同一食谱的 required_concepts |
| 消耗 | **消耗** 3 个 ImaginaryConcept |
| 产出 | **无 Poem trait**，仅 +literary_fame |
| literary_fame 增益 | +5（固定值，不受 Tier/Level/管道乘数影响） |
| 文案 | "意象未全，凑成一首打油诗，聊以自慰。" |

### 诗词上限检查

- **检查时机**：点击「开始创作」按钮时，而非面板打开时
- 检测 `PlayerState.created_poems` 中是否有未使用的诗词
- 有则拒绝创作并提示

---

## 收益公式

### Poem Level

```
poem_level = max(concept_A.level, concept_B.level, concept_C.level)
```

范围：0-2。

### Tier 合并

| 旧 Tier | 新 Tier | 名称 |
|---------|---------|------|
| 1 | 1 | 世俗 |
| 2, 3 | 2 | 诗史（合并） |

取 3 个 concept 的 `min(current_tier)` 作为整体 tier。
ImaginaryComprehender 合并逻辑同步修改：`current_tier` 上限从 3 降为 2。

### 收益表（合并后）

| Tier | base_secular | base_history | 说明 |
|------|-------------|-------------|------|
| 1 | poem_level × 10 | 0 | 纯赚钱 |
| 2 | poem_level × (-20) | poem_level × 20 | 亏钱赚文学声望 |

### 管道乘数（自动从匹配食谱的 specific_topic 获取）

| 管道 | Tier 1 | Tier 2 |
|------|--------|--------|
| SECULAR (GAN_YE, YING_ZHI) | history×0, secular×1.5 | history×1.0, secular×3.0 |
| BROADCAST (DENG_GAO, HUAI_GU, JI_LV, SHAN_SHUI) | history×0, secular×0 | history×1.2, secular×0 |

> ⚠️ **已删除副作用 Trait**（原 `[无病呻吟的废纸]` 和 `[触怒龙颜的死书]` + `political_purge_poem` push_event）。
> ⚠️ **已删除虚伪反噬**（原 IAM=zuanying + tier=3 阻断逻辑）。

---

## 食谱数据模型

### 食谱文件（已改为两段式）

| 文件 | specific_topic | required_fragments（两段式 concept uuid） |
|------|---------------|------------------------------------------|
| `poem_tian_cheng.tres` | GAN_YE | `aesthetic:elegant`, `emotion:ambition`, `society:famine` |
| `poem_weizuo_cheng.tres` | GAN_YE | `finance:broke`, `myth:animal`, `theme:history` |
| `poem_zheng_jianyi.tres` | GAN_YE | `health:exhausted`, `theme:martial`, `emotion:sorrow` |

### 食谱索引结构

```
Database.recipe_index: Dictionary[String, Poem]
  key = "aesthetic:elegant|emotion:ambition|society:famine"  # required_fragments 排序后 | 拼接
  value = Poem resource
```

key 构建方式：将 `required_fragments` 数组排序后以 `|` 拼接。

---

## 数据流（V5）

```
┌─────────────────────────────────────────────────────┐
│              食谱加载（Database._init）                │
│                                                      │
│  poem_recipes/*.tres                                 │
│    │                                                 │
│    ├─ 读取 required_fragments（两段式 concept uuid）   │
│    ├─ 排序拼接 → recipe_key                          │
│    └─ recipe_index[recipe_key] = Poem resource       │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│              PoemCrafter 用户操作                      │
│                                                      │
│  选 3 个 ImaginaryConcept (uuid_A, uuid_B, uuid_C)    │
│    │                                                 │
│    └─→ PoemCraftingCalculator.calculate_poem_grade() │
│          │                                           │
│          ├─ 1. 构建 concept_set = {A, B, C}          │
│          ├─ 2. 在 recipe_index 中精确查找            │
│          │     ├─ 命中 → Tier 收益计算               │
│          │     ├─ 2/3 子集 → 打油诗                  │
│          │     └─ <2 → 失败                          │
│          ├─ 3. poem_level = max(levels)              │
│          ├─ 4. min_tier → 收益公式                    │
│          ├─ 5. recipe.specific_topic → 管道乘数       │
│          └─ 6. 生成 Operators (money/literary_fame)  │
└─────────────────────────────────────────────────────┘
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd:1) | **重构** | poem_level=max(); Tier2&3合并; FragmentMatcher精确Set匹配; 打油诗fallback; 删除副作用Trait; 删除虚伪反噬 |
| [`core/fragment_matcher.gd`](core/fragment_matcher.gd:1) | **重构** | 从加权评分改为精确Set匹配+2/3子集检测；输入直接为两段式concept uuid |
| [`core/database.gd`](core/database.gd:1) | **修改** | _init() 加载 poem_recipes/*.tres，构建 recipe_index |
| [`core/model/poem.gd`](core/model/poem.gd:1) | **修改** | required_fragments 语义改为两段式 concept uuid |
| [`core/imaginary_comprehender.gd`](core/imaginary_comprehender.gd:1) | **修改** | current_tier 上限从 3 降为 2 |
| [`data/1_core_rules/poem_recipes/*.tres`](data/1_core_rules/poem_recipes/poem_tian_cheng.tres:1) | **修改** | required_fragments 从四段式改为两段式 concept uuid |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd:1) | **修改** | 断开 poem_type 按钮逻辑；调用新接口；打油诗渲染；上限检查移至按钮点击 |
| [`ui/poem_crafter.tscn`](ui/poem_crafter.tscn:1) | **修改** | poem_type 按钮改为纯展示（移除 toggle 逻辑）；PoemDemands 节点实例化 `poem_demands.tscn` 独立场景 |
| [`ui/poem_demands.gd`](ui/poem_demands.gd:1) | **新增** | 独立场景脚本，`_ready()` 中 call_deferred 自填充，遍历 `Database.recipe_index` 实例化 `poem_demand.tscn` 并填充 Title + ImaginaryDemand |
| [`ui/poem_demands.tscn`](ui/poem_demands.tscn:1) | **新增** | 独立场景，包含 SmoothScrollContainer＞V＞poem_demand 默认实例 |
| [`ui/poem_demand.tscn`](ui/poem_demand.tscn:1) | **新增** | 单独的 PoemDemand 场景模板（Title + ImaginaryDemand Label） |
| [`tests/test_poem_crafting_comprehensive.gd`](tests/test_poem_crafting_comprehensive.gd:1) | **修改** | 适配新匹配逻辑 |
| [`tests/test_poem_crafting_fragment.gd`](tests/test_poem_crafting_fragment.gd:1) | **修改** | 适配新 FragmentMatcher 接口 |
| [`tests/test_imagery_tier_system.gd`](tests/test_imagery_tier_system.gd:1) | **修改** | Tier 上限 2 |
| [`DOCUMENTATIONS/feature_intents/poem_imagery_matching.md`](DOCUMENTATIONS/feature_intents/poem_imagery_matching.md:1) | **更新** | 本文档 |

---

## 状态转换

```
[玩家打开诗词面板]
    │
    ├─ Category 无 tier（未合并）
    │   → UI 可见但不可选中
    │
    ├─ 选了 3 个已合并 Category
    │   → 预览 Tier 收益
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
            │         ├─ 消耗 3 个 Concept
            │         ├─ Poem.new() → PlayerState.created_poems
            │         └─ push_event("poem_reveal")
            │
            ├─ 2/3 子集匹配 → 打油诗
            │     ├─ 消耗 3 个 Concept
            │     ├─ literary_fame += 5
            │     └─ 文案提示
            │
            └─ <2 匹配 → ❌ 失败
                  ├─ 不消耗 Concept
                  └─ 惩罚文案："意象散乱，强行拼凑..."
```

---

## 架构决策记录

| # | 决策 | 结论 |
|---|------|------|
| 1 | Poem Level 公式 | `max(三个Concept.level)` |
| 2 | Tier 2&3 合并 | Tier >= 2 统一为 Tier 2；收益用原 Tier 3 公式（×20）+ 原 Tier 2 惩罚（-20） |
| 3 | FragmentMatcher 匹配方式 | 精确 Set 相等（无序），输入直接为两段式 concept uuid |
| 4 | 打油诗 | 2/3 子集命中 → 消耗概念 + literary_fame +5，不产 Poem trait |
| 5 | poem_type 按钮 | 改为纯展示筛选器，断开所有逻辑连接，全类型盲搜 |
| 6 | 管道乘数 | 保留，自动从匹配食谱的 specific_topic 获取 |
| 7 | 副作用 Trait | **删除**（原 `[无病呻吟的废纸]` 和 `[触怒龙颜的死书]` + political_purge_poem） |
| 8 | 虚伪反噬 | **删除** |
| 9 | 食谱索引位置 | Database._init() 加载 poem_recipes/*.tres → recipe_index |
| 10 | 诗词上限检查 | 移至「开始创作」按钮点击时检查 |
| 11 | 食谱数据格式 | required_fragments 直接存储两段式 concept uuid，不做四段提取 |
