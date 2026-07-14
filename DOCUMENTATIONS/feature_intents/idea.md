# Idea — 理念系统

## 设计意图

理念（Idea）是玩家可选择的长期加成策略。每个理念包含多个等级的 buff，玩家消耗资源逐步解锁更强增益。

V2 重构：从「直接操作属性值」改为「注册表修饰器模式」。

## 核心架构

```
BuffOperator（数据源） → GameSaveData.active_modifiers（注册表） → ModifierRegistry（查询） → 各执行管线
```

### 注册表条目格式

```json
{
  "source": "idea_chizibaiyi",   // 来源理念 UUID
  "type": "efficiency",          // 修饰器类型
  "named_key": "s_mod_pct",     // named_amounts.json 的 key
  "value": 20,                   // 运行时解析值
  "condition": BaseRequirements  // 可选条件
}
```

### ModifierType 枚举

| Type | 说明 | 集成点 |
|------|------|--------|
| `efficiency` | 属性获取效率百分比加成 | `PlayerState.append_stat()` |
| `per_xun_passive` | 每旬被动增长 | `SurvivalManager._process_single_xun()` |
| `action_specific` | 特定行动的属性加成 | `PropertyOperator.operate()` |
| `cap_boost` | 属性上限百分比加成 | `PlayerState.append_stat()` hard_max 约束 |
| `relation_speed_pct` | NPC 关系需求百分比减免 | `RelationFlagManager.get_help_requirement()` |
| `relation_speed_abs` | NPC 关系需求绝对旬数减少 | `RelationFlagManager.get_help_requirement()` |
| `npc_trade_tier` | NPC 交易档次步进（TODO） | 预留，待 NPC 交易系统实现 |

## 核心模型

| 字段 | 类型 | 说明 |
|------|------|------|
| `idea_buffs` | `Array[BaseOperator]` | 逐级解锁的 buff 列表，index = 等级。支持 `BuffOperator` 和 `MultiBuffOperator`（复合） |
| `current_idea_level` | `int` | 当前解锁等级（-1 未激活，0 为第一级） |
| `idea_demonstrations` | `Array[String]` | 每级对应的展示描述文本 |
| `idea_cost_name` | `String` | 升级消耗的属性名 |
| `idea_cost_amount` | `int` | 每次升级的固定消耗数值 |
| `counter_idea` | `String` | 互斥理念的 uuid，空=无冲突 |

## BuffOperator（重构后）

| 字段 | 类型 | 说明 |
|------|------|------|
| `named_amount_key` | `String` | `named_amounts.json` 的 key |
| `modifier_type` | `String` | 7 种修饰器类型之一 |
| `condition` | `BaseRequirements` | nullable — DSL requirement 条件 |
| `source_uuid` | `String` | 运行时由 Idea 注入 |

## MultiBuffOperator

当理念某级有多个 BuffOperator 时使用此容器类。`operate()` 和 `on_exit()` 会递归注入 `source_uuid`。

## 持久化

- `GameSaveData.current_unlock_ideas: Array[String]` — 已解锁理念的 uuid 列表
- `GameSaveData.active_modifiers: Array[Dictionary]` — 活跃修饰器注册表（持久化到存档）
- `GameSaveData.current_action_id: String` — 瞬态字段，用于 ActionMatchRequirement 条件匹配
- `Idea.current_idea_level` — 每个理念持有自己的等级（存于 `.tres` 资源中）

## 消耗资源映射

| 理念类别 | 消耗资源 | 具体理念 |
|---------|---------|---------|
| 兴 | `inspiration` | 赤子白衣、沉郁顿挫 |
| 势 | `momentum` | 折节干谒、草莽落拓 |
| 望 | `prestige` | 五陵年少、清流风骨 |

## 6 个理念一览

### 兴 — 赤子白衣（`idea_chizibaiyi`）↔ 沉郁顿挫

| Lv | idea_chizibaiyi | type | named_key | condition |
|----|----------------|------|-----------|-----------|
| 0 | 兴获取效率+20% | `efficiency` | `s_mod_pct`(20) | null |
| 1 | 每旬+2灵感 | `per_xun_passive` | `s_inspiration_gain`(2) | null |

| Lv | idea_chenyuduncuo | type | named_key | condition |
|----|------------------|------|-----------|-----------|
| 0 | 少陵原兴+80% | `action_specific` | `l_mod_pct`(80) | ActionMatch(action=`denggao_shaolingyuan`) |
| 1 | 城府获取+50% + 上限+50% | `efficiency`+`cap_boost` | `m_mod_pct`(50) | null |

### 势 — 折节干谒（`idea_zhejieganye`）↔ 草莽落拓

| Lv | idea_zhejieganye | type | named_key | condition |
|----|-----------------|------|-----------|-----------|
| 0 | 携诗拜谒+20% | `action_specific` | `s_mod_pct`(20) | ActionMatch(action=`baiye_poem_visit`) |
| 1 | 势上限+20% + 每旬+2定力 | `cap_boost`+`per_xun_passive` | `s_mod_pct`(20)+`s_talent_gain`(2) | null |

| Lv | idea_caomangluotuo | type | named_key | condition |
|----|-------------------|------|-----------|-----------|
| 0 | 势获取效率+20% | `efficiency` | `s_mod_pct`(20) | null |
| 1 | T1 NPC好感-1旬 | `relation_speed_abs` | `xs_xun_reduction`(1) | NPCTier(tier=1) |

### 望 — 五陵年少（`idea_wulingshaonian`）↔ 清流风骨

| Lv | idea_wulingshaonian | type | named_key | condition |
|----|--------------------|------|-----------|-----------|
| 0 | 每旬+2望 | `per_xun_passive` | `s_prestige_gain`(2) | null |
| 1 | 清流NPC交易+1档 | `npc_trade_tier` | `s_tier_step`(1) | NPCFaction(faction=qingliu) |

| Lv | idea_qingliufenggu | type | named_key | condition |
|----|-------------------|------|-----------|-----------|
| 0 | 每旬+2才华 | `per_xun_passive` | `s_talent_gain`(2) | null |
| 1 | 清流关系需求-50% | `relation_speed_pct` | `m_mod_pct`(50) | NPCFaction(faction=qingliu) |

## 冲突配对

| 理念 | counter_idea |
|------|-------------|
| `idea_chizibaiyi` | `idea_chenyuduncuo` |
| `idea_chenyuduncuo` | `idea_chizibaiyi` |
| `idea_zhejieganye` | `idea_caomangluotuo` |
| `idea_caomangluotuo` | `idea_zhejieganye` |
| `idea_wulingshaonian` | `idea_qingliufenggu` |
| `idea_qingliufenggu` | `idea_wulingshaonian` |

## 新文件清单

| 文件 | 说明 |
|------|------|
| `core/buff_operator.gd` | 重构：纯注册表模式，删除 prop_name/amount |
| `core/multi_buff_operator.gd` | 新增：复合 buff 容器 |
| `core/modifier_registry.gd` | 新增：注册表查询门面（static） |
| `core/requirements/action_match_requirement.gd` | 新增：行动 ID 匹配条件 |
| `core/requirements/npc_faction_requirement.gd` | 新增：NPC 派系匹配条件 |
| `core/requirements/npc_tier_requirement.gd` | 新增：NPC 阶层匹配条件 |
| `core/model/game_save_data.gd` | 扩展：active_modifiers + current_action_id |

## 修改的文件清单

| 文件 | 修改 |
|------|------|
| `core/idea.gd` | 注入 source_uuid，递归处理 MultiBuffOperator |
| `core/player_state.gd` | append_stat 集成 efficiency/cap_boost |
| `core/survival_manager.gd` | 新增 _apply_idea_per_xun_passives |
| `core/model/property_operator.gd` | operate 集成 action_specific |
| `core/sub_action_executor.gd` | 设置/清除 current_action_id |
| `core/relation_flag_manager.gd` | 新增 get_help_requirement/is_help_sufficient |
| `tools/data/named_amounts.json` | 新增 mod_pct/tier_step/xun_reduction 刻度 |
