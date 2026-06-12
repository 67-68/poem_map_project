# [unreleased]
## Added
- 音效类别系统（AudioManager + UISoundComponent 联动）
  - [`core/audio_manager.gd`](core/audio_manager.gd) — `_load_sfx_categories()` 在 `_ready()` 时扫描 `assets/sounds/` 下所有一级子目录，预加载 `.ogg/.wav/.mp3` 到 `_sfx_category_cache` 字典
  - [`core/audio_manager.gd`](core/audio_manager.gd) — `play_sfx_category(category, pitch_rand)` 从指定类别缓存中随机选取一个音效播放
  - [`features/ui_sound_component.gd`](features/ui_sound_component.gd) — 新增 `click_category` / `hover_category` 字段，非空时走类别随机播放，空则向后兼容 `click_sound` / `hover_sound`
  - 使用方式：在 `assets/sounds/` 下建子目录（如 `click/`），放入 `.ogg` 文件，在 UISoundComponent Inspector 中设置 `click_category = "click"` 即可
- UI Jitter 抖动反馈
  - [`features/ui_sound_component.gd`](features/ui_sound_component.gd) — 新增 `enable_jitter` / `jitter_strength` / `jitter_duration` 导出字段
  - `_apply_jitter()` — 对父 Control 的 `position` 做 6 次随机微偏移 Tween 序列 + 最后归位，模拟触电式抖动

## Changed
- 叙事显示架构重构：`Background` (TextureRect) 重命名为 `EventUI`，独立脚本管理显示逻辑
  - [`characters/event_ui.gd`](characters/event_ui.gd) — 新增 `class_name EventUI extends TextureRect`
    - `display_instant()` — FAST 模式，瞬间填充所有 UI 元素（零回归）
    - `display_slow()` — SLOW 模式，打字机逐阶段显示（title → desc → example → option）
    - 打字机参数：`SLOW_SPEED=0.04s/字`（≈ 25 字/秒），`PHASE_PAUSE=0.6s` 阶段间停顿
    - 左键点击跳过当前阶段，自动进入下一阶段
  - [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) — `apply_narrative()` 路由分叉
    - `display_speed == SLOW` → 委托 `event_ui.display_slow()`
    - `display_speed == FAST`（默认） → 委托 `event_ui.display_instant()`
    - 删除直接操作 label 的硬编码代码
  - [`model/event.gd`](model/event.gd) — 新增 `DisplaySpeed` 枚举、`_namespace`、`display_speed` 字段（纯数据，零方法）
  - [`core/event_base_loader.gd`](core/event_base_loader.gd) — `_load_resource()` 扫描时自动填充 `_namespace` 和 `display_speed`
    - `_namespace` → 纯目录路径前缀（如 `"story_arcs.changan_rainfall."`）
    - `display_speed` → 当 `current_ns.begins_with("story_arcs.")` 时自动设为 `SLOW`
  - [`characters/narrative_overlay.tscn`](characters/narrative_overlay.tscn) — `Background` 节点重命名为 `EventUI`，挂载 `event_ui.gd`
  - 所有层级均注入完整日志链（EventBaseLoader → NarrativeOverlay → EventUI），支持 `Logging.info/debug` 追踪

## Added
- `AnimationObject` 类型体系 — 时间驱动舞台动画的一等公民抽象
  - `AnimationObject` (`model/animation_object.gd`) — `RefCounted` 基类，`finished` 信号 + `start()/stop()` 生命周期
  - `SlideAnimation` (`model/slide_animation.gd`) — 平滑缓动滑动，内部 Tween 强制 `TWEEN_PAUSE_PROCESS`
  - `ShatterAnimation` (`model/shatter_animation.gd`) — ShaderMaterial 切换粉碎解体
  - `FadeOutAnimation` (`model/fade_out_animation.gd`) — 透明度淡出销毁
  - `ImageHandle.create_slide()/create_shatter()/create_fade_out()` — 工厂方法（旧方法保留向后兼容）
  - `NarrativeOverlay._active_animations` + `track_animation()` — 事件队列自动等待动画播完再处理下个事件
  - 所有 AnimationObject Tween 均设置 `TWEEN_PAUSE_PROCESS`，世界暂停时动画继续播放

- `ImageManager` (Autoload) + `ImageHandle` — 统一的 stateful 图片管理架构
  - `ImageManager.present(tex, pos) → ImageHandle`：展示图片并返回操作句柄
  - `ImageManager.play_shatter(tex, pos)`：便捷 fire-and-forget 粉碎
  - `ImageManager.play_slide(tex, from, to)`：便捷 fire-and-forget 滑动
  - `ImageHandle.slide_to(target, duration) → Signal`：滑动到目标位置，可 await
  - `ImageHandle.shatter(duration, params)`：粉碎解体并自动销毁
  - `ImageHandle.fade_out(duration)`：淡出并自动销毁
  - `ImageHandle.set_opacity() / set_scale() / set_modulate()`：链式属性修改
  - 旧 `ImageEffectManager` 标记为 `@deprecated`，所有方法转发到 `ImageManager`

## Changed
- `GuaranteeNextOperator` 新增 `main_tag` 导出字段 — 可选限定保证事件仅在指定 main_tag 的抽奖中生效
- `EventManager.guarantee_next` 信号签名扩展为 `(event_key: String, main_tag: String)`
- `EventManager.roll_events()` 实现 guarantee 三路分支逻辑：
  - **分支 A**（无 main_tag）：通用保证，通过 `Database.find_triggerable_item` 旁路所有 filter 强制命中
  - **分支 B**（main_tag 匹配）：正常消耗 guarantee，从当前事件池中搜索
  - **分支 C**（main_tag 不匹配）：保留 guarantee 供后续抽奖使用，不消耗
- `test_guarantee_next_operator.gd` 新增 11 个测试覆盖三路分支 + 边界条件，28 个断言全部通过

## Added
- Cinematic Overlay System — 系统级过场容器，黑屏打字机文字序列，用于年份过渡、角色死亡墓志铭等叙事插叙
  - `CinematicOverlay` (CanvasLayer, layer=128) — 独立于 UI 层的全屏覆盖，打字机效果 + 淡入淡出
  - `cinematic` 作为事件栈第 3 种条目类型 — 与 BaseEvent、Picker 同级，复用 LIFO 栈生命周期
  - `PlayTransitionOperator` — 遵守 BaseOperator 契约，emit `push_cinematic` 推入栈
  - DSL 语法: `play_transition(texts=["天宝四年，秋。", "你踏入长安。"])`
- `mid_of_wenhuaquan_party` 事件新增「欣赏艺术」选项，使用 `ScanAndPushOperator` 扫描 `action:entertain:elegant` / `action:entertain:martial` 标签事件池，动态推送匹配的随机事件

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
