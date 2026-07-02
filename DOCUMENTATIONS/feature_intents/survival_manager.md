# SurvivalManager — 生存结算系统

## 文件
- `core/survival_manager.gd` — 核心生存结算管线
- `core/month_end_settlement.gd` — 月末结算 + 属性实时染色

## 时序

由 TimeService.on_xun_tick 触发 _process_single_xun_settlement()，管线顺序（不可更改）：
1. aggregate_trait_effect() — trait 持续效果、疾病进展
2. _cost_survival() — 基础生存扣除（-5 money，流浪 -2）
3. _update_heartbeat_sfx() / death_judgement() — 濒死判定
4. operate_state_transistors() — 状态转换 / 旷达切换
5. ActionManager.process_xun_tick() — Lock/Block 到期清理
6. EventBus.xun_settlement_completed — UI 刷新信号
7. call_deferred("_post_xun_money_deduct") — 延迟扣除 30 money（快照后执行）

## 关键机制

### 延迟扣除 (call_deferred)
- 每旬末尾延迟扣除 30 money
- day 29 时 on_month_tick 快照先执行，扣除在后 → -30 计入下月 delta
- 染色系统每旬初清零，仅反映当旬属性变化

### 属性实时染色
- MonthEndSettlement 监听 player_stat_changed
- 比较当前值 vs 月度快照，增长绿 / 衰减红 / 无变化恢复默认
- 每旬初由 _on_xun_color_reset() 清空，不再依赖月初清空
