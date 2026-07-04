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
- Action（含父 action 和 sub-action）可携带 `possibility: String`（archetype，来自 `tools/data/named_amounts.json`，默认 `"l_success_rate"`=100%）
- **父 action 抽奖**：点击 Action 时，在 sub-action Picker 弹出 **之前** 进行抽奖。`randi() % 101 > get_possibility_int()` 时执行 `failed_result.operate()` 并 return
- **Sub-action 抽奖**：玩家从 Picker 中选择子行动后，在 [`_on_sub_action_picked()`](ui/action_button.gd) 中对子 action 独立投骰：
  - `get_possibility_int() >= 100`：跳过投骰，确定性成功
  - `roll > threshold`：执行 `sub_action.failed_result.operate()`（含 PushEventOperator 推送失败事件），设置 `_sub_failed = true`
  - `roll <= threshold`：执行 `sub_action.action_results`（如存在）
  - 失败时 **跳过** `EventManager.scan_events()`，因为 `failed_result` 中的 PushEventOperator 已推送事件
  - 成功时正常调用 `scan_events()`，匹配不到事件时触发 sub-action 的 `fallback_event_uuid`
- `generator > possibility`：有 active generator 时跳过抽奖
- 可用 archetype：`s_success_rate=50` / `m_success_rate=80` / `l_success_rate=100`

### failed_result
- `failed_result: ChoiceResult` — 抽奖未中签时的兜底结果
- 默认值为空 ChoiceResult（无操作）
- 可通过编辑器配置为 PushEventOperator 等，用于触发失败叙事

### Fallback 事件（scan_events 池空时的兜底叙事）
- `fallback_event_uuid` 指向 `data/1_core_rules/events/fallback/` 下的事件 — 当事件扫描池空时触发
- **语义约定**：fallback 事件代表"一次正常但无特殊事件发生的行动"，**不是**"失败/无人问津"。应使用 success archetype（有收益），叙事基调为平和/成功
- Sub-action 成功路径（PASS）调用 `scan_events()`，若池空则 fallback 承担叙事
- Sub-action 失败路径（FAIL）由 `failed_result.operate()` 中的 PushEventOperator 直接推送 `_failed_fallback` 事件，不经过 scan_events
- 当前 fallback 事件及对应 archetype：

| Fallback UUID | Archetype | 叙事基调 |
|---|---|---|
| `fangshi_maizi_fallback` | `maizi_success` | 正常卖字交易 |
| `fangshi_shiyao_fallback` | `shiyao_success` | 正常试药换钱 |
| `fangshi_fgmaizi_fallback` | `fgmaizi_success` | 正常风骨卖字 |
| `fangshi_banzhuan_fallback` | `banzhuan_success` | 正常搬砖（确定性） |
| `denggao_qujiangchi_fallback` | `qujiangchi_success` | 正常登曲江池 |
| `denggao_leyouyuan_fallback` | `leyouyuan_success` | 正常登乐游原 |
| `denggao_shaolingyuan_fallback` | `shaolingyuan_success` | 正常登少陵原 |

- 对应的失败叙事在 `_failed_fallback` 变体中（如 `fangshi_maizi_failed_fallback`），由 possibility 失败路径的 PushEventOperator 直接推送

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

## HoverDisplayFlow — 统一 Hover 显示架构（v3.0）

`ui/hover_popup_manager.gd` 不再使用浮动 Popup，改用三种可插拔 FlowType 委托 `NarrativeOverlay` 面板呈现 hover 信息。

### FlowType 枚举

| FlowType | 触发场景 | Enter 动画 | Exit 动画 | 承载 UI |
|----------|---------|-----------|----------|---------|
| `SLIDE_FROM_RIGHT` | Action 按钮 hover | `TapeVisualizer.play_slide_in_from_right(0.3s)` → 整个 NarrativeOverlay 从右侧滑入 | 1s 后或行动开始时 `play_slide_to_right(0.3s)` 滑出 | `NarrativeOverlay.hover_container/hover_label` |
| `BELOW_OVERLAY` | Picker/EventBtn hover | `hover_container` 显形显示 | 0.15s 后或选项选择后 `hide_hover_text()` | `NarrativeOverlay.hover_container/hover_label` |
| `POPUP_LEGACY` | Ambition HUD | 原有浮动 popup（CanvasLayer 四象限定位） | `popup.visible = false` | `CanvasLayer + Control` |

### 架构

- `hover_popup_manager.gd`: `HoverBinding` 状态机不变，`SHOWING/IDLE` entry/exit 委托 `HoverDisplayDelegate` 子类
- 委托子类：`SlideFromRightDelegate` / `BelowOverlayDelegate` / `PopupLegacyDelegate`
- `narrative_overlay.gd`: 暴露 `show_hover_text(narrative, vector)` / `hide_hover_text()` 接口，操作 `HoverContainer`（tscn 内置 `HSeparator` + `Label`）
- `tape_visualizer.gd`: `play_slide_in_from_right(duration)` / `play_slide_to_right(duration)`
- 竞态：`SceneActionPanel._on_button_pressed()` / `NarrativeOverlay._on_event_ready_to_play()` / `PickerTapeAttachment._on_card_clicked()` 均调用 `HoverPopupManager.dismiss_all()`

### 消费方注册方式

```gdscript
# SLIDE_FROM_RIGHT — action hover
HoverPopupManager.register(self, {"narrative": hint["narrative"], "vector": hint["vector"]},
    0.2, 1.0, HoverPopupManager.FlowType.SLIDE_FROM_RIGHT)

# BELOW_OVERLAY — picker/event hover
HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text},
    0.2, 0.15, HoverPopupManager.FlowType.BELOW_OVERLAY)

# POPUP_LEGACY — ambition hover (行为不变)
HoverPopupManager.register(_ambition_btn, ambition_hud, 0.2, 0.15,
    HoverPopupManager.FlowType.POPUP_LEGACY)
```

## ActionHintBuilder — 行动提示文本统一构建器

静态工具类 `core/action_hint_builder.gd`，将所有 Action hover 提示文本的格式化逻辑集中到一处，消除重复。

### 设计意图

- **单一真相源**：所有 `describe_preview()` 遍历、operator 格式化、叙事层/向量层聚合均由此类负责，UI 控件（action_button、picker_item、event_btn）仅调用接口，不自行拼写文本。
- **两套接口覆盖两种场景**：主行动 hover（`build_action_hint` 输入一个 Action）和子行动 picker hover（`build_sub_action_preview` 输入 success/fail archetype operators）。
- **统一 hover 显示管道**：所有 hover 文本（锁定原因、success_hint、operator 预览）均通过 HoverPopupManager + NarrativeOverlay HoverContainer 呈现，不再使用原生 tooltip_text 或独立浮动 popup。
- **动态刷新**：`set_locked`/`set_unlocked` 触发 HoverPopup 注销+重建，hover 时永远拿到最新状态。

### 接口

| 方法 | 输入 | 输出 | 用途 |
|------|------|------|------|
| `build_action_hint(action, is_locked)` | Action + 锁定标志 | `{narrative, vector}` | 主行动按钮 hover popup |
| `build_operator_preview(operators)` | Array[BaseOperator] | Array[String] | 单列 operator 转 "• {desc}" 行 |
| `build_choice_result_preview(result)` | ChoiceResult | Array[String] | ChoiceResult 解包后委托 build_operator_preview |
| `build_sub_action_preview(action, success_ops, fail_ops)` | Action + archetype operators | String | 子行动 picker tooltip 专用格式 |

### 文件

- `core/action_hint_builder.gd` — 静态构建器（本模块）
- `ui/action_button.gd` — 消费方：主按钮 hover（SLIDE_FROM_RIGHT）、sub-action picker 预览
- `picker_item.gd` — 消费方：picker 项 hover（BELOW_OVERLAY）
- `characters/event_btn.gd` — 消费方：事件选项 hover（BELOW_OVERLAY）
- `ui/hover_popup_manager.gd` — 统一显示管道（v3.0 FlowType 架构）
- `characters/narrative_overlay.gd` — hover 文本渲染（HoverContainer/HoverLabel）
- `characters/tape_visualizer.gd` — 右侧滑入/滑出动画

## 重复行动疲惫系统（Repeated Action Fatigue）

### 设计意图

连续两次执行同一类型的行动时，第二次行动会受到 20% 的效益惩罚：
- 获得属性（val > 0）：减少 20%（×0.8）
- 消耗属性（val < 0）：增加 20%（×1.2）

这促使玩家在重复行动与切换行动之间做策略抉择。

### 状态模型

- `PlayerState.last_action_tags: Array[String]` — 持久状态，存上一次执行完成的 action 的识别 tag 集合
- `PlayerState._is_repeated_action: bool` — 瞬态快照，仅在当前 action 的 operators 执行期间有效
- `PlayerState.is_action_repeated(tags) -> bool` — 纯函数，检查给定 tags 是否与 last_action_tags 有交集

### 识别 Tag 匹配规则

- SceneAction：识别 tags = [main_tag] + action_tags
- 普通 Action：识别 tags = action_tags
- 交集匹配：当前 tags 集合 ∩ last_action_tags 非空 ⇒ 重复行动

### 生命周期

1. **Hover Preview 阶段**：`ActionHintBuilder` 读取 `last_action_tags`，临时设置 `_is_repeated_action` 调用 `describe_preview()`，展示调整后数值如「金钱 ↑↑↑：+40（原+50，重复行动-20%）」
2. **执行前**：`action_button._on_button_pressed()` / `_on_sub_action_picked()` 调用 `is_action_repeated()` 设置瞬态 `_is_repeated_action`
3. **执行中**：`PropertyOperator.operate()` 读 `_is_repeated_action` 决定是否乘倍率
4. **执行后**：更新 `last_action_tags` 为当前 action 的识别 tags

### Sub-action 两阶段处理

- Picker 选择：父 action 的 operators 未执行，不更新 `last_action_tags`
- `_on_sub_action_picked()`：在父+子 operators 执行前计算 `_is_repeated_action`（使用子 action 的识别 tags），执行后更新 `last_action_tags`

### 相关文件

- `core/player_state.gd` — `last_action_tags` + `_is_repeated_action` + `is_action_repeated()`
- `core/model/property_operator.gd` — `operate()` 倍率应用 + `describe_preview()` 调整后展示
- `core/action_hint_builder.gd` — `_check_repeated()` + hover preview 时临时设 `_is_repeated_action`
- `ui/action_button.gd` — `_on_button_pressed()` / `_on_sub_action_picked()` 中快照计算 + tags 更新
