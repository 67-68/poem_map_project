# 诗词意象匹配引擎 — 架构辩论报告与最终方案

> **状态：** 架构决策（最终版）
> **日期：** 2026-06-29
> **相关文档：**
> - [`imagery_tier_synthesis_poem_engine.md`](imagery_tier_synthesis_poem_engine.md) — V3 意象阶级·合成坍缩·诗词评价引擎
> - [`imaginary_system_report.md`](../imaginary/imaginary_system_report.md) — 意象系统技术报告
> - [`tag_dictioinary.md`](../events/tag_dictioinary.md) — 五维宪法
> - [`emotion_imagery_orthogonal_pipeline_v2.md`](emotion_imagery_orthogonal_pipeline_v2.md) — 意象获取管线 V2

---

## 0. 辩论背景

用户需要在现有的**意象阶级系统 (Tier 1-3)** 和 **三级抽象概念合成机制**之上，增加诗词的"意象匹配"逻辑。即：一首诗不只是看 Tier，还需要检验玩家提交的**具体意象**是否"贴合"这首诗的主题。

核心矛盾：如何在保留已有三段式 Category（如 `ENV_NATURE_GRASS`）和四段式 Fragment（如 `ENV_NATURE_GRASS:changanzacao`）的前提下，设计一套既不臃肿、又不依赖树状层级距离的匹配引擎。

---

## 1. 辩论过程回顾

### 1.1 用户原始方案 — 层级树临近度评分

```text
一首诗要求 A:B:C:D, E:F:G:K
玩家提交 A:B:C:D → 20 权重
玩家提交 A:B:C:F → 10 权重（partial match）
其他 → 0 权重
累计 30 权重 → 获得这首诗
```

**g 的诊断：**

| 维度 | 评价 |
|------|------|
| **架构定位** | 在独立游戏中手动构建 N 叉树层级结构，性价比极低 |
| **性能风险** | 权重评分需要遍历+嵌套比较，做不到 O(1) |
| **可维护性** | 每增加一个新意象需要重新调整整个树，填表地狱 |
| **玩家感知** | 玩家在 UI 上完全看不懂隐性的树状距离 |
| **反悔成本** | 极高，一旦铺开重构等于重写 |

### 1.2 g 提出的替代方案 — 扁平化 Tag 容器 + 加载时膨胀

**核心思路：** 运行时不做任何字符串匹配或树遍历，在数据加载时一次性将四段式 Tag 膨胀为扁平 Set。

```
原始: ENV_NATURE_GRASS_changanzacao
膨胀: ["ENV", "ENV_NATURE", "ENV_NATURE_GRASS", "ENV_NATURE_GRASS_changanzacao"]
```

匹配时只需 `Set.intersection()`，时间复杂度 O(1)。

**优势：**
- 保全了三段式/四段式机制在配置端的沉没成本
- 运行时极其简洁
- 绝对拒绝 `startswith` 和字符串遍历

### 1.3 用户的反驳 — 保留现有系统

> "问题在于，我之前已经搞了抽象层级了，我得为我已经完成的部分找点市场，要不然我就得重构大半个系统了"

**关键点：**
- 现有 Category 体系（`ImaginaryTag.uuid` = 三段式 Category）已在 [`ImaginaryComprehender`](../../core/imaginary_comprehender.gd) 中实现了合并/坍缩机制
- 现有 Tier 体系（1-3 级）已在 [`PoemCraftingCalculator`](../../core/poem_crafting_calculator.gd) 中实现了木桶效应 + 管道乘数
- 不希望重新设计整个意象存储结构

### 1.4 g 的妥协 — 加载时膨胀适配器

> "既然不能改祖宗之法（你的 JSON 格式），那我们就在数据加载层做手脚！绝对不要把脏活留到运行时。"

采用 **解析时膨胀 (Load-time Expansion)**：
- JSON 中的四段式 Tag 保持不变
- 游戏初始化时一次性膨胀为包含所有层级的扁平 Set
- 运行时仍然是纯粹的 Set 交集

---

## 2. 最终决策

### 2.1 诗词匹配的双层校验

诗词创作需要同时通过两层校验：

```text
┌─────────────────────────────────────────────────────┐
│              诗词创作校验管道                          │
├─────────────────────────────────────────────────────┤
│                                                      │
│  第一层: Tier 等级匹配 (已有，不变)                     │
│  ┌──────────────────────────────────────────────┐    │
│  │ min_tier 木桶效应 → 管道乘数 → Grade 计算      │    │
│  │ 来自 V3 引擎，不需要改动                        │    │
│  └──────────────────────────────────────────────┘    │
│                         ↓                             │
│  第二层: 详细概念匹配 (新增)                           │
│  ┌──────────────────────────────────────────────┐    │
│  │ 诗词配方声明 required_fragments（四段式 Tag 列表）│    │
│  │ 玩家提交的 3 个意象 → 展开为 flat Set            │    │
│  │ Set.intersection() → 权重累加 → 阈值判定       │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 2.2 权重评分规则

```
精确匹配 (4段完全一致):    A:B:C:D → A:B:C:D    = 20 权重
同类匹配 (前3段一致):       A:B:C:E → A:B:C:D    = 10 权重
无匹配:                    A:E:F:G → A:B:C:D    = 0 权重
```

- 门槛: **30 权重** 即解锁该诗
- 实现方式: 在数据加载时将四段式 Tag 膨胀为 `[A, A:B, A:B:C, A:B:C:D]`，然后对膨胀后的 Set 做交集
- 精确命中的四级 Tag 权重 20，三级命中权重 10

### 2.3 数据流改动

```text
旧流程:
  事件获取碎片 → basic_imaginaries(中间态) → 合并为 Category → 合成抽象概念

新流程:
  事件获取碎片 → 直接存储为具体意象(Fragment) → 合并为 Category → 合成抽象概念
                               ↓
                        诗词匹配时直接参与 Set 交集

移除: basic_imaginaries 作为中间存储
保留: Category(ImaginaryTag) 作为升级/合并的载体
新增: Fragment 直接存储在 Category 上，不再包一层 basic_imaginaries 的字典壳
```

**关键改动：**

| 组件 | 旧设计 | 新设计 |
|------|--------|--------|
| 碎片存储 | `basic_imaginaries: Array[Dictionary]` (`{blueprint_id, contexts, tier}`) | 直接存储扁平 Tag Set（加载时膨胀） |
| 抽象概念合成 | 需要 basic_imaginaries 作为中间态 | 直接从 Tag Set 中提取前三段作为抽象概念 |
| 诗词匹配 | 遍历 basic_imaginaries 逐条比较 blueprint_id | Set 交集，O(1) |

### 2.4 惩罚机制（"你不会写"）

当玩家提交的 3 个意象的膨胀 Set 与任何诗词的 `required_fragments` 膨胀 Set 的交集权重 < 30：

> "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。"

- 浪费 AP/写诗机会
- 不产出任何诗词
- 不消耗意象（玩家保留意象，下次再试）

---

## 3. 架构约束与边界

### 3.1 不可触碰的底线

1. **运行时绝对禁止 `startswith`** — 所有字符串匹配必须在加载时完成膨胀
2. **禁止修改五维宪法的 Tag 格式** — `PREFIX_CATEGORY_TYPE_SPECIFIC` 格式不变
3. **保留现有 Tier 引擎** — [`PoemCraftingCalculator`](../../core/poem_crafting_calculator.gd) 的木桶效应 + 管道乘数逻辑不动
4. **保留 `ImaginaryTag` 核心角色** — Category 仍然是升级/合并的载体

### 3.2 数据流契约

```
事件触发
  │
  ├─→ ImaginaryManager.add_imagenary()
  │     └─→ 写入 Fragment 到 Category（不再经过 basic_imaginaries）
  │
  ├─→ ImaginaryComprehender.merge_category()
  │     └─→ 将 Category 下的 Fragments 坍缩为 tier + level
  │     └─→ 保留原始 Fragments 到 merged 字段（供诗词匹配使用）
  │
  └─→ PoemCrafter (诗词创作)
        ├─→ 第一层: PoemCraftingCalculator.calculate_poem_grade()（Tier 匹配）
        └─→ 第二层: FragmentMatcher.match_fragments()（详细概念匹配）
              └─→ 膨胀 Set 交集 → 权重累加 → 阈值判定
```

---

## 4. 实施任务列表

```text
诗词意象匹配引擎重构:
  - [ ] 新增 FragmentMatcher (core/fragment_matcher.gd) @high
        - load-time 膨胀函数: A:B:C:D → [A, A:B, A:B:C, A:B:C:D]
        - match(): 膨胀 Set 交集 + 权重累加（精确 20, 同类 10）
        - 阈值判定 (30) + 惩罚文案生成
  - [ ] 修改 ImaginaryTag 数据结构 @high
        - 移除 basic_imaginaries: Array[Dictionary]
        - 新增 fragments: Array[String]（存储膨胀后的 flat Set）
        - 新增 expanded_tags: Array[String]（已膨胀的完整标签集）
        - 保留 merged: Array（坍缩备份）
  - [ ] 修改 ImaginaryManager.add_imagenary() @medium
        - 不再包装为 {blueprint_id, contexts, tier} 字典
        - 直接写入原始四段式 Tag 到 fragments
        - 调用 TagAdapter 膨胀写入 expanded_tags
  - [ ] 修改 ImaginaryComprehender @medium
        - merge_category: 从 fragments 读取而非 basic_imaginaries
        - 坍缩后清空 fragments，保留到 merged
  - [ ] 重构 PoemCraftingCalculator @medium
        - 注入 FragmentMatcher 调用
        - 双层校验: tier 匹配 → fragment 匹配
        - 返回 PoemResult（含匹配详情）
  - [ ] 更新 PoemCrafter UI @low
        - 展示 FragmentMatcher 匹配进度（提示"还差 X 权重"）
        - 惩罚状态的 UI 反馈
  - [ ] 更新 LegendaryPoem 配置格式 @high
        - 新增 required_fragments: Array[String]（四段式 Tag 列表）
        - 保留 imagenary_demand（tier 校验用）
  - [ ] 数据迁移脚本 @medium
        - 将现有 basic_imaginaries 字典迁移为新 fragments 格式
        - 对每个 fragment 调用膨胀适配器
  - [ ] 测试并修改
  - [ ] 更新对应文档
  - [ ] 提交 commit
```

---

## 5. 开放问题

| # | 问题 | 决策 |
|---|------|------|
| 1 | 多个匹配级别权重是取最高还是累加？ | ✅ **累加**（2026-06-29） |
| 2 | Fragment 膨胀分隔符用 `_` 还是 `:`？ | ✅ **`:`**（2026-06-29，与五维宪法一致） |
| 3 | 惩罚文案是否根据当前 IAM 有不同 flavor？ | ❓ 待定 |
| 4 | `merged` 字段存储原始四段式还是膨胀后的 Set？ | ❓ 待定 |

---

## 6. 辩论附录：被否决的方案

### 方案 A：层级树临近度算法 ❌

- 否决原因：需要人工构建 N 叉树，维护成本灾难级，玩家感知差
- 反悔成本：极高

### 方案 B：运行时 startswith ❌

- 否决原因：O(N*M) 性能，幽灵 Bug（`GRASS` 误匹配 `GRASSHOPPER`）
- 反悔成本：低（但一旦上线难以修复）

### 方案 C：完全推倒重来 ❌

- 否决原因：破坏现有的 Tier 体系 + ImaginaryComprehender 的沉没投资
- 反悔成本：最高

---

**结论：** 采用加载时膨胀 + Set 交集的工业级标准解法，最大限度保留现有系统，只在 Fragment 存储层和诗词匹配层做最小侵入性改动。
