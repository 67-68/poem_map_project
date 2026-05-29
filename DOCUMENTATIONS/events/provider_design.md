# Provider 设计与动态选项生成机制

## 概述

Provider 是一种声明式的**动态选项生成器**。它允许在 CSV 中用一行 DSL 定义"从 context 中的某个列表，为每个元素生成一个选项"的常见模式，而不是在脚本里手写循环创建 `EventOption`。

**核心文件:**
- 基类：[`core/model/base_provider.gd`](../../core/model/base_provider.gd)
- 唯一实现：[`core/model/item_provider.gd`](../../core/model/item_provider.gd)
- 解析入口：[`parser/dsl_parser.gd:234`](../../parser/dsl_parser.gd:234)

## 设计动机

在事件驱动的游戏系统中，经常出现这样的需求：

> "酒馆里有 3 个 NPC（张三、李四、王五），玩家可以选择走向其中任意一个。"

传统做法是在事件里写死 3 个选项。但如果 NPC 列表是动态的（由上游事件决定），或者 NPC 数量不确定，写死选项就完蛋了 💀。

Provider 的作用就是把"遍历列表→生成选项→绑定事件"这个模式**封装成一行 DSL 配置**：

```
item_provider(list_key="guests", text_template="走向 {item}", target_event_key="event_talk", payload_key="target_npc")
```

## Provider DSL 语法

### 格式

```
<func_name>(<param_name>=<value>, <param_name>=<value>, ...)
```

**规则：**
- 使用 [`NamedDSLParser.parse_single()`](../../parser/named_dsl_parser.gd) 解析，与 operator/requirement 语法一致
- 函数名映射到 Provider 类（目前仅 `item_provider` → `ItemProvider`）
- 参数 key=value 直接 set 到 provider 实例的对应 `@export` 字段
- **不支持多个 provider**，一列只取一个

### 目前支持的 Provider

| 函数名 | 类 | 说明 |
|--------|-----|------|
| `item_provider` | [`ItemProvider`](../../core/model/item_provider.gd) | 从 context 列表生成选项，每个元素一个选项 |

### item_provider 参数

| 参数 | 必需 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `list_key` | **是** | String | — | Context 中列表的 key，例如 `"guests"`。运行时从 `context[list_key]` 读取数组 |
| `text_template` | **是** | String | — | 按钮文字模板，用 `{item}` 占位。例如 `"走向 {item}"` |
| `target_event_key` | **是** | String | — | 点击后触发的事件 key（`BaseEvent.uuid` 或 String key） |
| `payload_key` | **是** | String | — | 传递给目标事件的 payload key，例如 `"target_npc"`。每个选项会注入 `{payload_key: item}` 到 context |
| `use_push_event` | 否 | bool | `false` | 是否使用 `PushEventOperator`（默认用 `EventOperator`/`request_event_key`）。`true` 时事件会推入栈（LIFO），中断当前事件流 |

### 示例

**CSV 行：**
```csv
,random_event,evt_tavern_talk,"guests=[libai;dufu;wangwei]",,酒馆闲谈,,,item_provider(list_key="guests", text_template="走向 {item}", target_event_key="event_talk", payload_key="target_npc"),
```

**解析过程：**

1. `context` 列解析出 `custom_params = {"guests": PackedStringArray["libai", "dufu", "wangwei"]}`
2. `provider` 列解析出 `ItemProvider` 实例：
   - `list_key = "guests"`
   - `text_template = "走向 {item}"`
   - `target_event_key = "event_talk"`
   - `payload_key = "target_npc"`
3. 事件初始化时，`custom_params` 合并进 context → `context["guests"] = ["libai", "dufu", "wangwei"]`
4. `provider.provide(context)` 被调用，遍历 `guests` 列表生成 3 个选项：

| 选项文字 | payload context |
|---------|----------------|
| "走向 libai" | `{target_npc: libai}` |
| "走向 dufu" | `{target_npc: dufu}` |
| "走向 wangwei" | `{target_npc: wangwei}` |

每个选项点击后触发 `event_talk` 事件，携带对应的 `target_npc` 到目标事件的 context 中。

## 数据流

```
CSV 行
  ├─ context 列 → DSLParser.parse_context()
  │   └─ custom_params.guests = PackedStringArray["libai","dufu","wangwei"]
  │       ↓ merge 进事件 context
  │
  └─ provider 列 → DSLParser.parse_provider_field()
      └─ ItemProvider { list_key, text_template, target_event_key, payload_key }
          ↓ 绑定到 event.provider
          ↓

运行时触发事件：
  event.init(context)
    → Util.merge_context(context, custom_context_params)
      → context["guests"] = ["libai", "dufu", "wangwei"]  ← 数组值直接覆盖
    → provider.init(context)        ← 无操作，直接返回 context
    → provider.provide(context)     ← 遍历 context[list_key] 生成选项
      → _build_option(item)
        → 创建 EventOption
        → description = text_template.replace("{item}", str(item))
        → custom_context_params = {payload_key: item}
        → choice_result.operators = [EventOperator(event_key=target_event_key)]
        → 返回 EventOption 数组

选项展示给玩家：
  → 玩家点击 "走向 libai"
    → 触发 event_talk 事件
    → context 中包含 {target_npc: libai}
    → event_talk 的模板/操作符可以读取 target_npc
```

## 解析器注册

新增 Provider 类型需要在 [`DSLParser._load_provider_script()`](../../parser/dsl_parser.gd:201) 注册映射：

```gdscript
static func _load_provider_script(func_name: String) -> GDScript:
    match func_name:
        "item_provider":
            return load("res://core/model/item_provider.gd")
        # 新增 Provider 在这里加一行：
        # "npc_provider":
        #     return load("res://core/model/npc_provider.gd")
        _:
            return null
```

## 相关代码

- Provider 解析入口：[`DSLParser.parse_provider_field()`](../../parser/dsl_parser.gd:234)
- Provider 注册表：[`DSLParser._load_provider_script()`](../../parser/dsl_parser.gd:201)
- Provider 实例化：[`DSLParser._create_provider_instance()`](../../parser/dsl_parser.gd:208)
- Provider 基类：[`BaseProvider`](../../core/model/base_provider.gd)
- ItemProvider 实现：[`ItemProvider`](../../core/model/item_provider.gd)
- NamedDSLParser（解析 param=val 语法）：[`NamedDSLParser`](../../parser/named_dsl_parser.gd)
- 选项生成时的 payload 注入：[`EventOption.custom_context_params`](../../model/event/event_option.gd:9)
- Context 数组合并：[`Util.merge_context()`](../../core/util.gd:300)
