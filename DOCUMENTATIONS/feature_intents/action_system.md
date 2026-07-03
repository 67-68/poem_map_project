# Action System (行动系统)

## 坊市子行动 Archetype（搬砖 / 以身试药 / 卖字 / 风骨卖字）

这四个行动是 `action_fangshi`（坊市）的 sub_actions，定义在 [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) 中。

### 设计意图

- **子行动 vs 独立行动**：子行动不是主行动（如拜谒/登高）的平级实体，而是挂在坊市 Action 的 `sub_actions` 列表下的子 Action。玩家先选坊市 → 弹出 Picker → 选具体子行动。
- **成功/失败对子模式（方案 B）**：以身试药、卖字、风骨卖字各拆分为 `xxx_success` / `xxx_failure` 两个独立 archetype，parent 均为空，不继承任何已有 archetype。搬砖为确定性行动，只有成功 archetype。
- **概率不进入 archetype**：成功/失败的概率由 Action 运行时字段 `possibility` 控制，archetype 仅定义成本和结果 DSL。`possibility` 需要在生成 .tres 文件后在 Godot 编辑器中手动配置。

### 数值映射（来自 named_amounts.json）

| Archetype | 消耗 | 成功收益 | 失败收益 |
|-----------|------|----------|----------|
| banzhuan | m_health_cost(-30) | l_money_gain(50) | 无（确定性） |
| shiyao_success | s_health_cost(-15) | xl_money_gain(80) | — |
| shiyao_failure | m_health_cost(-30) | — | poisoned + m_talent_gain(5) |
| maizi_success | s_health_cost(-15) + m_fame_cost(-5) | l_money_gain(50) | — |
| maizi_failure | s_health_cost(-15) | — | l_money_gain(50) + m_fame_cost(-5) |
| fgmaizi_success | s_health_cost(-15) | l_money_gain(50) + m_fame_gain(5) | — |
| fgmaizi_failure | s_health_cost(-15) | — | s_money_gain(15) + s_fame_gain(2) |

### 约束

- `poisoned` trait 已在 `model/enumerates.gd` TRAITS 枚举中注册，并在 `data/1_core_rules/traits/_traits.csv` 中配置（prop_sub health 15/旬，2旬到期自动移除）。
- 所有新 archetype 的 `era: ""`（无时代限制）、`universal_requirement: ""`（成本在 result 中以 prop_sub 表达）。

## 登高子行动 Archetype（曲江池 / 乐游原 / 少陵原）

这三个子行动挂载在 `action_denggao`（登高/远游）下，定义在 [`tools/data/event_archetypes.json`](tools/data/event_archetypes.json) 中。

### 设计意图

- 与坊市子行动同模式：先选登高 → 弹出 Picker → 选具体登高地点。
- 曲江池无失败 variant（确定性，对应 l_success_rate=100%）。
- 所有 archetype 的 `parent: ""`，与 denggao 父 archetype 及其他任何 archetype 无继承关系。
- 概率仅标注在 `possibility` 字段，运行时由 Action 系统处理，archetype 不做路由。

### 数值映射

| Archetype | 成功收益 | 失败收益 |
|-----------|----------|----------|
| qujiangchi_success | m_health_recovery(+30) | 无（确定性） |
| leyouyuan_success | l_health_recovery(+50) | — |
| leyouyuan_failure | — | health+15 + sprained_ankle trait |
| shaolingyuan_success | m_health_recovery(+30) + m_talent_gain(+5) | — |
| shaolingyuan_failure | — | s_talent_cost(-2) |

### 约束

- `sprained_ankle` trait 已在 `model/enumerates.gd` TRAITS 枚举中注册，并在 `data/1_core_rules/traits/_traits.csv` 中配置（行动时间 +1，2旬到期自动移除）。
- 所有新 archetype 的 `era: ""`（无时代限制）、`universal_requirement: ""`（成本在对应 .tres 的 action_results 中以 sub 类 operator 表达）。

## 相关文件
- `core/model/action.gd` — Action 数据模型（含 sub_actions / possibility / failed_result 字段）
- `core/model/scene_action.gd` — SceneAction（含 main_tag）
- `ui/action_button.gd` — 行动按钮 UI 与点击处理
- `core/model/action_tag_filter.gd` — 事件标签过滤器
- `core/event_manager.gd` — 事件扫描与抽奖
- `characters/narrative_overlay.gd` — 叙事纸带渲染（含 Picker 呈堂）
- `characters/narrative_director.gd` — 叙事状态机（管理 picker 栈）

## 设计意图

### Sub-Action 系统
- Action 可携带 `sub_actions: Array[String]`（Action UUID 字符串数组，运行时通过 `Database.get_action(uuid)` 解析为 Action 资源）
- 点击带 sub_actions 的 Action 时，先弹出 Picker 让玩家选择子行动
- 选中后：执行父 Action 的 operators → 以 AND 模式进行事件扫描
- **事件匹配使用子 action 的 tags 和 fallback**，而非父 action：
  - 子 action 是 SceneAction：用其 `main_tag` 作为事件桶 key，`action_tags` 进 `current_action_tags`
  - 子 action 是普通 Action：`main_tag` 传空串（全量桶），所有 `action_tags` 进 `current_action_tags`，靠 ActionTagFilter AND 模式做多 tag 交集过滤
  - `fallback_event_uuid` 始终取自子 action
- Picker 在 operators 之前弹出，sub-action 选择影响后续事件匹配

### Possibility 抽奖系统
- Action 可携带 `possibility: String`（archetype，来自 `tools/data/named_amounts.json`，默认 `"l_success_rate"`=100%）
- 点击 Action 时，在 sub-action Picker 弹出 **之前** 进行抽奖
- `generator > possibility`：有 active generator 时跳过抽奖
- 抽奖失败（`randi() % 101 > get_possibility_int()`）：执行 `failed_result.operate()` 并 return，不执行 operators / scan
- 可用 archetype：`s_success_rate=50` / `m_success_rate=80` / `l_success_rate=100`

### failed_result
- `failed_result: ChoiceResult` — 抽奖未中签时的兜底结果
- 默认值为空 ChoiceResult（无操作）
- 可通过编辑器配置为 PushEventOperator 等，用于触发失败叙事

### Tag 匹配模式
- 默认 OR 模式：`current_action_tags` 中任一 tag 命中事件 `target_tags` 即通过
- Sub-action 触发 AND 模式（`context['tag_match_mode'] = 'all'`）：所有 `current_action_tags` 必须全部在事件 `target_tags` 中

### Sub-Action Picker Tooltip 预览
- 当玩家 hover 子行动 Picker 项时，tooltip 向量层顶部显示预览文本（由 `action_button._build_sub_action_preview()` 构建）：
  - `概率: {n}%成功，`
  - `[成功效果]`: 遍历 `action_results` 的 `describe_preview()`，空则 fallback「成败未卜…」
  - `[失败效果]`: 遍历 `failed_result.operators` 的 `describe_preview()`，空则 fallback「后果难料…」
- 预览文本通过 `entity.set_meta("sub_action_preview", ...)` 从 `action_button` 传给 `picker_item`
- `picker_item._register_hover_popup()` 将预览前置插入 `vector_lines`，后接 archetype operators 描述
