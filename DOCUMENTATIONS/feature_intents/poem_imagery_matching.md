# 诗词意象匹配 — 功能意图

**状态**: ❌ 未实现（架构决策已定，待开发）

---

## 意图摘要（<200字）

诗词创作增加第二层校验：除了 Tier 等级匹配，还需检验玩家提交的具体意象是否贴合诗词主题。每首诗声明所需的四段式 Tag，玩家提交的 3 个意象展开为扁平 Set 后做交集匹配——精确 20 权重，同类 10 权重，每条 Fragment 只取最精确层，累计 30 解锁。同时增加诗词上限（同一时间仅持有一首）和使用后归档图鉴（附带使用情境描述）。移除 `basic_imaginaries` 中间态，Fragment 直接存储在 Category 上。

---

## 核心玩法

- **双层校验**：Tier 等级（木桶效应）→ Fragment 详细匹配（权重累加），任一未过则创作失败
- **权重规则（累加制，每条 Fragment 只取最精确匹配）**：
  - 精确匹配（4 段完全一致）：`A:B:C:D` → `A:B:C:D` = 20
  - 同类匹配（前 3 段一致）：`A:B:C:E` → `A:B:C:D` = 10
  - 无匹配：0
  - **同一条 Fragment 不重复计分**：若 `A:B:C:D` 精确命中，不再重复计算其 `A:B:C` 的同类分
  - 不同 Fragment 分别计分后**累加**，门槛 30
  - 举例：提交 `A:B:C:D` + `E:F:G:H` + `X:Y:Z:W`，诗词要求 `A:B:C:D` + `E:F:G:K`
    - `A:B:C:D` → 精确 20，不计同类
    - `E:F:G:H` → 同类 10（前 3 段匹配 `E:F:G`）
    - 合计 30 → ✅ 解锁
- **惩罚机制**：权重不足 → "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。" 浪费写诗机会但不消耗意象
- **诗词上限**：同一时间只能持有一首未使用的诗词（未来可扩展上限）。PoemCrafter 检测玩家已有诗词时拒绝创作并报错
- **图鉴归档**：诗词使用后移入图鉴页面，附带一句使用情境描述（如"呈于皇帝御览""题于长安酒肆墙壁"）。无描述则不显示该句，无默认 fallback
- **加载时膨胀**：所有四段式 Tag 在初始化时一次性膨胀为 `["A", "A:B", "A:B:C", "A:B:C:D"]` 存入 flat Set（用 `:` 分隔以兼容五维宪法），运行时纯 Set 交集，O(1)

---

## 数据流

```
事件获取意象 → 写入 Fragment（四段式 Tag）
                    ↓
           TagAdapter 加载时膨胀 → flattened Set
                    ↓
    ┌───────────────┴───────────────┐
    │                               │
    ↓                               ↓
ImaginaryComprehender            PoemCrafter
合并/坍缩 → tier + level         选 3 个 Category
                                    ↓
                            FragmentMatcher.match()
                              ├─ 收集 3 个 Category 的 expanded_tags
                              ├─ 与诗词 required_fragments 膨胀 Set 求交集
                              └─ 权重累加 → ≥30? 解锁 : 惩罚
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`core/model/imaginary.gd`](/core/model/imaginary.gd:1) | **重构** | 移除 `basic_imaginaries: Array[Dictionary]`，新增 `fragments: Array[String]` + `expanded_tags: Array[String]` |
| [`core/fragment_matcher.gd`](/core/fragment_matcher.gd:1) | **新建** | 加载时膨胀函数 + 运行时 Set 交集匹配 + 权重累加 |
| [`core/imaginary_manager.gd`](/core/imaginary_manager.gd:1) | **修改** | `add_imagenary()` 直接写入 Fragment，不再包装为字典 |
| [`core/imaginary_comprehender.gd`](/core/imaginary_comprehender.gd:1) | **修改** | `merge_category()` 从 `fragments` 读取，坍缩后清空保留到 `merged` |
| [`core/poem_crafting_calculator.gd`](/core/poem_crafting_calculator.gd:1) | **修改** | 注入 `FragmentMatcher` 调用，双层校验返回值 |
| [`core/model/legendary_poem.gd`](/core/model/legendary_poem.gd:1) | **修改** | 新增 `required_fragments: Array[String]` 字段 |
| [`ui/poem_crafter.gd`](/ui/poem_crafter.gd:1) | **修改** | 过滤无 tier 的 Category + 上限检查（已有诗词则拒绝）+ 匹配进度 + 惩罚 UI |
| [`ui/poem_gallery.gd`](/ui/poem_gallery.gd:1) | **新建** | 诗词图鉴页面，展示已使用的诗词 + 使用情境描述 |
| [`core/model/poem_record.gd`](/core/model/poem_record.gd:1) | **新建** | 诗词归档数据结构：标题、内容、创作日期、使用情境（可选）、tier |
| 数据迁移脚本 | **新建** | 将现有 `basic_imaginaries` 字典迁移为 `fragments` 格式 |

---

## 状态转换

```
[玩家打开诗词面板]
    │
    ├─ 已有未使用的诗词
    │   → ❌ 拒绝创作，提示"已有诗作，先将其送出或题壁后再来"
    │
    ├─ Category 无 tier（未感悟/未合并）
    │   → UI 灰显，不可选中。需先合并碎片获得 tier 后才能用于创作
    │
    ├─ 选了 3 个已合并 Category（有 tier）
    │   → Tier 校验通过 → FragmentMatcher 匹配
    │       ├─ 权重 ≥ 30 → ✅ 创作成功，消耗 Category，新诗词覆盖旧诗词槽位
    │       └─ 权重 < 30 → ❌ 惩罚文案，保留 Category，浪费机会
    │
    ├─ Tier 校验未过（已有逻辑，不改动）
    │   → ❌ 直接失败
    │
    └─ 诗词被使用（赠诗/题壁/应制等）
        → 移入图鉴页面，附带使用情境描述（空则不显示该句）
```

---

## 开放问题

| # | 问题 | 决策 |
|---|------|------|
| 1 | 多个匹配级别权重是取最高还是累加？ | ✅ **累加（sum）** — 既有精确又有同类 → 20+10 |
| 2 | 膨胀后的层级分隔符用 `_` 还是 `:`？ | ✅ **`:`** — 与五维宪法 Tag 内部标准分隔符一致 |
| 3 | 惩罚文案是否根据当前 IAM（狂客/钻营/逢迎）有不同 flavor？ | ❓ 待定 — A: 统一文案 / B: 分 IAM 定制 |
| 4 | `merged` 字段存储原始四段式还是膨胀后的 Set？ | ❓ 待定 — A: 原始四段式 / B: 膨胀后 Set |
