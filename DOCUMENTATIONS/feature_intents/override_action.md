# Override Action — Picker 右侧面板覆盖行动机制

## 设计意图

当玩家在 Picker 左栏选中一个 sub-action 后，右栏不仅显示默认的确认执行按钮，还动态展示「覆盖行动」按钮。覆盖行动由其他 Action 的 `override_action` 字段指向当前选中的 sub-action UUID 来定义，每个覆盖行动按当前场景的 NPC 生成独立按钮。

## 核心流程

```
玩家在左栏选中 sub-action (UUID=X)
  → 遍历所有 Action，找 override_action == X 的 Action（覆盖行动列表）
  → 对于每个覆盖行动 A：
      → 遍历所有 NPC 文档，筛选：preferred_places 包含 current_place AND current_day ∈ appear_days AND person_state ≠ uncharted
      → 每个匹配 NPC 创建一个 OverrideButton（显示 "NPC名 + 行动名"）
      → 锁定检查：若 A.uuid ∈ NPC.normal_actions AND NPC.person_state < know_about → 锁定（灰色）
      → person_state == uncharted 的 NPC 完全不显示对应按钮
  → 右栏底部保留默认 NpcActionButton（执行原始 sub-action X）
```

## 按钮状态矩阵

| person_state | 按钮创建? | action ∈ normal_actions | 最终状态 |
|-------------|----------|------------------------|---------|
| `uncharted` | ❌ 不创建 | - | 不显示 |
| `not_meet` | ✅ 创建 | 是 → 🔒 锁定 | `person_state < know_about` |
| `know_about` | ✅ 创建 | 是 → ✅ 解锁 | `person_state >= know_about` |
| `inner_circle` | ✅ 创建 | - | ✅ 解锁 |
| `blood_oath` | ✅ 创建 | - | ✅ 解锁 |

## 锁定条件

- 覆盖行动 A 的 UUID 出现在 NPC 的 `normal_actions` 列表中
- 该 NPC 的 `person_state` 低于 `"know_about"`（即 `"not_meet"`）
- 锁定原因："需要与{NPC名称}相识方可执行此行动"

## NPC 匹配条件

- `NPCDocument.preferred_places` 包含 `PlayerState.stay_place`（空数组 = 任意地点）
- `TimeService.current_day` 在 `NPCDocument.appear_days` 中（空数组 = 始终可用）
- NPC 的 `person_state` 不为 `"uncharted"`（未被发现的 NPC 不参与匹配）

## 涉及文件

| 文件 | 类型 | 说明 |
|------|------|------|
| [`core/npc_action_lock_checker.gd`](core/npc_action_lock_checker.gd) | 新建 | 锁定判定静态类 |
| [`ui/override_action_button.gd`](ui/override_action_button.gd) | 新建 | 覆盖行动按钮类 |
| [`ui/override_action_button.tscn`](ui/override_action_button.tscn) | 新建 | 按钮场景模板 |
| [`ui/picker_tape_attachment.gd`](ui/picker_tape_attachment.gd) | 修改 | 动态创建 OverrideButton + 默认 NpcActionButton |
| [`core/model/action.gd`](core/model/action.gd) | 已有字段 | `override_action` 字段 |
| [`model/npc_document.gd`](model/npc_document.gd) | 已有字段 | `normal_actions` / `preferred_places` / `appear_days` |
