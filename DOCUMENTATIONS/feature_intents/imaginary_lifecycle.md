# Imaginary 生命周期系统 (V13: + 意象消失后果)

## 文件
- `core/model/imaginary.gd` — Imaginary extends Trait（V11: 新增 imaginary_type, created_at_day）
- `core/model/imaginary_grant_chance.gd` — Action 意象获取概率条目 Resource
- `core/model/action.gd` — 新增 `imaginary_grants: Array[ImaginaryGrantChance]` + `resolve_imaginary_grants()`
- `core/model/trait.gd` — Trait 基类（duration_xun/lasting_xun/trait_effect_operations）
- `core/operators/roll_imaginary_operator.gd` — 创建 Imaginary（含 type 读取 + FIFO）
- `core/sub_action_executor.gd` — `_try_imaginary_grant()` 行动触发意象获取入口
- `core/player_state.gd` — `_on_request_add_imaginary()` / `init_imaginaries()` + `_enforce_imaginary_limit()` **V13: 删前 emit imaginary_lost**
- `core/eventbus.gd` — **V13: 新增 signal `imaginary_lost(data: Dictionary)`**
- `core/survival_manager.gd` — `_process_imaginary_effects()` **V13: 删前 emit imaginary_lost** + `_on_imaginary_lost()` handler + flag 注册
- `core/tag_manager.gd` — `_sync_poem_stance()` 三大类计数 → stance tag
- `core/poem_effect_calculator.gd` — 空壳类，发布诗词效果计算
- `core/action_hint_builder.gd` — `build_trait_hint()` Imaginary 分支
- `ui/left_player_panel.gd` — `_rebuild_trait_grid()` 遍历 `Database.imaginaries_detail`
- `ui/trait_demonstrator.gd` — `set_trait()` HSeparator 到期进度条（长度=剩余/总*最大宽）
- `ui/trait_demonstrator.tscn` — HSeparator 节点
- `ui/poem_crafter.gd` — 删除 MODE_TO_INTENT/溢出Slot；接入 CheckButton 发布效果
- `tools/data/imaginary_definitions.json` — 意象定义库（name/level/type/get_hint）
- `data/1_core_rules/events/fallback/imaginary_gain_fallback.tres` — 通用意象获取 fallback 事件
- `data/1_core_rules/events/fallback/imaginary_loss_fifo_fallback.tres` — **V13: FIFO顶替消失叙事**
- `data/1_core_rules/events/fallback/imaginary_loss_expire_fallback.tres` — **V13: 自然到期消失叙事**
- `data/3_actions_pool/actions/*.tres` — 5 个父 action 配置 `imaginary_grants`

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

## V12: 行动触发意象获取 (Action-Triggered Imaginary Grant)

### 设计意图

玩家执行子行动成功后，有一定概率通过加权抽奖获得一个与行动类型关联的意象。意象获取事件通过 `request_event_key` 进入队列（不打断正常叙事流），与主事件顺序播放。

### ImaginaryGrantChance 数据类

[`core/model/imaginary_grant_chance.gd`](core/model/imaginary_grant_chance.gd:1) — 每个条目描述一种意象类型及其独立获取概率。多个条目间通过加权单次 Roll 消歧。

### Action 字段

- [`Action.imaginary_grants`](core/model/action.gd:1): `Array[ImaginaryGrantChance]` — 多条目配置
- [`Action.imaginary_type`](core/model/action.gd:1) + `imaginary_obtain_possibility`: 旧单条目字段（废弃但保留兼容）
- [`Action.resolve_imaginary_grants(parent)`](core/model/action.gd:1): 优先级: 自己的 grants > 旧字段 fallback > 父行动继承

### 数据流

```
SubActionExecutor.execute() success 路径
  → _try_imaginary_grant(sub_action, state)
    → resolve_imaginary_grants(parent_action)
    → 加权单次 Roll（randi() % 101）
    → 命中 → 按 type 从 imaginary_definitions.json 过滤
    → 随机选一个意象
    → EventBus.request_add_imaginary → 写入 Database
    → EventBus.request_event_key → 队列排队叙事事件
  → scan_events → request_event_key 主事件
  → 播放顺序: 意象事件 → 主事件
```

### 各父 Action 意象配置

| 父 Action | 意象类型 | 概率 | 概率值 |
|-----------|:---:|:---:|:---:|
| bai_ye (拜谒) | 功名 | `xxs_success_rate` | 20% |
| fang_shi (坊市) | 功名 | `xxxs_success_rate` | 10% |
| fang_shi (坊市) | 狂放 | `xxxs_success_rate` | 10% |
| du_zhuo (闲居) | 隐逸 | `xxs_success_rate` | 20% |
| deng_gao (出游) | 隐逸 | `xxxs_success_rate` | 10% |
| jiao_you (交游) | 狂放 | `xxs_success_rate` | 20% |

> 子行动不填 `imaginary_grants`，运行时自动从父 action 继承。

### 事件路由

- 专属事件 `imaginary_gain_{uuid}` 存在 → 使用专属事件
- 专属事件不存在 → fallback `imaginary_gain_fallback`，动态插值 `{@imaginary_gain_hint}`
