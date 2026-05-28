# URN 系统文档

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

## API 接口

所有接口都是 `ENUMS` 类的 `static func`，使用方式：

```gdscript
# 生成 URN
var urn = ENUMS.make_urn(ENUMS.URN_TYPE.POET, "libai_001")
# → "urn:poem_map:poet:libai_001"

# 解析 URN
var parsed = ENUMS.parse_urn("urn:poem_map:poem:jiang_jin_jiu")
# → { "namespace": "poem_map", "type": "poem", "resource_id": "jiang_jin_jiu" }

# 类型转字符串
var type_str = ENUMS.urn_type_to_str(ENUMS.URN_TYPE.ACTION)
# → "action"

# 字符串转类型
var type_enum = ENUMS.find_urn_type("life-path-point")
# → ENUMS.URN_TYPE.LIFE_PATH_POINT
```

### 错误处理

所有接口在输入无效时都会：
1. 调用 `Logging.err()` 打印错误日志
2. 返回安全默认值（空字典、空字符串、-1 等）

**不要在调用方再包一层 try/catch 吞错误。**

## 如何添加新的资源类型

**核心契约：** `enum URN_TYPE` 是 `core/database.gd` 中所有加载数据类型的**清单列表**。
- 在 `database.gd` 里加了一个 `var artifacts: Dictionary` 来装新数据？→ 必须在 `URN_TYPE` 里加 `ARTIFACT`。
- 在 `database.gd` 里删了一个变量？→ `URN_TYPE` 里对应的条目也要删（或者标记 deprecated）。

**这是双向绑定，缺一不可。** 如果不同步，`find_triggerable_item()` 也好，将来基于 URN 的资源寻址也好，都会漏掉数据。

如果需要新增一种资源类型（例如 `artifact`），需要修改 **4 个地方**：

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

### Step 3: `core/database.gd` — 添加到查找链

如果这个类型需要通过 `find_triggerable_item()` 查找，添加对应分支：

```gdscript
if artifacts.get(uuid):
    return artifacts[uuid]
```

### Step 4: `DOCUMENTATIONS/urn_system.md` — 更新文档

在资源类型表格中追加一行：

```
| artifact | artifacts | Registry/CSV/DataHelper | 文物数据 |
```

### 反悔成本

**低。** 改 4 个文件，每个都是加一行。没有上游依赖需要重构。

## 设计说明

### 为什么用连字符 `-` 而不是下划线 `_`？

URN 规范中资源类型部分惯例使用连字符。enum 值本身用大写+下划线（如 `LIFE_PATH_POINT`），但 `to_urn_str()` 转换时会自动做 `replace("_", "-")`。

### 为什么不分 namespace？

目前所有资源共享 `poem_map` 一个 namespace。如果后续需要隔离（如 `mod:xxx` 和 `core:xxx`），可以在 `parse_urn()` 中扩展 namespace 校验逻辑，同时增加 `make_urn_ex(namespace, type, id)` 重载。

但现阶段没必要 🤓☝️。奥卡姆剃刀：用不到就不加。
