# 诗词评分创作 — 功能意图

**状态**: 🔴 执行中（V9: 纯函数评分制 + 三级事件库抽奖）

---

## 意图摘要（<200字）

砍掉 V8 的 C(N,3) 食谱枚举。诗词创作改为线性评分制：根据 Imaginary 数量与等级打分，超出 `max_imaginary_managable` 的额外 Imaginary 每个扣 5 分。评分定基础等级（平庸/佳作/绝唱），再按比例概率升级。mode 硬赋值 secular/literary 值（干谒→64/0，登高→0/48）。从三个等级的 EventBase 事件库抽选具体诗词事件展示。所有参与计算的 Imaginary 全量消耗。

---

## 核心玩法

### 评分算法（V9）

```
score = Σ(每个 Imaginary 的贡献)

对每个 Imaginary（index 从 0 开始）:
  index < max_manageable  →  + (imaginary.level × 5)
  index >= max_manageable →  -5（溢出惩罚）
```

**如果 `imaginaries.size() < max_manageable`** → 计算函数返回错误，PoemCrafter 阻断创作。

### 等级阈值

| 等级 | score 范围 | 显示文本 | `Poem.level` |
|------|-----------|---------|-------------|
| 平庸 | < 25 | 平庸 | 1 |
| 佳作 | 25 ≤ score < 50 | 佳作 | 2 |
| 绝唱 | ≥ 50 | 绝唱 | 3 |

### 概率升级

纯函数仅输出 `upgrade_probability`，`randf()` 由 PoemCrafter 执行：

```
base_level < 3 时:
  upgrade_probability = (score - current_threshold) / (next_threshold - current_threshold)
  其中 current_threshold = (base_level - 1) × 25, next_threshold = base_level × 25
```

例：score=40 → base_level=2 (佳作), upgrade_probability=(40-25)/(50-25)=0.60 → 60% 概率升绝唱。

### mode → 值硬赋值

| Mode | secular_value | literary_value |
|------|:------------:|:-------------:|
| `gan_ye` (干谒权贵) | 64 | 0 |
| `deng_gao` (登高抒怀) | 0 | 48 |

### 纯函数契约

[`PoemCraftingCalculator.calculate_poem_grade`](core/poem_crafting_calculator.gd:1) 是**无状态、幂等纯函数**：

- 禁止 `randf()` / `Database` / `PlayerState` / `Time` 调用
- `max_manageable` 由调用方显式传入
- 仅输出计算值，不执行副作用

### 三级事件库

诗词展示事件从对应等级的 EventBase 抽取：

| EventBase | 等级 | fallback 事件 |
|-----------|------|--------------|
| `poem_level_1` | 平庸 | `poem_level_1_fallback` |
| `poem_level_2` | 佳作 | `poem_level_2_fallback` |
| `poem_level_3` | 绝唱 | `poem_level_3_fallback` |

### 意象消耗

创作成功后**消耗所有参与计算的 Imaginary**（全量清空 `Database.imaginaries_detail`）。

---

## 更改文件

| 文件 | 改动 |
|------|------|
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd:1) | **重写** — 纯函数评分 + 等级分 + 升级概率计算 |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd:1) | **修改** — `_on_button_pressed` + `_preview_current` 适配 V9 |
| [`core/event_manager.gd`](core/event_manager.gd:1) | **新增方法** — `draw_from_event_base` 从指定 EventBase 抽事件 |
| [`data/1_core_rules/events/poem_levels/eb_poem_level_1.json`](data/1_core_rules/events/poem_levels/eb_poem_level_1.json) | **新建** — 平庸事件库 |
| [`data/1_core_rules/events/poem_levels/eb_poem_level_2.json`](data/1_core_rules/events/poem_levels/eb_poem_level_2.json) | **新建** — 佳作事件库 |
| [`data/1_core_rules/events/poem_levels/eb_poem_level_3.json`](data/1_core_rules/events/poem_levels/eb_poem_level_3.json) | **新建** — 绝唱事件库 |
| [`data/1_core_rules/events/fallback/poem_level_1_fallback.tres`](data/1_core_rules/events/fallback/poem_level_1_fallback.tres) | **新建** — 平庸匿名诗 |
| [`data/1_core_rules/events/fallback/poem_level_2_fallback.tres`](data/1_core_rules/events/fallback/poem_level_2_fallback.tres) | **新建** — 佳作匿名诗 |
| [`data/1_core_rules/events/fallback/poem_level_3_fallback.tres`](data/1_core_rules/events/fallback/poem_level_3_fallback.tres) | **新建** — 绝唱匿名诗 |
