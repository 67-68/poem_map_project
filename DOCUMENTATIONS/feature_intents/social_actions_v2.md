# 六个社交行动 V2 — 需求文档

**状态**: 🟢 已编码（GDScript + JSON + .tres）

## 完整生命周期（V2）

```
玩家点选 sub-action（Picker）
  │
  ├─ 1. possibility 投骰（get_possibility_int() vs rand）
  │     ├─ PASS → 继续
  │     └─ FAIL → failed_result.operate() → 退出
  │
  ├─ 2. action_results 执行（init 链 → operate 链）
  │     来源: [action.archetype_uuid] → Database.get_archetype_by_uuid(uuid, "success")
  │           → ActionArchetype.universal_result（DSL 字符串）
  │           → MicroDSLParser.parse_consequence_operators()（预解析为 operator 数组）
  │           → Action.get_all_action_results() 返回该数组
  │
  │     .tres 的 action_results 字段留空（[]），不参与此路径。
  │     所有 operator 来自 archetype JSON 的 universal_result。
  │
  │     operator 执行顺序（init 链传递 context）:
  │       a) PickNpcOperator.init → 选人 → context[npc_target]
  │       b) PersonStateOperator.init → 捕获 context
  │       c) add_random_leverage.init → 捕获 context
  │       d) PropertyOperator.init → 无操作（prop 类型不需要 context）
  │       e) PickNpcOperator.operate() → 写 actor:npc:X + social:X 到 current_action_tags
  │       f) PersonStateOperator.operate() → set/upgrade person_state
  │       g) add_random_leverage.operate() → 加把柄
  │       h) PropertyOperator.operate() → append_stat（扣钱/加进度）
  │
  ├─ 3. 时间扣除（day_consumed + trait 惩罚）
  │
  ├─ 4. current_action_tags 追加 action 自身 tags（sub_action.action_tags）
  │
  └─ 5. scan_events(tag_match_mode='all')
        ├─ ActionTagFilter: 事件必须同时拥有 actor:npc:X + social:X 标签
        ├─ 命中 → EventBus.request_event_key → 纸带展示
        └─ 池空 → fallback_event_uuid 兜底叙事（{@npc_name} 动态插值）
```

## 行动列表

### ① 宴席 / 推荐信 (jiaoyou_hold_feast)

| 项 | 值 |
|----|-----|
| location | `pingkangfang` |
| archetype | `jiaoyou_hold_feast_success` (money -xl) |


### ② 普通拜谒 / 升级 (baiye_normal)

| 项 | 值 |
|----|-----|
| location | `huangcheng` |
| archetype | `baiye_normal_success` (money -m, progress +s) |

**action_results：**
```
pick_npc(mode=random; state=blood_oath; state_compare=lt; key=npc_target; social_tag=social:upgrade)
person_state(mode=upgrade; target_key=npc_target)
```

> `state=blood_oath; state_compare=lt` 过滤：排除已是最高级（blood_oath）的 NPC，not_meet / know_about / inner_circle 均可被选中升级。

### ③ 暗巷刺探 (jiaoyou_leverage_farm)

| 项 | 值 |
|----|-----|
| location | `xishi` |
| archetype | `jiaoyou_leverage_farm_success` (money -m) |

**action_results：**
```
pick_npc(mode=random; key=npc_target; social_tag=social:leverage)
add_random_leverage(target_key=npc_target)
```

### ④ 同游长安 (jiaoyou_tongyou_changan)

| 项 | 值 |
|----|-----|
| location | 无限制 |
| archetype | `jiaoyou_tongyou_changan_success` (money -s) |

**action_results：**
```
pick_npc(mode=random; key=npc_target; social_tag=social:acquaint)
```

### ⑤ 广发行卷 (baiye_mass_distribution)

| 项 | 值 |
|----|-----|
| location | `huangcheng` |
| archetype | `baiye_mass_distribution_success` (money -l) |

**action_results：**
```
pick_npc(mode=random; state=uncharted; key=npc_target; social_tag=social:baiye)
person_state(mode=set; state=not_meet; target_key=npc_target)
```

## 代码变更清单

### 新建文件
| 文件 | 说明 |
|------|------|
| [`core/operators/pick_npc_operator.gd`](core/operators/pick_npc_operator.gd) | 统一 NPC 选择器（3 mode） |
| [`core/operators/person_state_operator.gd`](core/operators/person_state_operator.gd) | 统一人物状态操作（2 mode） |

### 修改文件
| 文件 | 说明 |
|------|------|
| [`model/npc_document.gd`](model/npc_document.gd) | + `relate_to` + `person_state` 默认值 `uncharted` |
| [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd) | 五态状态机 + `UNCHARTED` |
| [`core/model/action.gd`](core/model/action.gd) | + `archetype_uuid` + `get_all_action_results()` |
| [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) | + `pick_npc`/`person_state` 解析 |
| [`ui/action_button.gd`](ui/action_button.gd) | init 链 + `get_all_action_results()` 合并 |
| [`core/operators/add_random_leverage_operator.gd`](core/operators/add_random_leverage_operator.gd) | + `target_key` + `init()` |
| [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) | + 12 个 archetype（6 success + 6 failure） |

### 需要手动编辑 .tres 文件（需在 Godot 编辑器中操作）

| 文件 | 改动 |
|------|------|
| `data/3_actions_pool/actions/jiao_you/jiaoyou_hold_feast.tres` | + action_results（3 个 operator）+ archetype_uuid="jiaoyou_hold_feast_success" |
| `data/3_actions_pool/actions/bai_ye/baiye_normal.tres` | action_results 替换占位符为 PickNpc + PersonState；+ archetype_uuid |
| `data/3_actions_pool/actions/jiao_you/leverage_farm.tres` | + action_results（2 个 operator）+ archetype_uuid |
| `data/3_actions_pool/actions/jiao_you/jiaoyou_tongyou_changan.tres` | + action_results（1 个 operator）+ archetype_uuid |
| `data/3_actions_pool/actions/bai_ye/baiye_mass_distribution.tres` | action_results 替换占位符为 PickNpc + PersonState；+ archetype_uuid |

### Fallback 事件（需手动编辑）

每个 fallback 事件的叙事文本需要支持 `{@npc_name}` 动态插值。

## 涉及 NPC 的 relate_to 配置

需要给以下 NPC 的 `.tres` 文件补充 `relate_to` 数据（用于未来社交场景）：

| NPC | 建议 relate_to |
|-----|---------------|
| libai | gaoshi, wangwei, zhengqian |
| wangwei | libai, zhengqian, qingliu |
| zhengqian | wangwei, gaoshi |
| gaoshi | libai, zhengqian |
| qingliu | wangwei, zhengqian |
