# Trait 设计 (Trait Design System)

## 概述

Trait（特征/身份）是玩家在游戏过程中通过行为积累获得的**质变身份卡**。与 Prop（属性/数值）不同，Trait 是身份而非状态——状态会自然消退，身份只有通过极端事件才能洗白。

> **核心原则：** Trait 必须破坏规则。如果没有给玩家带来特殊的 UI 选项、特权或极其严厉的惩罚，它就只配当一个 Prop。

---

## 核心架构

### 数据收敛原则

**绝对不要做 1 对 1 的底层冗余。** 量变积累池（Prop）和质变结果（Trait）是解耦的。多个不同的 Trait 甚至可以共享同一个底层 Prop。

| 错误做法 | 正确做法 |
|---------|---------|
| 为 `trait:corrupt` 建专门的 `flag:corrupt_progress` | 复用通用 Prop `CORRUPTION_SCORE` |
| 每个 Trait 单独写 Operator | 共享数据流转，统一由 Milestone Observer 结算 |

### 过程积累 vs 质变触发

```
# 过程积累：玩家干坏事，只调用最基础的 prop_add
prop_add(name=CORRUPTION_SCORE; val=10)

# 后台结算：Milestone Observer 在回合结束时统一结算
if CORRUPTION_SCORE > 100:
    grant_trait("corrupt_1")
```

**没有任何专门的 Operator，只有最纯粹的数据流转。**

---

## Trait 的路线与进阶 (Trait Paths)

Trait 应该有路线。低级酒鬼（嗜酒如命）可以进化成高级酒鬼（酒中仙）。但有一个铁律：**永远不要超过 3 个阶段。**

| 阶段 | 定位 | 效果 |
|------|------|------|
| **阶段 1（入门）** | 初现端倪 | 改变少部分对话，解锁基础专属选项 |
| **阶段 2（进阶）** | 深陷其中 | 改变世界对你的看法，解锁核心收益，带有明显负面代价 |
| **阶段 3（化境/深渊）** | 病入膏肓 | 游戏机制的质变（如彻底免疫某种惩罚，或永远无法进入某种势力） |

---

## 质变要求的数学模型

**必须是非线性的（指数级递增）。**

| 等级 | 阈值 | 获取难度 |
|------|------|---------|
| Lv 1（初现端倪） | 100 积分 | 随便玩玩就能拿到，尝到甜头 |
| Lv 2（深陷其中） | 500 积分 | 需要刻意去刷，甚至放弃其他路线 |
| Lv 3（病入膏肓） | 2000 积分 | 极限流玩法，必须把整个大唐的资源都砸进去 |

线性阈值（100/200/300）会导致玩家轻易在一个月内把所有 Trait 刷满，游戏直接丧失目标感。

---

## Trait 创建本体论原则

### 三句宪法

1. **Trait 是身份，不是状态。**
   - 状态会自然消退，身份只有通过极端事件才能洗白。

2. **Trait 必须破坏规则。**
   - 没有给玩家带来特殊 UI 选项、特权或严厉惩罚的，不配叫 Trait。

3. **Trait 的获取必须有叙事仪式感。**
   - 获得时必须全屏弹窗、给成就。绝不能像赚了 10 块钱一样悄无声息。

### 新手 Trait 设计示例

**问题：** 玩家在完成第一场清流宴会并表现优异后，获得什么新手 Trait？

**候选方案：`【诗坛新秀】** `

| 属性 | 值 |
|------|-----|
| **获取条件** | 清流宴会表现优异，声望 > 50 |
| **破坏规则的方式** | 解锁特殊选项"以诗会友"，在社交事件中额外增加声望获取 |
| **负面代价** | 引发浊流势力的敌意，某些选项被锁定 |
| **仪式感** | 全屏弹窗 + 获得成就"初露锋芒" |

---

---

## 疾病系统 (Disease Subclass)

`Disease` 是 `Trait` 的一个子类（[`core/model/disease.gd`](../../core/model/disease.gd)），专门用于**随时间推进恶化的负面身份**。疾病不是通过 Milestone Observer 结算的，而是通过**生存管理器（SurvivalManager）的 `aggregate_trait_effect()`** 在每旬自动推进。

### 字段说明

| 字段 | 类型 | 作用 |
|------|------|------|
| `on_enter_event` | String | 获得该疾病时通过 `guarantee_next` 触发的诊断事件 key |
| `progression_target` | String | N 旬后替换为的下一个疾病 uuid（如 `"disease_zhanwang_mania"`） |
| `progression_xun` | int | 推进所需的旬数（回合数） |
| `hijack_provider` | BaseProvider | 选项劫持提供者（如 ManiaProvider 插入疯狂选项） |
| `topic` | String | 大类：`DISEASE`（躯体）/ `MENTAL_ILLNESS`（精神） |
| `specific_topic` | String | 小类：`sickAcute` / `sickChronic` / `depression` / `mania` |
| `buffer_to_prop` | DictMultiplyOperator | 患病期间的属性比例增益/衰减（可选） |
| `trait_effect_operations` | Array[PropertyOperator] | 每旬自动执行的属性变化 |

### 生命周期

```
                    ┌─ 诊断事件 (on_enter_event) ──┐
                    │                                │
  [trait_operator ADD] ──→ guarantee_next.emit() ──→ 玩家体验诊断事件
                    │
                    ▼
        每旬 survival_manager 结算:
          - 执行 trait_effect_operations (±属性)
          - 累计 progression_xun 计数
          - 达到阈值 → trait_replace(progression_target)
                    │
                    ▼
              下一阶段疾病
```

### 疾病链（进度系统）

疾病采用**链式恶化**设计，每阶段约持续 6 旬（2 个月）：

| 阶段 | 示例 | 属性影响 | 推进 |
|------|------|---------|------|
| **急性期**（`sickAcute`） | 风寒急 `disease_fenghan_acute` | 无（默认） | 6 旬 → 慢性期 |
| **慢性期**（`sickChronic`） | 肺痨 `disease_feilao_chronic` | talent×0.5, money×0.6, literary_fame×0.8（衰减） | 6 旬 → 自身（锁定） |
| **郁症**（`depression`） | 失意之郁 `disease_shiyi_depression` | HEALTH-3, LITERARY_FAME-3 每旬 | 6 旬 → 狂症 |
| **狂症**（`mania`） | 谵狂 `disease_zhanwang_mania` | HEALTH-10, LITERARY_FAME+5 每旬 | **终端**（不推进） |
| | | + hijack_provider 劫持事件选项 | |

> **设计原则：** 躯体疾病（风寒→肺痨）遵循"急性→慢性"路径，精神疾病（失意之郁→谵狂）遵循"抑郁→狂躁"路径。慢性期和终端疾病的 `progression_target` 指向自身或为空，表示不再恶化。

### 选项劫持 (hijack_provider)

`hijack_provider` 是一个 `BaseProvider` 子类，在 [`BaseEvent.init()`](../../model/event.gd) 中被调度。当检测到玩家拥有带 `hijack_provider` 的 `Disease` trait 时：

1. **`provide()`** → 在选项列表最前面插入特殊选项（如狂症选项）
2. **`init()`** → 给所有现有选项增加额外代价（如健康消耗 + BURNOUT）

当前实现：[`ManiaProvider`](../../core/model/mania_provider.gd)

### 数据文件位置

```
data/1_core_rules/disease/
├── disease_fenghan_acute.tres        # 风寒急（躯体·急性）
├── disease_feilao_chronic.tres       # 肺痨（躯体·慢性）
├── disease_shiyi_depression.tres     # 失意之郁（精神·抑郁）
├── disease_zhanwang_mania.tres       # 谵狂（精神·狂躁·终端）
├── event_disease_fenghan_diagnosis.tres   # 风寒诊断事件
├── event_disease_shiyi_diagnosis.tres     # 壮志难酬诊断事件
├── event_disease_zhanwang_crazy.tres      # 狂言事件（狂症触发）
├── provider_mania_example.tres            # 狂症 Provider 配置
├── _disease_diagnosis_events.csv          # CSV 同步源：诊断事件
└── _disease_contamination_events.csv      # CSV 同步源：污染事件
```

---

## 相关文档

- [情绪获取系统](./emotion_get_system.md) — Prop 积累的三大通道
- [事件选项系统](./event_option_system.md) — 选择如何影响 Prop 积累
- [环境情绪注入设计](./design_get_emotion_in_event.md) — on_enter 阶段的情绪变化
- [情绪-意象系统](../imaginary/emotion_imaginary_system.md) — 情绪与意象的连接
- [大唐 Tag 本体论与五维宪法](./tag_dictioinary.md) — 疾病 Tag 枚举（sickAcute/sickChronic/MENTAL）
