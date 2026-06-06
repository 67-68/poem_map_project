# 情绪获取系统 (Emotion Acquisition System)

## 概述

情绪（Emotion）是玩家的临时状态（Volatile Stat），属于连续属性（Prop），而非离散资源。与意象（Imaginary）不同，情绪不能像道具一样"掉落"——它必须是玩家在游戏世界中摸爬滚打时留下的**沉淀物 (Byproduct)**。

> **核心原则**：情绪是伴生物，不是战利品。

---

## 三大获取通道

根据现有事件 DSL 系统，情绪获取无需新系统，直接融合在现有机制中。共三个通道：

---

### 通道 1：日常行为的"情绪转换器"（主动获取）

通过【观赏艺术】、【喝酒交游】等日常事件，玩家用【金钱/时间】兑换【情绪/灵感】。

**DSL 配置示例 — 听古琴选项结算：**

```gdscript
Option_1_Op: prop_add(name=MONEY; val=-200) | prop_add(name=TRANQUILITY; val=15) | prop_add(name=FATIGUE; val=10)
```

**玩家行为逻辑：** "我马上要去参加李白的狂欢宴会，但 ARROGANCE（狂傲）不够，无法解锁拼酒的特殊选项。我得先去西市花钱看场剑器舞，把狂傲值刷上去。"

---

### 通道 2：叙事选择的"情感残渣"（伴生获取）

在任何大型随机事件、政治事件中，玩家的每一个选择都应顺手附带情绪变化。这叫**数值的叙事感**。

**示例 — 事件【朋友被贬】：**

```gdscript
# 选项 1：写诗痛骂朝廷（需要狂傲底色）
Option_1_Req: prop_gt(name=ARROGANCE; val=30)
Option_1_Op: prop_add(name=OFFICIAL_PRESTIGE; val=-50) | prop_add(name=ANGER; val=20) | imaginary_add(id="sword")

# 选项 2：强忍悲痛，送别朋友（理智/隐忍路线）
Option_2_Req:
Option_2_Op: prop_add(name=SORROW; val=15) | prop_add(name=AMBITION; val=5)
```

**行为逻辑：** 玩家为了活命选择选项 2，虽保住官位，但系统冷酷地塞了 15 点 SORROW 和 5 点 AMBITION。长此以往，玩家会变成一个极度压抑的功利主义者。

---

### 通道 3：天地万物的"被动渲染"（环境获取）

利用大地图的时间系统进行隐性注入。在回合结算/每月结算 Operator 里，根据季节或地点自然地改变情绪。

| 触发条件 | 效果 | 叙事对应 |
|---------|------|---------|
| 秋季每旬 | `prop_add(name=SORROW; val=2)` | 自古逢秋悲寂寥 |
| 在名山节点驻留 | `prop_add(name=TRANQUILITY; val=3)` | 山水涤荡心灵 |

---

## 终极 Gameplay 闭环 (Economy Loop)

```
蓄水（攒情绪）： 玩家花钱听曲、经历大地图事件，默默积累 ANGER / ARROGANCE
     ↓
爆发（夺意象）： 带着满腔狂傲参加清流宴会，因情绪达标解锁隐藏选项"斗酒诗百篇"
     ↓        成功夺取极品意象【黄河之水】
     ↓
变现（写绝句）： 打开 PoemCrafter，消耗灵感，用【黄河之水】合成千古绝句
     ↓        获得【诗仙】Trait 和巨额声望
     ↓
消耗（情绪清空）： 诗写完后情绪宣泄完毕，对应情绪值归零或减半
```

**所有环节全部通过 `prop_add` 跑通，无中间商。**

---

## 情绪管理的设计权衡

### 情绪上限问题

| 方案 | 优点 | 缺点 |
|------|------|------|
| **无上限叠加**（类经验值） | 玩家可长期积累，满足感强 | 数值可能失控，高情绪玩家碾压低门槛 |
| **有上限（如 100）+ 写诗消耗** | 数值可控，推动创作循环 | 需要精心设计消耗公式 |

**推荐方案：** 设定上限（100），写出一首旷世名作后消耗对应的情绪值（"一吐为快"），形成"积累 → 爆发 → 清空"的循环。

---

## 相关文档

- [环境情绪注入设计](./design_get_emotion_in_event.md) — on_enter 阶段的三种注入模式
- [情绪-意象系统](../imaginary/emotion_imaginary_system.md) — 情绪与意象的连接机制
- [事件选项系统](./event_option_system.md) — 选项结果的情绪操作符
- [Trait 设计](./trait_designs.md) — 情绪积累到阈值后的质变
- [意象获取事件标准规范](./imagery_gain_event_standard.md) — 情绪门槛在意象获取中的具体应用
