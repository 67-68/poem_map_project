# Imaginary 生命周期系统 (V9.1: 继承 Trait + 重复获取后缀副本)

## 文件
- `core/model/imaginary.gd` — Imaginary extends Trait（V9 重构）
- `core/model/trait.gd` — Trait 基类（duration_xun/lasting_xun/trait_effect_operations）
- `core/model/property_operator.gd` — PropertyOperator（Lv2 扣血用）
- `core/operators/roll_imaginary_operator.gd` — 创建 Imaginary（含重复后缀化）
- `core/player_state.gd` — `_on_request_add_imaginary()` / `init_imaginaries()` + `_resolve_imaginary_uuid()`
- `core/survival_manager.gd` — `_process_imaginary_effects()` 统一使用 lasting_xun/duration_xun
- `core/action_hint_builder.gd` — `build_trait_hint()` Imaginary 分支
- `ui/left_player_panel.gd` — `_rebuild_trait_grid()` 遍历 `Database.imaginaries_detail`
- `ui/trait_demonstrator.gd` — `set_trait()` 检测 `is Imaginary`，印章按等级着色
- `tools/data/imaginary_definitions.json` — 意象定义库（name/level/get_hint）

## 核心机制

### 继承链 (V9)

```
Resource → GameEntity → Trait → Imaginary
```

Imaginary 继承 Trait 的全部字段，共享统一的到期系统（`duration_xun` + `lasting_xun`）。

### 重复获取 → 后缀副本（V9.1 新增）

当玩家已持有某意象时，再次获取**不再补偿 talent+3**，改为创建带数字后缀的独立副本：

| 场景 | 结果 |
|------|------|
| 首次获取 "snow" | uuid = "snow" |
| 再次获取 "snow" | uuid = "snow1"（副本） |
| 第三次获取 "snow" | uuid = "snow2" |

副本属性：
- **name**：从 `imaginary_definitions.json` 取基础名的 name（"snow1" 的展示名仍是 "孤雪"）
- **level**：沿用新获取的入参（`RollImaginaryOperator` 的 `level`；`_on_request_add_imaginary` 默认 1）
- **duration_xun**：统一 2
- **get_hint**：复用基础名的 hint
- **到期**：各自独立到期删除，不晋升
- **数量上限**：无

### 字段对比

| 字段 | V7/V8 | V9 | 说明 |
|------|-------|-----|------|
| `expiry_trait` | `@export var` | 继承自 Trait | 不再用于 Imaginary（到期统一删除） |
| `expiry_flag` | `@export var` | **删除** | 冗余（`add_trait()` 自动去重） |
| `created_at_day` | `@export var` | **删除** | 替换为 `duration_xun=2` + `lasting_xun` |
| `level_effect_health` | `@export var` | **删除** | 替换为 `trait_effect_operations` |
| `level` | `@export var` | 保留 | |
| `get_hint` | `@export var` | 保留 | |
| `duration_xun` | 无 | 继承=2 | Trait 基类字段 |
| `lasting_xun` | 无 | 继承=0 | Trait 基类字段 |
| `trait_effect_operations` | 无 | Lv2: `[health -5]` | Trait 基类字段 |

### 状态转换

```
Lv1 Imaginary
  → 创建时: duration_xun=2, lasting_xun=0
  → 每旬: lasting_xun += 1（无副作用）
  → 2旬后: lasting_xun >= 2 → 直接删除

Lv2 Imaginary
  → 创建时: duration_xun=2, lasting_xun=0, trait_effect_operations=[health -5]
  → 每旬: lasting_xun += 1 → operate_continuous_effect() 执行 health -5
  → 2旬后: lasting_xun >= 2 → 直接删除

Lv3 Imaginary
  → 创建时: duration_xun=2, lasting_xun=0
  → 持有期: 每持有 1 个 AP 上限 -1（在 `get_current_ap_cap()` 中实现）
  → 每旬: lasting_xun += 1（无 trait_effect_operations）
  → 2旬后: lasting_xun >= 2 → 直接删除
```

### AP 公式（不变）

```
AP = max(健康阶梯AP - count(lv3_imaginaries) - (呕心沥血 ? 2 : 0), 1)
```

- Lv3 计数改用 `lasting_xun < duration_xun` 判断活跃状态（不再依赖 `created_at_day`）

### 防叠层（已删除）

V8 的 `expiry_flag` 防叠层机制已删除。`PlayerState.add_trait()` 内部对同一 traits 去重（`if not traits.has(trait_name)`），同一疾病不会重复添加，无需额外 flag。

## 管线位置（不变）

```
1.   aggregate_trait_effect()          ← trait 持续效果（含呕心沥血扣血）
1.3  _process_imaginary_effects()      ← lasting_xun 递增 + Lv2 operate_continuous_effect + 到期删除
1.5  _sync_health_ap_traits()          ← 健康→AP 同步
2.   _cost_survival()                  ← AP 刷新
```

## UI：左侧面板混排

Imaginary 与 Trait 混排在同一 `TraitGrid` 中：

- 印章取 `name[0]`，颜色按等级：L1 灰 / L2 白 / L3 金
- Hover 提示通过 `ActionHintBuilder.build_trait_hint()` 的 `is Imaginary` 分支生成：
  - 显示：名称 / 等级 / get_hint / trait_effect_operations
  - 不显示：buffer_to_prop / buffer_to_region / time_penalty / 持续区 / hover_narrative

## 旧存档兼容

无 `created_at_day` 字段，无特殊兼容需求。新存档的 Imaginary 默认为 `duration_xun=2, lasting_xun=0`。

## DSL 分隔符

第一层 `|`，第二层 `;`，第三层 `/`。
