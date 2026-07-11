# Resource Converter CSV — 行动与 Archetype 统一数据源

## 背景

此前行动（Action）和对应 Archetype 分裂在三个地方：
- `tools/data/event_archetypes.json` — 手工维护的 JSON，约 60 个 archetype
- `data/3_actions_pool/actions/*.tres` — 手工创建/编辑的 Godot Resource 文件
- `data/1_core_rules/resource_converters.csv` — 半自然语言的设计草稿（已废弃）

三者必然不同步，且新增/修改一个行动需要同时改 JSON + .tres 两处。

## 解决

将 `resource_converters.csv` 升级为 **唯一数据源**。编辑器同步时，一行 CSV 自动生成：
- **4 个 ActionArchetype**：`{uuid}_cost` / `{uuid}_success` / `{uuid}_failure` / `{uuid}_defer`
- **1 个 Action .tres**：保存到 `data/3_actions_pool/actions/{parent}/{uuid}.tres`

`event_archetypes.json` 最终废弃（保留作为 fallback 兼容过渡期）。

## 状态转换

```
开发者在 CSV 中编辑一行
  → Godot 编辑器内点击同步按钮（google_sheet_fetcher.tscn）
    → csv_cloud_loader → 检测 data_type="resource_converter"
      → DSLParser._parse_resource_converter()
        → 4 个 ActionArchetype 注入 Database.action_archetypes
        → 1 个 Action Resource 保存为 .tres
  → 运行时 ActionManager._init_archetype_cache()
    → 如果 Database 已注入（编辑器同步过），直接使用
    → 否则从 CSV 文件运行时解析（fallback）
```

## CSV 表头

| 列 | 必需 | 说明 |
|---|---|---|
| `uuid` | 是 | 行动 UUID（同时也是文件名） |
| `name` | 是 | 显示名 |
| `parent_action` | 是 | 父行动 UUID，如 `fang_shi` |
| `required_place` | 否 | 地点限制：`xishi`/`pingkangfang`/`huangcheng`/空 |
| `description` | 是 | tooltip 描述 |
| `action_tags` | 是 | 枚举 int，逗号分隔 |
| `day_consumed` | 否 | 耗时天数，0=继承父 |
| `possibility` | 是 | 成功率 archetype key |
| `cost_dsl` | 否 | 消耗 archetype DSL（点击即扣） |
| `success_dsl` | 是 | 成功 archetype DSL |
| `failure_dsl` | 否 | 失败 archetype DSL |
| `defer_dsl` | 否 | defer 每旬消耗 DSL |
| `context` | 否 | 零碎字段，`|` 分隔 kv |
| `custom_option` | 否 | DSL 无法处理的硬编码逻辑 |

### context 字段格式

```
fallback_event=xxx|failed_fallback=yyy|defer_xun=l_xun_cost|ap_cost_per_xun=m_ap_cost|lock_narrative=文本|failed_hints={"money":"叙事","health":"叙事"}
```

### custom_option 关键字

| 关键字 | 行为 |
|---|---|
| `poem_selector:fame` | 注入 PoemRewardOperator(fame) + PoemRequirement |
| `poem_selector:money` | 注入 PoemRewardOperator(money) + PoemRequirement |
| `poem_selector:baiye` | 注入 PoemRewardOperator(baiye) + PoemRequirement |
| `consume_leverage` | 注入 ConsumeRandomLeverageOperator |

## 相关文件

- `data/1_core_rules/resource_converters.csv` — 数据源
- `parser/dsl_parser.gd` — `_parse_resource_converter()` / `_build_action_from_row()` / `_apply_custom_option()`
- `core/csv_cloud_loader.gd` — DATA_MANIFEST 条目 + resource_path 路由
- `core/action_manager.gd` — `_init_archetype_cache()` 改为 CSV 加载
- `core/model/action_archetype.gd` — 数据模型（不变）
- `core/model/action.gd` — Action 模型（不变）
- `tools/data/named_amounts.json` — 数值 archetype 表
