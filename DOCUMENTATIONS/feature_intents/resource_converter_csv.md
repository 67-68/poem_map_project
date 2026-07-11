# Resource Converter CSV — 行动与 Archetype 统一数据源

## 背景

此前行动（Action）和对应 Archetype 分裂在三处：`event_archetypes.json` + `.tres` + 设计草稿 CSV。三者必然不同步。

## 解决

`resource_converters.csv` 为**唯一数据源**。编辑器同步时，一行 CSV 自动生成：

- **4 个 ActionArchetype .tres** → `data/1_core_rules/archetypes/{uuid}_{cost|success|failure|defer}.tres`
- **1 个 Action .tres** → `data/3_actions_pool/actions/{parent}/{uuid}.tres`

`event_archetypes.json` 已删除。

## 数据流

```
editor sync → csv_cloud_loader
  → DSLParser._parse_resource_converter()
    → 每个 archetype 作为 ActionArchetype Resource（设 resource_path）
    → 每个 action 作为 Action Resource（设 resource_path）
  → save_resources_to_tres() 按 resource_path 保存

runtime → DataScanner.scan("res://data/")
  → 自动扫描 data/1_core_rules/archetypes/*.tres
  → Database 遍历分支识别 ActionArchetype → action_archetypes[uuid]

tool/fallback → ActionManager._init_archetype_cache()
  → CSV 运行时解析 → 返回的资源中提取 ActionArchetype 注册到 Database
```

## CSV 表头

| 列 | 必需 | 说明 |
|---|---|---|
| `uuid` | 是 | 行动 UUID（同时也是文件名） |
| `name` | 是 | 显示名 |
| `parent_action` | 是 | 父行动 UUID，如 `fang_shi` |
| `required_place` | 否 | 地点限制 |
| `description` | 是 | tooltip 描述 |
| `action_tags` | 是 | 枚举 int，逗号分隔 |
| `day_consumed` | 否 | 耗时天数，0=继承父 |
| `possibility` | 是 | 成功率 archetype key |
| `cost_dsl` | 否 | 消耗 archetype DSL |
| `success_dsl` | 是 | 成功 archetype DSL |
| `failure_dsl` | 否 | 失败 archetype DSL |
| `defer_dsl` | 否 | defer 每旬消耗 DSL |
| `context` | 否 | 零碎字段 |
| `custom_option` | 否 | 硬编码逻辑关键字 |

## custom_option 关键字

| 关键字 | 行为 |
|---|---|
| `poem_selector:fame/money/baiye` | 注入 PoemRewardOperator + PoemRequirement |
| `consume_leverage` | 注入 ConsumeRandomLeverageOperator |

## 相关文件

- `data/1_core_rules/resource_converters.csv` — 数据源
- `parser/dsl_parser.gd` — `_parse_resource_converter()` / `_build_action_from_row()`
- `core/csv_cloud_loader.gd` — DATA_MANIFEST 条目 + resource_path 路由
- `core/model/action_archetype.gd` — `ActionArchetype` Resource 模型（@export 字段 + .create() 工厂）
- `core/database.gd` — `ActionArchetype` 分支索引到 `action_archetypes`
- `core/action_manager.gd` — `_init_archetype_cache()` 运行时 fallback
