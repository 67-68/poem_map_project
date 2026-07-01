# [unreleased]

## Fixed

- **意象系统 .tres 脚本引用错误** — 32 个 ImaginaryConcept 资源文件引用错误的脚本
  - data/1_core_rules/imaginaries/*.tres — 批量修正 uid/script_class/path 从 imaginary.gd → imaginary_concept.gd
  - 根因：Phase 2 将 imaginary.gd 的 class_name 从 ImaginaryTag 改为 Imaginary，但 .tres 仍引用旧脚本，导致 Database.imaginaries 存储 Imaginary 而非 ImaginaryConcept，PoemCrafter 显示 0 个活跃概念
- **单意象左键=右键合并** — PoemCrafter 中 fragment_count==1 时左键直接触发合并
  - ui/poem_crafter.gd — _rebuild_subviewport() 中 fragment_count==1 时 concept_selected 信号连接至 on_concept_merge_requested
  - ui/poem_crafter.gd — 修正误导警告 "need ≥2 fragments" → "need ≥1 fragment"（l2_threshold=1 始终允许单碎片合并）
- **行动按钮 TOCTOU Bug** — 点击"拜谒"触发"独酌"事件的时序错误
  - [`core/action_manager.gd`](core/action_manager.gd:300) — 删除 `end_action_batch()` 中的 `request_refresh_action_panel.emit()`，全量按钮重建仅由 `on_xun_tick` 触发；锁定态增量更新由 `reevaluate_all_locks()` → `_refresh_locks_only()` 处理
  - [`ui/action_button.gd`](ui/action_button.gd:156) — `_on_button_pressed()` 在 `end_action_batch()` 之前快照 action 元数据（main_tag、fallback、generator、action_tags），事件扫描使用快照而非 `self.action`，防御 `refresh() → update_action()` 覆盖 `self.action`
  - 根因：`SceneActionScroll.refresh()` 调用 `update_action()` 在按钮自己的信号 handler 栈帧内替换了 `self.action`，导致后续代码读到错误的 action 引用（拜谒 → 独酌）

## Changed
- **属性矩阵大清理** — 属性从 12+6 缩减至 6 个核心属性
  - [`model/enumerates.gd`](model/enumerates.gd) — `PROPS` 枚举重构：只保留 `MONEY`, `HEALTH`, `TIME`, `LITERARY_FAME`, `PROGRESS`, `TALENT`
  - [`core/player_state.gd`](core/player_state.gd) — `init_props()` 适配新枚举，`TIME` 初始化为 10（每旬重置），`PROGRESS` 从 `resources.progress` 映射
  - **新增 `TIME` 属性**：每旬自动重置为 10，代表玩家可支配的时间资源
  - **废弃属性映射**：`fatigue`/`burnout`/`sick` → 并入 `health`；`progress`/`official_prestige` → 合并为 `progress`；`ambition`/`inspiration`/`drunk` → 删除
  - 代码层 12 个文件适配：所有 `player_state.gd`、`survival_manager.gd`、`month_end_settlement.gd`、`consequence_executer.gd` 等文件中的 `change_stat`/`get_stat_val` 调用全部迁移到新属性名
  - 16 个 Config JSON（`tools/event_base_config_*.json`）中 177 处 `operator_dsl`/`result` 属性引用全部替换
  - 16 个 CSV（`data/4_eras/747_kuangda/` 下各事件库）全量 reassembly 重生成

那个完全没有错误的git提交是错的. 我发现我打开了搜索框筛选了东西
太整蛊了, 搞了一个晚上 + 一个早上的注册表之类的方法尝试不要全部import, 最后发现项目体积和资源全部import差不多, 因为最后还是使用了直接打包assets文件夹
sometimes simpler is better, 总有可以优化的资源空间

## Added
- **NarrativeOverlay 动画策略系统** — 纸带入场动画支持从底部滑入
  - [`model/enumerates.gd`](model/enumerates.gd) — 新增 `enum ANIMATION_STRATEGY { DEFAULT, SLIDE_FROM_BOTTOM }`
  - [`model/ui_decl.gd`](model/ui_decl.gd) — 新增 `@export var animation_strategy: int` 字段（默认 0 = DEFAULT）
  - [`characters/tape_visualizer.gd`](characters/tape_visualizer.gd) — 新增 `play_show_tape_from_bottom()` 方法：shadow_box 从屏幕底部外（`y=+viewport`）CUBIC+EASE_OUT 滑入到 `_tape_target_y`
  - [`characters/narrative_overlay.gd`](characters/narrative_overlay.gd) — `_on_event_ready_to_play` 中 `else` 分支按 `data.ui_decl.animation_strategy` 路由：`SLIDE_FROM_BOTTOM` → `play_show_tape_from_bottom()`；其他 → `play_show_tape()`
  - 动画策略是每个事件的独立属性，事件结束后自动回归默认（DEFAULT），无需显式 revert
  - [`data/5_story_arcs/755_backhome/event_demo_slide_from_bottom.tres`](data/5_story_arcs/755_backhome/event_demo_slide_from_bottom.tres) — 演示事件，`animation_strategy=1`，选择后打印 info 无副作用
- **清流·焦虑** 事件库（4个事件：2 坊市 + 1 交游 + 1 独酌）
  - [`tools/event_base_config_qingliu_jiaolv.json`](tools/event_base_config_qingliu_jiaolv.json) — 事件配置，单维度 `jiaolv_scenario`（4 值），`BURNOUT>50 & MONEY 10-50 & AMBITION 30-100` 通用需求，`store_to` 路由到 fangshi/jiaoyou/duzhuo
  - [`tools/event_base_config_qingliu_jiaolv_sandbox.json`](tools/event_base_config_qingliu_jiaolv_sandbox.json) — 12 条叙事种子（每场景 3 条），单维度沙盒格式
  - [`data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv`](data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv) — 生成输出，4 事件 + 4 选项（单选设计）
  - 四个焦虑场景：status_tax（坊市的护城河 / 蜀锦袍子）、fomo_scam（情报贩子的杀猪盘）、illusion_control（赛博算命 / 胡僧玉佛）、doomsday_binge（鸩酒解渴 / 除夕买醉, scale=1.05）
  - 通用选项结果：`burnout+3 / fatigue+5`，各场景 operator 以 `money 大额流失` + `情绪惩罚` 为核心
  - Prompt 经 prompt-engineer 修复：移除过度拟合的具体比喻、消除「略带悲悯」与「不评判」的矛盾、叙事结构抽象为契约式约束
- **清流·道心破碎** 事件库（10个事件：3 独酌 + 7 社交）
  - [`tools/event_base_config_qingliu_daoxin_posui.json`](tools/event_base_config_qingliu_daoxin_posui.json) — 事件配置，10个维度组合，`BURNOUT>70` 通用需求，`store_to` 路由到 duzhuo/jiaoyou/fangshi/baiye
  - [`tools/event_base_config_qingliu_daoxin_posui_sandbox.json`](tools/event_base_config_qingliu_daoxin_posui_sandbox.json) — 30 条种子文本（每事件 3 条）
  - [`data/4_eras/747_kuangda/qingliu_daoxin_posui/_qingliu_daoxin_posui_events.csv`](data/4_eras/747_kuangda/qingliu_daoxin_posui/_qingliu_daoxin_posui_events.csv) — 生成输出，含完整 DSL 操作链
  - 独酌维度：frozen_imagery、subconscious_prosody、nonexistent_companion
  - 社交维度：poverty_as_aesthetic、porter_forbidden、echo_chamber_losers、empty_endorsement、asymmetric_sunk_cost、connection_reset、prop_at_banquet
  - 通用选项结果模板：`fatigue+8 / BURNOUT+5 / SORROW+5`
  - [`tools/event_generator/main.py`](tools/event_generator/main.py) — 新增 `--complete-uuids` CLI flag，支持指定 UUID 重新生成并保留其余行

## Fixed
- 云端 CSV 同步管线输出目录与 Registry 重构成 Bug
  - [`core/csv_cloud_loader.gd`](core/csv_cloud_loader.gd) — trait 数据 `save_path` 从 `res://data/tres_traits/traits.csv` 改为 `res://data/1_core_rules/traits/_traits.csv`，`.tres` 文件输出到 `data/1_core_rules/traits/` 目录，被 DataScanner 正确映射到 `bases["1_core_rules.traits"]`，修复了 `Database.get_trait("kuangda_kuangke")` 返回 `null` 的问题
  - [`core/csv_cloud_loader.gd`](core/csv_cloud_loader.gd) — 彻底移除 `_regenerate_registries()` 函数定义及全部 4 处调用点，废弃 `resources_registry_creator.gd` 在 CSV 同步管线中的使用，数据定位完全由 DataScanner 硬编码目录扫描完成

## Added
- **疾病系统（Disease 范例）** — Trait 子类 `Disease`，支持链式恶化、诊断事件、选项劫持
  - [`core/model/disease.gd`](core/model/disease.gd) — `Disease extends Trait`，新增字段：`on_enter_event`（诊断事件触发）、`progression_target` / `progression_xun`（旬数推进）、`hijack_provider`（选项劫持）
  - [`core/model/mania_provider.gd`](core/model/mania_provider.gd) — `ManiaProvider extends BaseProvider`，为狂症患者在所有事件选项中插入疯狂选项 + 增加健康消耗
  - [`core/model/trait.gd`](core/model/trait.gd) — topic 枚举新增 `DISEASE` / `MENTAL_ILLNESS`
  - [`core/event_manager.gd`](core/event_manager.gd) — `_guaranteed_event_key` 重构为 `_guaranteed_events: Array[Dictionary]` FIFO 队列，支持多事件堆叠
  - [`core/trait_operator.gd`](core/trait_operator.gd) — ADD 后检测 `Disease.on_enter_event` → `guarantee_next.emit()`
  - [`core/survival_manager.gd`](core/survival_manager.gd) — `aggregate_trait_effect()` 内检测 `Disease.progression_target` → `trait_replace`
  - [`model/event.gd`](model/event.gd) — `BaseEvent.init()` 内扫描玩家 trait，发现带有 `hijack_provider` 的 `Disease` 即调度劫持
  - `data/1_core_rules/disease/` — 4 个范例 Disease .tres（风寒急 / 肺痨 / 失意之郁 / 谵狂）、3 个诊断事件、1 个 ManiaProvider 配置
  - [`DOCUMENTATIONS/events/tag_dictioinary.md`](DOCUMENTATIONS/events/tag_dictioinary.md) — 新增 sick/sickAcute/sickChronic/MENTAL(depression/mania) 枚举
  - [`DOCUMENTATIONS/events/trait_designs.md`](DOCUMENTATIONS/events/trait_designs.md) — 新增「疾病系统 (Disease Subclass)」章节
- **疾病系统 Phase 2** — 污染事件库 + 桥接事件 + 现有事件库接入
  - [`data/1_core_rules/disease/_disease_contamination_events.csv`](data/1_core_rules/disease/_disease_contamination_events.csv) — 16 个污染事件（4 疾病 × 4 事件），使用 trigger_tags 按疾病阶段过滤：`[actor:health:sickAcute]` / `[actor:health:sickChronic]` / `[actor:mental:depression]` / `[actor:mental:mania]`
  - [`data/1_core_rules/disease/_disease_diagnosis_events.csv`](data/1_core_rules/disease/_disease_diagnosis_events.csv) — 5 个诊断+桥接事件（含 2 个 bridge 事件：fenghan_bridge / shiyi_bridge），桥接事件通过 `trait_add(name=disease_xxx)` 直接从 sick 态过渡到 Disease
  - [`data/1_core_rules/disease/event_disease_bridge_fenghan.tres`](data/1_core_rules/disease/event_disease_bridge_fenghan.tres) — 风寒急桥接事件 .tres 桩
  - [`data/1_core_rules/disease/event_disease_bridge_shiyi.tres`](data/1_core_rules/disease/event_disease_bridge_shiyi.tres) — 失意之郁桥接事件 .tres 桩
  - 接入 747_kuangda 事件库（4 CSV × 1 trait_add）：
    - [`data/4_eras/747_kuangda/_duotai_humiliation_events.csv`](data/4_eras/747_kuangda/_duotai_humiliation_events.csv) — 转身入人流 → `trait_add(name=disease_shiyi_depression)`
    - [`data/4_eras/747_kuangda/_qingliu_daoxin_posui_events.csv`](data/4_eras/747_kuangda/_qingliu_daoxin_posui_events.csv) — 墨滴隐字 → `trait_add(name=disease_zhanwang_mania)`
    - [`data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv`](data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv) — 买醉淋雨 → `trait_add(name=disease_fenghan_acute)`
    - [`data/4_eras/747_kuangda/_kuangke_zhuoliu_events.csv`](data/4_eras/747_kuangda/_kuangke_zhuoliu_events.csv) — 雪夜转身 → `trait_add(name=disease_fenghan_acute)`
  - 接入 745_ambition 事件库（1 CSV × 1 trait_add）：
    - [`data/4_eras/745_ambition/_scene_imagery_library_events.csv`](data/4_eras/745_ambition/_scene_imagery_library_events.csv) — 冷眼旁观 → `trait_add(name=disease_fenghan_acute)`
  - [`plans/disease_system_phase2.md`](plans/disease_system_phase2.md) — Phase 2 完整设计文档（疾病链生命周期、污染事件表、桥接事件、接入点）
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
