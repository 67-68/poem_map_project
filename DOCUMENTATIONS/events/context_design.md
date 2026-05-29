# Context 设计与自定义参数合并机制

## 概述

`context` 列是 CSV 中替代旧版分散字段（`trigger_tags`、`weight`、`background` 等）的统一入口。它使用 **`|` 分隔的 DSL 语法**，将多个参数压缩为一个字符串，同时也为模板系统提供了自定义参数注入的通道。

## Context DSL 语法

```
tag:<4段式tag>,<4段式tag>|weight:<float>|background:(<URN>)|<customKey>:<customValue>|<customKey>=[val1;val2;val3]
```

### 字段说明

| 字段 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `tag` / `trigger_tags` | 否 | String | 逗号分隔的触发标签列表，使用 4 段式格式。支持 `[tag1,tag2]` 方括号语法 |
| `weight` | 否 | Float | 权重，默认 `10.0` |
| `background` | 否 | String | 背景图 URN，用括号包裹。示例：`background:(bg_tavern_night)` |
| `*customKey` | 否 | String / `PackedStringArray` | 自定义模板参数。普通值直接写字符串；方括号 `[a;b;c]` 语法自动解析为 `PackedStringArray` |

### 值分隔符规则

| 场景 | 分隔符 | 原因 |
|------|--------|------|
| 字段间分隔 | `|`（竖线） | tag 内部已用 `:` 和 `,`，`|` 在 DSL 中从不出现 |
| Key-Value 分隔 | `=`（推荐）或 `:`（兼容） | 等号更直观，与常见配置语法一致 |
| 普通数组（自定义参数） | `;`（分号） | 避免与逗号 key:value 扩展逻辑冲突 |
| tag 列表 | `,`（逗号） | tag 本身不含逗号，逗号安全 |

### 为什么自定义参数数组用 `;` 而不是 `,`？

因为 catch-all 分支中，逗号被用来拆分**附加 key:value 对**（见 [`DSLParser.parse_context()`](../../parser/dsl_parser.gd:93)）。如果你写：

```
some_key=[a,b,c]
```

当前解析器看到逗号，会尝试把 `b` 和 `c` 解析成独立的 `key:value` 字段，结果惨不忍睹 💀。

用 `;` 做数组分隔符完美避开冲突，方括号包裹让解析器能明确识别"这是一个数组字面量"。

### 示例

```
tag:actor:status:temporary:drunk,city:econ:level:prosperous|weight:15.5|background:(bg_tavern_night)|difficulty:hard|reward_mult:2.0
```

这个 context 解析后会产生：

```json
{
  "trigger_tags": ["actor:status:temporary:drunk", "city:econ:level:prosperous"],
  "weight": 15.5,
  "background": "bg_tavern_night",
  "custom_params": {
    "difficulty": "hard",
    "reward_mult": "2.0"
  }
}
```

### 带数组的示例

```
tag:actor:status:temporary:drunk|candidates=[libai;dufu;wangwei]|difficulty:hard
```

解析后：

```json
{
  "trigger_tags": ["actor:status:temporary:drunk"],
  "weight": 10.0,
  "background": "",
  "custom_params": {
    "candidates": PackedStringArray["libai", "dufu", "wangwei"],
    "difficulty": "hard"
  }
}
```

方括号数组语法各种变体：

| 输入 | 输出类型 | 输出值 |
|------|---------|--------|
| `key=[a;b;c]` | `PackedStringArray` | `["a", "b", "c"]` |
| `key=[a]` | `PackedStringArray` | `["a"]` |
| `key=[]` | `PackedStringArray` | `[]` |
| `key=[a; ;c]` | `PackedStringArray` | `["a", "c"]`（空元素被 strip 过滤） |
| `key=plain` | `String` | `"plain"` |

## 自定义参数 (custom_params)

### 定义

context DSL 中，**key 不属于 `tag` / `trigger_tags` / `weight` / `background` 这四个已知字段的，自动归入 `custom_params`**。

### 类型

- **普通值**（无方括号）：`String`，`merge_context` 中尝试转数值做乘法叠加，否则当文本字符串直接存储
- **数组值**（`[a;b;c]` 方括号语法）：`PackedStringArray`，`merge_context` 中直接覆盖（不做数学运算）

### 用途

`custom_params` 提供了一种"模板参数注入"机制：事件模板可以在 `init()` 时从 context 中读取自定义参数，动态调整自身行为。

### 示例场景

假设有一个"打猎"事件模板，它希望根据 context 中的 `difficulty` 和 `reward_mult` 调整难度和奖励：

CSV 行：
```csv
,random_event,evt_hunt_01,"tag:action:intent:hunt:forest|difficulty:hard|reward_mult:2.0",,深山狩猎,林中传来虎啸,prop:money:+50
```

解析后，`custom_context_params` = `{"difficulty": "hard", "reward_mult": "2.0"}`。

在 `RandomEvent.init()` 中，通过 `Util.merge_context()` 合并到 context 字典，模板即可在初始化时读取这些参数：

```gdscript
# RandomEvent.init() 内部
Util.merge_context(context, custom_context_params)
# context 现在包含 "difficulty": "hard", "reward_mult": 2.0
```

## merge_context 函数

### 定义位置

[`core/util.gd:300`](../../core/util.gd:300)

### 签名

```gdscript
static func merge_context(base: Dictionary, overlay: Dictionary) -> Dictionary
```

### 合并规则

| overlay 值类型 | base 值类型 | 行为 |
|---------------|-------------|------|
| `int` / `float` | `int` / `float` | **相乘**：`base[key] *= overlay[key]` |
| `int` / `float` | 不存在 / 非数值 | **直接覆盖**：`base[key] = overlay[key]` |
| `String`（可转数值） | 任意 | **数值乘法**：按 `float` 相乘 |
| `String`（纯文本） | 任意 | **直接覆盖**：作为文本字符串存储 |
| `Array` / `PackedStringArray` | 任意 | **直接覆盖**：数组作为 opaque 值传递，不尝试数学运算 |

### 为什么 int/float 是相乘而不是相加？

**贝叶斯思考模式**：在游戏模板系统中，`custom_params` 通常表示"倍率调整"（难度倍率、奖励倍率等）。相乘是在不知道 base 值具体量级的情况下，最安全的"缩放"操作。如果 context 中已有的 base 值是 `reward_mult: 1.5`，overlay 传入 `reward_mult: 2.0`，相乘得到 `3.0` 意味着"在已有倍率基础上再翻倍"，符合直觉。

如果是相加，耦合性太强（需要知道 base 的确切语义），而且容易越界。

### 调用链

```
CSV 解析时：
  DSLParser.parse_context() → 提取 custom_params → 存入 event.custom_context_params

事件初始化时：
  RandomEvent.init(context)
    → Util.merge_context(context, custom_context_params)  # 合并自定义参数
    → super.init(context)                                  # BaseEvent 初始化
    → event_result.init(context) if event_result           # 事件级结果初始化
```

### 自定义参数完整生命周期

```
CSV 行
  ↓ context 列
DSLParser.parse_context()
  ↓ 提取非标准 key → custom_params（String 或 PackedStringArray）
RandomEvent.custom_context_params
  ↓ init() 时调用
Util.merge_context(context, custom_context_params)
  ↓ int/float 相乘，String 转数值或文本，Array 直接覆盖
合并后的 context
  ↓ 传给 super.init() / event_result.init()
模板系统读取自定义参数
```

## 相关代码

- Context DSL 解析：[`DSLParser.parse_context()`](../../parser/dsl_parser.gd:27)
- 自定义参数存储：[`RandomEvent.custom_context_params`](../../model/random_event.gd:10)
- Context 合并：[`Util.merge_context()`](../../core/util.gd:300)
- 合并调用点：[`RandomEvent.init()`](../../model/random_event.gd:12)
