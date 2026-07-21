# PoemPage — 诗词图鉴页面

## 设计意图

提供一个全屏覆盖的诗词图鉴页面，展示玩家已解锁的诗词类型（10 种组合）和已创作的特殊诗词（lore=true）。左侧双列表（类型列表 + 历史诗词列表），右侧根据选中项切换 TypeDescriptor / PoemDescriptor 详情面板。

## 系统架构

```
PoemType .tres (data/1_core_rules/poem_types/) → DataScanner → Database.poem_types
                                                                    ↓
PlayerState.created_poems (lore=true 筛选)  ─────────────────→ PoemPage (ui/poem_page.gd)
                                                                    ↓
                                            左侧 PoemTypeScroll / HistoryPoemScroll
                                            右侧 TypeDescriptor / PoemDescriptor (切换显示)
```

## 数据结构

### PoemType (core/poem_type.gd, extends GameEntity)

| 字段 | 类型 | 用途 |
|------|------|------|
| `composition` | Array[String] | 三个意象类型的无序组合（功名/隐逸/狂放），共 10 种 |
| `publication_effects` | Array[BuffOperator] | 发布该类型诗词时触发的 Buff 效果 |

### 10 种组合（multiset of 3 from {功名, 隐逸, 狂放}）

| # | UUID | 组成 | UI展示名 | 文史锚点 |
|---|------|------|---------|---------|
| 1 | `poem_type_ggg` | 功名×3 | 金戈边塞 | 盛唐边塞诗派（高适、岑参） |
| 2 | `poem_type_ggy` | 功名×2+隐逸 | 登临寄怀 | 处江湖之远则忧其君 |
| 3 | `poem_type_ggk` | 功名×2+狂放 | 任侠慷慨 | 盛唐游侠精神（杨炯、少年李白） |
| 4 | `poem_type_gyy` | 功名+隐逸×2 | 丘壑寄傲 | 谢灵运式孤高，山水寄傲骨 |
| 5 | `poem_type_gyk` | 功名+隐逸+狂放 | 盛唐气象 | 三象完美统一（风骨浑融） |
| 6 | `poem_type_gkk` | 功名+狂放×2 | 狂歌请缨 | 悲壮纵酒，报国无门之愤 |
| 7 | `poem_type_yyy` | 隐逸×3 | 山水田园 | 王维、孟浩然式彻底归隐 |
| 8 | `poem_type_yyk` | 隐逸×2+狂放 | 竹林风度 | 竹林七贤式避世狂纵 |
| 9 | `poem_type_ykk` | 隐逸+狂放×2 | 诗酒傲世 | 李白式山中与幽人对酌 |
| 10 | `poem_type_kkk` | 狂放×3 | 潇洒浪漫 | 李白《将进酒》式天马行空 |

## 页面布局

```
┌──────────────────────────────────────────────────────┐
│                                                [X]   │
│  ┌─────────────────┬───┬──────────────────────────┐ │
│  │ TypeCount        │   │ TypeDescriptor (默认可见) │ │
│  │ "你解锁了N个类型" │   │  TypeTitle               │ │
│  ├─────────────────┤   │  组成                     │ │
│  │ PoemTypeScroll   │   │  "功名 + 隐逸 + 狂放"     │ │
│  │  [类型1]         │   │  效果                     │ │
│  │  [类型2]         │   │  BuffOperator.describe()  │ │
│  │  ...             │   │                           │ │
│  ├─────────────────┤   │ PoemDescriptor (默认隐藏)  │ │
│  │ PoemCount        │   │  PoemTitle                │ │
│  │ "你解锁了N首诗词" │   │  组成                     │ │
│  ├─────────────────┤   │  "功名 + 功名 + 隐逸"      │ │
│  │ HistoryPoemScroll│   │  等级                     │ │
│  │  [诗1]           │   │  LvN                      │ │
│  │  [诗2]           │   │  内容                     │ │
│  │  ...             │   │  poem.description         │ │
│  └─────────────────┴───┴──────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

## 切换逻辑

| 点击来源 | TypeDescriptor.visible | PoemDescriptor.visible |
|---------|----------------------|----------------------|
| PoemTypeScroll 按钮 | true | false |
| HistoryPoemScroll 按钮 | false | true |

## 数据填充

### TypeCount
统计 `PlayerState.created_poems` 中诗词覆盖了多少种不同的 PoemType 组合。匹配方式：将 poem 的 `used_imaginary_types` 展平为 sorted Array 后与 `PoemType.composition` sorted 比较。

### PoemCount
`PlayerState.created_poems` 中 `lore==true` 的诗词数量。

### TypeDescriptor.Composition
`PoemType.composition` 的三项用 `tr()` 翻译后用 " + " 连接。

### TypeDescriptor.Effect
遍历 `PoemType.publication_effects`，每个 `BuffOperator.describe_preview()` 结果用换行连接。

### PoemDescriptor.Composition
将 poem 的 `used_imaginary_types` 展平：{"功名": 2, "隐逸": 1} → "功名 + 功名 + 隐逸"，每项用 `tr()` 翻译。

### PoemDescriptor.Level
"Lv{N}"，N = poem.level。

### PoemDescriptor.PoemContent
`poem.description`（即诗词正文）。

## 文件清单

| 文件 | 改动 |
|------|------|
| `core/poem_type.gd` | 添加 @tool 注解，增加 `get_effects_text()` 辅助方法 |
| `core/database.gd` | 新增 `poem_types: Dictionary` 字段 + 在 `_scan_bases_to_typed_dicts` 中分拣 PoemType |
| `data/1_core_rules/poem_types/*.tres` | 新建 10 个 PoemType .tres |
| `ui/poem_page.gd` | **新建** — 完整页面脚本 |
| `ui/poem_page.tscn` | 修改 ext_resource script 引用从 note_page.gd → poem_page.gd |
