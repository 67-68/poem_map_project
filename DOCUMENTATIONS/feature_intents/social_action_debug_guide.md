# Social Action 排障手册

**最后更新**: 2026-07-12  
**范围**: `pick_npc` / `person_state` / `social_tag` 相关的社交行动全链路

---

## 1. 架构全景图

```
玩家点击主 Action（如 交游）
  │
  ├─ action_button._on_button_pressed()
  │     ├─ cost archetype init → operate（扣资源，选 NPC，注入 tag）
  │     ├─ 投骰 → outcome = success / failure
  │     ├─ [sub-action] → Picker → _on_sub_action_picked()
  │     └─ [非 sub-action] → action_results.operate() → scan
  │
  ├─ _on_sub_action_picked()（sub-action 回调）
  │     ├─ Step 1: cost.init() → PickNpcOperator 选 NPC → ctx["npc_target"]
  │     ├─ Step 3: 投骰 → _sub_outcome
  │     ├─ Step 4: cost.operate() → 扣钱 + tag 注入
  │     └─ 分支:
  │           SUCCESS → append tags + scan(required_tags, npc_target, …)
  │           FAILURE → sub_action.failed_result.operate()（如 PushEventOperator）
  │
  ├─ EventManager.scan_events(context)
  │     └─ ActionTagFilter.filter(tickets, context)
  │           └─ AND 模式: context.required_tags 全匹配
  │
  ├─ NarrativeDirector → _on_event_ready_to_play
  │     └─ event.init(context) → RandomEvent.init(context)
  │           ├─ archetype preinit: dup.init(context) ← ⚠️ 必须捕获返回值!
  │           └─ archetype_base+outcome: dup.init(context) ← ⚠️ 同
  │
  └─ ConsequenceExecuter.execute_result(choice_result)
        └─ PersonStateOperator.operate()
              └─ _captured_context["npc_target"] → set/upgrade person_state
```

---

## 2. 关键文件索引

| 文件 | 角色 | 重点关注 |
|------|------|----------|
| [`ui/action_button.gd`](ui/action_button.gd) | 行动入口，sub-action 回调 | `_on_sub_action_picked()` 577-680 行 |
| [`core/operators/pick_npc_operator.gd`](core/operators/pick_npc_operator.gd) | 选 NPC + 注入 tag | `init()` 返回 ctx，`operate()` 写 current_action_tags |
| [`core/operators/person_state_operator.gd`](core/operators/person_state_operator.gd) | 修改 person_state | `operate()` 从 `_captured_context` 读 npc_target |
| [`core/npc_selector.gd`](core/npc_selector.gd) | 三种选人模式 | `skip_availability` 参数 |
| [`core/npc_availability_manager.gd`](core/npc_availability_manager.gd) | NPC 时间窗口 | `appear_days` 是 1-based |
| [`model/random_event.gd`](model/random_event.gd) | 事件 init，注入 archetype operator | **258/276 行 init() 返回值必须捕获** |
| [`core/model/action_tag_filter.gd`](core/model/action_tag_filter.gd) | AND/OR tag 匹配 | `required_tags` vs `current_tags` |
| [`core/database.gd`](core/database.gd) | 事件桶索引 | `_extract_pool_tag()` — 事件无 `action:` 前缀 tag 不会入桶 |
| [`data/1_core_rules/resource_converters.csv`](data/1_core_rules/resource_converters.csv) | 所有 action 的 DSL 源头 | cost_dsl / success_dsl / failure_dsl / defer_dsl |

---

## 3. 已踩过的坑（按发现顺序）

### 坑 1: NPC 注册缺失

**症状**: `pick_npc` 选不到某个 NPC  
**根因**: NPC 不在 `ENUMS.RELATION_TARGET` 枚举 + `RELATION_TARGET_TIER` 分级表中  
**排查**: 
- 检查 [`model/enumerates.gd`](model/enumerates.gd:115) 是否有该 NPC
- 检查 [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd:68) 的 tier 表
- 检查 `data/2_characters/npc_docs/` 是否有 `.tres` 文件且 `preferred_places` 非空

### 坑 2: SetRandomPersonStateOperator 硬编码状态过滤（已废弃）

**症状**: 开局所有 NPC 都是 `uncharted`，但 operator 只接受 `not_meet`  
**根因**: [`set_random_person_state_operator.gd`](core/operators/set_random_person_state_operator.gd:44) 过滤条件 `!= NOT_MEET`  
**修复**: 改为 `!= UNCHARTED`（后改为不再使用此 operator，统一用 pick_npc + person_state）

### 坑 3: appear_days 1-based vs current_day 0-based

**症状**: NPC 在某些 day 永远不可用  
**根因**: `appear_days` 用 1-10，`TimeService.current_day` 是 0-9  
**修复**: [`NPCAvailabilityManager`](core/npc_availability_manager.gd:30) 内部 `day + 1` 转换  
**检查点**: 搜索日志 `NPCAvailabilityManager.*不可用`

### 坑 4: skip_availability 缺失 — "听人说起"不需要 NPC 在场

**症状**: 坊间买醉永远选不到指定 NPC  
**根因**: 酒馆"听人提起"不需要 NPC 物理在场，但 `NPCSelector` 强制检查 `appear_days`  
**修复**: 全链路加了 `skip_availability` 参数
- [`PickNpcOperator`](core/operators/pick_npc_operator.gd:53): `@export var skip_availability`
- [`NPCSelector`](core/npc_selector.gd:24): 三方法 + 参数
- [`MicroDSLParser`](parser/micro_dsl_parser.gd:1414): DSL 解析
- CSV: `pick_npc(…; skip_availability=true)`

### 坑 5: 事件不入桶 — `_extract_pool_tag` 硬编码 action: 前缀

**症状**: 专属事件 `_target_tags = ["actor:npc:shenyi", "social:acquaint"]` 永远匹配不到  
**根因**: [`_extract_pool_tag`](core/database.gd:900) 只接受 `action:` 前缀 tag 做桶 key  
**修复**: 改为接受任意非空 tag  
**检查点**: 搜索日志 `get_random_events: no events for main_tag`

### 坑 6: PickNpcOperator.operate() 无脑注入 tag + 失败也走专属事件

**症状**: 投骰失败仍展示成功叙事，且 `person_state` 不执行  
**根因**: [`_on_sub_action_picked`](ui/action_button.gd:638-672) 没有按 `_sub_outcome` 分支  
**修复**: 
- SUCCESS → 追加 sub_tags + inject social/actor + scan + archetype_base=success → person_state 执行
- FAILURE → 执行 `sub_action.failed_result.operate()`（PushEventOperator → 失败 fallback）
- **关键**: 失败时走 `failed_result`（.tres 文件中 `failed_result.operators[0]` 的 PushEventOperator），不是 `fallback_event_uuid`

### 坑 7: cost vs success 拆分 — person_state 在 success archetype 但 init 返回被丢弃

**症状**: `PersonStateOperator` 报 `npc_target 为空`（tavern_gacha/baiye_normal 都受影响）  
**根因**: [`RandomEvent.init()`](model/random_event.gd:258) 两处 `dup.init(context)` 丢弃了返回值  
**修复**: `context = dup.init(context)` — 链式传递

```
baiye_normal_success DSL:
  pick_npc(by_place) | person_state(upgrade) | prop_add(progress)

修复前:
  pick_npc.init(ctx) → 返回 {npc_target:"zhengqian"} → 丢弃!
  person_state.init(ctx) → ctx 仍为空 → operate 时 npc_target="" → 静默失败

修复后:
  ctx = pick_npc.init(ctx) → ctx 包含 npc_target
  ctx = person_state.init(ctx) → 正确拿到
```

---

## 4. 排障速查清单

当遇到「选不到人」「关系不变」「tag 不匹配」「事件不触发」时：

### 4.1 NPC 选择阶段

```
□ grep "NPCSelector.*选中 NPC" → 选中的是谁？
□ grep "跳过.*preferred_places" → 地点不匹配？
□ grep "跳过.*day=.*不可用" → 时间窗口？考虑 skip_availability
□ grep "跳过.*state=" → person_state 过滤掉了？
```

### 4.2 Tag 注入阶段

```
□ grep "PickNpcOperator.operate" → 注入了 actor:npc:X 和 social:X 吗？
□ grep "cost archetype operate.*tags now" → 当前 tags 列表正确吗？
□ grep "SUCCESS.*npc_target" → context 中有 npc_target 吗？
```

### 4.3 事件扫描阶段

```
□ grep "scan_events.*main_tag" → main_tag="" 是预期吗？非空会导致桶路由限制
□ grep "required_tags" → required_tags 是否只含 actor:npc: + social: 前缀？
□ grep "get_random_events.*for main_tag" → 事件桶是否有内容？
□ grep "Event added to pool" → 专属事件在池中吗？
```

### 4.4 事件执行阶段

```
□ grep "DIAG.*_on_event_ready_to_play" → context 中有 npc_target 吗？
□ grep "DIAG.*RandomEvent.init.*npc_target" → 传递正确吗？
□ grep "PersonStateOperator.operate" → _captured_context 有 npc_target 吗？
□ grep "RelationFlagManager.*person_state set to" → 写入确认
```

### 4.5 关系可见性

```
□ SocialConnectionPage: _rebuild_tree 是否在 show_page() 时被调用？
□ person_state 从 uncharted 变成 not_meet 后，SocialConnectionPage 应显示
```

---

## 5. DSL 书写规范

### 正确模式

```csv
# cost: 扣钱 + 选人（不依赖 outcome）
cost_dsl = "prop_sub(money)|pick_npc(mode=by_place; places=…; state=uncharted; social_tag=social:X)"

# success: 改状态（依赖 outcome=success 才执行）
success_dsl = "person_state(mode=set; state=not_meet)"

# failure: 扣钱或空（失败时只扣钱，不改关系）
failure_dsl = "prop_sub(money)"
```

### 关键规则

1. **`pick_npc` 放在 cost** — 选人 + tag 注入在投骰前完成，结果通过 `_sub_cost_ctx["npc_target"]` 传递给事件层
2. **`person_state` 放在 success** — 只有成功才改关系
3. **失败走 `failed_result`** — 不要用 `fallback_event_uuid`（那是 success 的 fallback）
4. **专属事件加桶标签** — 至少一个 tag 做 `_extract_pool_tag` 桶路由（不限定 `action:` 前缀）
5. **`skip_availability=true`** — 用于"听人说起"等不需要 NPC 在场的场景
