# Idea — 理念系统

## 设计意图

理念（Idea）是玩家可选择的长期加成策略。每个理念包含多个等级的 buff，玩家消耗资源逐步解锁更强增益。

## 核心模型

| 字段 | 类型 | 说明 |
|------|------|------|
| `idea_buffs` | `Array[BuffOperator]` | 逐级解锁的 buff 列表，index = 等级 |
| `current_idea_level` | `int` | 当前解锁等级（-1 未激活，0 为第一级） |
| `idea_demonstrations` | `Array[String]` | 每级对应的展示描述文本 |
| `idea_cost_name` | `String` | 升级消耗的属性名 |
| `idea_cost_amount` | `int` | 每次升级的固定消耗数值 |
| `counter_idea` | `String` | 互斥理念的 uuid，空=无冲突 |

## 持久化

- `GameSaveData.current_unlock_ideas: Array[String]` — 已解锁理念的 uuid 列表
- `Idea.current_idea_level` — 每个理念持有自己的等级（存于 `.tres` 资源中，不直接持久化到存档）

## IdeaPage 三栏布局

```
┌──────────────┬────────────────────┬──────────────────────┐
│  左栏：5槽位  │    中栏：详情       │    右栏：候选池      │
│  (已解锁理念)  │                    │    (动态 IdeaBtn)    │
│              │ 名称 + 效果描述     │                      │
│  槽位1: 兴   │ ✅ 效果1            │  [兴：存在城府]  ←可点 │
│  槽位2: 空   │ 🔒 效果2            │  [默：冲淡]     ←可点 │
│  槽位3: 空   │                    │  [默：全神贯注] ←锁定 │
│  槽位4: 空   │ [解锁效果2? 消耗]    │                      │
│  槽位5: 空   │    300点兴] 点击升级 │                      │
└──────────────┴────────────────────┴──────────────────────┘
```

### 左栏 — 5 个 LinkButton 槽位
- `GameSave.data.current_unlock_ideas` 的前 5 项
- 点击选中 → 中栏展示详情

### 中栏 — 详情面板
- 名称（`Idea.name`）
- 效果列表（遍历 `idea_demonstrations`，已解锁 ✅ / 未解锁 🔒）
- 升级按钮：`"解锁效果{num}？消耗 {amount}点{name}"`
  - 资源不足时置灰并标注"（不足）"
  - 满级时显示"已满级"
  - 如果该理念不属于当前玩家（未解锁），禁用

### 右栏 — 候选理念池
- 遍历 `Database.ideas`，跳过已解锁的
- 实例化 `IdeaBtn`（`res://ui/idea_btn.tscn`）
- 冲突检测：如果候选理念的 `counter_idea` 指向已解锁理念，或反之，标记为锁定
- 锁定文本：`"被锁定，由于{已有理念名}：与{候选理念名}冲突"`

## 冲突检测逻辑

```gdscript
# 双向检测：
# 1. 候选理念.counter_idea == 已解锁理念.uuid
# 2. 已解锁理念.counter_idea == 候选理念.uuid
# 任一成立 → 锁定
```

## 关联文件

| 文件 | 说明 |
|------|------|
| `core/idea.gd` | Idea 模型类（`extends GameEntity`） |
| `core/buff_operator.gd` | 单条 buff 操作器 |
| `core/database.gd` | `ideas` 字典 + `get_idea()` |
| `core/idea_page.gd` | 理念总览页 UI 逻辑 |
| `core/model/game_save_data.gd` | `current_unlock_ideas` 持久化 |
| `ui/idea_page.tscn` | 三栏布局场景 |
| `ui/idea_btn.gd` | IdeaBtn 脚本（`set_idea()`） |
| `ui/idea_btn.tscn` | 候选按钮场景 |
