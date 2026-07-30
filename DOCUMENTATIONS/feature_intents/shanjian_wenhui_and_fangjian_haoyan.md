# 山间文会 / 坊间豪宴 — 需求文档

**状态**: 🟡 已编码，待测试

## 设计意图

为交游系统新增两个 faction 过滤的 NPC 发现行动：
- **山间文会**: 以声望 (prestige) 为门槛，发现清流人脉（T2 文人 + T3 李白）
- **坊间豪宴**: 以势力 (momentum) 为门槛，发现浊流人脉（T3 权贵）

## 行动一览

| 属性 | 山间文会 | 坊间豪宴 |
|------|:---:|:---:|
| **UUID** | `jiaoyou_shanjian_wenhui` | `jiaoyou_fangjian_haoyan` |
| **Parent** | `jiao_you` | `jiao_you` |
| **地点** | 无限制（城外山上） | `pingkangfang`（城内） |
| **门槛** | 望(prestige) ≥ 10 | 势(momentum) ≥ 10 |
| **消耗** | `l_money_cost`(-50) + `m_health_cost`(-30) | `xl_money_cost`(-80) |
| **胜率** | 80% | 80% |
| **成功** | pick_npc(faction=qingliu) uncharted → not_meet | pick_npc(faction=zhuoliu) uncharted → not_meet |
| **失败** | 扣钱扣血，无事发生 | 扣钱，无事发生 |
| **Tag** | `[30, 82]` | `[30, 83]` |

## 状态转换

```
玩家点选交游 → Picker
  ├── 山间文会 → 望 ≥ 10?
  │     ├─ 否 → 灰化: 声望不足
  │     ├─ 是 → 投骰 80%
  │     │     ├── PASS → 扣 l_money + m_health
  │     │     │         → pick_npc(faction=qingliu, state=uncharted)
  │     │     │         → person_state → not_meet
  │     │     │         → scan_events → fallback
  │     │     └── FAIL → 扣 l_money + m_health → fallback
  │
  └── 坊间豪宴 → 势 ≥ 10?
        ├─ 否 → 灰化: 势力不足
        ├─ 是 → 投骰 80%
        │     ├── PASS → 扣 xl_money
        │     │         → pick_npc(faction=zhuoliu, state=uncharted)
        │     │         → person_state → not_meet
        │     │         → scan_events → fallback
        │     └── FAIL → 扣 xl_money → fallback
```

## 核心改动：PickNpcOperator 扩展

新增 `faction` 参数 (`qingliu` / `zhuoliu`)，为空时完全向后兼容。

DSL 新语法：
```
pick_npc(mode=random; faction=qingliu; state=uncharted; key=npc_target; social_tag=social:acquaint)
```

**NPCSelector.select_by_faction()** 遍历 RELATION_TARGET，查 `ModifierConfig.NPC_FACTION_MAP` 过滤。

## 涉及文件

| 文件 | 改动 |
|------|------|
| [`core/operators/pick_npc_operator.gd`](core/operators/pick_npc_operator.gd) | + `faction` export + _pick_random 路由 |
| [`core/npc_selector.gd`](core/npc_selector.gd) | + `select_by_faction()` |
| [`model/enumerates.gd`](model/enumerates.gd) | + `ACTION_JIAOYOU_SHANJIAN_WENHUI`(82) + `ACTION_JIAOYOU_FANGJIAN_HAOYAN`(83) |
| [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) | `_exec_pick_npc_op` + faction 参数 |
| `data/1_core_rules/archetypes/jiaoyou_shanjian_wenhui_*.tres` | **新建** cost/success/failure (3) |
| `data/1_core_rules/archetypes/jiaoyou_fangjian_haoyan_*.tres` | **新建** cost/success/failure (3) |
| `data/3_actions_pool/actions/jiao_you/jiaoyou_shanjian_wenhui.tres` | **新建** |
| `data/3_actions_pool/actions/jiao_you/jiaoyou_fangjian_haoyan.tres` | **新建** |
| [`data/3_actions_pool/actions/jiao_you.tres`](data/3_actions_pool/actions/jiao_you.tres) | sub_actions +2 |
| [`data/1_core_rules/resource_converters.csv`](data/1_core_rules/resource_converters.csv) | +2 行 |
| [`data/1_core_rules/translations/_dynamic_events.csv`](data/1_core_rules/translations/_dynamic_events.csv) | +12 个 key |
| `data/1_core_rules/events/fallback/shanjian_wenhui_*_fallback.tres` | **新建** success + failed (2) |
| `data/1_core_rules/events/fallback/fangjian_haoyan_*_fallback.tres` | **新建** success + failed (2) |
