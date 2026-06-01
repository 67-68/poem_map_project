# Tag 幂等性创建原则 (本体论构建)

> **配套文档：**
> - [`tag_dictioinary.md`](tag_dictioinary.md)（词汇参考层）
> - [`tag_pattern_confliction.md`](tag_pattern_confliction.md)（格式演进历史）
> - [`scene_action_and_player_tag_filter.md`](scene_action_and_player_tag_filter.md)（运行时匹配机制）
> - [`player_current_action_tag_life_cycle.md`](player_current_action_tag_life_cycle.md)（生命周期层）

---

## 核心问题

Tag 系统如果没有创建规约，最终必然演变成一本没人看得懂的天书。任何人拍脑袋就能往系统里塞一个新 Tag，等价于往图书馆里随机扔书不贴标签。

**解法：MECE 原则（Mutually Exclusive, Collectively Exhaustive — 相互独立，完全穷尽）。**

---

## 三问法：幂等性创建流程

每次面对一个新事件/场景/动作时，必须**机械式地回答三个问题**才能生成 Tag。这就叫**幂等性（Idempotency）**——同样的输入，永远输出同样的 Tag。

这三个问题产出标签的前三个层级，第四个层级取决于事件自己的属性。例如"月下听琴"的第四个层级就是 `qin_under_moon`。

---

### 第 1 问：动作归属（Domain & Category）

> **玩家在干嘛？**

只能从以下**动作词典**中选择，禁止凭空发明新词。

| 动作 | 含义 | 典型场景 |
|------|------|----------|
| `social` | 社交 | 拜访、宴请、结交、送别 |
| `entertain` | 娱乐 | 酒馆、歌舞、游戏、赏玩 |
| `travel` | 赶路 | 行路、远游、迁徙、探索 |
| `work` | 干活 | 公务、农耕、经商、学艺 |

> 动作词典是**封闭集**。如果发现某个动作无法归类，**优先修改归类方式**，而不是扩张词典。词典膨胀到超过 10 个条目时，必须重新审视分类是否违反了 MECE。

---

### 第 2 问：气质定调（Type）

> **它的底色是什么？**

只能从以下**气质词典**中选择：

| 气质 | 含义 | 典型情绪色彩 |
|------|------|--------------|
| `elegant` | 雅 | 文人雅集、诗词唱和、琴棋书画 |
| `sensual` | 俗 | 酒池肉林、市井喧嚣、声色犬马 |
| `martial` | 武 | 比武、行侠、征战、冲突 |
| `miserable` | 惨 | 离别、落魄、悲伤、死亡 |

> 气质词典是**封闭集**。四大气质覆盖了中国古典叙事中绝大部分情绪基调，不够用再考虑扩张，但请先质疑自己的分类是否准确。

---

### 第 3 问：结果产出（Specific / Resource）

> **这个动作主要跟什么打交道？**

这是一个**半开放集**——有预定义族类，但允许在族类下扩展具体值。

#### 常见产出族类

| 族类 | 含义 | 示例 |
|------|------|------|
| `with_*` | 与谁相关 | `with_qingliu`（清流）、`with_zhuoliu`（浊流） |
| `poetry` | 诗词相关 | — |
| `wine` | 酒相关 | — |
| `politics` | 政治相关 | — |
| `brawl` | 斗殴相关 | — |
| `commerce` | 商业相关 | — |
| `art` | 艺术相关 | `art:dance`、`art:music` |

---

### 第 4 级标签的绝对生成法则

前三级的格式为 `domain:category:type`，解决"这件事的性质是什么"（如 `action:entertain:elegant`）。

第四级标签（specific）只有一个职责：指出这场事件的**原子核心实体（Atomic Entity）**。

| 规则 | 说明 | 错误示范 | 正确示范 |
|------|------|---------|---------|
| **必须是纯粹的名词** | 不允许任何状态描述词、时间词、地点词或形容词 | `sad_qin`（混入情绪） | `guqin` |
| **必须是系统的最小资源单位** | 具体的乐器、舞蹈流派、官职等 | `beautiful_garden`（太抽象） | `garden` |
| **去语境化 (De-contextualization)** | 剥离所有外部条件 | `qin_under_moon`（混入环境） | `guqin` |

---

## 案例演练

### 案例 1：「在酒馆看胡人打架」

| 问题 | 答案 | 理由 |
|------|------|------|
| 动作？ | `entertain` | 在酒馆消费时间，属于娱乐 |
| 气质？ | `martial` | 打架是武斗场面 |
| 产出？ | `wine` + `brawl` | 酒馆场景 + 斗殴事件 |

**合成 Tag：** `action:entertain:martial:brawl`

> 也可以用 `action:entertain:martial:wine`，取决于强调的是「斗殴事件本身」还是「在酒馆看热闹」。引擎通过前缀匹配可以同时命中这两个 Tag。

### 案例 2：「拜访清流名士，谈诗论道」

| 问题 | 答案 |
|------|------|
| 动作？ | `social` |
| 气质？ | `elegant` |
| 产出？ | `with_qingliu` + `poetry` |

**合成 Tag：** `action:social:elegant:with_qingliu`

### 案例 3：「在街市卖艺赚钱」

| 问题 | 答案 |
|------|------|
| 动作？ | `work` |
| 气质？ | `sensual` |
| 产出？ | `commerce` + `art:performance` |

**合成 Tag：** `action:work:sensual:commerce`

---

## 规约执行 (Enforcement)

光有文档不够——必须通过自动化手段锁死规约。

### 1. Linter 规则

在现有 [Linter 系统](../linter/) 中添加校验规则：

```
规则 ID:     TAG_IDEMPOTENT_CREATION
检查目标:    所有新增/修改的 Tag 字符串
校验逻辑:
  1. 按冒号 : split 为 3-4 段
  2. 第 1 段必须是动作词典中的值（social/entertain/travel/work）
  3. 第 2 段必须是气质词典中的值（elegant/sensual/martial/miserable）
  4. 如果只有 3 段，自动补 :general（兼容旧数据）
  5. 如果有 4 段，第 4 段不强制校验，但推荐使用预定义族类
违规处理: push_error + 阻断事件注册
```

### 2. Tag 生成 SOP

```
1.  确定动作 → 查动作词典
    ├─ 匹配 → 用该值
    └─ 不匹配 → 重新审视分类，而非扩张词典
2.  确定气质 → 查气质词典
    ├─ 匹配 → 用该值
    └─ 不匹配 → 同上
3.  确定产出 → 查产出族类
    ├─ 匹配预定义族类 → 用该值
    └─ 不匹配 → 在合理范围内新增族类（需评审）
4.  合成 Tag 格式: action:{domain}:{type}:{specific}
5.  运行 Linter 验证
```

---

## 与现有系统的关系

```
┌────────────────────────────────────────────────────────────┐
│                     Tag 幂等性创建原则                       │
│                   (本文 - 本体论/规约层)                     │
│                   定义「Tag 应该怎么造」                      │
├────────────────────────────────────────────────────────────┤
│                     tag_pattern_confliction.md              │
│                   (格式定义层)                               │
│                   定义「Tag 长什么样」(3段/4段)                │
├────────────────────────────────────────────────────────────┤
│          scene_action_and_player_tag_filter.md             │
│                   (运行时匹配层)                              │
│                   定义「Tag 怎么用」(前缀匹配)                 │
├────────────────────────────────────────────────────────────┤
│          player_current_action_tag_life_cycle.md           │
│                   (生命周期层)                                │
│                   定义「Tag 怎么流动」(注入/清除)              │
└────────────────────────────────────────────────────────────┘
```

---

## 注意事项

1. **前缀匹配的兼容性**：三问法生成的 Tag 天然兼容前缀匹配机制（详见 [`scene_action_and_player_tag_filter.md`](scene_action_and_player_tag_filter.md)）。`action:social:elegant` 即可匹配 `action:social:elegant:with_qingliu`。

2. **不要过度分类**：如果某个事件只出现一次，不值得为它新开一个产出族类。80% 的事件应该能用现有的产出族类覆盖（20/80 原则）。

3. **词典的演进机制**：动作词典和气质词典虽然是封闭集，但可以按需审议扩张。每次扩张必须：
   - 书面记录扩张理由
   - 更新本文档的词典表
   - 更新 Linter 规则
   - 添加至少 3 个能证明该新值有用的案例

---

## 五维分面法（第二种分类方法）

> 不使用三问法时，也可以用此方法替代。两种方法择一即可。

不要死磕一个事件属于什么"绝对分类"，而是把世界拆解成 5 个独立的面（Facet）。事件库配置表中，每个事件的 `Trigger_Tags` 应该是一个数组，从以下 5 个维度中按需挑选拼装。

### 维度对照表

| 维度 | 含义 | 对应 Tag 格式 |
|------|------|--------------|
| **动因面 (Action)** | 你在干什么？ | `ACTION_MAIN_JIAOYOU_GENERAL` |
| **状态面 (Actor State)** | 你现在是什么状态？ | `ACTOR_HEALTH_SICK_GENERAL` |
| **环境/时局面 (Environment)** | 外部世界怎么了？ | `SOCIAL_NATURE_AUTUMN_GENERAL` |
| **审美/意境面 (Vibe)** | 这件事的文学灵魂？ | `INTEL_VIBE_ZEN_GENERAL` |
| **对象面 (Target)** | 跟谁？（可选） | `TARGET_FACTION_QINGLIU` |

### 架构实战：多标签交集碰撞

使用五维分面法后，事件触发逻辑变得高度立体且可复用。

**场景：** 玩家处于【秋天】(`SOCIAL_NATURE_AUTUMN`)，且【极度郁结】(`ACTOR_EMOTION_DESPAIR`)。他点击了【登高】按钮 (`ACTION_MAIN_DENGGAO`)。

Event Manager 拿着这三个 Tag 扫事件库：

| 事件 | Tags | 匹配度 |
|------|------|--------|
| **事件 A：** 普通登高 | `[ACTION_MAIN_DENGGAO]` | 命中 1 个 |
| **事件 B：** 秋日登高思乡 | `[ACTION_MAIN_DENGGAO, SOCIAL_NATURE_AUTUMN, INTEL_VIBE_HISTORY]` | 命中 2 个 |
| **事件 C：** 绝境中的绝唱（极稀有） | `[ACTION_MAIN_DENGGAO, SOCIAL_NATURE_AUTUMN, ACTOR_EMOTION_DESPAIR]` | 命中 **3 个**（完美契合）|

系统拉起事件 C，文本描述："秋风萧瑟，你满心郁结，登上高台，只觉天地苍茫，怆然而涕下。"结算时直接给予极品意象。

### 行动建议

1. **打散事件 Tag 数组：** 不要用单个 Tag 描述完整个事件（不要搞出 `ACTION_DENGGAO_IN_AUTUMN_WHILE_SICK` 这种怪物）。拆成 `[ACTION_DENGGAO, SOCIAL_AUTUMN, ACTOR_SICK]`。

2. **情绪获取顺理成章：** 当一个事件同时挂载了 `ACTION_TRAVEL_EXILE` 和 `SOCIAL_WAR_RUIN`，系统自动根据这两个 Tag 就能推导出应该在 `on_enter` 时给玩家增加 `DESPAIR`。**标签本身就是数据的驱动力。**
