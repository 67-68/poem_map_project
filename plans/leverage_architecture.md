# 杠杆系统架构方案 v2

> 状态: 已确认 — 待实施

---

## 0. 技术约束审计

### PlayerState flag 系统限制

当前 `register_virtual_flag` 只支持 `str`, `int`, `bool` 三种类型。list 类型不被支持。

**存储方案：JSON 编码的 str flag**

```
flag_gen_leverage_TARGET_IDENTITY_QUANGUI = '["quangui_corruption","quangui_treason"]'
```

- flag 注册为 `str` 类型
- RelationFlagManager 内部做 `JSON.stringify()` / `JSON.parse_string()` 编解码
- 调用方无感，API 层面操作的是 `Array[String]`

---

## 1. 核心数据模型

### Leverage Item = String Key

每个把柄是一个唯一的 string key，格式约定：

```
{target_tag_short}_{context_descriptor}
```

示例：

| Leverage Key | 对应的具体事件 | 无事件时降级到 |
|---|---|---|
| `quangui_corruption` | `event_threaten_quangui_corruption` | `event_threaten_TARGET_IDENTITY_QUANGUI` |
| `quangui_treason` | `event_threaten_quangui_treason` | `event_threaten_TARGET_IDENTITY_QUANGUI` |
| `zhuoliu_bribe` | `event_threaten_zhuoliu_bribe` | `event_threaten_TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |

### 诱饵代币约定

Key 以 `decoy_` 前缀开头 → 事件路由时指向"失败勒索"叙事

| Leverage Key | 事件查找顺序 |
|---|---|
| `quangui_corruption` | ① `event_threaten_quangui_corruption` → ② `event_threaten_TARGET_IDENTITY_QUANGUI` |
| `decoy_violence` | ① `event_threaten_decoy_violence` → ② `event_threaten_TARGET_IDENTITY_QUANGUI` |

### 生命周期

```
事件文本 → leverage_add(key="quangui_corruption")
  → RelationFlagManager.add_leverage("TARGET_IDENTITY_QUANGUI", "quangui_corruption")
  → flag: '["quangui_corruption","quangui_treason"]'
  → toast: [系统提示：你获得了关于权贵的把柄]

(后续) 玩家选择威胁权贵
  → RelationFlagManager.try_use_leverage("TARGET_IDENTITY_QUANGUI")
  → pop "quangui_corruption" from list
  → check: event_threaten_quangui_corruption 是否存在？
    ├─ 存在 → push event_threaten_quangui_corruption
    └─ 不存在 → push event_threaten_TARGET_IDENTITY_QUANGUI (通用降级)
```

---

## 2. RelationFlagManager 改造

```gdscript
# ── 常量 ──
const FLAG_PREFIX_LEVERAGE: String = "flag_gen_leverage_"
const EVENT_PREFIX_THREATEN: String = "event_threaten_"

# ── 内部编解码 ──
static func _get_leverage_list(target_tag: String) -> Array:
    var flag_id = FLAG_PREFIX_LEVERAGE + target_tag
    if PlayerState.has_flag(flag_id):
        var raw = PlayerState.get_flag(flag_id)
        if raw is String and not raw.is_empty():
            var parsed = JSON.parse_string(raw)
            if parsed is Array:
                return parsed
    return []

static func _set_leverage_list(target_tag: String, list: Array) -> void:
    var flag_id = FLAG_PREFIX_LEVERAGE + target_tag
    if not Database.get_flag(flag_id):
        PlayerState.register_virtual_flag(flag_id, "str")
    var json_str = JSON.stringify(list)
    PlayerState.set_flag(flag_id, json_str, "str")

# ── 公开 API ──

static func add_leverage(target_tag: String, leverage_key: String) -> void
static func get_leverage_keys(target_tag: String) -> Array
static func has_leverage(target_tag: String) -> bool
static func consume_leverage(target_tag: String, leverage_key: String) -> bool
static func try_use_leverage(target_tag: String) -> Dictionary
  # → {consumed: bool, leverage_key: String, event_id: String}
  # event_id 先尝试具体事件 event_threaten_{key}, 降级到 event_threaten_{target_tag}
```

---

## 3. LeverageAddOperator

**文件:** `core/operators/leverage_add_operator.gd`

```gdscript
@tool
class_name LeverageAddOperator extends BaseOperator

@export var target_tag: String
@export var leverage_key: String
@export var silent: bool = false

func operate():
    RelationFlagManager.add_leverage(target_tag, leverage_key)
    if not silent:
        var label = _resolve_label(target_tag)
        var msg = "获得了关于「%s」的把柄" % [label]
        EventBus.request_toast.emit("[系统提示]：" + msg, 1)
```

### MicroDSLParser 注册

```gdscript
const FUNC_LEVERAGE_ADD := "leverage_add"
cd[FUNC_LEVERAGE_ADD] = func(p, r): return _exec_leverage_add_op(p, r)
```

同时注册 `info` 算子（InfoDemoOperator 挂载到 dispatch）:
```gdscript
const FUNC_INFO := "info"
cd[FUNC_INFO] = func(p, r): return _exec_info_op(p, r)
```

---

## 4. DSL 语法

```yaml
# 获取有效把柄
operator_dsl: 'leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="quangui_corruption")'

# 诱饵代币
operator_dsl: 'leverage_add(target_tag="TARGET_IDENTITY_QUANGUI"; key="decoy_violence")'

# 静默模式
operator_dsl: 'leverage_add(target_tag="TARGET_NPC_LIBAI"; key="libai_secret"; silent=true)'

# 系统通知
operator_dsl: 'info(msg="你注意到了一些可疑的事情")'
```

---

## 5. 实施顺序

```
Phase 1: RelationFlagManager 改造
  ├── 改为 list[str] 存储 (JSON str flag)
  ├── add_leverage / get_leverage_keys / has_leverage
  ├── consume_leverage (按 key 精确匹配)
  ├── try_use_leverage (LIFO + 具体事件优先降级)
  └── 更新 test_relation_flag_manager.gd

Phase 2: LeverageAddOperator + info 算子
  ├── core/operators/leverage_add_operator.gd
  ├── 注册到 MicroDSLParser._consequence_dispatch
  └── info 算子注册 (InfoDemoOperator)

Phase 3: 手动通用威胁事件
  ├── event_threaten_TARGET_IDENTITY_QUANGUI
  ├── event_threaten_TARGET_IDENTITY_ZHUOLIU_OFFICIAL
  ├── event_threaten_TARGET_IDENTITY_QINGLIU_OFFICIAL
  ├── event_threaten_TARGET_IDENTITY_QINGLIU_OWNER
  ├── event_threaten_TARGET_NPC_LIBAI
  ├── event_threaten_TARGET_NPC_WANGWEI
  └── (放在 data/1_core_rules/relations/)

🆕 Phase 3.5: 测试阶段
  ├── 创建一个测试事件（包含 leverage_add DSL）
  ├── 在游戏中手动触发
  └── 验证: flag 写入正确 + 通知显示 + 威胁事件推送

Phase 4: leverage_add 注入到现有事件
  ├── 在 12 个杠杆点的事件 DSL 中插入 leverage_add
  └── 诱饵代币用 decoy_ 前缀

Phase 5: 事件库批量生成 (扩展阶段)
  ├── 创建 event_base_config_threaten.json
  └── 跑管线批量生成每个身份/NPC 的具体威胁事件
```

---

## 6. Mermaid

```mermaid
flowchart TD
    subgraph Storage[存储]
        Flag(flag_gen_leverage_TAG: str) -->|JSON.parse| List[["key1","key2"]]
    end

    subgraph Acquire[获取]
        Event[事件结算] --> Op[leverage_add operator]
        Op --> Mgr1[add_leverage]
        Mgr1 --> Encode[JSON.stringify]
        Encode --> Flag
        Op --> Toast[request_toast 系统通知]
    end

    subgraph Use[使用]
        Try[try_use_leverage] --> Pop[pop_back LIFO]
        Pop --> Check{event exists?}
        Check -->|Yes| Specific[push 具体事件]
        Check -->|No| Fallback[push 通用事件]
    end

    subgraph Decoy[诱饵代币]
        DecoyKey[decoy_* 前缀] --> DecoyEvent[失败勒索事件]
    end
```
