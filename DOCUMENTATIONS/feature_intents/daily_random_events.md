# 每日随机事件系统 — 功能意图

**状态**: ✅ 已实现

---

## 意图摘要

每旬结算后有 20% 概率从 12 个全局随机事件中抽取一个展示给玩家。涵盖权贵社交、市井求生、风景偶遇、天气交通、朋友邀约五大类。使用 EventBase AVERAGE 策略，保证叙事多样性。

---

## 核心机制

- **触发时机**: 每旬结算管线末尾（`_process_single_xun_settlement`）通过 `call_deferred` 延迟触发，避免与月末结算事件冲突
- **触发概率**: `randf() < 0.2`（20%）
- **抽取策略**: EventBase AVERAGE — 抽中后加入黑名单，权重再分配给同 base 剩余事件。12 个事件全部触发后重置循环（`reset_on_empty=true`）
- **范围**: 全时代可用（`era=""`），tutorial/game_over 时跳过

---

## 事件清单

### 1. 权贵类
| UUID | 标题 | 选项 A | 选项 B |
|------|------|--------|--------|
| `daily_quangui_yanxi` | 权贵邀宴 | 赴宴：兴-10 + 势+5 | 拒绝：势-8 + 兴+6 |
| `daily_quangui_qiushi` | 权贵求诗 | 应允：消耗随机诗词 + 势+5 | 拒绝：势-8 |
| `daily_quangui_siyao` | 权贵私邀 | 接受：势+8 | 推脱：无效果 |

### 2. 市井求生类
| UUID | 标题 | 选项 A | 选项 B |
|------|------|--------|--------|
| `daily_shengbing` | 偶染风寒 | 延医：钱-50 + 健康+15 | 硬扛：健康-50 |
| `daily_tanhuo` | 炭火涨价 | 购买：钱-30 | 扛着：健康-30 |
| `daily_suanming` | 算命先生 | 接受：钱-30 → 链式子事件 | 婉拒：无效果 |
| `daily_suanming_result` | 命中注定 | 恍然大悟：兴+10 | — |

### 3. 风景偶遇类
| UUID | 标题 | 选项 A | 选项 B |
|------|------|--------|--------|
| `daily_qujiangchi` | 路过曲江池 | 驻足观赏：兴+6 | — |
| `daily_dayanta` | 路过大雁塔 | 登塔：健康+30 + 兴+6 | 匆匆：钱+30 |

### 4. 天气交通类
| UUID | 标题 | 选项 | 效果 |
|------|------|------|------|
| `daily_xiayu` | 长安遇雨 | — | `_time` -1（消耗 1AP） |
| `daily_zhengshui` | 征税堵门 | — | `_time` -1（消耗 1AP） |

### 5. 朋友邀请类
| UUID | 标题 | 选项 A | 选项 B |
|------|------|--------|--------|
| `daily_gaoshi_cansen` | 高适岑参邀酒 | 赴约：钱-50 + 随机 Lv3 意象 | 婉拒：无效果 |
| `daily_libai_jiu` | 李白邀酒 | 不醉不归：健康-30 + 文名+8 | 婉拒：无效果 |

---

## 数据流

```
TimeService.on_xun_tick
  → SurvivalManager._process_single_xun_settlement()
    → call_deferred("_try_daily_random_event")
      → randf() < 0.2 ?
        YES → EventManager.draw_from_event_base("daily_random", {})
          → EventBase AVERAGE 黑名单过滤
          → 权重抽取 → request_event_key
        NO  → 无事发生
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`data/3_actions_pool/events/_daily_events.csv`](data/3_actions_pool/events/_daily_events.csv) | **新建** | 13 行 CSV（12 事件 + 1 链式子事件） |
| [`data/3_actions_pool/events/eb_daily_random.json`](data/3_actions_pool/events/eb_daily_random.json) | **新建** | EventBase 分组配置 |
| [`data/3_actions_pool/events/daily_*.tres`](data/3_actions_pool/events/) | **新建** | 13 个生成的 .tres 资源文件 |
| [`tools/data/named_amounts.json`](tools/data/named_amounts.json) | 修改 | 新增 10 个 cost 档位 |
| [`core/survival_manager.gd`](core/survival_manager.gd) | 修改 | 添加 `_try_daily_random_event()` 方法 |
| [`core/csv_cloud_loader.gd`](core/csv_cloud_loader.gd) | 修改 | DATA_MANIFEST 注册新 CSV |

---

## 状态转换

```
[旬结算完成]
    │
    ├─ tutorial/game_over → 跳过
    │
    └─ randf() >= 0.2 → 跳过（80%）
    │
    └─ randf() < 0.2 → 触发（20%）
        │
        ├─ 扫描 eb_daily_random.json
        ├─ AVERAGE 黑名单过滤
        ├─ 权重抽取 1/12 事件
        ├─ 展示 NarrativeOverlay
        │   ├─ 单选项事件 → 自动执行 → pop
        │   └─ 双选项事件 → 玩家选择 → 执行结果 → pop
        └─ 标记事件入黑名单（12 个全部触发后 reset）
```

---

## 注意事项

- **AP 扣除**: `_time` 属性使用 `prop_sub(name=time; val=s_time_cost)` 其中 `s_time_cost=-1`
- **链式子事件**: `daily_suanming` → `push_event(daily_suanming_result)`，子事件 `pop_event()` 后返回
- **月末冲突**: 使用 `call_deferred` 延迟触发，确保月末结算先入栈
- **AVERAGE reset**: `reset_on_empty=true` 保证 12 个事件全触发后重置循环
