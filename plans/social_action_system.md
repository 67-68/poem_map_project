# 社交行动系统 — 架构设计文档 v4 (final)

> **核心原则：充血模型。** UI 层只传意图，不传成功/失败。事件内部裁决。
> **UX 原则：** 威胁和交好同时存在时，通过路由事件让玩家三选一（交好/威胁/返回），不自动裁决。
> **返回路径：** 通过 `social_data.origin_event_key` 将原事件 push 回栈顶（`_on_interrupt_pressed` 第 514 行已自动 erase `interrupt_event`，不会无限循环）。

---

## 新增算子

### 1. ConditionalRandomOperator

### 为什么需要它

现有底座：
- `ConditionalOperator` — 有双分支数组，但是纯条件判定（deterministic），无随机性
- `RandomOperator` — 有随机掷骰，但是无条件修饰、无双分支数组

需要融合两者：**条件修饰过的随机掷骰 + 双分支数组**。

### 文件

[`core/operators/conditional_random_operator.gd`](core/operators/conditional_random_operator.gd)

### 结构

```
ConditionalRandomOperator extends BaseOperator
├── @export var base_chance: int = 50           # 基础概率 (0-99)
├── @export var modifiers: Array[ChanceModifier] # 条件修饰符列表
├── @export var success_result: Array[BaseOperator]  # 成功分支
├── @export var fail_result: Array[BaseOperator]     # 失败分支
├── @export var success_hint: String = ""       # 成功 toast
└── @export var failed_hint: String = ""        # 失败 toast

ChanceModifier extends Resource
├── @export var trait_key: String = ""          # trait uuid (如 "kuangda_kuangke")
├── @export var delta: int = 0                  # 概率修正量 (+20 或 -30)
└── @export var label: String = ""              # 调试用标签 (如 "狂客修正")
```

### 执行逻辑

```
operate():
  effective = base_chance
  for each modifier in modifiers:
    if modifier.trait_key == "" or PlayerState.has_trait(modifier.trait_key):
      effective += modifier.delta
  effective = clamp(effective, 0, 99)
  
  roll = randi() % 100
  if roll < effective:
    execute success_result[]
    show success_hint
  else:
    execute fail_result[]
    show failed_hint
```

**关键设计：** `trait_key == ""` 的 modifier 无条件生效（作为基准偏移）。非空的才检查 PlayerState。

### 在 .tres 中的使用

作为 `ChoiceResult.operators[]` 或 `on_enter_result.operators[]` 的子资源。一个威胁事件可以这样：

```
on_enter_result = ChoiceResult(
  operators = [
    ConditionalRandomOperator(
      base_chance = 40,
      modifiers = [
        ChanceModifier(trait_key="kuangda_kuangke", delta=+30),   # 狂客+30
        ChanceModifier(trait_key="kuangda_zuanying", delta=+20),   # 钻营+20
        ChanceModifier(trait_key="kuangda_fengying", delta=-20),   # 逢迎-20
        ChanceModifier(trait_key="", delta=0),                      # 无旷达: 基准40%
      ],
      success_result = [PushEventOperator("event_threaten_success")],
      fail_result = [PushEventOperator("event_threaten_failed")],
      success_hint = "威胁奏效",
      failed_hint = "威胁被无视"
    )
  ]
)
```

---

## 数据流 v4 final（路由事件版）

```
BambooSlip 点击
  → context = {main_tag: trait_uuid}
  → EventManager.scan_events(0, context)
  → roll_events() 选中事件 ev_name (String)

  → 🪝 SocialActionResolver.enrich_context(ev, ev_name, context)
    → 从 context.main_tag 推导 relation_target
    → 查询 RelationFlagManager.get_leverage_keys(relation_target)
    → 无 leverage → 不注入，直接返回
    → 三级匹配 threaten_id + do_favor_id

    ┌─ 威胁和交好都存在 ─────────────────────────────────┐
    │ context["social_data"] = {                          │
    │   "threaten": threaten_id,                          │
    │   "do_favor": do_favor_id,                          │
    │   "target_tag": target_tag,                         │
    │   "origin_event_key": ev_name   ← 🆕 返回路径用      │
    │ }                                                   │
    │ context["interrupt_event"] = {                      │
    │   "text": "社交行动",                                │
    │   "event_key": "event_social_router"                │
    │ }                                                   │
    └────────────────────────────────────────────────────┘

    ┌─ 仅威胁存在 ───────────────────────────────────────┐
    │ context["interrupt_event"] = {                      │
    │   "text": "威胁",                                    │
    │   "event_key": threaten_id                          │
    │ }                                                   │
    └────────────────────────────────────────────────────┘

    ┌─ 仅交好存在 ───────────────────────────────────────┐
    │ context["interrupt_event"] = {                      │
    │   "text": "交好",                                    │
    │   "event_key": do_favor_id                          │
    │ }                                                   │
    └────────────────────────────────────────────────────┘

  → EventBus.request_event_key.emit(ev_name, context)
  → NarrativeOverlay.apply_narrative(ev, context)
  → EventUI 显示 interrupt 按钮

  ┌─ 用户点击按钮 → _on_interrupt_pressed() ─────────────┐
  │ 1. Pop 原事件（current_event_data）从栈顶               │
  │ 2. Push interrupt_event.event_key 到栈顶               │
  │ 3. _process_next() 接管新栈顶                         │
  │                                                      │
  │   pushed 的是 event_social_router:                   │
  │     router 展示 3 个 EventOption:                     │
  │      1. "交好" → ContextKeyPushEventOperator(        │
  │           context_key="social_data.do_favor")         │
  │      2. "威胁" → ContextKeyPushEventOperator(        │
  │           context_key="social_data.threaten")         │
  │      3. "返回" → ContextKeyPushEventOperator(        │
  │           context_key="social_data.origin_event_key") │
  │                                                      │
  │   防无限循环: _pending_interrupt_context 已 erase      │
  │   "interrupt_event" (第 514 行), 所以 push 回去的原    │
  │   事件不会再显示 interrupt 按钮 ✅                     │
  └──────────────────────────────────────────────────────┘
```

### 新增算子: ContextKeyPushEventOperator

类似 PushEventOperator，但 `event_key` 从 context 动态读取而非 @export 写死。

```
ContextKeyPushEventOperator extends BaseOperator
├── @export var context_key: String = ""  # 如 "social_data.threaten"
└── _captured_context: Dictionary

operate():
  event_key = 从 _captured_context 按 context_key 路径读取
  EventBus.push_event.emit(event_key, _captured_context)
```

> **为什么需要它：** router 事件的选项必须动态选择目标事件（威胁/交好的 event_id 是运行时决定的），无法用静态 PushEventOperator。

---

## 事件文件清单

### 新增文件

| 文件 | uuid | 说明 |
|------|------|------|
| `core/operators/conditional_random_operator.gd` | — | ✅ ConditionalRandomOperator + ChanceModifier（已交付） |
| `core/social_action_resolver.gd` | — | ✅ SocialActionResolver 核心模块（已交付） |
| `core/operators/context_key_push_event_operator.gd` | — | ContextKeyPushEventOperator — 从 context 动态读 event_key |
| `data/1_core_rules/relations/event_social_router.tres` | `event_social_router` | 🆕 路由事件 — 三选项（交好/威胁/返回） |
| `data/1_core_rules/relations/event_do_favor.tres` | `event_do_favor` | 默认交好（通用 fallback） |
| `data/1_core_rules/relations/event_threaten_generic.tres` | `event_threaten_generic` | 默认威胁（通用 fallback，ConditionalRandomOperator 裁决） |
| `data/1_core_rules/relations/event_threaten_kuangke.tres` | `event_threaten_kuangke` | 狂客-威胁（base_chance=70） |
| `data/1_core_rules/relations/event_do_favor_kuangke.tres` | `event_do_favor_kuangke` | 狂客-交好 |
| `data/1_core_rules/relations/event_threaten_fengying.tres` | `event_threaten_fengying` | 逢迎-威胁（base_chance=25） |
| `data/1_core_rules/relations/event_do_favor_fengying.tres` | `event_do_favor_fengying` | 逢迎-交好 |
| `data/1_core_rules/relations/event_threaten_zuanying.tres` | `event_threaten_zuanying` | 钻营-威胁（base_chance=60） |
| `data/1_core_rules/relations/event_do_favor_zuanying.tres` | `event_do_favor_zuanying` | 钻营-交好 |

### 已有文件修改

| 文件 | 修改 |
|------|------|
| `core/event_manager.gd` | ✅ roll_events() 后调用 SocialActionResolver.enrich_context()（已交付） |
| `core/social_action_resolver.gd` | 🆕 enrich_context 需要更新：注入 social_data + interrupt_event（路由模式） |
| `event_threaten_success.tres` | 移除意外 money+10 PropertyOperator |
| `event_threaten_failed.tres` | 补上 literary_fame -20 ChoiceResult |
| `parser/micro_dsl_parser.gd` | 🆕 注册 ContextKeyPushEventOperator |
| `parser/named_dsl_parser.gd` | 🆕 注册 context_key_push_event 关键字 |

### 不修改

| 文件 | 原因 |
|------|------|
| `ui/bamboo_slip.gd` | 🚫 UI 层，不需传 relation_target |
| `characters/event_ui.gd` | 🚫 interrupt_btn 机制不被改动 — 复用已有 `_setup_interrupt_from_context` |
| `characters/narrative_overlay.gd` | 🚫 `_on_interrupt_pressed` 已被完美复用，无需改动 |

### 旷达状态事件内部裁决参数

| 状态 | 威胁事件 | base_chance | 修正 |
|------|---------|-------------|------|
| 狂客 | `event_threaten_kuangke` | 70 | （狂客已通过路由进入，无需额外修正） |
| 逢迎 | `event_threaten_fengying` | 25 | （逢迎已通过路由进入，无需额外修正） |
| 钻营 | `event_threaten_zuanying` | 60 | （钻营已通过路由进入，无需额外修正） |
| 通用 fallback | `event_threaten_generic` | 40 | 空 trait modifier 基准 40% |

> **注意：** 旷达状态事件内部仍使用 `ConditionalRandomOperator`，但 base_chance 已反映该状态的倾向。这样可以后续扩展（比如加 `lilinfu_student` trait 修饰符）。

---

## 关键架构决策

| 决策 | 结论 |
|------|------|
| 成功/失败由谁裁决？ | 事件内部的 `ConditionalRandomOperator`，绝不泄漏到 UI 层 |
| 威胁和交好同时存在时？ | 路由事件（`event_social_router`）— 三选项让玩家选，不自动二选一 |
| 仅一个 action 存在时？ | 直接 inject 该 action 到 interrupt_event，跳过路由 |
| "返回"按钮行为 | `ContextKeyPushEventOperator(context_key="social_data.origin_event_key")` — 推回原事件 |
| 返回防无限循环 | `_on_interrupt_pressed` 第 514 行已 erase `interrupt_event`，push 回的原事件不再显示按钮 |
| SocialActionResolver 签名 | `enrich_context(ev: BaseEvent, ev_name: String, context: Dictionary) -> Dictionary` |
| SocialActionResolver 职责 | 事件 ID 路由 + interrupt_event 注入决策 |
| 旷达状态路由 | 确定性 — 狂客→狂客事件，逢迎→逢迎事件，钻营→钻营事件 |
| 通用 fallback | 一个通用事件，内部 ConditionalRandomOperator 随机裁决 |
| UI 层改动 | **零改动** — 完美复用已有 interrupt_btn 基础设施 |
| ContextKeyPushEventOperator | 替代 PushEventOperator，用于 router 的动态 event_key 选择 |
| 没有声明 success/failed 时 | Logging.err + 按钮不显示，不静默降级 |
