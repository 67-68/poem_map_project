# SurvivalManager — 生存结算系统

## 文件
- `core/survival_manager.gd` — 核心生存结算管线
- `core/month_end_settlement.gd` — 月末结算 + 属性实时染色
- `data/3_actions_pool/decided_events/event_money_lower_0_innkeeper.tres` — 旬末没钱事件

## 时序

由 TimeService.on_xun_tick 触发 _process_single_xun_settlement()，管线顺序（不可更改）：
1. aggregate_trait_effect() — trait 持续效果、疾病进展
1.5. _sync_health_ap_traits() — 健康→AP 阶梯同步（必须在 aggregate 之后，确保中毒等扣血 trait 已生效）
2. _cost_survival() — 基础生存扣除（-5 money）+ AP 刷新（健康联动）
3. _update_heartbeat_sfx() / death_judgement() — 濒死判定
4. operate_state_transistors() — 状态转换 / 旷达切换
5. ActionManager.process_xun_tick() — Lock/Block 到期清理
6. EventBus.xun_settlement_completed — UI 刷新信号
7. call_deferred("_post_xun_money_deduct") — 延迟扣除 30 money → **若 money < 0 触发 event_money_lower_0_innkeeper**

## 旬末没钱事件

- **触发条件**：`_post_xun_money_deduct()` 执行后 `money < 0`
- **事件 uuid**：`event_money_lower_0_innkeeper`
- **事件名**：流落街头
- **选项**：单选项「咬牙撑过去」→ `HEALTH -20`
- **设计意图**：旬末大额扣费后才检测，而非日常小额扣费时触发。没钱了没有选择权，强制叙事 + 健康惩罚。

## 关键机制

### 延迟扣除 (call_deferred)
- 每旬末尾延迟扣除 30 money
- day 29 时 on_month_tick 快照先执行，扣除在后 → -30 计入下月 delta
- 染色系统每旬初清零，仅反映当旬属性变化

### 健康→AP 阶梯系统

通过 [`HEALTH_AP_TIERS`](core/survival_manager.gd:13) const dict 数组配置，作为唯一真相源：

| 健康 | AP 上限 | 特质 | display_char |
|------|---------|------|-------------|
| ≤ 30 | 5 | `terminal_illness`（病入膏肓） | 病 |
| ≤ 59（即 < 60） | 8 | `exhaustion_initial`（疲态初显） | 疲 |
| ≥ 60 | 10（默认） | 无 | — |

消费方通过静态查询接口获取数据：
- `SurvivalManager.get_current_ap_cap()` → `int` — [`_cost_survival()`](core/survival_manager.gd:55) AP 刷新、[`time_control_panel`](world/time_control_panel.gd:1) 圆点上限
- `SurvivalManager.get_active_ap_hint()` → `String` — [`action_hint_builder`](core/action_hint_builder.gd:1) hover 提示文本
- `SurvivalManager.get_active_ap_hint_color()` → `String` — hover 提示颜色

新增阶梯只需在 `HEALTH_AP_TIERS` 数组中插入一条，所有消费方自动生效。

### 属性实时染色
- MonthEndSettlement 监听 player_stat_changed
- 比较当前值 vs 月度快照，增长绿 / 衰减红 / 无变化恢复默认
- 每旬初由 _on_xun_color_reset() 清空，不再依赖月初清空
