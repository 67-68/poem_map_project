# RollImaginaryOperator — 按等级随机获取意象

## 文件
- `core/model/imaginary.gd` — Imaginary 模型（`get_hint: String` 字段）
- `tools/data/imaginary_definitions.json` — 意象定义库（`level` 和 `get_hint` 字段）
- `core/operators/roll_imaginary_operator.gd` — RollImaginaryOperator（本文件）
- `core/player_state.gd` — PlayerState（`_on_request_add_imaginary` 统一写入入口）
- `core/eventbus.gd` — `request_add_imaginary(tag, context)` 信号
- `parser/micro_dsl_parser.gd` — DSL 解析注册
- `core/_export_dependency_anchor.gd` — Web export 预加载引用

## 核心机制

### DSL 语法

```
roll_imaginary(level=2)
```

`level` 参数指定要随机的意象等级（1/2/3）。Operator 从 `imaginary_definitions.json` 中筛选对应等级的所有意象，随机选取一个加入玩家。

### 数据流（V12 统一管道）

```
CSV results: roll_imaginary(level=N)
  → MicroDSLParser 解析为 RollImaginaryOperator(level=N)
  → init(context) 阶段:
      1. 加载 imaginary_definitions.json
      2. 过滤 level==N 的条目
      3. 随机选一个
      4. context["imaginary_gain_hint"] = 选中项的 get_hint
  → operate() 阶段:
      1. 从定义库加载 name
      2. 组装 context Dict: {name, level, get_hint, trait_effect_operations(Lv2)}
      3. 发射 EventBus.request_add_imaginary(base_uuid, context)
         → PlayerState._on_request_add_imaginary(tag, context)
         → 统一创建 Imaginary + context 字段覆盖 + FIFO + emit imaginary_changed
      4. show_hint() 做 toast 通知
```

### 架构决策：统一写入管道

**V12 之前**：RollImaginaryOperator 直接写 `Database.imaginaries_detail` + 自己做 FIFO 顶替，绕过了 PlayerState 的信号管道，导致 FIFO 逻辑在两处重复且 RollImaginaryOperator 版本因 autoload 路径错误而失效。

**V12 之后**：RollImaginaryOperator 只负责「选意象 + 传上下文」，不再直接操作 Database。所有 Imaginary 写入走 PlayerState._on_request_add_imaginary 统一入口，FIFO 逻辑只存在于 PlayerState 一处。

### Imaginary 模型字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `get_hint` | `String` | 获取时的外部描写提示，自包含，不依赖上下文。eg. "一件粗麻布衣，缝补痕迹历历可见" |

### describe_preview() 覆盖

在 hover 预览阶段（`ActionHintBuilder`），通过多态调用展示预览文本：

- `level=1` → `"随机获得一个等级1的意象"`
- `level=2` → `"随机获得一个等级2的意象"`
- `level=3` → `"随机获得一个等级3的意象"`

> 注意：此时 `init()` 未执行，随机尚未发生，无法显示具体意象名。执行后通过 `show_hint()` 做 toast 通知具体获得的内容。

### imaginary_definitions.json 字段

每条意象增加：
- `level` (int): 意象等级，1/2/3
- `get_hint` (str): 自包含的外部描写

### context Dict 契约

RollImaginaryOperator 传给 PlayerState 的 context 字典：

```gdscript
{
    "name": "意象显示名",                    # 覆盖定义库的 name（可选）
    "level": 2,                              # 覆盖定义库的 level（可选）
    "get_hint": "一件粗麻布衣...",            # 覆盖定义库的 get_hint（可选）
    "trait_effect_operations": [             # Lv2 专属：持有期效果（可选）
        { "property": "health", "value": -5 }
    ]
}
```

## 状态转换

无状态转换。RollImaginaryOperator 是纯随机获取操作符。

## 与现有 operator 的区别

| Operator | 功能 |
|----------|------|
| `imagery_add(name=xxx)` | 添加指定名称的意象 |
| `imaginary_level_reward(...)` | 弹出 picker 让玩家选，按等级给名声奖励 |
| **`roll_imaginary(level=N)`** | 从定义库随机选对应等级的一个，自包含获取 |

## DSL 分隔符

第一层 `|`，第二层 `;`，第三层 `/`。
