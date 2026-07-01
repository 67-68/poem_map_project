# 意象系统全面简化 Refactor

> **⚠️ 权威声明：本文档是意象系统架构的最终权威。所有之前的文档（`DOCUMENTATIONS/imaginary/*.md`、`DOCUMENTATIONS/events/tag_dictioinary.md`、`DOCUMENTATIONS/feature_intents/poem_imagery_matching.md`）中与本 refactor 冲突的部分均以本文档为准。**

**日期**: 2026-07-01
**状态**: 执行中

---

## 动机

1. `image_dictionary.json` + Python 管线「场景×情绪→自动选最佳意象」打分系统过于复杂，维护成本高
2. 四段式冒号 Tag 字符串匹配（`TagManager.prefix_match`）是过度工程，实际使用中只需直接引用
3. `Imaginary` 类的 `perceptions` 字段无人使用，`detail_imaginaries` 四段式Tag解析逻辑复杂且易出错
4. 整体方向：从「字符串解析+动态打分」退回到「直接引用+简单映射」

---

## 新架构

### 数据模型

```
Imaginary (意象实体)
├── uuid: String          # 简单名，如 "snow", "drunk"
├── name: String          # 展示名，如 "孤雪"
└── concepts: String[]    # 关联的 ImaginaryConcept uuid，如 ["environment:snow", "emotion:tranquility"]

ImaginaryConcept (抽象概念)
├── uuid: String          # 如 "environment:snow"
├── name: String          # 如 "雪意"
├── description: String
├── current_level: int    # 0-2
├── current_tier: int     # 1-3
└── merged: Array         # 合并备份
```

### 关系：意象 → 多个抽象概念

一个意象（如 "snow"）可以关联多个抽象概念（如 `environment:snow` 和 `emotion:tranquility`）。
当玩家在 PoemCrafter 中合并时，选择一个 concept 进行坍缩，该意象被消耗，对应 concept level+1。

### 数据流

```
imagery_add(name=snow)
  → ImageryAcquisitionOperator.operate()
    → EventBus.request_add_imaginary.emit("snow")
      → PlayerState._on_request_add_imaginary("snow")
        → 查 imaginary_definitions.json 获取 {name:"孤雪", concepts:["environment:snow","emotion:tranquility"]}
        → 创建/更新 Imaginary(uuid="snow", concepts=[...])
        → 存入 Database.imaginaries_detail["snow"]
        → EventBus.imaginary_changed.emit()

ImaginaryComprehender._derive_concept_groups()
  → 遍历 Database.imaginaries_detail 中所有 Imaginary
  → 读 Imaginary.concepts 数组（不再冒号分割）
  → 按 concept_key 分组
  → 返回 { "environment:snow": [Imaginary"snow", Imaginary"frost"], ... }

merge_category("environment:snow")
  → 消耗引用该 concept 的所有 Imaginary
  → concept.current_level = min(count, 2)
  → EventBus.imaginary_changed.emit()
```

---

## 改动清单

### Phase 1: Python 管线清理
- DELETE `tools/data/image_dictionary.json`
- DELETE `tools/event_generator/scorer.py` 中 `extract_image_pool`/`pick_best_image`/`is_valid_combination`
- DELETE `tools/plugins/emotion_pair_imagery_plugin.py`
- DELETE `tools/plugins/imagery_acquisition_plugin.py`
- 从 `tools/event_generator/operator_translator.py` 删除 `ImageryAnchor` + `translate_imagery_add()`
- 从 `tools/event_generator/main.py` 删除所有 `image_dict` 逻辑
- 从 `tools/event_generator/prompts.py` 删除 `ImageryItem` 引用
- 从 `tools/config.py` 删除 `ImageryItem` 类

### Phase 2: Imaginary 类简化
- 重写 `core/model/imaginary.gd`: `detail_imaginaries`→`concepts: Array[String]`，删除 `perceptions`
- 重写 `tools/data/imaginary_definitions.json`: 新格式 `uuid → {name, concepts}`

### Phase 3: Tag 匹配删除
- 从 `core/tag_manager.gd` 删除 `prefix_match()` + `normalize_3part_depreciated_tag()`
- 重构 `core/model/action_tag_filter.gd` filter()
- 重构 `core/event_manager.gd` scan_poem_events()
- 审阅 `core/operators/scan_and_push_operator.gd`

### Phase 4: 运行时重写
- 重写 `core/player_state.gd` `_on_request_add_imaginary()`
- 简化 `core/imaginary_comprehender.gd` `_derive_concept_groups()`
- 简化 `core/fragment_matcher.gd`
- 更新 `core/operators/imagery_acquisition_operator.gd`

### Phase 5: CSV 迁移
- 所有 `imagery_add(name=CATEGORY:value)` → `imagery_add(name=value)`

### Phase 6: UI + 测试 + 文档
- 修改 `ui/poem_crafter.gd` / `ui/poem_uis/detail_imaginary.gd`
- 更新/删除相关测试
- 更新 `DOCUMENTATIONS/`

---

## CSV 映射规则

旧格式 `CATEGORY:value` → 取 `value` 作为新名字。

| 旧格式 | 新格式 |
|--------|--------|
| `SOCIETY:famine` | `famine` |
| `ENVIRONMENT:snow` | `snow` |
| `HEALTH:drunk` | `drunk` |
| `TRAVEL:exile` | `exile` |
| `COURT:corrupt` | `corrupt` |
| `EMOTION:despair` | `despair` |
| `VIBE_AESTHETIC_ELEGANT:ink_stone` | `ink_stone` |
| `ENV_NATURE_NIGHTMOON:cold_moon` | `cold_moon` |
| `VIBE_PHILOSOPHY_ZEN:temple_bell` | `temple_bell` |
| `TARGET_FACTION_ROYAL:jade_step` | `jade_step` |
| `ACTION_ENTERTAIN_DRINK:empty_cup` | `empty_cup` |
| `ENVIRONMENT:wind` | `wind` |

每个新名字在 `imaginary_definitions.json` 中定义其关联的 `concepts`。

---

## `imaginary_definitions.json` 新格式

```json
{
  "snow": {
    "name": "孤雪",
    "concepts": ["environment:snow", "emotion:tranquility"]
  },
  "famine": {
    "name": "饥荒",
    "concepts": ["society:famine"]
  },
  "drunk": {
    "name": "醉意",
    "concepts": ["health:drunk"]
  }
}
```
