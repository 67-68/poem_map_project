# Action System (行动系统)

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
- Action 可携带 `sub_actions: Array[Action]`（真实的 Action 资源数组）
- 点击带 sub_actions 的 Action 时，先弹出 Picker 让玩家选择子行动
- 每个 picker 选项携带父 Action 的 main_tag 元数据（为未来多行动混合选择做铺垫）
- 选中后：执行父 Action 的 operators → 以 AND 模式进行事件扫描（事件必须同时匹配 sub-action uuid 和父 action main_tag）
- Picker 在 operators 之前弹出（方案1），sub-action 选择影响后续效果

### Possibility 抽奖系统
- Action 可携带 `possibility: int`（0~100，默认 100）
- 点击 Action 时，在 sub-action Picker 弹出 **之前** 进行抽奖
- `generator > possibility`：有 active generator 时跳过抽奖
- 抽奖失败（`randi() % 101 > possibility`）：执行 `failed_result.operate()` 并 return，不执行 operators / scan

### failed_result
- `failed_result: ChoiceResult` — 抽奖未中签时的兜底结果
- 默认值为空 ChoiceResult（无操作）
- 可通过编辑器配置为 PushEventOperator 等，用于触发失败叙事

### Tag 匹配模式
- 默认 OR 模式：`current_action_tags` 中任一 tag 命中事件 `target_tags` 即通过
- Sub-action 触发 AND 模式（`context['tag_match_mode'] = 'all'`）：所有 `current_action_tags` 必须全部在事件 `target_tags` 中
