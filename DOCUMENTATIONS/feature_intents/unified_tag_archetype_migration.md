# 统一 Tag 系统 & Action Results → Archetype 迁移

## 意图

1. **废弃 `locational_tags` / `province_tags`**：Action 不再有独立的地区标签体系，所有 tag 合并为唯一的 `action_tags: Array[String]`。
2. **废弃 `action_results: Array[BaseOperator]`**：所有 operator 定义迁移到 archetype（`tools/data/event_archetypes.json`），Action 仅保留 `archetype_uuid` 指针。
3. **废弃 `AREA_TAGS` / `PROVINCES` 枚举**：这两个枚举从 `model/enumerates.gd` 中删除。

## 现状分析

| 概念 | 位置 | 用途 | 实际使用情况 |
|------|------|------|-------------|
| `Action._action_tags` | `core/model/action.gd:25` | 事件匹配（写入 `current_action_tags`） | **活跃** — ActionTagFilter 核心依赖 |
| `Action._locational_tags` + `_province_tags` → `area_tags` | `core/model/action.gd:33-42` | 设计上应该是事件匹配的地区维度 | **基本死代码** — 仅在 linter 中读取，ActionTagFilter 不使用 |
| `Action.action_results` | `core/model/action.gd:44` | 行动执行时的 operator 列表 | **活跃但分散** — 21 个 .tres 中还有残留，同时 archetype 路径也在使用 |
| `Action.archetype_uuid` | `core/model/action.gd:75` | 指向 archetype 的 success/cost/failure operators | **活跃** — `get_all_action_results()` / `get_cost_operators()` 已支持 |
| `Territory._editor_area_tags` + `_province_tags` | `world/province_resource.gd:10-11` | 地图地区标签，供 Decision 过滤用 | **活跃** — `decision_scroll.gd` 用 `location.area_tags` 过滤决策 |
| `ENUMS.AREA_TAGS` | `model/enumerates.gd:6-8` | 仅 2 个值：`AREA_HORSE_WEALTH`, `AREA_EXCESSIVE_OFFICIAL` | 基本无用 |
| `ENUMS.PROVINCES` | `model/enumerates.gd:132-136` | 仅 1 个值：`CHANG_AN` | 基本无用 |

## 变更范围

### Phase 1: 删除 Action 侧的死代码

**文件: `core/model/action.gd`**
- 删除 `_locational_tags: Array[ENUMS.AREA_TAGS]`（第 33 行）
- 删除 `_province_tags: Array[ENUMS.PROVINCES]`（第 34 行）
- 删除 `area_tags` 计算属性（第 35-42 行）
- 删除 `action_results: Array[BaseOperator]`（第 44 行）
- 简化：`_action_tags` 保持，`action_tags` 计算属性保持

**文件: `model/enumerates.gd`**
- 删除 `AREA_TAGS` 枚举（第 6-8 行）
- 删除 `PROVINCES` 枚举（第 132-136 行）
- 删除 `to_area_str()`（第 325-330 行）
- 删除 `to_province_str()`（第 339-344 行）

### Phase 2: 更新 Territory（保留但去枚举化）

**文件: `world/province_resource.gd`**
- `_editor_area_tags: Array[ENUMS.AREA_TAGS]` → `_editor_area_tags: Array[String]`（直接存字符串 key）
- `_province_tags: Array[ENUMS.PROVINCES]` → 删除，合并到 `_editor_area_tags`
- `area_tags` 计算属性简化为直接返回 `_editor_area_tags`
- `merge()` 方法相应调整

### Phase 3: 迁移 action_results → archetype

**文件: `core/model/action.gd`**
- `get_all_action_results()` 简化为仅走 archetype 路径（删除 `action_results` fallback）
- `get_cost_operators()` 保持不变（已仅走 archetype）
- `get_outcome_archetype_operators()` 保持不变

**文件: `parser/dsl_parser.gd`**（第 1564-1601 行）
- `_apply_custom_option()` 中不再写入 `action.action_results`，改为向 archetype 注入 operators
- 具体：`consume_leverage` / `poem_selector:*` 的 operator 注入目标从 `action_results` 改为对应的 archetype entry

### Phase 4: 清理所有消费方

以下文件引用 `action_results` / `area_tags` 需要更新：

| 文件 | 当前引用 | 变更 |
|------|---------|------|
| `ui/action_button.gd:9-12,44-46,70-71,214-219` | `action_results.size()`, `action_results` 遍历 | 改为走 archetype 路径 |
| `ui/main_action_button.gd:9-12,44-46,70-71,214-219` | 同上 | 同上 |
| `core/sub_action_executor.gd:73-78,126-130,138,154` | `action_results` 遍历 | 改为走 archetype 路径 |
| `core/action_hint_builder.gd:33-43` | `action_tags` 读取 | 保持（action_tags 保留） |
| `core/hints/action_hint_formatter.gd:162-166,306-310` | `action_results` 读取用于 preview | 改为走 archetype |
| `debuggers/event_action_tag_linter.gd:46-47` | `a.area_tags` 读取 | 删除 area_tags 检查逻辑 |
| `tests/test_action_manager_time.gd:20-21,25-26,62-78,85-86` | `action_results` 赋值 | 改为设置 archetype |
| `tests/test_sub_action_system.gd:87-102,163-164` | `action_tags` | 保持（action_tags 保留） |
| `tests/test_scan_and_push_operator.gd` | `current_action_tags` | 保持 |

### Phase 5: 迁移 .tres 文件

21 个 .tres 中有 `action_results` 引用，需要将其内容迁移到 `event_archetypes.json`：

| .tres | action_results 内容 | 目标 archetype |
|-------|-------------------|----------------|
| `feng_zhao.tres` | 1 个 operator | `feng_zhao_success` |
| `baiye_threaten.tres` | ConsumeRandomLeverageOperator | `baiye_threaten_success` |
| `baiye_poem_visit.tres` | PoemRewardOperator | `baiye_poem_visit_success` |
| `jiwen_leverage_exchange.tres` | ConsumeRandomLeverageOperator | `jiwen_leverage_exchange_success` |
| `fangshi_sell_poem.tres` | PoemRewardOperator | `sell_poem_success` |
| `jiaoyou_recite_poem.tres` | PoemRewardOperator | `recite_poem_success` |
| `zhengqian_poem_exchange.tres` | 1 个 operator | `zhengqian_poem_exchange_success` |
| `tut_duzhuo_heyaojiu.tres` | 2 个 operator (cost+gain) | `heyaojiu_success` |
| `tut_taoist_dispel_fog.tres` | 2 个 operator | 对应 archetype |
| `meet_youxiang.tres` (decision) | PushEventOperator | decision 不走 archetype? |
| `update_to_rank8_official.tres` (decision) | 1 个 operator | decision 不走 archetype? |
| `tut_zhu_liu_base.tres` | SetStayPlaceOperator | `zhuliu_base_success` |
| `tut_zhu_liu_upper.tres` | SetStayPlaceOperator | `zhuliu_upper_success` |

> ⚠️ **Decision 文件** (`meet_youxiang.tres`, `update_to_rank8_official.tres`) — 这些不是 Action 而是 Decision，它们的 `action_results` 是否需要迁移？Decision 体系是否有 archetype？

## 不变量 / 约束

1. `action_tags: Array[String]` 是唯一 tag 入口，语义不变（事件匹配）。
2. `archetype_uuid` 是唯一 operator 入口，不再有 `.tres` 内嵌 operator。
3. `Territory.area_tags` 保留但去除枚举依赖，直接存 String。
4. `PlayerState.current_action_tags` / `last_action_tags` 不变。
5. 事件匹配管道（`ActionTagFilter`）不变。
6. Decision 体系暂不纳入本次变更（需要确认）。

## 未知项（需要用户确认）

1. **Decision 的 `action_results`**：`data/3_actions_pool/decisions/` 下的 2 个 .tres 也有 `action_results`，是否一并迁移到 archetype？
2. **Territory 的 CSV 数据**：`_province_tags` 和 `_editor_area_tags` 在 CSV 中的列名和格式是否需要同步修改？
3. **event_archetypes.json** 目前不存在于 `tools/data/` 目录。archetype 数据存储在哪里？（可能是 `data/1_core_rules/` 下的 .tres 文件？）

## 相关文件汇总

### 直接修改
- `core/model/action.gd`
- `model/enumerates.gd`
- `world/province_resource.gd`
- `parser/dsl_parser.gd`
- `ui/action_button.gd`
- `ui/main_action_button.gd`
- `core/sub_action_executor.gd`
- `core/hints/action_hint_formatter.gd`
- `core/action_hint_builder.gd`
- `debuggers/event_action_tag_linter.gd`
- `tests/test_action_manager_time.gd`
- `tests/test_sub_action_system.gd`

### .tres 文件需迁移
- `data/3_actions_pool/actions/feng_zhao.tres`
- `data/3_actions_pool/actions/bai_ye/baiye_threaten.tres`
- `data/3_actions_pool/actions/bai_ye/baiye_poem_visit.tres`
- `data/3_actions_pool/actions/bai_ye/jiwen_leverage_exchange.tres`
- `data/3_actions_pool/actions/fang_shi/fangshi_sell_poem.tres`
- `data/3_actions_pool/actions/jiao_you/jiaoyou_recite_poem.tres`
- `data/3_actions_pool/actions/jiao_you/zhengqian_poem_exchange.tres`
- `data/3_actions_pool/actions/du_zhuo/tut_duzhuo_heyaojiu.tres`
- `data/3_actions_pool/actions/jiao_you/tut_taoist_dispel_fog.tres`
- `data/3_actions_pool/actions/zhu_liu/tut_zhu_liu_base.tres`
- `data/3_actions_pool/actions/zhu_liu/tut_zhu_liu_upper.tres`
- `data/3_actions_pool/decisions/meet_youxiang.tres`
- `data/3_actions_pool/decisions/update_to_rank8_official.tres`

### 可能涉及的 CSV 数据
- `base_province` / `territories` 相关 CSV（如果使用了 `AREA_TAGS` / `PROVINCES` 枚举列）
