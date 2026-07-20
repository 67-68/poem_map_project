# player_observer — 资源消耗观测 + 里程碑追踪系统

## 相关文件

| 文件 | 角色 |
|------|------|
| [`core/player_observer.gd`](../../core/player_observer.gd) | autoload，三层架构核心 |
| [`core/milestones_config.json`](../../core/milestones_config.json) | 里程碑配方配置 |
| [`core/player_state.gd`](../../core/player_state.gd) | cost context 栈方法 |
| [`core/eventbus.gd`](../../core/eventbus.gd) | milestone_achieved 信号 |
| [`ui/main_action_button.gd`](../../ui/main_action_button.gd) | 父 action cost 前 push/pop context |
| [`core/sub_action_executor.gd`](../../core/sub_action_executor.gd) | 子 action cost 前 push/pop context |
| [`ui/poem_crafter.gd`](../../ui/poem_crafter.gd) | 发射 poems_created 信号 |
| [`project.godot`](../../project.godot) | autoload 注册 |

## 三层架构

```
Layer 1 (信号输入): 5 个分散入口
  ─ before_property_change (双通道: cost分桶 + 属性累加)
  ─ on_person_state_changed (过滤 know_about → friends_made)
  ─ poems_created (→ poems_created 累加)
  ─ idea_upgraded (→ ideas_accepted 累加)
  ─ on_xun_tick (→ xun_lived 累加)

Layer 2 (统一累加器 + 分桶):
  unified_accumulators    — 扁平累加（用于里程碑检测）
  consumption_by_identity — 按身份分桶（cost context 路径）
  resource_to_topic       — 资源→topic 消耗对照

Layer 3 (里程碑配方轮询):
  每次累加器变更 → 轮询 milestones_config.json
  达到阈值且未标记 → 写入 achieved_milestones + 发射 milestone_achieved
```

## 数据结构

```
unified_accumulators: {
    poems_created, friends_made, ideas_accepted,
    health_consumed, money_consumed, xun_lived, days_consumed
}
consumption_by_identity: { identity → { prop → abs_delta } }
resource_to_topic:       { prop → { topic → abs_delta } }
achieved_milestones:     { milestone_key → { achieved_at_day: int } }
```

## 7 个里程碑配方

| key | accumulator | threshold | 信号源 |
|-----|-------------|-----------|--------|
| first_poem | poems_created | 1 | PoemCrafter → poems_created |
| first_friend | friends_made | 1 | RelationFlagManager → on_person_state_changed (know_about) |
| first_idea | ideas_accepted | 1 | IdeaPage → idea_upgraded |
| health_100 | health_consumed | 100 | PlayerState → before_property_change |
| money_100 | money_consumed | 100 | 同上 |
| survive_10_xun | xun_lived | 10 | TimeService → on_xun_tick |
| days_100 | days_consumed | 100 | PlayerState → before_property_change |
