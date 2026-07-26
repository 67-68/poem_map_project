# 入幕系统（Rumu System）— 功能意图

**状态**: 🏗️ 框架建立 + 10 archetype 创建完毕，fallback 事件复用 `event_cooldown_wall`

---

## 意图摘要（<200字）

为 `baiye_touzeng`（拜谒·入幕）行动提供 per-xun 事件选择机制。三种入幕模式（清流/浊流/富商）各有独立的 `ArchetypeEventPicker`，每旬均分概率选择 archetype，注入其 operators 到 fallback 事件。`ConsumeRandomPoemOperator` 支持诗词→属性转换。

---

## 10 个 Archetype 映射

| # | Mode | UUID | Cost DSL | Gain DSL |
|---|------|------|----------|----------|
| 1 | 清流 | `rumu_qingliu_money_to_prestige` | `prop_sub(name=money; val=l_money_cost)` | `prop_add(name=prestige; val=l_prestige_gain)` |
| 2 | 清流 | `rumu_qingliu_money_to_talent` | `prop_sub(name=money; val=l_money_cost)` | `prop_add(name=talent; val=l_talent_gain)` |
| 3 | 清流 | `rumu_qingliu_health_to_prestige` | `prop_sub(name=health; val=l_health_cost)` | `prop_add(name=prestige; val=l_prestige_gain)` |
| 4 | 清流 | `rumu_qingliu_health_to_talent` | `prop_sub(name=health; val=l_health_cost)` | `prop_add(name=talent; val=l_talent_gain)` |
| 5 | 浊流 | `rumu_zhuoliu_talent_to_momentum` | `prop_sub(name=talent; val=l_talent_cost)` | `prop_add(name=momentum; val=l_momentum_gain)` |
| 6 | 浊流 | `rumu_zhuoliu_poem_to_momentum` | `consume_random_poem` | `prop_add(name=momentum; val=m_momentum_gain)` |
| 7 | 浊流 | `rumu_zhuoliu_talent_to_money` | `prop_sub(name=talent; val=l_talent_cost)` | `prop_add(name=money; val=l_money_gain)` |
| 8 | 富商 | `rumu_fushang_talent_to_money` | `prop_sub(name=talent; val=m_talent_cost)` | `prop_add(name=money; val=m_money_gain)` |
| 9 | 富商 | `rumu_fushang_poem_to_momentum` | `consume_random_poem` | `prop_add(name=momentum; val=m_momentum_gain)` |
| 10 | 富商 | `rumu_fushang_poem_to_prestige` | `consume_random_poem` | `prop_add(name=prestige; val=m_prestige_gain)` |

**Fallback 事件**：所有 10 个 archetype 统一复用 `event_cooldown_wall`（archetype operators 在运行时由 `RandomEvent.init()` 注入）。

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/operators/consume_random_poem_operator.gd` | **新建** | `ConsumeRandomPoemOperator` — 随机消耗一首诗词 |
| `parser/micro_dsl_parser.gd` | **修改** | 注册 `consume_random_poem` DSL 函数 |
| `core/_export_dependency_anchor.gd` | **修改** | preload `ConsumeRandomPoemOperator` |
| `data/1_core_rules/archetypes/rumu_*.tres` | **新建** ×10 | 10 个 ActionArchetype |
| `model/rumu_qingliu_picker.gd` | **修改** | 填充 4 个 archetype keys |
| `model/rumu_zhuoliu_picker.gd` | **修改** | 填充 3 个 archetype keys |
| `model/rumu_fushang_picker.gd` | **修改** | 填充 3 个 archetype keys |

---

## ConsumeRandomPoemOperator

- DSL: `consume_random_poem`（无参数）
- 行为: 遍历 `PlayerState.get_traits()` 收集所有 `Poem` 实例 → `randi()%N` 随机选 → `PlayerState.remove_trait()`
- 无诗时: `Logging.err` + 静默返回
- 通知: `EventBus.on_trait_change.emit()`

---

## 待完成

1. 在 `resource_converters.csv` 的 `baiye_touzeng` 行 context 列添加 `event_picked_per_xun=rumu_qingliu_picker`
2. 为三种入幕模式创建独立的叙事 fallback 事件（当前复用 `event_cooldown_wall`）
3. 同步 CSV 后运行 CSV cloud loader 生成对应 `.tres`
