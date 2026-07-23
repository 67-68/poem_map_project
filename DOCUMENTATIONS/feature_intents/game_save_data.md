# GameSaveData — 运行时状态统一存储

## 涉及文件

- `core/model/game_save_data.gd` — 纯数据类 (RefCounted)，运行时所有可持久化状态的唯一真源
- `core/game_save.gd` — Autoload 包装 Node，持有 `GameSaveData` 实例
- `core/player_state.gd` — 改造：所有属性 getter/setter 代理到 `GameSave.data`
- `core/game_state.gd` — 改造：持久化字段代理到 `GameSave.data`
- `core/time_service.gd` — 改造：`_total_days_elapsed` / `_tick_checkpoint` 代理
- `core/database.gd` — 改造：`imaginaries_detail` 代理
- `core/runtime_probe.gd` — 适配新结构
- `ui/top_stat_item.gd` — 修复 UI 直读 `prop.val`
- `ui/left_player_panel.gd` — 修复 UI 直读 `prop.val`
- `ui/ambition_hud.gd` — 修复 UI 直读 `prop.val`
- `debuggers/property_label.gd` — 修复调试器直读 `prop.val`
- `project.godot` — 新增 `GameSave` autoload 注册

## 预期效果

将所有可持久化的运行时状态集中到一个 `GameSaveData` 实例中，各 Autoload 保留现有 API 签名完全不变，内部改为 getter/setter 代理到 `GameSave.data`。所有外部调用方零改动。

## 状态字段清单

| 分组 | 字段 | 来源 Autoload | 存储位置 |
|------|------|--------------|---------|
| 属性值 | `properties: Dictionary` | PlayerState | `GameSave.data.properties` |
| 情绪 | `emotions: Dictionary` | PlayerState | `GameSave.data.emotions` |
| Flag | `flags: Dictionary` | PlayerState | `GameSave.data.flags` |
| 特质 | `traits: Array[String]` | PlayerState | `GameSave.data.traits` |
| 身份 | `player_name`, `current_location` | PlayerState | `GameSave.data.*` |
| 野心 | `ambition_uuid`, `ambition_start_days` | PlayerState | `GameSave.data.*` |
| 行动 | `current_action_tags`, `last_action_tags` | PlayerState | `GameSave.data.*` |
| 诗词 | `created_poems: Array` | PlayerState | `GameSave.data.*` |
| 意象 | `imaginaries_detail: Dictionary` | Database | `GameSave.data.imaginaries_detail` |
| 世界 | `year`, `current_era`, `is_game_over`, `death_cause`, `ratio_time`, `mood` | GameState | `GameSave.data.*` |
| 时间 | `total_days_elapsed`, `tick_checkpoint` | TimeService | `GameSave.data.*` |

## 明确不迁移的内容

- **瞬态字段**：`_is_repeated_action`, `last_event`, `session_deferred_cleanups`
- **常量**：`start_year`, `end_year`, `time_span`, `max_imaginary_managable`
- **含 Callable 不可序列化**：所有 buffer/queue (`event_buffer`, `chat_buffer`, `master_timeline`, `event_queue`)
- **场景引用**：`map`, `faction_renderer`, `current_selected_poet`
- **静态定义**：`_imaginary_defs`（从 JSON 加载）、所有 Database 只读数据表
- **SourceOfTruth**：纯调试初始值注入，不纳入 GameSaveData

## 状态转换

1. **启动初始化**：`GameSave._init()` 创建 `GameSaveData()` 实例，所有字段为默认值
2. **SourceOfTruth 注入**：`PlayerState._ready()` 调用 `init_props()/init_traits()/init_flags()/init_emotions()` 从 `SourceOfTruth` 读取初始值并写入 `GameSave.data`
3. **运行时读写**：所有 operator → `PlayerState.append_stat()` → 管道修正 → `GameSave.data.properties[key] = new_val`
4. **保存**：`GameSave.data.to_dict()` 导出可 JSON 序列化的 Dictionary
5. **加载**：`GameSave.data.from_dict(d)` + 外部注入 Resource 对象（created_poems, imaginaries_detail）

## 关键设计决策

- **Property.val 变为模板默认值**，运行时值存在 `GameSave.data.properties`（避免 Resource 被运行时修改后无法区分初始值和当前值）
- **ambition 存 UUID 字符串**，PlayerState getter 从 Database 实时解析回 AmbitionData 引用
- **ambition 默认值 "" 和 -1**：`ambition_uuid` 默认为空字符串、`ambition_start_days` 默认为 -1，确保新游戏不自动激活野心。野心由 `event_intro_745` 事件管线中的 `AmbitionOperator` 负责激活（此时 `TimeService._total_days_elapsed` 已正确初始化为 268200+）。
- **RelationFlagManager 不动**：它本身无状态（纯 static func），数据已通过 flags 字典存储
- **所有 Autoload 的 @export var 保留**，仅内部改为 getter/setter → 编辑器 Inspector 依然可见，序列化不受影响
