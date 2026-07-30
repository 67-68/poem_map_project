# 社交三行动 — 需求文档

## 设计意图

为交游系统新增两个 sub-action，形成完整的社交谋略路线：**发现节点 → 积累把柄**。

### 动机

现有交游 sub-actions（同游长安、宣读诗词）侧重文雅社交和正面声望，缺少底层社交权谋路线。这三个行动补全了灰色区域的玩法空白。

---

## 行动一览

| Sub-action | UUID | 成本 | 概率 | 效果 |
|-----------|------|------|------|------|
| 坊间买醉 | `jiaoyou_tavern_gacha` | s_money(-15) + 1AP | 20% | 随机 T1 not_meet → know_about |
| 暗巷刺探 | `jiaoyou_leverage_farm` | m_money(-30) + 1AP | 50% | 随机给任意人一个把柄 |

## 状态机

### person_state 状态迁移
```
not_meet ──(坊间买醉 20%)──→ know_about
```

### leverage 生命周期
```
[无把柄] ──(暗巷刺探 50%)──→ [有把柄] ──(威胁/交好路由)──→ [消耗]
```

---

## 数据流

```
玩家选交游 → Picker 弹出
  ├── 选"坊间买醉" → possibility(20%) 
  │     ├── PASS → scan_events → 池空 → tavern_gacha_success_fallback
  │     │     └── archetype tavern_gacha_success:
  │     │           prop_sub(money, s_money_cost)|set_random_person_state(tier=1, state=know_about)
  │     └── FAIL → tavern_gacha_failure_fallback
  │           └── archetype tavern_gacha_failure:
  │                 prop_sub(money, s_money_cost)
  │
  ├── 选"暗巷刺探" → possibility(50%)
  │     ├── PASS → scan_events → 池空 → leverage_farm_success_fallback
  │     │     └── archetype leverage_farm_success:
  │     │           prop_sub(money, m_money_cost)|add_random_leverage()
  │     └── FAIL → leverage_farm_failure_fallback
  │           └── archetype leverage_farm_failure:
  │                 prop_sub(money, m_money_cost)
  │
```

---

## 引入的新系统

### RELATION_TARGET_TIER（社会阶层分级）

| 层级 | 成员 | 用途 |
|------|------|------|
| T1 市井 | hushang | 坊间买醉可发现 |
| T2 文人 | gaoshi, wangwei, zhengqian, qingliu | 未来中层级行动 |
| T3 权贵 | libai, lilinfu, jiwen, youxiangfu, waiqi, yangguozhong, guoguofuren | 未来高层级行动 |

### 把柄 key 池（10 个通用无状态 key）

debt_secret / family_scandal / past_crime / illicit_affair / tax_evasion / forgery / bribery_record / academic_fraud / embezzlement / betrayal_secret

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd) | **修改** | +RELATION_TARGET_TIER |
| [`core/operators/set_random_person_state_operator.gd`](core/operators/set_random_person_state_operator.gd) | **新建** | tier 筛选 + not_meet → know_about |
| [`core/operators/add_random_leverage_operator.gd`](core/operators/add_random_leverage_operator.gd) | **新建** | 随机 target + 随机把柄 key |
| [`core/operators/add_random_intro_operator.gd`](core/operators/add_random_intro_operator.gd) | **新建** | 随机 target + add_intro |
| [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) | **修改** | +3 个执行器 + 常量 + dispatch |
| [`tools/data/named_amounts.json`](tools/data/named_amounts.json) | **修改** | +xxs_success_rate=20 |
| [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) | **修改** | +6 个 archetype |
| [`model/enumerates.gd`](model/enumerates.gd) | **修改** | +3 个 ACTION_TAGS |
| [`data/3_actions_pool/actions/jiao_you.tres`](data/3_actions_pool/actions/jiao_you.tres) | **修改** | sub_actions 追加 3 个 UUID |
| `data/3_actions_pool/actions/jiao_you/tavern_gacha.tres` | **新建** | 坊间买醉 sub-action |
| `data/3_actions_pool/actions/jiao_you/leverage_farm.tres` | **新建** | 暗巷刺探 sub-action |
| `data/1_core_rules/events/fallback/tavern_gacha_success_fallback.tres` | **新建** | "酒肆奇遇" |
| `data/1_core_rules/events/fallback/tavern_gacha_failure_fallback.tres` | **新建** | "独饮空归" |
| `data/1_core_rules/events/fallback/leverage_farm_success_fallback.tres` | **新建** | "暗巷拾遗" |
| `data/1_core_rules/events/fallback/leverage_farm_failure_fallback.tres` | **新建** | "空守一夜" |
