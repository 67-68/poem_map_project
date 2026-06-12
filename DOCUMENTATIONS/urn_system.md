# URN 系统与数据访问接口文档

## 概述

URN（统一资源名称）系统为项目中的所有资源类型提供统一的标识符协议。

**格式：** `urn:poem_map:<resource-type>:<resource-id>`

**示例：**
- `urn:poem_map:poet:libai_001` — 诗人李白
- `urn:poem_map:poem:jiang_jin_jiu` — 诗词《将进酒》
- `urn:poem_map:action:travel-parting-withLiBai` — 行动标签
- `urn:poem_map:life-path-point:poem_chang_hen_ge` — 人生轨迹点

## 核心定义

所有 URN 类型常量定义在 [`model/enumerates.gd`](../model/enumerates.gd) 的 `URN_TYPE` 枚举中。

### 当前支持的资源类型

| URN 类型 | database.gd 变量名 | 数据来源 | 说明 |
|----------|-------------------|---------|------|
| `poet` | `poet_data` | Registry (.tres) | 诗人数据 |
| `poem` | `poem_data` | Registry (.tres) | 诗词数据 |
| `faction` | `factions` | Registry (.tres) | 势力 |
| `province` | `base_province` | CSV (Territory) | 基础省份 |
| `territory` | `territories` | CSV (Territory) | 领土 |
| `msger` | `msger_data` | Registry (.tres) | 消息者数据 |
| `history-event` | `history_events` | DataHelper | 历史事件 |
| `random-event` | `random_events` | DataHelper | 随机事件 |
| `end-random-event` | `end_random_events` | DataHelper | 结局随机事件 |
| `chat-bubble` | `chat_bubble_data` | DataHelper | 聊天气泡 |
| `focused-chat` | `focused_chat_data` | DataHelper | 聚焦对话 |
| `ambition` | `ambitions` | DataHelper | 抱负/雄心 |
| `trait` | `traits` | DataHelper | 特性 |
| `property` | `properties` | DataHelper | 属性 |
| `action` | `actions` | DataHelper | 行动 |
| `decision` | `decisions` | DataHelper | 决策 |
| `decided-event` | `decided_events` | DataHelper | 已决定事件 |
| `imaginary` | `imaginaries` | DataHelper | 想象物 |
| `tag` | `tags` | Registry (.tres) | 标签 |
| `flag` | `flags` | Registry (.tres) | 标记 |
| `life-path-point` | `life_path_points` | Registry (.tres) | 人生轨迹点 |
| `legendary-poem` | `legendary_poems` | DataHelper | 传奇诗词 |
| `normal-poem-event` | `normal_poem_events` | DataHelper | 普通诗词事件 |
| `city` | `cities` | Registry (.tres) | 城市（内部合并用）|
| `event-option` | `event_options` | .tres 资源文件 | 事件选项 |
| `event-base` | `event_base_pool` | EventBaseLoader | 事件基底（含 FocusChat） |
| `state-transistor` | `state_transistors` | DataHelper | 状态转移 |
| `npc-document` | `npc_document` | DataHelper | NPC 文档 |
| `poem-taste` | `poem_taste` | DataHelper | 诗词品味 |

## 数据访问接口

[`core/database.gd`](../core/database.gd) 提供三层数据访问体系，按优先级使用：

### 第一层：类型化 Getter（推荐）

对每个数据类型的 O(1) uuid 查询，直接返回 Resource 实例：

```gdscript
Database.get_trait(uuid)        # → Trait | null
Database.get_property(uuid)     # → Property | null
Database.get_flag(uuid)         # → Flag | null
Database.get_imaginary(uuid)    # → Imaginary | null
Database.get_action(uuid)       # → Action | null
Database.get_focused_chat(uuid) # → FocusedChat | null
Database.get_chat_bubble(uuid)  # → ChatBubble | null
Database.get_ambition(uuid)     # → Ambition | null
Database.get_decision(uuid)     # → Decision | null
Database.get_npc_document(uuid) # → NPCDocument | null
Database.get_state_transistor(uuid) # → StateTransistor | null
Database.get_poem(uuid)         # → Poem | null
Database.get_poet(uuid)         # → Poet | null
Database.get_faction(uuid)      # → Faction | null
Database.get_province(uuid)     # → Province | null
Database.get_territory(uuid)    # → Territory | null
Database.get_msger(uuid)        # → Msger | null
Database.get_tag(uuid)          # → Tag | null
Database.get_event_option(uuid) # → EventOption | null
Database.get_poem_taste(uuid)   # → PoemTaste | null
Database.get_life_path_point(uuid) # → LifePathPoint | null
Database.get_history_event(uuid)# → HistoryEvent | null
Database.get_normal_poem_event(uuid) # → NormalPoem | null
Database.get_legendary_poem(uuid)    # → LegendaryPoem | null
Database.get_end_random_event(uuid)  # → EndRandomEvent | null
```

### 第二层：遍历方法

获取整个数据集的 Dictionary（通过 getter 访问而非裸 dict，便于后续私有化）：

```gdscript
Database.get_traits_all()       # → Dictionary (uuid → Trait)
Database.get_properties_all()   # → Dictionary (uuid → Property)
Database.get_flags_all()        # → Dictionary (uuid → Flag)
# ... 所有类型均有对应的 *_all() 方法
```

### 第三层：统一入口 resolve()

当不确定 key 的格式或类型时，使用统一入口：

```gdscript
Database.resolve(key)                                  # 自动查找
Database.resolve(key, "BaseEvent")                     # 限定类型
Database.resolve(key, "FocusedChat", true)             # 静默模式
```

支持三种 key 格式（按优先级依次尝试）：
1. `"base_name.event_id"` — 点号语法，对应 `event_bases` 分表
2. 直接 uuid — 命中 `_raw_data_pool` 统一池
3. uuid 后缀匹配 — 在 `"namespace.uuid"` 格式 key 中模糊匹配

## 如何添加新的资源类型

**核心契约：** `enum URN_TYPE` 是 [`core/database.gd`](../core/database.gd) 中所有加载数据类型的**清单列表**。
- 在 `database.gd` 里加了一个 `var artifacts: Dictionary` 来装新数据？→ 必须在 `URN_TYPE` 里加 `ARTIFACT`。
- 在 `database.gd` 里删了一个变量？→ `URN_TYPE` 里对应的条目也要删（或者标记 deprecated）。

**这是双向绑定，缺一不可。** 如果不同步，`_build_unified_index()` 会漏掉数据。

如果需要新增一种资源类型（例如 `artifact`），需要修改以下地方：

### Step 1: `model/enumerates.gd` — 注册类型

在 `enum URN_TYPE` 中追加新类型：

```gdscript
enum URN_TYPE {
    # ... 已有类型 ...
    ARTIFACT,   # artifacts — 文物数据
}
```

### Step 2: `core/database.gd` — 加载数据

在 `_init()` 中加载对应数据：

```gdscript
# Registry 方式
artifacts = Util.create_dict_from_registry(load("res://data/tres_artifacts_registry.tres"))

# CSV 方式
artifacts = Util.create_dict(DataLoader.load_csv_model(Artifact, 'artifacts'))

# DataHelper 方式（如果走事件系统）
var event_data = DataHelper.load_event_data()
artifacts = event_data.artifacts
```

### Step 3: `core/database.gd` — 加入统一索引

如果新类型需要通过 uuid 查询，在 `_build_unified_index()` 中加入扫描：

```gdscript
# 平铺字典扫描
_scan_flat_dict(artifacts, "artifacts")
```

如果新类型是嵌套结构（如 `random_events` 的 `{ tag: { uuid: Resource } }`），需要手动展开：

```gdscript
for bucket_key in artifacts:
    _scan_flat_dict(artifacts[bucket_key], "artifacts.%s" % str(bucket_key))
```

### Step 4: `core/database.gd` — 添加类型化 Getter

在 `get_*` 和 `get_*_all` 方法区域添加对应方法：

```gdscript
func get_artifact(uuid: String):
    return artifacts.get(uuid)

func get_artifacts_all() -> Dictionary:
    return artifacts
```

### Step 5: `DOCUMENTATIONS/urn_system.md` — 更新文档

在资源类型表格中追加一行，并在接口文档中补充 `get_artifact()` 和 `get_artifacts_all()`。

### 反悔成本

**低。** 改 5 个文件，每个都是加一行。没有上游依赖需要重构。

## 设计说明

### 为什么用连字符 `-` 而不是下划线 `_`？

URN 规范中资源类型部分惯例使用连字符。enum 值本身用大写+下划线（如 `LIFE_PATH_POINT`），但 `to_urn_str()` 转换时会自动做 `replace("_", "-")`。

### 为什么不分 namespace？

目前所有资源共享 `poem_map` 一个 namespace。如果后续需要隔离（如 `mod:xxx` 和 `core:xxx`），可以在 `parse_urn()` 中扩展 namespace 校验逻辑，同时增加 `make_urn_ex(namespace, type, id)` 重载。

但现阶段没必要 🤓☝️。奥卡姆剃刀：用不到就不加。
