# 情绪-意象正交生成管线 V2

> **状态：** 最终版架构契约
> **替代：** 旧版 4×4 方案
> **关键文件：** [`tools/config.py`](../tools/config.py), [`tools/generate_orthogonal_events.py`](../tools/generate_orthogonal_events.py), [`DOCUMENTATIONS/events/tag_dictioinary.md`](../DOCUMENTATIONS/events/tag_dictioinary.md)

---

## 0. 为什么要减少维度？（维度灾难）

```text
五维宪法 × 每维~5个枚举值 = 5×5×5×5×5 = 3125 种组合
其中 90% 是逻辑缝合怪：
    "在春暖花开时，穷困潦倒地，带着狂傲的情绪，和皇室，产生凄厉的互动……"
```

**核心认知：** 五维字典（[`tag_dictioinary.md`](../DOCUMENTATIONS/events/tag_dictioinary.md)）是**检索系统（标签库）**，不是生成矩阵。正交生成器的笛卡尔积只需要在 **1 个场景维度 × 1 个情绪维度** 上展开，其余维度由 LLM 根据叙事逻辑自动补全。

---

## 1. 四种事件类型（从简单到复杂）

### 类型 A：纯场景渲染事件（无意象、无情绪门槛）

| 属性 | 值 |
|------|-----|
| **维度** | 仅场景维度（1 维） |
| **生成量** | 10 场景 × 1 = 10 个 |
| **复杂度** | ⭐ 最低 |
| **产出** | 1 个普通选项（给点 FATIGUE 或小量资源） |
| **用途** | 填充事件池，防止"无事件可触发"的真空期 |

**数据流：**

```text
场景模板选择
    │
    ▼
on_enter 触发（环境情绪注入，如秋季 SORROW +2）
    │
    ▼
展示 1 个选项（无意象、无情绪守卫）
    │
    ▼
选项结算：prop_add(name=FATIGUE; val=5)
```

**CSV 示例（古刹避雨）：**

| 列 | 值 |
|----|-----|
| `title` | 山寺避雨 |
| `description` | 骤雨忽至，你闪入路旁一座荒废的古刹。殿中蛛网密布，佛像斑驳，唯有檐角的铜铃在风雨中发出清脆的声响。 |
| `trigger_tags` | `[ACTION_TRAVEL_ROAM/ENV_NATURE_SNOWSTORM/VIBE_PHILOSOPHY_ZEN]` |
| `on_enter` | `prop_add(name=TRANQUILITY; val=3)` （被动渲染） |
| `option_1_desc` | 拂去尘土，坐下避雨 |
| `option_1_req` |（无条件） |
| `option_1_result` | `prop_add(name=FATIGUE; val=-5)` |

---

### 类型 B：单情绪单线事件（1 个情绪守卫 + 1 个意象掉落）

| 属性 | 值 |
|------|-----|
| **维度** | 场景 × 单情绪（2 维） |
| **生成量** | 10 场景 × 6 单情绪 = **60 个** |
| **复杂度** | ⭐⭐ |
| **产出** | 1 个精英选项（情绪守卫 + 意象） + 1 个兜底选项 |
| **用途** | 核心事件池，覆盖最常见的"蓄水-爆发"需求 |

**维度定义：**

```
Dimension 1: 场景模板 (Scene Template)
    值: scene_banquet, scene_exile, scene_temple, scene_battlefield, 
        scene_farewell, scene_climb, scene_brawl, scene_monastery, 
        scene_drinking, scene_palace
    每个场景包含: 五维 Tag 预设 + 意象白名单(3-5个)

Dimension 2: 单情绪 (Single Emotion)
    值: ARROGANCE, TRANQUILITY, ANGER, SORROW, AMBITION, FATIGUE
    每个情绪包含: 对应的 prop_gt requirement
```

**数据流：**

```text
笛卡尔积展开: 10场景 × 6情绪 = 60 组合
    │
    ▼
剪枝过滤器: is_valid_combination(scene, emotion)
    │ 例如: scene_temple × AMBITION → ❌ 佛门不出野心
    │
    ▼
打分选择器: pick_best_image(scene_pool, target_emotion)
    │ Step 1: 取场景的意象白名单
    │ Step 2: 对每个意象按情绪亲缘度打分
    │ Step 3: 最高分 ≥ 30 则选中，否则丢弃
    │
    ▼
LLM Prompt 组装 + 调用
    │
    ▼
输出 CSV: 1 个 event 行 + 2 个 option 行
```

**意象掉落推演示例（[边塞劳军] × [SORROW]）：**

```
场景白名单: [beacon_fire, broken_halberd, blood_stain, starving_bone, torn_flag]

对 SORROW 打分:
  beacon_fire.affinities.SORROW = 40
  broken_halberd.affinities.SORROW = 70
  blood_stain.affinities.SORROW = 70
  starving_bone.affinities.SORROW = 95  ← 最高分 ✅
  torn_flag.affinities.SORROW = 85
→ 选中: starving_bone（饿殍）
```

**CSV 示例（[边塞劳军] × [SORROW]）：**

| 列 | 值 |
|----|-----|
| `title` | 风沙碎叶城 |
| `description` | 狂风卷起黄沙，你看到运送粮草的民夫倒在路边，尸骨未寒。在边塞的夕阳下，这一切显得如此荒诞而悲凉。 |
| `trigger_tags` | `[ACTION_TRAVEL_ROAM/ENV_SOCIETY_WAR/TARGET_FACTION_MILITARY/VIBE_THEME_MARTIAL]` |
| `option_1_desc` | 抚尸恸哭，哀民生之多艰 |
| `option_1_req` | `prop_gt(name=SORROW; val=20)` |
| `option_1_result` | `item_add(name=ENV_SOCIETY_FAMINE:starving_bone) | prop_add(name=SORROW; val=10)` |
| `option_2_desc` | 不忍再看，匆匆离开 |
| `option_2_req` |（无条件兜底） |
| `option_2_result` | `prop_add(name=FATIGUE; val=5)` |

---

### 类型 C：对立分支事件（2 个情绪守卫 + 2 个意象）

| 属性 | 值 |
|------|-----|
| **维度** | 场景 × 情绪对立对（2 维） |
| **生成量** | 10 场景 × 3 对立对 = **30 个** |
| **复杂度** | ⭐⭐⭐ |
| **产出** | 2 个精英选项（各自的情绪守卫 + 意象） + 1 个兜底选项 |
| **用途** | 核心剧情高潮，对应"灵魂拷问"时刻 |

**维度定义：**

```
Dimension 1: 场景模板 (Scene Template)  — 同上
Dimension 2: 情绪对立对 (Emotion Pair)
    值: pair_rebellion (ARROGANCE vs TRANQUILITY)
        pair_despair   (ANGER vs SORROW)
        pair_survival  (AMBITION vs FATIGUE)
    每个对包含: branch_A / branch_B 各自的情绪和 desc_req
```

**数据流：**

```text
笛卡尔积展开: 10场景 × 3对 = 30 组合
    │
    ▼
剪枝过滤器: 同时对两个情绪检查
    │ scene_temple × pair_survival(AMBITION)
    │   → AMBITION 在佛堂不合法，丢弃
    │
    ▼
打分选择器（执行两次）:
    │ 对 branch_A 的情绪: pick_best_image(scene_pool, branch_A.emotion)
    │ 对 branch_B 的情绪: pick_best_image(scene_pool, branch_B.emotion)
    │ 任何一个 < 30 则丢弃
    │
    ▼
LLM Prompt（告知两难困境结构）
    │
    ▼
输出 CSV: 1 个 event 行 + 3 个 option 行
```

**意象掉落推演（[边塞劳军] × [ANGER vs SORROW]）：**

```
场景白名单: [beacon_fire, broken_halberd, blood_stain, starving_bone, torn_flag]

选项 A (ANGER):
  beacon_fire.affinities.ANGER = 90
  broken_halberd.affinities.ANGER = 95  ← 最高分
  blood_stain.affinities.ANGER = 95     ← 并列
  starving_bone.affinities.ANGER = 80
  torn_flag.affinities.ANGER = 70
  → 随机选: broken_halberd（断戟）

选项 B (SORROW):
  beacon_fire.affinities.SORROW = 40
  broken_halberd.affinities.SORROW = 70
  blood_stain.affinities.SORROW = 70
  starving_bone.affinities.SORROW = 95  ← 最高分
  torn_flag.affinities.SORROW = 85
  → 选中: starving_bone（饿殍）
```

**CSV 示例（[边塞劳军] × [ANGEVR vs SORROW]）：**

| 列 | 值 |
|----|-----|
| `title` | 碎叶城下 |
| `description` | 你押送粮草来到碎叶城，却发现边防军克扣军粮，营帐外倒满了面黄肌瘦的民夫。副将李忠只是冷冷地看着你："军粮不足，先紧着将士们吃。" |
| `trigger_tags` | `[ACTION_TRAVEL_ROAM/ENV_SOCIETY_WAR/TARGET_FACTION_MILITARY/VIBE_THEME_MARTIAL]` |
| `option_1_desc` | 拔刀怒斥，血溅五步！ |
| `option_1_req` | `prop_gt(name=ANGER; val=30)` |
| `option_1_result` | `item_add(name=TARGET_OBJECT_SWORD:broken_halberd) | prop_add(name=ANGER; val=15)` |
| `option_2_desc` | 脱下冬衣，徒手掩埋 |
| `option_2_req` | `prop_gt(name=SORROW; val=30)` |
| `option_2_result` | `item_add(name=ENV_SOCIETY_FAMINE:starving_bone) | prop_add(name=SORROW; val=15)` |
| `option_3_desc` | 放下粮草，匆匆离去 |
| `option_3_req` |（无条件兜底） |
| `option_3_result` | `prop_add(name=FATIGUE; val=10)` |

---

### 类型 D：复合维度事件（场景 × 情绪对 × 对象，带剪枝）

| 属性 | 值 |
|------|-----|
| **维度** | 场景 × 情绪对立对 × TARGET 对象（3 维，可剪枝） |
| **生成量** | 10 场景 × 3 对 × 8 对象 = 240，剪枝后约 **80-120 个** |
| **复杂度** | ⭐⭐⭐⭐ |
| **产出** | 2 个精英选项（各有情绪守卫 + 意象 + NPC 交互） + 1 个兜底 |
| **用途** | 当基础 90 个事件不够时，横向扩展内容池 |

**维度定义：**

```
Dimension 1: 场景模板 (Scene Template)
Dimension 2: 情绪对立对 (Emotion Pair)  
Dimension 3: TARGET 对象 (Target Entity)
    值: LIBAI, DUFU, WANGWEI, ZHENGQIAN, QINGLIU, ZHUOLIU, ROYAL, MILITARY
```

**剪枝规则（核心——解决"郑虔不能出现在权贵夜宴"）：**

```python
def is_valid_combination(scene: str, emotion: str, target: str) -> bool:
    """实体冲突法：在笛卡尔积展开后、喂给 LLM 之前拦截非法组合。"""
    
    # 规则1: 特定 NPC 不能出现在特定场景
    NPC_SCENE_BLACKLIST = {
        "ZHENGQIAN": ["scene_banquet", "scene_palace"],  # 郑虔穷酸，不出现在权贵场所
        "YANGGUIFEI": ["scene_exile", "scene_battlefield"],  # 贵妃不出现在边塞
        "LIBEI": ["scene_monastery"],  # 李白不去修道（至少不去深山老林）
    }
    
    # 规则2: 特定情绪在特定场景下不合法
    SCENE_EMOTION_BLACKLIST = {
        "scene_temple": ["AMBITION", "ARROGANCE"],  # 佛门清净地
        "scene_brawl": ["TRANQUILITY"],  # 打架时不可能旷达
        "scene_palace": ["FATIGUE"],  # 朝堂上不能表露疲惫
    }
    
    # ... 检查通过返回 True
```

**数据流：**

```text
笛卡尔积展开: 10场景 × 3对 × 8对象 = 240 原始组合
    │
    ▼
剪枝过滤器（三项检查）:
    │ 场景×对象: 郑虔不去夜宴 ❌
    │ 场景×情绪: 佛堂不出野心 ❌  
    │ 情绪×对象: 贵妃不愤怒 ❌（贵妃愤怒不符合人设）
    │ → 过滤后约 80-120 个合法组合
    │
    ▼
打分选择器（执行两次，同上）
    │
    ▼
LLM Prompt（包含 NPC 对象信息）
    │
    ▼
输出 CSV
```

**CSV 示例（[古刹避雨] × [ANGER vs SORROW] × [郑虔]）：**

| 列 | 值 |
|----|-----|
| `title` | 破庙逢郑虔 |
| `description` | 你推开古刹大门时，看到一个衣衫褴褛的中年人正缩在墙角烤火——竟是当年被贬的郑虔！他看到你，苦笑一声："你也是被那场雨逼到这里的？" |
| `trigger_tags` | `[ACTION_TRAVEL_ROAM/ENV_NATURE_SNOWSTORM/VIBE_PHILOSOPHY_ZEN/TARGET_NPC_ZHENGQIAN]` |
| `option_1_desc` | 痛骂朝廷昏庸，李林甫当道 |
| `option_1_req` | `prop_gt(name=ANGER; val=30)` |
| `option_1_result` | `item_add(name=VIBE_THEME_MACABRE:ghost_fire) | prop_add(name=ANGER; val=15) | flag_int_append(name=zhengqian_favor; val=20)` |
| `option_2_desc` | 默默递上干粮，陪他坐到天明 |
| `option_2_req` | `prop_gt(name=SORROW; val=30)` |
| `option_2_result` | `item_add(name=VIBE_PHILOSOPHY_ZEN:incense_ash) | prop_add(name=SORROW; val=15) | flag_int_append(name=zhengqian_favor; val=-10)` |
| `option_3_desc` | 放下几枚铜钱，转身离去 |
| `option_3_req` |（无条件兜底） |
| `option_3_result` | `prop_add(name=FATIGUE; val=10)` |

---

## 2. 意象枚举池（28 个实体，供所有事件类型共享）

### 2.1 数据结构

每个意象实体包含：
- **`id`** —— 三段式 Tag ID（如 `ENV_NATURE_NIGHTMOON:cold_moon`）
- **`name`** —— 中文名（如"寒月"）
- **`affinities`** —— 情绪亲缘度映射 `{emotion: score(0-100)}`

### 2.2 完整列表

#### 锚定于 ENV（环境/时局）—— 6 个

| ID | 名称 | 情绪亲缘度 |
|-----|------|-----------|
| `ENV_NATURE_NIGHTMOON:cold_moon` | 寒月 | `TRANQUILITY:90, SORROW:80, FATIGUE:40` |
| `ENV_NATURE_AUTUMNWIND:falling_leaf` | 落木 | `SORROW:85, FATIGUE:70, TRANQUILITY:50` |
| `ENV_NATURE_SNOWSTORM:lone_snow` | 孤雪 | `TRANQUILITY:85, FATIGUE:80, SORROW:60` |
| `ENV_SOCIETY_WAR:beacon_fire` | 烽火 | `ANGER:90, AMBITION:70, ARROGANCE:50` |
| `ENV_SOCIETY_WAR:blood_stain` | 碧血 | `ANGER:95, SORROW:70, ARROGANCE:50` |
| `ENV_SOCIETY_FAMINE:starving_bone` | 饿殍 | `SORROW:95, ANGER:80, FATIGUE:60` |

#### 锚定于 VIBE（审美/文学母题）—— 7 个

| ID | 名称 | 情绪亲缘度 |
|-----|------|-----------|
| `VIBE_THEME_HISTORY:ruined_wall` | 残垣 | `SORROW:90, TRANQUILITY:50, FATIGUE:40` |
| `VIBE_THEME_MACABRE:ghost_fire` | 鬼火 | `SORROW:95, ANGER:60, FATIGUE:50` |
| `VIBE_PHILOSOPHY_ZEN:temple_bell` | 晨钟 | `TRANQUILITY:95, SORROW:40, FATIGUE:30` |
| `VIBE_PHILOSOPHY_ZEN:incense_ash` | 残香 | `TRANQUILITY:85, SORROW:60, FATIGUE:50` |
| `VIBE_AESTHETIC_SENSUAL:red_sleeve` | 红袖 | `ARROGANCE:85, AMBITION:75, TRANQUILITY:40` |
| `VIBE_AESTHETIC_ELEGANT:ink_stone` | 古砚 | `TRANQUILITY:80, AMBITION:60, ARROGANCE:40` |
| `VIBE_THEME_MARTIAL:border_flag` | 塞旗 | `ARROGANCE:80, ANGER:70, AMBITION:60` |

#### 锚定于 ACTION（动作/行为）—— 5 个

| ID | 名称 | 情绪亲缘度 |
|-----|------|-----------|
| `ACTION_TRAVEL_BOAT:lone_sail` | 孤帆 | `SORROW:90, TRANQUILITY:60, FATIGUE:50` |
| `ACTION_TRAVEL_BOAT:broken_oar` | 折桨 | `SORROW:80, FATIGUE:75, ANGER:50` |
| `ACTION_TRAVEL_CLIMB:high_tower` | 危楼 | `SORROW:85, ARROGANCE:60, TRANQUILITY:50` |
| `ACTION_SOCIAL_PARTING:willow_branch` | 折柳 | `SORROW:85, TRANQUILITY:50, FATIGUE:40` |
| `ACTION_ENTERTAIN_DRINK:empty_cup` | 空盏 | `ARROGANCE:90, SORROW:70, TRANQUILITY:50` |

#### 锚定于 TARGET（实体对象）—— 6 个

| ID | 名称 | 情绪亲缘度 |
|-----|------|-----------|
| `TARGET_OBJECT_SWORD:rusty_sword` | 锈剑 | `SORROW:80, FATIGUE:70, ARROGANCE:50` |
| `TARGET_OBJECT_SWORD:cold_blade` | 寒锋 | `ANGER:90, ARROGANCE:85, AMBITION:60` |
| `TARGET_OBJECT_GUQIN:broken_string` | 断弦 | `SORROW:90, TRANQUILITY:60, FATIGUE:50` |
| `TARGET_FACTION_MILITARY:torn_flag` | 残旗 | `SORROW:85, ANGER:70, FATIGUE:60` |
| `TARGET_NPC_LIBAI:wine_gourd` | 酒葫芦 | `ARROGANCE:95, TRANQUILITY:60, AMBITION:40` |
| `TARGET_NPC_DUFU:thatched_grass` | 茅草 | `SORROW:85, TRANQUILITY:60, FATIGUE:50` |

---

## 3. 场景模板（10 个场景，供所有事件类型共享）

| ID | 名称 | Tag 预设 | 意象白名单 |
|-----|------|---------|-----------|
// 当前的场景数据有问题，删除了

### 额外前期野心意象
ENV_POLITICS_PROSPER:cloud_and_sun (云日) - “总为浮云能蔽日”，代表靠近皇权、盛世气象。
TARGET_FACTION_ROYAL:jade_step (玉阶) - 代表朝堂、权力中枢、升迁之路。
TARGET_OBJECT_SWORD:giant_roc (大鹏) - 李白最爱，代表不甘平庸、一飞冲天。

---

## 4. 四种事件类型的生成量对比

| 类型 | 维度 | 原始组合 | 剪枝后 | 每事件选项数 | 总 CSV 行数 |
|------|------|---------|--------|------------|-----------|
| **A: 纯场景渲染** | 场景(10) | 10 | 10 | 1 选项 | 20 |
| **B: 单情绪单线** | 场景(10) × 单情绪(6) | 60 | ~55 | 2 选项(1精英+1兜底) | ~165 |
| **C: 对立分支** | 场景(10) × 情绪对(3) | 30 | ~28 | 3 选项(2精英+1兜底) | ~112 |
| **D: 复合维度** | 场景(10) × 情绪对(3) × 对象(8) | 240 | ~100 | 3 选项(2精英+1兜底) | ~400 |
| **总计（不含 D）** | | **100** | **~93** | | **~297** |
| **总计（含 D）** | | **340** | **~193** | | **~697** |

---

## 5. 核心算法：打分选择器

### 5.1 Python 伪代码

```python
# 全局意象字典
IMAGE_DICT: dict[str, ImageryItem] = { ... }  # 28 items

def pick_best_image_for_emotion(scene_pool: list[str], target_emotion: str) -> str | None:
    """
    在场景的合法意象池中，选出对目标情绪亲缘度最高的意象。
    返回意象 ID，如果最高分 < 30 则返回 None（丢弃该组合）。
    """
    best_image = None
    max_score = -1
    
    for img_key in scene_pool:
        score = IMAGE_DICT[img_key].affinities.get(target_emotion, 0)
        if score > max_score:
            max_score = score
            best_image = img_key
    
    if max_score < 30:
        return None  # 降级：该组合无合法意象
    
    return best_image
```

### 5.2 边界情况处理

| 场景 | 触发条件 | 处理方式 |
|------|---------|---------|
| **无意象匹配** | max_score < 30 | 跳过该组合，记录日志 |
| **多意象并列最高分** | 两个意象同分 | 随机选一个（增加多样性） |
| **场景池只有 1 个意象** | 场景配置太少 | 给场景补充意象，或跳过 |
| **情绪不在亲缘度表** | `affinities` 未配置该情绪 | 默认 score = 0 |

---

## 6. Prompt 模板

### 6.1 类型 B（单情绪单线）Prompt

```
【系统任务】
你是一个大唐叙事事件生成器。当前任务组合：
场景锚点：{scene_name}（{scene_description}）
玩家情绪门槛：{emotion_name} —— {emotion_desc}

【情绪守卫】
专属选项需要玩家 prop_gt(name={emotion_name}; val=20) 才能触发。

【场景标签预设】
{scene_tags}

【意象掉落约束】
专属选项的掉落意象必须且只能从以下列表中选择一个：
{candidate_images}
禁止发明列表外的新词！

【输出 JSON】
{
  "event_title": "15字以内标题",
  "event_desc": "{word_count_min}-{word_count_max}字描述",
  "trigger_tags": ["最多3个五维Tag"],
  "elite_option": {
    "text": "选项文本",
    "image_id": "选中意象的ID",
    "image_desc": "15字以内文学描述"
  },
  "fallback_option": {
    "text": "兜底行为"
  }
}
```

### 6.2 类型 C（对立分支）Prompt

```
【系统任务】
你是一个大唐叙事事件生成器。当前任务组合：
场景锚点：{scene_name}（{scene_description}）
冲突核心：{pair_name} —— {branch_A_desc} vs {branch_B_desc}

【两难结构】
请生成一个玩家必须在两种极端情绪中做出选择的事件。
选项 A 代表 {branch_A_emotion}，选项 B 代表 {branch_B_emotion}。
两选项的行为和后果必须天差地别。

【意象掉落】
- 选项 A 必须掉落: {branch_A_image}
- 选项 B 必须掉落: {branch_B_image}
请在文案中自然地描写玩家获得这些意象的过程。

【输出 JSON】
{
  "event_title": "...",
  "event_desc": "...",
  "trigger_tags": [...],
  "option_A": {"text": "...", "image_id": "..."},
  "option_B": {"text": "...", "image_id": "..."},
  "fallback_option": {"text": "..."}
}
```

---

## 7. 两种意象升级路线的选择

> 这是你之前问过的问题，我在这里记录两个备选方案，等你决定走哪条路。

### 方案 X：同类意象堆叠升阶（推荐首发）

```
3个 [VIBE_THEME_MARTIAL:rusty_sword] → 合成 1 个 [VIBE_THEME_MARTIAL:level2_sword]
纯数值验证，逻辑极度稳健
```

### 方案 Y：不同意象配方组合

```
[VIBE_THEME_MARTIAL:rusty_sword] + [ACTION_ENTERTAIN_DRINK:empty_cup] 
    → [VIBE_AESTHETIC_ELEGANT:侠客行意象]
需要配方表，更复杂，但涌现感更强
```

**建议：** 首发使用方案 X（堆叠升阶），等系统跑通后再考虑方案 Y。详见 [`imagery_gain_event_standard.md`](../DOCUMENTATIONS/imaginary/imagery_gain_event_standard.md) 的等级机制。

---

## 8. 实施路线图

### Phase A: 数据模型

| 任务 | 文件 |
|------|------|
| 新增 `ImageryItem` Pydantic 模型 | [`tools/config.py`](../tools/config.py) |
| 新增 `SceneTemplate` Pydantic 模型 | [`tools/config.py`](../tools/config.py) |
| 新增 `EmotionConfig` / `EmotionPair` 模型 | [`tools/config.py`](../tools/config.py) |
| 创建 28 个意象实体的 JSON | `tools/data/image_dictionary.json` |
| 创建 10 个场景模板的 JSON | `tools/data/scene_templates.json` |

### Phase B: 生成脚本

| 任务 | 文件 |
|------|------|
| 新增 `pick_best_image_for_emotion()` 函数 | [`tools/generate_orthogonal_events.py`](../tools/generate_orthogonal_events.py) |
| 新增 `is_valid_combination()` 剪枝函数 | 同上 |
| 支持类型 B（单情绪单线） | 同上 |
| 支持类型 C（对立分支） | 同上 |
| 支持类型 D（复合维度，晚点再做） | 同上 |

### Phase C: 测试

| 任务 | 说明 |
|------|------|
| Dry-run 类型 B 全部 60 组合 | 检查 Prompt 质量 |
| Dry-run 类型 C 全部 30 组合 | 检查两难叙事结构 |
| 全量生成 + Godot 导入 | 端到端验证 |

### Phase D: 收尾

| 任务 | 说明 |
|------|------|
| 更新旧文档过时标记 | 已完成 ✅ |
| 提交 commit | — |
| 同步 CSV 到云端 | — |

---

## 相关文档

- [意象阶级·合成坍缩·诗词评价引擎 V3](imagery_tier_synthesis_poem_engine.md) — Tier 系统、感悟坍缩、墨水污染定律、诗词评价引擎
- 碎片 Tier 由获取时的 IAM + 情绪运行时判定（见 `core/tier_determiner.gd`）
