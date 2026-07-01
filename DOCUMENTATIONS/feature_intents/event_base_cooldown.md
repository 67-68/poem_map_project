# 事件库隐藏冷却逻辑 — 功能意图

**状态**: 🏗️ 实现中

---

## 意图摘要（<200字）

为事件系统引入 EventBase 分组层。每个 EventBase 包含一组事件 + 抽取策略（AVERAGE），由 `eb_*.json` 配置。EventManager 抽取前先过滤 EventBase（era 不匹配则整组移除），AVERAGE 策略采用黑名单机制：抽中后加入封禁列表，同一 base 内将封禁事件权重再分配给未封禁事件，保持 base 总权重恒定。全封禁时整体移除，reset_on_empty 时清空黑名单。

---

## 核心玩法

- **EventBase 分组**：事件按 base 分组（如"野心交游事件库"），JSON 显式声明 `events` 数组
- **Era 过滤**：EventBase 声明所属 era，抽取时 era 不匹配则整组排除
- **AVERAGE 策略（黑名单 + 权重再分配）**：
  1. 抽中某 base 的事件 → 该事件加入此 base 的黑名单
  2. 下一次抽取前：黑名单事件从池中移除，其权重按比例再分配给同 base 剩余事件
  3. 保证 base 贡献给池的总权重始终不变（被封禁事件的权重不丢失，只转移）
  4. 若 base 内所有事件都在黑名单 → 整个 base 从池中移除
- **reset_on_empty**：当 base 内所有事件都被封禁且该标记为 true → 清空黑名单，重新开始循环

---

## 数据流

```
[eb_*.json] ──→ DataScanner 加载 ──→ EventBase Resource
                                        │
                    ┌───────────────────┘
                    ↓
            Database._build_event_base_index()
              ├─ event_bases_registry: { base_uuid → EventBase }
              └─ event_to_base_index:  { event_uuid → base_uuid }
                                        │
                    ┌───────────────────┘
                    ↓
            EventManager 抽取流程:
              scan_poem_events / scan_events
                │
                ├─ 1. 创建初始 tickets（不变）
                ├─ 2. _filter_tickets_by_event_bases(tickets, context)
                │     ├─ 遍历所有 EventBase
                │     ├─ era 匹配检查
                │     └─ 不匹配 → 从 tickets 移除该 base 的所有事件
                ├─ 3. _apply_event_base_blacklist(tickets)
                │     ├─ 对每个 AVERAGE base:
                │     │   ├─ 收集黑名单事件 → 从 tickets 中移除
                │     │   ├─ 权重再分配：封禁事件权重按比例分给同 base 剩余事件
                │     │   └─ 若全封禁 → 整个 base 移除
                │     └─ 非 AVERAGE base → 跳过
                └─ 4. scan_events_from_tickets(tickets, ...)
                      │
                      └─ 抽中后: _mark_event_base_triggered(event_uuid)
                            ├─ 查 base，若 AVERAGE → 加入黑名单
                            └─ 若全封禁 + reset_on_empty → 清空黑名单
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/model/event_base.gd` | **新建** | EventBase Resource: uuid, name, era, draw_strategies, reset_on_empty, events, generation_configs |
| `core/data_scanner.gd` | **修改** | 新增 `.json` 分支，解析 `eb_*.json` → 创建 EventBase |
| `core/database.gd` | **修改** | event_bases_registry + event→base 反向索引 + getter |
| `core/event_manager.gd` | **修改** | era 过滤 + AVERAGE 黑名单/权重再分配 + 触发追踪 |
| `data/4_eras/745_ambition/jiaoyou/eb_jiaoyou_745ambition.json` | **修改** | 添加 `events` 数组 |
| `DOCUMENTATIONS/feature_intents/event_base_cooldown.md` | **新建** | 本需求文档 |

---

## 状态转换

```
[EventBase 加载]
    │
    ├─ eb_*.json 有 events 数组
    │   → 创建 EventBase，构建 event→base 反向索引
    │
    └─ eb_*.json 无 events 数组或为空
        → 创建 EventBase，events 为空（不参与索引）

[EventManager 抽取 — Era 过滤]
    │
    ├─ base.era 为空 → 全时代，保留
    ├─ base.era == current_era → 匹配，保留
    └─ base.era != current_era → 过滤，移除其所有事件

[EventManager 抽取 — AVERAGE 黑名单]
    │
    ├─ ticket 属于 AVERAGE base
    │   ├─ event 在黑名单中 → 移除 ticket，权重转移给同 base 其余 ticket
    │   │   └─ 权重分配公式: rest_ticket.weight += banned_weight / rest_count
    │   └─ event 不在黑名单中 → 保留，可能接收额外权重
    │
    ├─ 该 base 所有事件都在黑名单 → 全部移除
    │   └─ 若 reset_on_empty → 下轮清空黑名单，重新可用
    │
    └─ ticket 不属于任何 base（或 base 无策略） → 不变

[抽中后]
    │
    ├─ event 属于 AVERAGE base → 加入 _blacklist[base_uuid]
    └─ 检查是否全封禁 → 是且 reset_on_empty → 清空 _blacklist[base_uuid]
```
