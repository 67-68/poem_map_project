# RollImaginaryOperator — 按等级随机获取意象

## 文件
- `core/model/imaginary.gd` — Imaginary 模型（新增 `get_hint: String` 字段）
- `tools/data/imaginary_definitions.json` — 意象定义库（新增 `level` 和 `get_hint` 字段）
- `core/operators/roll_imaginary_operator.gd` — RollImaginaryOperator（新建）
- `parser/micro_dsl_parser.gd` — DSL 解析注册
- `core/_export_dependency_anchor.gd` — Web export 预加载引用

## 核心机制

### DSL 语法

```
roll_imaginary(level=2)
```

`level` 参数指定要随机的意象等级（1/2/3）。Operator 从 `imaginary_definitions.json` 中筛选对应等级的所有意象，随机选取一个加入玩家。

### 数据流

```
CSV results: roll_imaginary(level=N)
  → MicroDSLParser 解析为 RollImaginaryOperator(level=N)
  → init(context) 阶段:
      1. 加载 imaginary_definitions.json
      2. 过滤 level==N 的条目
      3. 随机选一个
      4. context["imaginary_gain_hint"] = 选中项的 get_hint
  → operate() 阶段:
      1. 重复检测（已有该 Imaginary → talent +3）
      2. 否则创建 Imaginary(level=N) 写入 Database.imaginaries_detail
      3. 发射 EventBus.imaginary_changed
```

### Imaginary 模型新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `get_hint` | `String` | 获取时的外部描写提示，自包含，不依赖上下文。eg. "一件粗麻布衣，缝补痕迹历历可见" |

### imaginary_definitions.json 新增字段

每条意象增加：
- `level` (int): 意象等级，当前全部为 1
- `get_hint` (str): 自包含的外部描写

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
