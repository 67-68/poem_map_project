# Action System (行动系统)

## 相关文件
- `core/model/action.gd` — Action 数据模型（含 sub_actions 字段）
- `core/model/scene_action.gd` — SceneAction（含 main_tag）
- `ui/action_button.gd` — 行动按钮 UI 与点击处理
- `core/model/action_tag_filter.gd` — 事件标签过滤器
- `core/event_manager.gd` — 事件扫描与抽奖
- `characters/narrative_overlay.gd` — 叙事纸带渲染（含 Picker 呈堂）
- `characters/narrative_director.gd` — 叙事状态机（管理 picker 栈）

## 设计意图

### Sub-Action 系统
- Action 可携带 `sub_actions: Dictionary`（key=uuid, value=显示名）
- 点击带 sub_actions 的 Action 时，先弹出 Picker 让玩家选择子行动
- 每个 picker 选项携带父 Action 的 main_tag 元数据（为未来多行动混合选择做铺垫）
- 选中后：执行父 Action 的 operators → 以 AND 模式进行事件扫描（事件必须同时匹配 sub-action uuid 和父 action main_tag）
- Picker 在 operators 之前弹出（方案1），sub-action 选择影响后续效果

### Tag 匹配模式
- 默认 OR 模式：`current_action_tags` 中任一 tag 命中事件 `target_tags` 即通过
- Sub-action 触发 AND 模式（`context['tag_match_mode'] = 'all'`）：所有 `current_action_tags` 必须全部在事件 `target_tags` 中
