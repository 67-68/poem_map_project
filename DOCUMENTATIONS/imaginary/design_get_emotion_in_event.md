> ⚠️ **本文件已废弃 (2026-07-01)** — 意象系统已全面简化。权威文档请参见 [`plans/imagery_simplification_refactor.md`](../../plans/imagery_simplification_refactor.md)
> 五维宪法 Tag 系统、四段式字符串解析、`detail_imaginaries`、`perceptions` 字段均已删除。

# 事件环境情绪注入设计 (Emotion Injection in Event)

## 概述

本文档定义在事件 `on_enter` 阶段（事件刚加载、玩家尚未选择选项时）向玩家注入情绪的三种标准模式。情绪注入必须遵守 **极化原则 (Polarization)**——平庸的数值分配等于没有分配，玩家需要的是情绪尖刺来突破选项门槛。

---

## 核心原则

### 极化原则 (Polarization)

情绪值必须形成尖刺（Spike），而非平摊。只有尖刺才能帮助玩家击穿特定选项的门槛（如 `REQUIREMENT: SORROW > 30`）。

### 被动 vs 主动

- **被动渲染 (on_enter)**：事件加载时自动注入，属于环境渲染。必须极其克制且指向性明确。
- **主动抉择 (choice_result)**：玩家选择选项后结算，属于"叩问本心"。数值可以更大、更丰富。

---

## 三大注入模式

### Pattern A：单点刺穿 (The Razor) — 最常用

| 属性 | 值 |
|------|-----|
| **逻辑** | 只加 **1 种**情绪，给中高数值 |
| **场景** | 纯粹的环境冲击 |
| **DSL** | `prop_add(name=SORROW; val=15)` |
| **叙事示例** | 事件【路过马嵬坡】。`on_enter` 瞬间空气中弥漫的死寂让玩家 `SORROW +15`，确立整个事件的悲凉底色 |

### Pattern B：零和博弈 (The Push-Pull) — 内心冲突

| 属性 | 值 |
|------|-----|
| **逻辑** | 增加一种情绪，**扣除**另一种对立情绪 |
| **场景** | 价值观的强行扭转 |
| **DSL** | `prop_add(name=ARROGANCE; val=20) | prop_add(name=TRANQUILITY; val=-20)` |
| **叙事示例** | 事件【御赐金牌】。皇帝赏赐千金，狂傲暴涨，归隐的旷达被瞬间摧毁 |

### Pattern C：催化剂捆绑 (The Catalyst) — 驱动剧情

| 属性 | 值 |
|------|-----|
| **逻辑** | 1 种基础情绪 + `AMBITION`（入世动力） |
| **场景** | 激发玩家改变现状的欲望 |
| **DSL** | `prop_add(name=ANGER; val=10) | prop_add(name=AMBITION; val=15)` |
| **叙事示例** | 事件【目睹贪官强抢民女】。不仅感到愤怒，更产生"必须往上爬"的野心 |

---

## 时域隔离 (Temporal Isolation)

不要把所有的情绪获取都塞进 `on_enter`。`on_enter` 给得太多，玩家会觉得情绪是"被系统强奸的"。

| 阶段 | 定位 | 设计原则 |
|------|------|---------|
| `on_enter` | **触景生情**（底色） | 克制、指向性明确，推荐 Pattern A 微微给一点 |
| `choice_result` | **叩问本心**（抉择） | 根据玩家选择放大或反转情绪 |

### 高级设计示例

事件渲染悲凉氛围 → `on_enter` 给 `SORROW +5` → 三个选项：
- 【黯然落泪】：结算 `SORROW +15`（顺应氛围，放大情绪）
- 【仰天大笑出门去】：结算 `ARROGANCE +20`（逆反氛围，反转情绪）

**Player Agency（玩家代理权）永远高于一切。**

---

## 情绪极化后的 UI 表现

如果在 `on_enter` 阶段执行了 `prop_add(name=SORROW; val=15)`，必须让玩家立刻感知到情绪变化。可选方案：

| 方案 | 实现方式 |
|------|---------|
| **文本提示** | 在事件描述文本末尾动态追加"（你感到一阵悲凉）" |
| **屏幕特效 (VFX)** | 屏幕边缘做红/蓝色调闪烁 |
| **属性面板反馈** | 右上角属性面板弹上浮数字 `+15` |

---

## 相关文档

- [情绪获取系统](./emotion_get_system.md) — 情绪获取的三大通道
- [事件选项系统](./event_option_system.md) — 选项结果的情绪操作符
- [意象获取事件标准规范](./imagery_gain_event_standard.md) — 意象获取的现有途径和标准流程
