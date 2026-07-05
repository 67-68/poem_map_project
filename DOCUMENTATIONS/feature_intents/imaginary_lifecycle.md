# Imaginary 生命周期系统

## 文件
- `core/model/imaginary.gd` — Imaginary 模型（新增 `created_at_day` 字段）
- `core/player_state.gd` — 创建 Imaginary 时设置 `created_at_day`
- `core/survival_manager.gd` — 管线扩展 `_process_imaginary_effects()`，AP 公式修改
- `model/enumerates.gd` — `DISEASE_FENGHAN_IMAGINARY`、`DISEASE_OUXINLIXUE` 枚举
- `data/1_core_rules/traits/disease_fenghan_imaginary.tres` — 风寒 Trait
- `data/1_core_rules/traits/disease_ouxinlixue.tres` — 呕心沥血 Trait

## 核心机制

所有等级 Imaginary 统一保持 **2 旬（20 天）**，到期后按等级触发不同后果。

### 状态转换

```
Lv1 Imaginary
  → 2旬后: 直接删除（无副作用）

Lv2 Imaginary
  → 持有期: 每旬 health -5
  → 2旬后:
      ├─ flag_has_fenghan_imaginary == false → 添加 Trait: 风寒，设 flag=true，删除 Imaginary
      └─ flag_has_fenghan_imaginary == true  → 跳过转化，删除 Imaginary

Lv3 Imaginary
  → 持有期: 每持有 1 个 AP 上限 -1（在 get_current_ap_cap() 中实现）
  → 2旬后:
      ├─ flag_has_ouxin_imaginary == false → 添加 Trait: 呕心沥血，设 flag=true，删除 Imaginary
      └─ flag_has_ouxin_imaginary == true  → 跳过转化，删除 Imaginary
```

### 两个疾病 Trait

| Trait | uuid | 效果 | 实现方式 |
|-------|------|------|---------|
| 风寒 | `disease_fenghan_imaginary` | 所有 health 流失 ×1.5（仅负面） | `buffer_to_prop: health=1.5, NEGATIVE_ONLY` |
| 呕心沥血 | `disease_ouxinlixue` | 每旬 -5 健康 + AP 上限 -2 | `trait_effect_operations` + `get_current_ap_cap()` |

### AP 公式

```
AP = max(健康阶梯AP - count(lv3_imaginaries) - (呕心沥血 ? 2 : 0), 1)
```

**健康阶梯AP**：
- health ≤ 30 → 5
- health ≤ 60 → 8
- health > 60 → 10

### 防叠层

通过两个 bool flag 确保同一疾病只生效一次：
- `flag_has_fenghan_imaginary` — Lv2→风寒 已转化
- `flag_has_ouxin_imaginary` — Lv3→呕心沥血 已转化

## 管线位置

在 `_process_single_xun_settlement()` 中插入在 1.3 位置：

```
1.   aggregate_trait_effect()          ← trait 持续效果（含呕心沥血扣血）
1.3  _process_imaginary_effects()      ← 🆕 Lv2每旬扣血 + 到期删除与转化
1.5  _sync_health_ap_traits()          ← 健康→AP 同步
2.   _cost_survival()                  ← AP 刷新（使用新公式含 Lv3 + 呕心沥血惩罚）
```

顺序逻辑：
- Lv2 扣血在 1.3，在 AP 同步（1.5）之前 → 健康变化反映到 AP
- 呕心沥血扣血在 1（aggregate_trait_effect）→ 满足「颜色快照后结算」
- Lv3 AP 惩罚在 2（_cost_survival 中调用 get_current_ap_cap）→ 实时计算

## 旧存档兼容

- `created_at_day < 0` 的 Imaginary：跳过生命周期处理，降级警告
- `_count_active_lv3_imaginaries()` 中旧 Lv3 视为有效并警告

## DSL 分隔符

第一层 `|`，第二层 `;`，第三层 `/`。
