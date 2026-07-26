# 坊市 · 说书人 (Storyteller)

## 设计意图

挂载在坊市（fang_shi）下的子行动。玩家将心中最旧的故事（意象）在平康坊茶馆讲给人听，换取赏钱。成功率 80%。失败时意象照常消耗（讲了不讨喜的故事如战乱），但拿不到钱。

## 数值

| 项目 | 值 |
|------|-----|
| 父行动 | fang_shi (坊市, day=4) |
| 地点 | pingkangfang (平康坊) |
| 时间 | day_consumed=2 (覆盖父4天) |
| 成功率 | m_success_rate (80%) |
| 消耗 | consume_oldest_imaginary (最旧意象) |
| 成功 | +30 金 (m_money_gain) |
| 失败 | 无额外收益 (意象已在 cost 消耗) |
| 意象获取 | 继承父 fang_shi: 功名10%+狂放10% |

## 生命周期

```
玩家选坊市 → Picker弹出
  → 无意象? 说书人完全隐藏 (HIDE)
  → 有意象? 显示"说书人"选项 (平康坊📍)
  → 玩家选中 → cost: consume_oldest_imaginary (遍历 created_at_day 最小 → erase)
  → 投骰 80%
    → ✅ 成功: prop_add money +30 → scan_events → fangshi_storyteller_fallback
    → ❌ 失败: PushEventOperator → fangshi_storyteller_failed_fallback
```

## 失败叙事

讲了人们不喜欢的沉重意象（如战乱），听客扫兴散去——「谁要听这些丧气事？」

## 涉及文件

| 文件 | 改动 |
|------|------|
| `core/operators/consume_oldest_imaginary_operator.gd` | **新建** — is_viable/operate/describe_preview |
| `model/enumerates.gd` | **修改** — +ACTION_FANGSHI_STORYTELLER |
| `parser/micro_dsl_parser.gd` | **修改** — +FUNC_CONSUME_OLDEST_IMAGINARY + handler |
| `data/1_core_rules/resource_converters.csv` | **修改** — +1行 fangshi_storyteller |
| `data/3_actions_pool/actions/fang_shi.tres` | **修改** — sub_actions +fangshi_storyteller |
| `data/1_core_rules/events/fallback/fangshi_storyteller_fallback.tres` | **新建** |
| `data/1_core_rules/events/fallback/fangshi_storyteller_failed_fallback.tres` | **新建** |
| `ui/main_action_button.gd` | **修改** — +ConsumeOldestImaginaryOperator HIDE 检测 |
| `core/_export_dependency_anchor.gd` | **修改** — +preload |
| `data/1_core_rules/translations/_dynamic_events.csv` | **修改** — +6条翻译 |
