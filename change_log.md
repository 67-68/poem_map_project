# [unreleased]
## Changed
- `ScanAndPushOperator` 重构：删除内部重复的扫描/过滤管道，改为设置 `PlayerState.current_action_tags` 后委托给 `EventManager.scan_events_from_tickets(return_only=true)`，符合 DRY 原则
- `EventManager.scan_events_from_tickets()` 新增 `return_only` 参数：为 `true` 时返回选中事件 UUID 字符串，不发射 `request_event_key` 信号
- `test_scan_and_push_operator.gd` 全面适配新管道架构：19 个全部通过

## Added
- 3 个表演类随机事件：月下听琴（风雅）、胡旋醉舞（绮靡）、公孙剑器（雄健）
- 4 个新意象资源：entertain:elegant（风雅）、emotion:tranquility（旷达）、entertain:sensual（绮靡）、entertain:martial（雄健）
- 以上资源均注册到 tres_imaginaries_registry.tres 和 tres_random_event_registry.tres

## Removed
- 整个 Emotional Config 系统连根拔起 — 删除 `EmotionConfigs` 类、`ImagenaryEvaluator`、`ImaginaryManager` 节点及所有相关逻辑
- `BaseEvent.emotion_configs` 字段（`model/event.gd`）
- `EventOption.emotion_configs` 字段（`model/event/event_option.gd`）
- `ItemProvider.option_emotion_configs` 字段及相关逻辑
- `DSLParser` 中 `parse_emotion_configs` / `parse_single_emotion_config` / `get_imaginary_from_name` / `parse_single_emotion_condition` 方法
- `main.tscn` 中的 `ImagenaryManager` 节点
- CSV `emotion_config` 列
- 测试 `test_p2_parse_emotion_configs_*` 全套

## Added
- `PopToEventOperator` — 按事件 ID 寻址弹栈操作符，从栈中弹出到指定事件层级，未找到时报错无效果
- `EventBus.pop_to_event(event_key: String)` — 新信号，支持按 key 寻址弹栈
- `NarrativeOverlay._on_pop_to_event()` — 栈搜索 + 弹出到目标事件的处理器
- controller 支持 `$ dsl {consequence_operators}` 语法，可直接执行 DSL 操作符链
- `parse_flag_requirement` 的 int 分支实现（5 段式 `flag:int:OPERATOR:FLAG_ID:VALUE`）
- `interrupt_event(requirement_syntax, operator_syntax)` DSL 语法，用于事件触发前的中断检查（`interruptions` 列）
- `csv_cloud_loader.gd` 新增 `prefer_local_files` 选项，优先使用本地 CSV 文件，不存在时自动降级到云端拉取
- `csv_cloud_sync_cli.gd` 新增 CLI 入口脚本（extends SceneTree），支持 `godot -s` 命令行调用
- `godot_mcp.py` 自动识别 `csv_cloud_sync_cli.gd` 调用并追加 `--sync --prefer-local` 参数

## Fixed
- `DSLParser.parse_state_transistor()` CSV 列名对不上的 Bug：`target_resource_urn` → `target_resource`，`current_resource_urn` → `current_resource`，`triggered_event_key` → `triggered_event`

## Docs
- `controller_method.md` 添加 `$ dsl` 命令文档
- `parser/README.md` 补充 int flag requirement 5 段式语法，移除旧的歧义 4 段式文档
- `state_transistor.md` 修正 CSV 列名文档（去掉错误的 `_urn`/`_key` 后缀）

- 为死亡事件添加了两个测试事件，确保带tag的死亡事件可以正确被选择

# [0.8.0]
## Added
- eu4-like popup event system
- debug tool in navigation service for province connection
- debug overlay for province connection
- debug util
- character model instead of point
- time control GUI
- 年号
- chat bubble
- icon get logic: now can get use path but not only name
- can trigger plot as chain

## Fixed
- messager manager @tool error
- manually add connection to base province
- 触发逻辑
- icon can not parse
- focused chat can not trigger later event


# [0.7.0]
## Added
- after failed large batch refactor, I choose to refactor step by step
- poem data -> position point
- SizeService
- poem creation animation
- update popup appearance
- map
- text emitter
- click map can highlight
- faction render
- height map
- messanger

## Fixed
- can not load stamp config
- stamp level shiyi do not have texture
- low startup speed

# [0.4.0]
## Added
- start page


# [0.3.0]
## Added
- daylight
- rain
- controller ingame
- camera move

# [0.2.0]
## Added
- dataclass change to godot resource
- seperate pathpoint dataclass from poetdata
- change poet emotion into a area light
- adding universal light, activate when poet sad/happy extreme

# [0.1.0]
## Added
- 解析数据化作character point
- character point被点击切换颜色，使用tween平缓
- character point trail
- 时间slider
- slider经过十年出现提示左上角

## Fixed
- trail position 位置偏移
