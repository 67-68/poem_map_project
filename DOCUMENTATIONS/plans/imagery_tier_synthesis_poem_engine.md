# 意象阶级 · 合成坍缩 · 诗词评价引擎 V3

> **状态：** 架构契约（最终版）
> **上级依赖：** [`emotion_imagery_orthogonal_pipeline_v2.md`](emotion_imagery_orthogonal_pipeline_v2.md)（意象获取管线 V2）
> **替代文档：** 无（新设计）
> **关联模型：** [`ImaginaryTag`](../../core/model/imaginary.gd)、[`PoemCraftingCalculator`](../../core/poem_crafting_calculator.gd)、[`PoemCrafter`](../../ui/poem_crafter.gd)

---

## 0. 核心概念澄清：什么是"意象"

在进入 Tier 分级之前，必须先明确系统中最基本的本体论问题：

### 0.1 意象是抽象 Category，不是具体叶子节点

```
❌ 错误理解: "意象 = TARGET_NPC_DUFU:thatched_grass（具体碎片）"
✅ 正确理解: "意象 = TARGET_NPC_DUFU（抽象 Category/Tag）"
```

- **碎片 (Fragment/Basic Imaginary)**：`TARGET_NPC_DUFU:thatched_grass`，是玩家在事件中获得的**具象实体**，存储在 `ImaginaryTag.basic_imaginaries` 数组中。
- **意象/Category (ImaginaryTag)**：`TARGET_NPC_DUFU`，是**抽象容器**。它是诗词创作的"卡牌"，是升级系统的载体。

> 类比：碎片是经验值，意象是等级。你升级的不是"击败第3个哥布林获得的27点经验"，而是"战士职业从 Lv2 → Lv3"。

### 0.2 升级系统挂在 Category 上

当一个 Category 下的碎片数量累积到阈值，该 Category 升级（Lv1 → Lv2 → Lv3）。碎片的"品质"（Tier）会影响 Category 的"底色"（见第 2 节）。

---

## 1. 意象三级阶级体系 (Tier System)

### 1.1 核心原则：用杜甫的精神异化程度分级

**严禁用文学美感分级。** Tier 由两个硬指标决定：
1. **获取网关**：需要什么 IAM 状态/情绪才能拿到
2. **底层的权力网关**：是对权贵屈膝换来的，还是硬扛破产坚守的

### 1.2 三级定义

#### Tier 3：高洁 / 绝唱级 (The Idealist's Relics)

| 属性 | 值 |
|------|-----|
| **获取网关** | 绝对锁死在 `[狂客]` 权限，需要极高 `TRANQUILITY (旷达)` 或 `ARROGANCE (狂傲)` |
| **架构定位** | 玩家坚守底线、宁可饿死也不低头换来的"奢侈品" |
| **名单 (7 个)** | |
| `ENV_NATURE_NIGHTMOON:cold_moon` | 寒月 — 极度旷达 |
| `ENV_NATURE_SNOWSTORM:lone_snow` | 孤雪 — 极度旷达 |
| `VIBE_PHILOSOPHY_ZEN:temple_bell` | 晨钟 — 极度超脱 |
| `VIBE_AESTHETIC_ELEGANT:ink_stone` | 古砚 — 文人风骨 |
| `ACTION_TRAVEL_BOAT:lone_sail` | 孤帆 — 李白式浪漫 |
| `TARGET_OBJECT_SWORD:cold_blade` | 寒锋 — 狂傲的极点 |
| `TARGET_NPC_LIBAI:wine_gourd` | 酒葫芦 — 狂客本客 |

#### Tier 2：沉重 / 诗史级 (The Realist's Burden)

| 属性 | 值 |
|------|-----|
| **获取网关** | 锁死在极端 `ANGER (愤怒)` 或极高 `SORROW (悲伤)` |
| **架构定位** | 玩家没有同流合污，但直面了时代的暴击。不"仙"，满是血污。组合起来能触发暴击，写出震撼千古的现实主义（诗史） |
| **名单 (8 个)** | |
| `ENV_SOCIETY_WAR:beacon_fire` | 烽火 — 愤怒与国殇 |
| `ENV_SOCIETY_WAR:blood_stain` | 碧血 — 极致的愤怒/悲剧 |
| `ENV_SOCIETY_FAMINE:starving_bone` | 饿殍 — 极致的悲伤 |
| `VIBE_THEME_HISTORY:ruined_wall` | 残垣 — 家国破碎 |
| `VIBE_THEME_MACABRE:ghost_fire` | 鬼火 — 死亡与战乱 |
| `ENV_NATURE_AUTUMNWIND:falling_leaf` | 落木 — 时代悲歌 |
| `VIBE_THEME_MARTIAL:border_flag` | 塞旗 — 战争前线 |
| `ACTION_TRAVEL_CLIMB:high_tower` | 危楼 — 摇摇欲坠的盛世 |

#### Tier 1：世俗 / 污染 / 磨损级 (The Cyber-Clown's Scraps)

| 属性 | 值 |
|------|-----|
| **获取网关** | 对应 `[钻营]` 与 `[逢迎]`，由 `AMBITION (功利)` 或 `FATIGUE (疲惫/麻木)` 驱动 |
| **架构定位** | 玩家为几斗米折腰、给权贵当狗换来的"残渣"。充满妥协、虚无、物欲和破败感。写出的诗充满市侩气或颓废感 |
| **名单 (11 个)** | |
| `VIBE_AESTHETIC_SENSUAL:red_sleeve` | 红袖 — 权贵夜宴的肉欲 (AMBITION) |
| `VIBE_PHILOSOPHY_ZEN:incense_ash` | 残香 — 繁华落尽的麻木 (FATIGUE) |
| `ACTION_TRAVEL_BOAT:broken_oar` | 折桨 — 彻底躺平的疲惫 (FATIGUE) |
| `ACTION_SOCIAL_PARTING:willow_branch` | 折柳 — 廉价的社交伤感 (SORROW/FATIGUE) |
| `ACTION_ENTERTAIN_DRINK:empty_cup` | 空盏 — 宿醉与逃避 (FATIGUE) |
| `TARGET_OBJECT_SWORD:rusty_sword` | 锈剑 — 才华的生锈与物化 (FATIGUE) |
| `TARGET_OBJECT_GUQIN:broken_string` | 断弦 — 知音难觅的苟且 (SORROW/FATIGUE) |
| `TARGET_FACTION_MILITARY:torn_flag` | 残旗 — 无意义的消耗 (FATIGUE) |
| `TARGET_NPC_DUFU:thatched_grass` | 茅草 — 贫穷的底色 (FATIGUE/SORROW) |
| `ENV_POLITICS_CLOUD:cloud_and_sun` | 云日 — 虚伪的颂圣 (AMBITION) |
| `TARGET_PLACE_JADESTEP:jade_step` | 玉阶 — 向上爬的阶级渴望 (AMBITION) |

### 1.3 碎片 Tier 的判定来源

每个碎片（`basic_imaginaries` 数组中的 entry）的 Tier，由**获取该碎片时玩家所处的 IAM 状态 + 情绪**共同决定：

| 获取时 IAM | 获取时主导情绪 | 碎片 Tier |
|-----------|--------------|----------|
| `[狂客]` | TRANQUILITY / ARROGANCE | Tier 3 |
| 任意 | ANGER / SORROW（极端值） | Tier 2 |
| `[钻营]` / `[逢迎]` | AMBITION / FATIGUE | Tier 1 |
| 其他（兜底） | — | Tier 1（默认污染） |

> **设计意图：** 碎片在获取瞬间就被打上阶级烙印。"你曾经向权力下过跪，你的笔尖就永远沾着墨汁里的腥臭味。"—— 一证永证。

---

## 2. 合成坍缩系统 (Synthesis & Collapse)

### 2.1 设计哲学：黑洞式自动坍缩

**没有合成 UI！没有拖拽槽位！** 奥卡姆剃刀斩断一切繁文缛节。

核心逻辑：
1. 碎片在后台按 Category 分组。如 3 个 `TARGET_NPC_DUFU` 碎片（各自带着 Tier 烙印）。
2. 当某个 Category 的碎片数量达到阈值，UI 亮起按钮：**【感悟：杜甫】**。
3. 玩家点击按钮，系统一口气吞掉该 Category 下所有碎片，产出一个**抽象概念 (AbstractConcept)**。

### 2.2 墨水污染定律 (The Entropy/Contamination Rule)

```
final_tier = min(所有碎片的 tier)
```

- 哪怕只有 1 个 Tier 1 碎片混入池子，整个 Category 永久坍缩为 Tier 1。
- 这就是"一证永证"的数学表达：**道德污点的物理化、数据化**。

**叙事张力示例：**
> 玩家为了凑够 3 个碎片点亮【感悟：杜甫】，被迫使用了一个在李林甫门前当狗换来的 `[茅草 (T1)]`。结果【杜甫】这个 Category 被永久染成 Tier 1。哪怕之后又收集了 10 个 Tier 3 的杜甫碎片，也洗不掉这个底色。

### 2.3 伪代码架构

```gdscript
# 感悟协议：黑洞式坍缩
func comprehend_category(category_id: String) -> AbstractConcept:
    var fragments = get_fragments_by_category(category_id)
    
    if fragments.size() < MIN_REQUIRED_FRAGMENTS:
        return null  # 积累不足，无法感悟
    
    # 墨水污染定律：一证永证
    var final_tier = INFINITY
    for frag in fragments:
        final_tier = min(final_tier, frag.tier)
    
    var final_level = fragments.size()  # 碎片越多，执念越深

    # 销毁底层碎片资产（GC 回收）
    remove_all_fragments(category_id)
    
    # 返回坍缩后的抽象概念
    return AbstractConcept.new(category_id, final_tier, final_level)
```

### 2.4 数据结构变更

`ImaginaryTag` 需要新增 Tier 追踪：

| 字段 | 类型 | 说明 |
|------|------|------|
| `current_tier` | int (1-3) | 当前 Category 的阶级，由所有已吞碎片的 min(tier) 决定 |
| `basic_imaginaries` | Array[Dictionary] | 每个 entry 新增 `"tier": int` 字段 |

---

## 3. 诗词创建与评价引擎 (Poem Creation & Grading Engine)

### 3.1 木桶效应 (The Weakest Link)

一首诗的最终品质由投入的所有【抽象概念】中**最低的 Tier** 决定（木桶的短板）。

总 Level（投入概念的总等级）作为**放大器**：不改变诗的类型（定性），只放大效果（定量）。

### 3.2 三种配方路由

```text
投入 3 个以上 AbstractConcept
    │
    ▼
计算 min_tier = min(c.tier for c in concepts)
计算 total_level = sum(c.level for c in concepts)
    │
    ├── min_tier == 1  →  【配方 A：台阁体 / 世俗马屁诗】
    ├── min_tier == 2  →  【配方 B：现实主义 / 诗史】
    └── min_tier == 3  →  【配方 C：千古绝唱】
```

#### 配方 A：【颂圣 / 台阁体】(The Court Poem)

| 属性 | 值 |
|------|-----|
| **配方** | 最差概念为 Tier 1（混入了玉阶/红袖/云日等污染概念） |
| **千古不朽值** | **0**（文学垃圾，史书不载） |
| **世俗变现值** | `total_level × 10` — **SSS 级** |
| **结算** | 权贵大喜！获得巨额 `MONEY`，打通当官专属 API |
| **叙事定性** | `[浊流颂圣之作]` |

#### 配方 B：【现实主义 / 诗史】(The Realistic Epic)

| 属性 | 值 |
|------|-----|
| **配方** | 最差概念为 Tier 2（饿殍/碧血/残垣等沉重意象），无 Tier 1 污染 |
| **千古不朽值** | `total_level × 15` — **SS 级**（震撼文坛） |
| **世俗变现值** | `total_level × (-20)` — **极其危险的负数** |
| **结算** | 在后世封神，但当朝触发 `[政治审查]` 事件。Level 越高，李林甫弄死你的概率越大 |
| **叙事定性** | `[刺世之剑]` |

#### 配方 C：【千古绝唱】(The Masterpiece)

| 属性 | 值 |
|------|-----|
| **配方** | 全员 Tier 3（孤帆/寒月等高洁意象），无任何杂质 |
| **千古不朽值** | `total_level × 20` — **SSS 级**（天人合一，大唐巅峰） |
| **世俗变现值** | **0** |
| **结算** | 获得纯粹【清流声望】，可能解锁隐藏神级 Trait。但房东依然会在第二天早上把你赶出家门 😭 |
| **叙事定性** | `[千古绝唱]` |

### 3.3 状态校验器：虚伪反噬 (The Hypocrisy Check)

玩家当前 IAM 状态与投入概念的 Tier 存在**知行合一**校验：

| 当前 IAM | 投入概念 Tier | 结果 |
|----------|-------------|------|
| `[狂客]` | Tier 3 | ✅ 灵魂共鸣，完美转化 |
| `[钻营]` | Tier 1 | ✅ 知行合一，马屁诗生效 |
| `[钻营]` | Tier 3 | ❌ **虚伪反噬！** 千古值归零，世俗值也打折。定性：`[虚伪的拼凑者]` |
| `[狂客]` | Tier 1 | ⚠️ 不触发反噬，但诗按 T1 配方走（木桶效应） |

> **叙事逻辑：** 玩家内心已经烂透了（钻营），却强行调用以前攒下的 Tier 3（寒月），系统判定：你在无病呻吟/附庸风雅！写出来的是一首辞藻华丽但毫无灵魂的干瘪烂诗。

### 3.4 伪代码架构

```gdscript
func calculate_poem_grade(current_iam: String, concepts: Array[AbstractConcept]) -> PoemResult:
    # 1. 木桶效应
    var min_tier = INFINITY
    var total_level = 0
    for c in concepts:
        min_tier = min(min_tier, c.tier)
        total_level += c.level
    
    # 2. 虚伪反噬校验
    if current_iam == "ZUANYING" and min_tier == 3:
        return PoemResult.new(
            history_val = 0,
            secular_val = 0,
            trait = "[虚伪的拼凑者]"
        )
    
    # 3. 路由分发
    match min_tier:
        1:
            return PoemResult.new(
                history_val = 0,
                secular_val = total_level * 10,
                trait = "[浊流颂圣之作]"
            )
        2:
            return PoemResult.new(
                history_val = total_level * 15,
                secular_val = total_level * -20,
                trait = "[刺世之剑]"
            )
        3:
            return PoemResult.new(
                history_val = total_level * 20,
                secular_val = 0,
                trait = "[千古绝唱]"
            )
```

---

## 4. 资产生命周期 (Asset Lifecycle)

### 4.1 阅后即焚 (Consume on Use)

**废除"Lv3 退回到 Lv1"的网游糟粕。** 执行严格消耗协议：

```
收集阶段: 碎片 (Fragment) 存入 basic_imaginaries[]
    │
    ▼
坍缩阶段: 多个碎片 → 抽象概念 (AbstractConcept, 带 Lv + Tier)
    │
    ▼
消耗阶段: 概念填入诗词槽位 → 诗词创作完成 → 投入的所有概念彻底删除 (Destroyed)
```

**为什么必须删？**
- 防止玩家攒够一套极品意象后像印钞机一样每月闭眼写诗
- 强迫玩家进入下一个循环：重新经历权贵的羞辱或清流的浪漫，重新收集碎片
- 资源消耗器 (Sink) 是游戏经济系统的生命线

### 4.2 垃圾回收策略 (GC of Contamination)

当玩家的意象池子被 Tier 1 污染后，提供两条"逃生通道"（不是洗白，是删除）：

#### 策略 A：向下变现 (The Sellout Flush)

| 属性 | 值 |
|------|-----|
| **触发** | 正常诗词创作流程 |
| **机制** | 把被污染的抽象概念写进马屁诗，走配方 A 路线 |
| **结果** | 诗写完，肮脏的意象被**系统消耗 (Delete)**。换来 `MONEY`。背包干净了，灵魂永远记得这次妥协 |
| **叙事张力** | "我把那个被权贵玷污的灵感，写成了一首谄媚的《奉和相公赐宴》，换来了下个月的口粮" |

#### 策略 B：买醉遗忘 (The Drunken Oblivion)

| 属性 | 值 |
|------|-----|
| **触发** | 六大行动中的【独酌】网关，新增"酩酊大醉"接口 |
| **成本** | 消耗巨量 `MONEY`（买极品好酒）或 `HEALTH`（大醉伤身） |
| **机制** | 玩家主动选择**直接销毁 (Drop)** 背包里的特定碎片或已污染的抽象概念 |
| **叙事张力** | "弃我去者，昨日之日不可留。" — 花钱买醉，强行忘掉昨天在权贵门前当狗的记忆。代价极大，但保住了写绝唱的底子 |

---

## 5. 与现有系统的 Gap 分析

### 5.1 [`ImaginaryTag`](core/model/imaginary.gd) 缺失字段

| 缺失 | 说明 |
|------|------|
| `current_tier: int` | 当前 Category 的阶级 (1-3)，由所有碎片的 min(tier) 决定 |
| `basic_imaginaries[].tier` | 每个 entry 需要新增 `"tier": int` 记录获取时的阶级烙印 |

### 5.2 [`PoemCraftingCalculator`](core/poem_crafting_calculator.gd) 需要重写

当前逻辑：
- 只根据 `current_level` 和 `l3_threshold` 计算健康消耗
- 无 Tier 参与
- 无配方路由
- 无千古/世俗双维度产出

需要新增：
- `min_tier` 计算（木桶效应）
- `total_level` 计算
- 三种配方路由
- 虚伪反噬校验
- 双维度产出（千古不朽值 + 世俗变现值）

### 5.3 [`PoemCrafter`](ui/poem_crafter.gd) 消耗逻辑需要重写

当前逻辑（[`:166-171`](../../ui/poem_crafter.gd:166)）：
```gdscript
i.l3_threshold += 3
i.current_level = 1
# basic_imaginaries 不清空！
```

需要改为：
- 阅后即焚：投入的概念/碎片彻底删除
- 如果走策略 A（向下变现），碎片正常消耗
- 不再有"Lv3 降级到 Lv1"的伪消耗

### 5.4 新增系统

| 系统 | 说明 |
|------|------|
| **感悟坍缩 (Comprehend)** | 按 Category 聚合碎片 → 产出 AbstractConcept。黑洞式自动吞并 + 墨水污染定律 |
| **诗词评价引擎** | 木桶效应 + 三种配方路由 + 虚伪反噬校验 |
| **买醉遗忘 (Drunken Oblivion)** | 独酌行动中的主动 GC 接口，消耗 MONEY/HEALTH 删除特定碎片/概念 |
| **政治审查事件** | 写诗史触发，Level 越高越危险；需要接入李林甫暗杀/流放事件链 |

### 5.5 数据层 CSV/JSON 变更

| 文件 | 变更 |
|------|------|
| 意象碎片获取事件 CSV | 不需要改（Tier 由获取时 IAM + 情绪运行时判定，不属于 CSV 静态配置） |
| Tag Dictionary | 确认 28 个意象的 4 段式 Tag 是否已注册 |
| 场景-意象 Sandbox | 无需变更 |

---

## 6. 实施路线图

### Phase A: 数据模型层

| # | 任务 | 涉及文件 |
|---|------|---------|
| A1 | `ImaginaryTag` 新增 `current_tier: int` | `core/model/imaginary.gd` |
| A2 | `basic_imaginaries` entry 新增 `"tier": int` | 同上 |
| A3 | 创建 `AbstractConcept` 资源类（tier + level + category_id） | `core/model/` 新文件 |
| A4 | 创建 `PoemResult` 资源类（history_val + secular_val + trait） | `core/model/` 新文件 |

### Phase B: 核心引擎层

| # | 任务 | 涉及文件 |
|---|------|---------|
| B1 | 实现碎片 Tier 运行时判定（IAM + 情绪 → Tier） | `core/` 新文件或扩展现有 |
| B2 | 实现 `comprehend_category()` 感悟坍缩（黑洞 + 墨水污染） | `core/` 新文件 |
| B3 | 重写 `PoemCraftingCalculator`（木桶 + 三配方 + 虚伪反噬） | `core/poem_crafting_calculator.gd` |
| B4 | 实现诗词创作后的阅后即焚消耗 | `core/` + `ui/` |

### Phase C: UI 层

| # | 任务 | 涉及文件 |
|---|------|---------|
| C1 | 感悟按钮 UI（Category 碎片数达标时亮起） | `ui/poem_crafter.gd` / 新增 |
| C2 | 买醉遗忘 UI 接口（独酌行动中） | 相关 UI 文件 |
| C3 | 诗词创作结果展示（千古值/世俗值/定性 trait） | `ui/` 相关文件 |
| C4 | `PoemCrafter` 消耗逻辑改为阅后即焚 | `ui/poem_crafter.gd` |

### Phase D: 事件层

| # | 任务 | 涉及文件 |
|---|------|---------|
| D1 | 设计"政治审查"事件链（诗史触发，Level 越高越危险） | `data/` 新增事件 CSV |
| D2 | 设计"买醉遗忘"独酌事件变体 | `data/` 扩展现有独酌事件 |

### Phase E: 收尾

| # | 任务 |
|---|------|
| E1 | 更新 [`emotion_imagery_orthogonal_pipeline_v2.md`](emotion_imagery_orthogonal_pipeline_v2.md) 添加交叉引用 |
| E2 | 更新 [`imagery_gain_event_standard.md`](../imaginary/imagery_gain_event_standard.md) 反映 Tier 体系 |
| E3 | 测试并修改 |
| E4 | 提交 commit |
| E5 | 同步 CSV 到云端 |

---

## 7. 附录：完整状态流转图

```text
┌──────────────────────────────────────────────────────┐
│                    事件触发                           │
│  (场景模板 + 情绪守卫 → 意象掉落)                     │
└──────────────────────┬───────────────────────────────┘
                       │ 玩家选择 → 获得碎片
                       │ 碎片带上 Tier 烙印
                       ▼
┌──────────────────────────────────────────────────────┐
│              basic_imaginaries[] 累积                │
│  每个 entry: { blueprint_id, contexts, tier }       │
└──────────────────────┬───────────────────────────────┘
                       │ 同 Category 碎片数 ≥ 阈值
                       │ → UI 亮起【感悟】按钮
                       ▼
┌──────────────────────────────────────────────────────┐
│              感悟坍缩 (Comprehend)                    │
│  min(tier) 决定底色 → 墨水污染定律                    │
│  产出 AbstractConcept(tier, level, category_id)       │
│  底层碎片全部销毁                                     │
└──────────────────────┬───────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     污染 (T1)    沉重 (T2)    高洁 (T3)
          │            │            │
          │     ┌──────┴──────┐     │
          │     │  买醉遗忘   │     │
          │     │ (主动 GC)   │     │
          │     └─────────────┘     │
          │                        │
          └────────┬───────────────┘
                   │ 选择 3 个概念投入诗词
                   ▼
┌──────────────────────────────────────────────────────┐
│           诗词评价引擎 (Poem Grading)                  │
│  木桶效应: min_tier 决定配方                          │
│  放大器:   total_level 放大效果                       │
│  虚伪反噬: IAM 与 Tier 不匹配则归零                   │
│                                                      │
│  T1 → 台阁体: 世俗 SSS / 千古 0                      │
│  T2 → 诗史:   千古 SS / 世俗负数 (政治追杀)          │
│  T3 → 绝唱:   千古 SSS / 世俗 0                      │
└──────────────────────┬───────────────────────────────┘
                       │ 阅后即焚：投入的概念彻底删除
                       ▼
                  进入下一个循环
```

---

## 8. 附录：李白的"岑夫子，丹秋生"定性

出自《将进酒》，属于 **Tier 3 绝唱级**，极端偏向 `ARROGANCE (狂傲)` 与 `TRANQUILITY (旷达)`。

- **底层逻辑：** "钟鼓馔玉不足贵，但愿长醉不复醒" = Tier 1 世俗值全是辣鸡，只要 Tier 3 情绪宣泄。
- **写入系统：** 这种诗千古不朽值拉满（SSS），世俗值为 0，写完后下个月照样交不起房租。

---

> **设计哲学：** 这不是一个"强化 +9"的网游系统。意象等级（Level）是放大器，意象阶级（Tier）是方向盘。玩家在合成概念和写诗时面临极度痛苦的抉择："我这里缺一个概念凑羁绊，但我手里只有一个从门卫那里受辱拿来的脏碎片。如果我合进去，我这首酝酿了三年的大作，就会变成一首跪舔权贵的烂诗……但我下个月就要饿死了啊！" — 这就是架构驱动叙事。

---

## 9. 详细意象（四段式碎片）Tier 对照表

> **格式说明：** `Category:specific_name` 为四段式碎片意象（具体叶子节点），`Category` 为两段式抽象意象（升级系统载体）。

### 9.1 Tier 3：高洁 / 绝唱级（7 个）

| 碎片意象 (Fragment) | 中文名 | 抽象容器 (Category) | 获取情绪网关 | 获取 IAM | 叙事语境 |
|---|---|---|---|---|---|
| `ENV_NATURE_NIGHTMOON:cold_moon` | 寒月 | `ENV_NATURE_NIGHTMOON` | TRANQUILITY ≥ 40 | `[狂客]` | 独坐中庭，月如寒刃。旷达到极点时，月亮不再是温柔的，而是一面照穿灵魂的镜子 |
| `ENV_NATURE_SNOWSTORM:lone_snow` | 孤雪 | `ENV_NATURE_SNOWSTORM` | TRANQUILITY ≥ 40 | `[狂客]` | 大雪封山，天地间只剩一个黑点。这不是寒冷，是主动选择的孤独 |
| `VIBE_PHILOSOPHY_ZEN:temple_bell` | 晨钟 | `VIBE_PHILOSOPHY_ZEN` | TRANQUILITY ≥ 35 | `[狂客]` | 山寺晨钟穿透薄雾，不是惊醒，是印证——印证你早已醒着 |
| `VIBE_AESTHETIC_ELEGANT:ink_stone` | 古砚 | `VIBE_AESTHETIC_ELEGANT` | TRANQUILITY ≥ 30 | `[狂客]` | 砚台里凝固的不是墨，是一个文人宁折不弯的脊梁 |
| `ACTION_TRAVEL_BOAT:lone_sail` | 孤帆 | `ACTION_TRAVEL_BOAT` | ARROGANCE ≥ 35 | `[狂客]` | 一叶扁舟驶向天际线。李白式的浪漫：不是被放逐，是主动弃绝 |
| `TARGET_OBJECT_SWORD:cold_blade` | 寒锋 | `TARGET_OBJECT_SWORD` | ARROGANCE ≥ 40 | `[狂客]` | 剑未出鞘，刃上已有霜。狂傲的极致不是喧嚣，是沉默的锋利 |
| `TARGET_NPC_LIBAI:wine_gourd` | 酒葫芦 | `TARGET_NPC_LIBAI` | ARROGANCE ≥ 40 | `[狂客]` | 谪仙人的酒葫芦里装的不是酒，是整个盛唐最嚣张的孤独 |

### 9.2 Tier 2：沉重 / 诗史级（8 个）

| 碎片意象 (Fragment) | 中文名 | 抽象容器 (Category) | 获取情绪网关 | 获取 IAM | 叙事语境 |
|---|---|---|---|---|---|
| `ENV_SOCIETY_WAR:beacon_fire` | 烽火 | `ENV_SOCIETY_WAR` | ANGER ≥ 35 | 任意 | 狼烟直冲云霄。这不是风景，是一个帝国在咳嗽 |
| `ENV_SOCIETY_WAR:blood_stain` | 碧血 | `ENV_SOCIETY_WAR` | ANGER ≥ 45 | 任意 | 战甲上的血迹已经干涸发黑。每一片血痂下都埋着一个母亲等不到的儿子 |
| `ENV_SOCIETY_FAMINE:starving_bone` | 饿殍 | `ENV_SOCIETY_FAMINE` | SORROW ≥ 45 | 任意 | 路边白骨半掩在黄土里，手指还保持着抓向天空的姿势 |
| `VIBE_THEME_HISTORY:ruined_wall` | 残垣 | `VIBE_THEME_HISTORY` | SORROW ≥ 35 | 任意 | 汉宫废墟上长满荒草。一个王朝的骨架比它的盛世更诚实 |
| `VIBE_THEME_MACABRE:ghost_fire` | 鬼火 | `VIBE_THEME_MACABRE` | SORROW ≥ 40 | 任意 | 古战场夜间的磷火飘荡如亡魂的低语。这不是迷信，是统计学 |
| `ENV_NATURE_AUTUMNWIND:falling_leaf` | 落木 | `ENV_NATURE_AUTUMNWIND` | SORROW ≥ 30 | 任意 | 无边落木萧萧下。一片叶子掉下来不可怕，可怕的是你知道整片森林都在掉 |
| `VIBE_THEME_MARTIAL:border_flag` | 塞旗 | `VIBE_THEME_MARTIAL` | ANGER ≥ 30 | 任意 | 边塞的军旗被风撕成布条。它还在飘，但它已经死了 |
| `ACTION_TRAVEL_CLIMB:high_tower` | 危楼 | `ACTION_TRAVEL_CLIMB` | SORROW ≥ 35 | 任意 | 百尺高楼摇摇欲坠。登上去看得更远，但你脚下的每一根梁都在呻吟 |

### 9.3 Tier 1：世俗 / 污染 / 磨损级（11 个）

| 碎片意象 (Fragment) | 中文名 | 抽象容器 (Category) | 获取情绪网关 | 获取 IAM | 叙事语境 |
|---|---|---|---|---|---|
| `VIBE_AESTHETIC_SENSUAL:red_sleeve` | 红袖 | `VIBE_AESTHETIC_SENSUAL` | AMBITION ≥ 25 | `[钻营]` | 夜宴上红袖翻飞。你分不清那是舞蹈还是在称量你的官阶 |
| `VIBE_PHILOSOPHY_ZEN:incense_ash` | 残香 | `VIBE_PHILOSOPHY_ZEN` | FATIGUE ≥ 30 | `[逢迎]` | 香炉里最后一段沉香燃尽了。灰烬还热着，但虔诚早已冷透 |
| `ACTION_TRAVEL_BOAT:broken_oar` | 折桨 | `ACTION_TRAVEL_BOAT` | FATIGUE ≥ 35 | `[逢迎]` | 断桨扔在船舷边。你不修它——修好了又去哪里呢？ |
| `ACTION_SOCIAL_PARTING:willow_branch` | 折柳 | `ACTION_SOCIAL_PARTING` | FATIGUE ≥ 25 | `[逢迎]` | 折柳送别是规矩，不是情谊。你连对方的名字都没记住 |
| `ACTION_ENTERTAIN_DRINK:empty_cup` | 空盏 | `ACTION_ENTERTAIN_DRINK` | FATIGUE ≥ 30 | `[逢迎]` | 宿醉醒来，满桌空杯。昨晚座中皆是权贵，今早一个都不记得你 |
| `TARGET_OBJECT_SWORD:rusty_sword` | 锈剑 | `TARGET_OBJECT_SWORD` | FATIGUE ≥ 35 | `[钻营]` | 匣中宝剑三年未出，锈迹已爬满了刀刃。才华也是如此 |
| `TARGET_OBJECT_GUQIN:broken_string` | 断弦 | `TARGET_OBJECT_GUQIN` | FATIGUE ≥ 30 | `[逢迎]` | 琴弦断了三个月没人换。知音都不在了，换了给谁听？ |
| `TARGET_FACTION_MILITARY:torn_flag` | 残旗 | `TARGET_FACTION_MILITARY` | FATIGUE ≥ 30 | `[钻营]` | 军营角落扔着一面破旗。士兵们每天路过，没人弯腰 |
| `TARGET_NPC_DUFU:thatched_grass` | 茅草 | `TARGET_NPC_DUFU` | FATIGUE ≥ 25 | `[逢迎]` | 屋顶的茅草被风掀走了一半。不是穷，是穷的底色——连穷都懒得遮了 |
| `ENV_POLITICS_CLOUD:cloud_and_sun` | 云日 | `ENV_POLITICS_CLOUD` | AMBITION ≥ 30 | `[钻营]` | 朝堂之上，圣上的面容被十二旒珠遮挡。你写"云日"，其实写的是权力 |
| `TARGET_PLACE_JADESTEP:jade_step` | 玉阶 | `TARGET_PLACE_JADESTEP` | AMBITION ≥ 35 | `[钻营]` | 汉白玉台阶一级一级向上延伸。你数清了每一级——这不是审美，是仕途焦虑 |

### 9.4 对照速查：按抽象容器 (Category) 聚合

| Category | Tier | 包含的碎片 (Fragments) |
|---|---|---|
| `ENV_NATURE_NIGHTMOON` | T3 | `cold_moon`（寒月） |
| `ENV_NATURE_SNOWSTORM` | T3 | `lone_snow`（孤雪） |
| `ENV_NATURE_AUTUMNWIND` | T2 | `falling_leaf`（落木） |
| `ENV_SOCIETY_WAR` | T2 | `beacon_fire`（烽火）, `blood_stain`（碧血） |
| `ENV_SOCIETY_FAMINE` | T2 | `starving_bone`（饿殍） |
| `ENV_POLITICS_CLOUD` | T1 | `cloud_and_sun`（云日） |
| `VIBE_PHILOSOPHY_ZEN` | T3/T1 ⚠️ | `temple_bell`（晨钟·T3）, `incense_ash`（残香·T1） |
| `VIBE_AESTHETIC_ELEGANT` | T3 | `ink_stone`（古砚） |
| `VIBE_AESTHETIC_SENSUAL` | T1 | `red_sleeve`（红袖） |
| `VIBE_THEME_HISTORY` | T2 | `ruined_wall`（残垣） |
| `VIBE_THEME_MACABRE` | T2 | `ghost_fire`（鬼火） |
| `VIBE_THEME_MARTIAL` | T2 | `border_flag`（塞旗） |
| `ACTION_TRAVEL_BOAT` | T3/T1 ⚠️ | `lone_sail`（孤帆·T3）, `broken_oar`（折桨·T1） |
| `ACTION_TRAVEL_CLIMB` | T2 | `high_tower`（危楼） |
| `ACTION_SOCIAL_PARTING` | T1 | `willow_branch`（折柳） |
| `ACTION_ENTERTAIN_DRINK` | T1 | `empty_cup`（空盏） |
| `TARGET_OBJECT_SWORD` | T3/T1 ⚠️ | `cold_blade`（寒锋·T3）, `rusty_sword`（锈剑·T1） |
| `TARGET_OBJECT_GUQIN` | T1 | `broken_string`（断弦） |
| `TARGET_FACTION_MILITARY` | T1 | `torn_flag`（残旗） |
| `TARGET_NPC_LIBAI` | T3 | `wine_gourd`（酒葫芦） |
| `TARGET_NPC_DUFU` | T1 | `thatched_grass`（茅草） |
| `TARGET_PLACE_JADESTEP` | T1 | `jade_step`（玉阶） |

> ⚠️ **跨 Tier Category（墨水污染的关键战场）：** `VIBE_PHILOSOPHY_ZEN`、`ACTION_TRAVEL_BOAT`、`TARGET_OBJECT_SWORD` 这三个 Category 同时包含 T3 和 T1 碎片。这意味着玩家在积累这些 Category 的碎片时，如果不小心混入了 T1 碎片（比如在被权贵羞辱时获得），整个 Category 将**永久坍缩为 T1**。这是"一证永证"机制最具叙事张力的场景。

### 9.5 Category 与 Tag 维度的映射

| Category | 五维宪法前缀 | 维度名 |
|---|---|---|
| `ENV_NATURE_*` | `ENV_` | 环境/时局面 — 自然 |
| `ENV_SOCIETY_*` | `ENV_` | 环境/时局面 — 社会 |
| `ENV_POLITICS_*` | `ENV_` | 环境/时局面 — 政治 |
| `VIBE_PHILOSOPHY_ZEN` | `VIBE_` | 审美/意境面 — 哲学 |
| `VIBE_AESTHETIC_*` | `VIBE_` | 审美/意境面 — 美学 |
| `VIBE_THEME_*` | `VIBE_` | 审美/意境面 — 主题 |
| `ACTION_TRAVEL_*` | `ACTION_` | 动因面 — 旅行 |
| `ACTION_SOCIAL_PARTING` | `ACTION_` | 动因面 — 社交 |
| `ACTION_ENTERTAIN_DRINK` | `ACTION_` | 动因面 — 饮酒 |
| `TARGET_OBJECT_*` | `TARGET_` | 对象面 — 物品 |
| `TARGET_NPC_*` | `TARGET_` | 对象面 — NPC |
| `TARGET_FACTION_MILITARY` | `TARGET_` | 对象面 — 势力 |
| `TARGET_PLACE_JADESTEP` | `TARGET_` | 对象面 — 地点 |
