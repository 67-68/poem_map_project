# 记录所有被我蓄意创建的事件链

## 747 旷达期

### 清流·焦虑 (qingliu_jiaolv) — 4 事件
- **目标**: 焦虑驱动的短视消费行为。`BURNOUT > 50` 时触发，MONEY 10-50，AMBITION 30-100。
- **维度**: `jiaolv_scenario`（单维度 4 值）
- **场景路由**: status_tax → fangshi, fomo_scam → jiaoyou, illusion_control → fangshi, doomsday_binge → duzhuo
- **Operator 核心**: 金钱大额流失 + 情绪惩罚
- **选项设计**: 单选 (opt_jiaolv)，无 mechanics
- **配置**: [`tools/event_base_config_qingliu_jiaolv.json`](../../tools/event_base_config_qingliu_jiaolv.json)
- **沙盒**: [`tools/event_base_config_qingliu_jiaolv_sandbox.json`](../../tools/event_base_config_qingliu_jiaolv_sandbox.json)
- **CSV**: [`data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv`](../../data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv)

### 清流·道心破碎 (qingliu_daoxin_posui) — 10 事件
- **目标**: TBD
- **配置**: [`tools/event_base_config_qingliu_daoxin_posui.json`](../../tools/event_base_config_qingliu_daoxin_posui.json)
- **CSV**: [`data/4_eras/747_kuangda/qingliu_daoxin_posui/_qingliu_daoxin_posui_events.csv`](../../data/4_eras/747_kuangda/qingliu_daoxin_posui/_qingliu_daoxin_posui_events.csv)

##