# RelationFlagManager — v4: 四态关系层级系统

## 设计意图

将 RelationFlagManager 的 `favor` 连续好感度系统替换为 `person_state` 四态离散关系层级系统。

### 动机

1. **叙事匹配**：好感度 47 和 53 在叙事上没有本质区别，但倍率差异却造成无意义精度
2. **状态天然离散**：每级跃迁规则完全不同（T0→T1 打探、T1→T2 熬时间、T2→T3 献祭），离散状态机天然匹配
3. **判责分离**：RelationFlagManager 只做数据层原子操作（字符串替换），所有升级条件的判断逻辑由外部 Operator/Action/Event 负责

### 关系层级四态

```
T0: not_meet    — 听闻/迷雾，节点灰暗，不可直接交互
T1: know_about  — 泛泛之交/脸熟，节点解锁，基础资源置换
T2: inner_circle — 入幕之宾/核心圈，产出「势」和政治情报
T3: blood_oath  — 生死之交/政治死党，无视规则以势碾敌
```

### 数据流

```
写入: Operator → RelationFlagManager.upgrade_person_state() → NPCDocument.person_state
读取: UI/Requirement → RelationFlagManager.get_person_state() → NPCDocument.person_state
倍率: PlayerState.append_stat() → RelationFlagManager.get_tier_multiplier() → 离散乘法表
持久化: GameSaveData._snapshot_npc_relations() → to_dict() → JSON
        GameSaveData.restore_npc_relations_to_documents() ← from_dict() ← JSON
```

## 变更清单

### 修改文件

| 文件 | 变更 |
|------|------|
| [`model/npc_document.gd`](model/npc_document.gd) | 删除 `favor` 字段 |
| [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd) | PERSON_STATE 扩展为4态；新增 `upgrade_person_state()` / `get_next_person_state()` / `get_tier_multiplier()`；新增 `_PERSON_STATE_ORDER` / `_TIER_MULTIPLIER_TABLE`；删除全部 favor API（`get_favor/set_favor/add_favor/clear_favor/has_favor_flag`）；删除信号钩子系统（`connect_to_player_state/_on_before_property_change/_calculate_favor_multiplier/get_and_reset_favor_multiplier`） |
| [`core/player_state.gd`](core/player_state.gd) | 好感度倍率调用替换为 `get_tier_multiplier()` 直接查询 |
| [`core/model/game_save_data.gd`](core/model/game_save_data.gd) | 删除 `favor` 持久化字段 |
| [`core/operators/advance_plot_placeholder_operator.gd`](core/operators/advance_plot_placeholder_operator.gd) | `add_favor()` → `upgrade_person_state()` |
| [`tests/test_relation_flag_manager.gd`](tests/test_relation_flag_manager.gd) | 新增四态/upgrade/tier_multiplier 测试 |
| [`DOCUMENTATIONS/feature_intents/relation_flag_manager.md`](DOCUMENTATIONS/feature_intents/relation_flag_manager.md) | 本文件 |

### 未修改

- `leverage` / `help` / `intro` 全部 API 保持不变
- `person_state` CRUD (`get/set/is/clear/get_known_targets`) API 签名不变
- `ENUMS.RELATION_TARGET` / `ENUMS.to_relation_str()` 不变
- `RELATION_TARGET_TIER` 不变

## PERSON_STATE 常量

```gdscript
const PERSON_STATE = {
    "NOT_MEET":     "not_meet",       # T0
    "KNOW_ABOUT":   "know_about",     # T1
    "INNER_CIRCLE": "inner_circle",   # T2
    "BLOOD_OATH":   "blood_oath",     # T3
}
```

## 新增 API

### upgrade_person_state

```gdscript
## 升级 target 的 person_state 到下一级（自动推算）。
## 返回 true 表示升级成功，false 表示已是最高级或状态异常。
## 外部调用方负责判责（金钱/物品/Title 检查），本函数只做数据操作。
static func upgrade_person_state(target_tag: String) -> bool
```

### get_next_person_state

```gdscript
## 返回 target 当前状态下可跃迁到的下一级 person_state。
## 线性链表: not_meet → know_about → inner_circle → blood_oath → ""
static func get_next_person_state(target_tag: String) -> String
```

### get_tier_multiplier

```gdscript
## 根据 target 当前 person_state 返回离散属性倍率。
## is_good=true 取好属性列，false 取坏属性列。
static func get_tier_multiplier(target_tag: String, is_good: bool) -> float
```

### 倍率表

| Tier | 好属性收益 | 坏属性惩罚 |
|------|:------:|:------:|
| T0 not_meet | 0.0× | 0.0× |
| T1 know_about | 1.0× | 1.0× |
| T2 inner_circle | 1.5× | 0.67× |
| T3 blood_oath | 2.5× | 0.4× |

## 已删除 API

```
❌ DEFAULT_FAVOR
❌ get_favor / set_favor / add_favor / clear_favor / has_favor_flag
❌ _current_favor_multiplier
❌ connect_to_player_state
❌ _on_before_property_change
❌ _calculate_favor_multiplier
❌ get_and_reset_favor_multiplier
```
