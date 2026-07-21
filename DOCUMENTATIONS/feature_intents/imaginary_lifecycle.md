# Imaginary 生命周期系统 (V11: 三大类意象 + FIFO顶替 + 5旬到期)

## 文件
- `core/model/imaginary.gd` — Imaginary extends Trait（V11: 新增 imaginary_type, created_at_day）
- `core/model/trait.gd` — Trait 基类（duration_xun/lasting_xun/trait_effect_operations）
- `core/operators/roll_imaginary_operator.gd` — 创建 Imaginary（含 type 读取 + FIFO）
- `core/player_state.gd` — `_on_request_add_imaginary()` / `init_imaginaries()` + `_enforce_imaginary_limit()`
- `core/survival_manager.gd` — `_process_imaginary_effects()` 统一使用 lasting_xun/duration_xun
- `core/tag_manager.gd` — `_sync_poem_stance()` 三大类计数 → stance tag
- `core/poem_effect_calculator.gd` — 空壳类，发布诗词效果计算
- `core/action_hint_builder.gd` — `build_trait_hint()` Imaginary 分支
- `ui/left_player_panel.gd` — `_rebuild_trait_grid()` 遍历 `Database.imaginaries_detail`
- `ui/trait_demonstrator.gd` — `set_trait()` HSeparator 到期进度条（长度=剩余/总*最大宽）
- `ui/trait_demonstrator.tscn` — HSeparator 节点
- `ui/poem_crafter.gd` — 删除 MODE_TO_INTENT/溢出Slot；接入 CheckButton 发布效果
- `tools/data/imaginary_definitions.json` — 意象定义库（name/level/type/get_hint）

## 核心机制

### V11: 三大类意象

每个意象归属于三种大类之一：**功名** / **隐逸** / **狂放**。

| 大类 | 典型意象 | 语义 |
|------|---------|------|
| 功名 | 骐骥、苍生、玉阶、烽火、泰山、青史 | 入世、济世、仕途 |
| 隐逸 | 布衣、孤雪、古砚、寒月、折柳、落木 | 归隐、孤独、自然 |
| 狂放 | 醉意、空盏、危楼、鬼火、寒锋、沧海 | 不羁、纵情、雄浑 |

### 继承链

```
Resource → GameEntity → Trait → Imaginary
  + imaginary_type: String   (新增)
  + created_at_day: int      (新增，FIFO 排序)
```

### V11: FIFO 顶替机制

当持有意象总数 > `PlayerState.max_imaginary_managable` 时，删除 `created_at_day` 最小的（最旧的）意象。

| 触发点 | 方法 |
|--------|------|
| `RollImaginaryOperator.operate()` | 写入后调用 `_enforce_imaginary_limit()` |
| `PlayerState._on_request_add_imaginary()` | 同上 |
| `PlayerState.init_imaginaries()` | 同上 |

### 到期: 5 旬

- **duration_xun = 5**（V9 为 2）
- 每旬 `lasting_xun += 1`
- `lasting_xun >= 5` → 直接删除
- UI: [`TraitDemonstrator`](ui/trait_demonstrator.gd:1) 中 HSeparator 宽度 = `(剩余/5) × PanelContainer.size.x`

### 状态转换

```
Lv1 Imaginary (duration_xun=5)
  → 每旬: lasting_xun += 1
  → 5旬后: lasting_xun >= 5 → 删除

Lv2 Imaginary (duration_xun=5, trait_effect_operations=[health -5])
  → 每旬: lasting_xun += 1 → operate_continuous_effect() 执行 health -5
  → 5旬后: 删除

Lv3 Imaginary (duration_xun=5)
  → 每旬: lasting_xun += 1
  → 持有期: AP 上限 -1（每持有 1 个 Lv3）
  → 5旬后: 删除
```

## Stance 系统 (V11 重写)

不再依赖 `poem.intent`（已删除）。改为统计当前持有意象的三大类数量：

```
功名数 > (隐逸数 + 狂放数) → zhuoliu（浊流诗人）
(隐逸数 + 狂放数) > 功名数 → qingliu（清流诗人）
相等 → neutral（中立诗人）
无任何意象 → 清空所有 stance tag
```

执行点：`TagManager._sync_poem_stance()` 每旬 tick + trait 变动时触发。

## 发布诗词效果 (V11 新增)

`PoemCrafter` 的 CheckButton「并发布诗词」勾选后，调用 [`PoemEffectCalculator.calculate(poem)`](core/poem_effect_calculator.gd:1) 计算效果，结果注入事件 ctx 的 `publish_effect` 字段。当前为 placeholder。

## UI: 左侧面板

- Imaginary 与 Trait 混排在 [`TraitGrid`](ui/left_player_panel.gd:484) 中
- 印章颜色: L1 灰 / L2 白 / L3 金
- HSeparator 显示到期剩余比例（Imaginary 专属）
