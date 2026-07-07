# trait_effect_mechanics.md — trait effect hint 构建器

> 📅 更新日期：2026-07-07

## 文件

- [`core/action_hint_builder.gd`](core/action_hint_builder.gd:343) — `build_trait_hint(trait_data: Trait) -> String`
- [`tests/test_trait_hint_builder.gd`](tests/test_trait_hint_builder.gd:1) — GUT 测试
- [`tools/dump_trait_hints.gd`](tools/dump_trait_hints.gd:1) — 全量 dump 脚本
- [`view_tests/vtest_trait_hints.tscn`](view_tests/vtest_trait_hints.tscn:1) — dump 场景入口

## 函数签名

```gdscript
static func build_trait_hint(trait_data: Trait) -> String
```

## Imaginary 输出格式

```
【name】
Lv{N} 意象 — {description}（如有）

{get_hint}（如有）

━━━ 效果 ━━━
• 每旬：{trait_effect_operations.describe_preview()}
（持有期无副作用）  ← 无 trait_effect_operations 时

━━━ 持续 ━━━
• {N}旬后自动移除（已持续{N}旬）
• {N}旬后转化为「{expiry_trait_name}」（已持续{N}旬）

{hover_narrative}（如有）
```

## 普通 Trait 输出格式

```
【name】
{GameEntity.description}（如有）

━━━ 效果 ━━━
• 每旬：{trait_effect_operations}          ← 每旬结算
• {prop_name} {模式} ×{n}                  ← buffer_to_prop
• {prop_name}（区域）{模式} ×{n}           ← buffer_to_region
• 所有行动 +{n}天                           ← time_penalty
• {label}：+{n}天                           ← conditional_time_penalties
• 行动力上限 {±n}                           ← ap_penalty
（无特殊效果）                               ← 全部为空时

━━━ 持续 ━━━
• {N}旬后自动移除（已持续{N}旬）
• {N}旬后转化为「{expiry_trait_name}」（已持续{N}旬）
（无此 section 当 duration_xun == 0）

{hover_narrative}
```

## 边界情况

| 条件 | 行为 |
|------|------|
| trait_data == null | 返回 `""` |
| 所有效果字段为空 | 显示 `（无特殊效果）` |
| duration_xun == 0 | 跳过整个持续 section |
| hover_narrative 为空 | 不输出空行 |
| description 为空 | 跳过该行 |
| Imaginary 无 trait_effect_operations | 显示 `（持有期无副作用）` |

## 全量诊断工具

```bash
# 关闭 Godot 编辑器，运行：
/Applications/Godot.app/Contents/MacOS/Godot --headless res://view_tests/vtest_trait_hints.tscn
# 输出文件：
# macOS: ~/Library/Application Support/Godot/app_userdata/poem_map/trait_hint_dump.txt
```

dump 脚本自动扫描：
1. `res://data/1_core_rules/traits/` — 所有 Trait .tres
2. `res://data/1_core_rules/disease/` — 所有 Disease .tres
3. `Database.imaginaries_detail` — 运行时 Imaginary
