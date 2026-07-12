# Imaginary 重复获取 → 后缀副本机制

## 目标

当玩家获取一个已持有的意象时，不再补偿 `talent +3`，改为创建一个带数字后缀的独立副本实例。

## 行为规范

```
首次获取 "snow"  → 创建 Imaginary(uuid="snow")
再次获取 "snow"  → 创建 Imaginary(uuid="snow1")
第三次获取 "snow" → 创建 Imaginary(uuid="snow2")
...
```

| 属性 | 规则 |
|------|------|
| 副本 uuid | 基础名 + 最小可用数字后缀（`snow` → `snow1` → `snow2` ...） |
| 副本 name | 从 `imaginary_definitions.json` 取基础名的 name（无后缀） |
| 副本 level | 沿用新获取的入参（`RollImaginaryOperator` 的 `level` 参数；`_on_request_add_imaginary` 默认 1） |
| 副本 duration_xun | 统一 2 |
| 副本 get_hint | 复用基础名的 hint |
| 到期行为 | 各自独立到期删除，不晋升 |
| 数量上限 | 无 |

## 消费方兼容性审计

| 消费方 | 访问方式 | 影响 |
|--------|----------|:---:|
| `survival_manager` — 到期删除 | `.erase(uuid)` 精确删除 | ✅ |
| `imaginary_comprehender` — 阅后即焚 | `.erase(uuid)` 精确删除 | ✅ |
| `fragment_matcher` — 诗词匹配 | 精确 uuid Set 匹配 | ✅（`snow` 始终存在，因为先于 `snow1`） |
| `poem_crafting_calculator` — 评分 | 只读 `imag.level` | ✅ |
| `lianju_score_operator` | `.values()` 遍历 | ✅ |
| `imaginary_level_reward_operator` | `.values()` 遍历 | ✅ |
| `imaginary_sound_listener` | diff 快照 | ✅ |
| `action_hint_builder` | 只读展示 | ✅ |
| `UI left_player_panel` | 遍历展示 | ✅ |

## 实现范围

### 改动文件（2 个业务文件 + 1 个文档）

1. **`core/player_state.gd`** — 两个改动点：
   - 新增工具方法 `_resolve_imaginary_uuid(base_name)` — 找下一个可用 uuid
   - 修改 `_on_request_add_imaginary()` — 删除 talent+3 分支，改为后缀化创建

2. **`core/operators/roll_imaginary_operator.gd`** — 一个改动点：
   - 修改 `operate()` — 删除 talent+3 分支，改为后缀化创建，level 沿用 `self.level`

3. **`DOCUMENTATIONS/feature_intents/imaginary_lifecycle.md`** — 更新状态转换说明

### 核心算法

```gdscript
## 返回下一个可用的 uuid
## "snow" 不存在 → "snow"
## "snow" 已存在 → "snow1"
## "snow", "snow1" 都存在 → "snow2"
static func _resolve_imaginary_uuid(base_name: String) -> String:
    if not Database.imaginaries_detail.has(base_name):
        return base_name
    var counter := 1
    while Database.imaginaries_detail.has(base_name + str(counter)):
        counter += 1
    return base_name + str(counter)
```

### Level 来源差异

- `RollImaginaryOperator`：`level` 来自 DSL 入参 `roll_imaginary(level=N)`，存储在 `self.level`
- `PlayerState._on_request_add_imaginary`：来自 `ImageryAcquisitionOperator` 广播，无 level 参数，默认 `level = 1`

### Name 回退

副本的 `name` 始终从 `imaginary_definitions.json` 取基础名的 name（去后缀查询），确保 `snow1` 的展示名仍是「孤雪」而非空字符串。
