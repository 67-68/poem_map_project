# NotePage — 笔记/便签总览页（已实现）

## 设计意图

提供一个全屏覆盖的便签/笔记页面，作为「钩子触发系统」的展示界面。
玩家在游戏过程中触发特定条件（属性达标、Flag 变化、Trait 变化）时，
对应的 Note 会被触发并持久化，玩家可通过 NotePage 浏览已触发的笔记。

## 系统架构

```
[Note .tres] → DataScanner → Database.notes
                                    ↓
                            NoteManager (Autoload)
                            ├─ 建 _notes_by_prop 索引（PropertyRequirement 剪枝）
                            ├─ 监听 player_stat_changed / on_flag_change / on_trait_change
                            ├─ 满足条件 → note.triggered = true + GameSave 持久化
                            └─ 发射 EventBus.note_triggered 信号
                                    ↓
                            right_info_panel.gd
                            ├─ _special_label 显示「点击注解按钮查看关于「XX」的注解」
                            └─ 5s 后自动清除
                                    ↓
                            NotePage (ui/note_page.gd)
                            ├─ 左侧按钮列表（仅已触发笔记）
                            ├─ 右侧详情展示（Note 字段映射）
                            ├─ 打开时自动选中第一个 → 清除 SpecialLabel
                            └─ 无笔记时显示「暂无可查看的笔记」
```

## 页面布局

```
┌──────────────────────────────────────────────────────┐
│                                                [X]   │
│  ┌──────────────┬───┬──────────────────────────────┐ │
│  │ NoteAmount   │   │  DemonTitle (note.name)      │ │
│  │ "已触发 1/3"  │   │                               │ │
│  ├──────────────┤   │  DemonPoem (note.description) │ │
│  │ [Scroll]     │   │  "朝扣富儿门..."               │ │
│  │  [Btn] 坊市..│   │                               │ │
│  │  [Btn] 拜谒..│   │  DemonDescription             │ │
│  │              │   │  (note.description_explanation)│ │
│  │              │   │                               │ │
│  │              │   │  NoteTitle "注："              │ │
│  │              │   │  NoteNarrative                │ │
│  │              │   │  (note.note_narrative)         │ │
│  │              │   │                               │ │
│  │              │   │  NoteLogical                   │ │
│  │              │   │  (note.note_explanation)        │ │
│  │              │   │                               │ │
│  │              │   │  [Placeholder] 无笔记时显示    │ │
│  └──────────────┴───┴──────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## 数据结构

### Note (core/note.gd)

| 字段 | 类型 | 用途 |
|------|------|------|
| `uuid` | String | 唯一标识 |
| `name` | String | 笔记标题 |
| `description` | String | 诗词片段（DemonPoem） |
| `description_explanation` | String | 白话解释（DemonDescription） |
| `note_narrative` | String | 叙事文本（NoteNarrative） |
| `note_explanation` | String | 机制解释（NoteLogical） |
| `requirement` | BaseRequirements | 触发条件（PropertyRequirement/FlagRequirement 等） |
| `triggered` | bool | 是否已触发 |

### GameSaveData 新增字段

| 字段 | 类型 | 用途 |
|------|------|------|
| `triggered_note_uuids` | Array[String] | 已触发笔记的 UUID 列表（持久化） |

## 触发逻辑

### PropertyRequirement 剪枝

在 `NoteManager._load_and_index()` 中预建 `_notes_by_prop: Dictionary`：
```
{ "money": [Note_A, Note_B], "health": [Note_C] }
```
当 `player_stat_changed("money")` 时，只检查 `_notes_by_prop["money"]` 中的 Note，
避免 O(n) 全量遍历。

### 判定

```gdscript
if note.requirement.compare(PlayerState):
    note.triggered = true
    GameSave.data.triggered_note_uuids.append(note.uuid)
    EventBus.note_triggered.emit(note.uuid)
```

### SpecialLabel 清除路径

1. 用户在 NotePage 中 **选中** 笔记 → `_clear_special_hint()`
2. **5 秒超时** → SceneTreeTimer 自动清除

## 状态转换

```
NotePage 初始化（visible = false）
  │
  ├─ EventBus.note_page_toggled 接收 → toggle
  │    ├─ expand == false → show_page()
  │    │    ├─ refresh_list() → 加载已触发笔记列表
  │    │    ├─ 自动选中第一个笔记 / 显示待触发占位
  │    │    └─ 清除 SpecialLabel
  │    └─ expand == true  → hide_page()
  │
  ├─ show_page() 动画
  │    ├─ EventBus.narrative_tape_hide_requested (refcount++)
  │    ├─ BlurManager.show_cinematic_blur()
  │    ├─ await 0.5s
  │    ├─ Main.slide_panels_out()
  │    ├─ await 0.65s
  │    ├─ BlurManager.hide_cinematic_blur() + trigger_event_blur()
  │    ├─ 恢复原始 offset
  │    ├─ show() + tween（TRANS_CUBIC EASE_OUT）
  │    └─ expand = true
  │
  └─ hide_page() / X 按钮点击 / 选中笔记清除提示
       ├─ EventBus.narrative_tape_show_requested (refcount--)
       ├─ BlurManager.return_to_hub()
       ├─ Main.slide_panels_in()
       ├─ kill existing tween
       ├─ tween size→(103,47) position→(520,565) + callback hide()
       └─ expand = false
```

## 触发按钮

- [`right_info_panel.tscn`](ui/right_info_panel.tscn) 中 `NoteBtn`（带 note_stamp.png 图章图标）
- [`right_info_panel.gd`](ui/right_info_panel.gd:23) 中的 `_note_btn` onready 引用
- 点击 → `EventBus.note_page_toggled.emit()`

## NoteManager Autoload

- 注册位置: project.godot 中 `Database` 之后
- 名称: `NoteManager`
- 路径: `res://core/note_manager.gd`

## 数据声明

笔记数据放置在 `data/1_core_rules/notes/` 目录下，
由 `DataScanner` 自动扫描分类，`Database.notes` 持有。

示例文件: `data/1_core_rules/notes/note_fangshi_chuyou.tres`

## 依赖

| 组件 | 文件 | 用途 |
|------|------|------|
| Note | `core/note.gd` | 笔记数据模型 |
| NoteManager | `core/note_manager.gd` | 触发中枢 |
| NotePage | `ui/note_page.gd` | 展示页面 |
| RightInfoPanel | `ui/right_info_panel.gd` | SpecialLabel 提示 |
| EventBus | `core/eventbus.gd` | note_triggered 信号 |
| GameSaveData | `core/model/game_save_data.gd` | 触发状态持久化 |
| DataScanner | `core/data_scanner.gd` | 自动加载 notes 目录 |
| PropertyRequirement | `core/property_requirement.gd` | 属性触发条件 |
