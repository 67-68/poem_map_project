# 诗词评分创作 — 功能意图

**状态**: 🟢 V11（三大类意象 + 删除 intent + 发布效果）

---

## 意图摘要（<200字）

线性评分制不变。意象总数为 `max_imaginary_managable`（FIFO 保证不溢出），无需截断/溢出逻辑。创建 Poem 时删除 `poem.intent` 赋值，命中配方设 `poem.lore = true`。CheckButton「发布」勾选后调用 `PoemEffectCalculator` 计算效果并注入事件 ctx。

---

## V11 变更

| 变更项 | 说明 |
|--------|------|
| 删除 MODE_TO_INTENT | poem 不再有 intent 字段（TagManager 改为意象三大类计数） |
| 删除溢出 Slot 逻辑 | FIFO 已保证 `≤ max_imaginary_managable`，无需随机截断 |
| poem.lore | 命中配方时设为 `true`（表示有典故/出处） |
| CheckButton 发布 | 勾选→调用 `PoemEffectCalculator.calculate(poem)` → ctx.publish_effect |
| 意象数量不足阻断 | 保留：`< max_imaginary_managable` 仍阻断创作 |

### 评分算法（不变）

```
score = Σ(每个 Imaginary 的贡献)
index < max_manageable  → +(imaginary.level × 5)
index >= max_manageable → 不再到达（FIFO 保证）
```

### mode → 即时激励 (V10, 保留)

| Mode | 即时奖励 | named_amounts |
|:----:|:--------:|:---:|
| `gan_ye` (干谒权贵) | money | `m_money_gain` = 30 |
| `deng_gao` (登高抒怀) | prestige | `m_prestige_gain` = 5 |

## 更改文件

| 文件 | 改动 |
|------|------|
| `core/model/imaginary.gd` | V11: 新增 `imaginary_type` + `created_at_day` 字段 |
| `core/poem_effect_calculator.gd` | **新建** — 空壳类，calculate(poem) → effect_desc+rewards |
| `ui/poem_crafter.gd` | 删除 MODE_TO_INTENT/溢出Slot；poem.lore=true；CheckButton 发布效果 |
| `core/operators/roll_imaginary_operator.gd` | type 读取；duration_xun=5；FIFO 顶替 |
| `core/player_state.gd` | `_on_request_add_imaginary` 读 type+duration_xun=5+FIFO；`_enforce_imaginary_limit()` |
| `core/tag_manager.gd` | `_sync_poem_stance` + `_inject_poem_stance_death_tag` → 三大类计数 |
| `ui/trait_demonstrator.gd` | HSeparator 动态长度 + on_xun_tick 刷新 |
| `tools/data/imaginary_definitions.json` | 每个条目新增 `"type"` 字段 |
