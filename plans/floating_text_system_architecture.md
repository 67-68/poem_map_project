# 统一飘字系统架构规划

> 状态: 架构提案 v2
> 新增核心原则: "不暴露裸数据，只展示预定义文本"

---

## 0. 核心原则：模糊文本契约

> **不要飘 "+5 金钱"**，而是飘 "你掂量着一大袋钱，沉重，厚实。"

### 规则

所有的飘字内容必须**间接引用**数据模型自带的文本描述，禁止硬编码数值到飘字文本里。

| 数据类型 | 文本来源 | 现有实现 |
|----------|----------|----------|
| **Property (属性) 变化** | `Property.get_staged_perception_text()` | ✅ 已存在 [`core/model/property.gd:17`](core/model/property.gd:17) |
| **Trait (特质) 获得/失去** | `Trait.description` (继承自 `GameEntity`) | ✅ 已有 `description` 字段 |
| **Imaginary (意象) 获得** | `ImaginaryTag.name` + 等级描述 | ⚠️ 需要补充等级文本映射 |
| **系统通知** | 事件文案直接定义 | ✅ 直接传字符串 |

### 设计推导

```
原始数据: prop_sub(name=money, val=50)
        ↓
传统做法: 飘 "-50 两"  ← 裸数据，杜绝
        ↓
正确做法: 
  1. 调用 Database.properties["money"].get_staged_perception_text()
     → 根据变化后的 val 返回 "你掂量着一大袋钱，沉重，厚实。"
  2. 或者根据变化幅度 delta 生成上下文文本:
     → "你的钱袋沉了不少" / "你的钱袋轻了一些"
```

**但注意:** `get_staged_perception_text()` 返回的是**绝对状态描述**（基于当前值），不是**变化描述**。所以需要区分两种场景：

| 场景 | 内容类型 | 示例 |
|------|----------|------|
| **变化提示** (飘一下) | 变化幅度的模糊文本 | "行囊又重了几分" / "囊中羞涩了" |
| **状态查询** (停在面板上) | 绝对状态文本 | "你富可敌国" / "一贫如洗" |

→ 所以还需在 `Property` 上新增一个 `get_change_perception_text(delta: int)` 方法。

---

## 1. 现状诊断

```
当前系统地图:
┌────────────────────────────────────────────────────────────────────┐
│  FloatingText (Node2D, 世界坐标)  ← PoolManager 管理              │
│    ├─ messager.gd 调用 (信使路过)                                  │
│    └─ text_emitter.gd 调用 (硬编码 'test') ← 废弃                  │
├────────────────────────────────────────────────────────────────────┤
│  SimpleToast (Control, UI坐标)     ← EventBus.request_warning_toast│
│    ├─ event_btn.gd (选项禁用)                                      │
│    ├─ base_operator.gd (operator警告)                              │
│    └─ info_demo_operator.gd (info)                                 │
├────────────────────────────────────────────────────────────────────┤
│  pop_up.gd (Control, UI坐标)       ← EventBus.request_text_popup   │
│    ├─ timeline.gd (new decade)                                     │
│    └─ time_control_panel.gd (choose a poet)                        │
├────────────────────────────────────────────────────────────────────┤
│  DialogueBubble (Control)          ← 独立生命周期 (不动)            │
│  PoemPopup (Control)               ← 独立生命周期 (不动)            │
└────────────────────────────────────────────────────────────────────┘
```

### 核心问题

1. **`SimpleToast` 和 `pop_up.gd` 功能重叠** — 都是 UI 层短暂停留 + 淡入淡出，合并可消掉一个冗余节点
2. **`FloatingText` 半废** — 池化机制和动画都有，但没人正经用它传达游戏信息
3. **缺乏分类信号** — 没有区分「属性变化」「物品获得」「系统提示」「警告」

---

## 2. 飘字分类矩阵

| 类型 | 信号 | 坐标系 | 文本来源 | 颜色 | 动画 | 持续时间 | 使用场景 |
|------|------|--------|----------|------|------|----------|----------|
| **属性变化** | `request_float_text` | 世界 (Node2D) | `Property.get_change_perception_text(delta)` | 绿(+) / 红(-) | 上浮 50px + 缩放 0.4→0.7 + 淡出 | 1.5s | `prop_sub` 扣钱 |
| **物品/意象获得** | `request_float_text` | 世界 (Node2D) | `Trait.description` / `ImaginaryTag.name` | 金色 | 上浮 + 缩放弹跳 | 2.0s | 获得道具/意象 |
| **系统提示** | `request_toast` | UI (Control) | 事件文案 | 白色 | 缩放 0.9→1.0 + 淡入淡出 | 3.0s | "new decade" |
| **警告** | `request_toast` | UI (Control) | 事件文案 | 红色 | 缩放 + 淡入淡出 | 3.0s | 选项禁用 |

> **核心原则:** 世界飘字传达「我身上发生了什么」，UI Toast 传达「系统状态变化」。
> 两者坐标系分离，避免 Camera 缩放时 UI 文字乱跑。

---

## 3. 信号契约设计

在 [`core/eventbus.gd`](core/eventbus.gd) 新增 2 个信号，废弃 2 个旧信号:

```gdscript
# ──────────────────────────────────────────────
# 新信号
# ──────────────────────────────────────────────

## [推荐] 世界坐标飘字
## content: 模糊文本 (BBCode 支持), 如 "[color=#FFD700]塞外风情[/color]"
## world_pos: 世界坐标
signal request_float_text(content: String, world_pos: Vector2)

## [推荐] UI Toast 
## content: 文本内容
## type: ToastType { INFO = 0, WARNING = 1 }
signal request_toast(content: String, type: int)

# ──────────────────────────────────────────────
# 废弃信号 (@deprecated - 迁移到新信号)
# ──────────────────────────────────────────────
signal request_text_popup          # → 改用 request_toast
signal request_warning_toast       # → 改用 request_toast(text, 1)
```

---

## 4. Property 扩展: `get_change_perception_text()`

在 [`core/model/property.gd`](core/model/property.gd) 新增方法:

```gdscript
## 根据变化量 delta 返回描述性文本
## delta > 0: 增加, delta < 0: 减少
## 用于飘字系统，避免暴露裸数值
func get_change_perception_text(delta: int) -> String:
    var abs_delta = abs(delta)
    var direction = "gain" if delta > 0 else "loss"
    
    # 先从 .tres 配置的 staged_perceptions 找变化描述
    # 如果配置了 change_perceptions 则用，否则 fallback 到通用文本
    for perception in change_perceptions:
        if perception.min_delta <= abs_delta and abs_delta <= perception.max_delta:
            return perception.get_text(direction)
    
    # fallback: 使用阶段感知文本 (当前状态的描述)
    return get_staged_perception_text()
```

需要新增数据结构:

```gdscript
# core/model/prop_change_perception.gd
class_name PropChangePerceptionData extends Resource
@export var min_delta: int = 0    # 变化量下限
@export var max_delta: int = 999  # 变化量上限
@export var gain_text: String = ""  # 增加时文本
@export var loss_text: String = ""  # 减少时文本

func get_text(direction: String) -> String:
    return gain_text if direction == "gain" else loss_text
```

**`.tres` 配置示例 (money.tres):**
```
change_perceptions = [
    { min_delta=1,   max_delta=10,  gain_text="多了几枚铜钱",   loss_text="花了几枚铜钱" },
    { min_delta=11,  max_delta=50,  gain_text="你掂量着一大袋钱", loss_text="荷包缩水不少" },
    { min_delta=51,  max_delta=999, gain_text="你现在富可敌国",   loss_text="破财免灾" },
]
```

> 注意: `change_perceptions` 是**可选的扩展配置**。没有配置的 property 直接 fallback 到 `get_staged_perception_text()`，不影响现有系统。

---

## 5. 消费端: Operator 触发飘字

### 5.1 PropertyOperator 改造

在 [`core/model/property_operator.gd`](core/model/property_operator.gd) 的 `operate()` 末尾:

```gdscript
# operate() 末尾新增:
var delta = new_val - old_val
var prop = Database.properties.get(property_name)
if prop:
    var perception_text = prop.get_change_perception_text(delta)
    var world_pos = PlayerState.get_global_position()  # 或从 context 取
    EventBus.request_float_text.emit(perception_text, world_pos)
```

### 5.2 TraitOperator 改造

在 [`core/model/trait_operator.gd`](core/model/trait_operator.gd):

```gdscript
# operate() 末尾新增:
var trait = Database.traits.get(trait_name)
if trait and trait.description:
    EventBus.request_float_text.emit(trait.description, world_pos)
```

---

## 6. SimpleToast + pop_up 合并

**结论: 合并，消掉 `pop_up`。**

- 保留 `SimpleToast` 作为基座，改名 `ToastOverlay`
- 吸收 `pop_up` 的 `EventBus.request_text_popup` 连接
- `pop_up.gd` 和 `pop_up.tscn` 标记 `@deprecated` 保留兼容

---

## 7. 文件变更清单

```
# ── 新增 ──
core/model/prop_change_perception.gd     ← PropChangePerceptionData 类
plans/floating_text_system_architecture.md ← 本文

# ── 修改 ──
core/eventbus.gd                          ← +2 信号, 旧信号标记 deprecated
core/model/property.gd                    ← +get_change_perception_text() + change_perceptions 数组
core/model/property_operator.gd           ← operate() 末尾 emit request_float_text
core/model/trait_operator.gd              ← operate() 末尾 emit request_float_text
world/floating_text.gd                    ← play() 参数化 (颜色/缩放/上升距离)
world/float_text.tscn                     ← Label 默认字号/样式微调
world/simple_toast.gd                     ← 改名 ToastOverlay, 支持 type 参数

# ── 标记废弃 ──
ui/pop_up.gd                              ← 添加 @deprecated 注释
ui/pop_up.tscn                             ← 添加 @deprecated 注释

# ── 不动 ──
world/dialogue_bubble.gd                  ← 独立交互生命周期
features/poem_popup.gd                    ← 独立播放系统
```

---

## 8. 执行顺序

```
Phase 1: 数据层 (2 文件)
  [1] 新增 PropChangePerceptionData 类
  [2] Property 扩展 get_change_perception_text()
  └─ 不影响现有系统，纯新增

Phase 2: 信号层 (1 文件)
  [3] EventBus 新信号 + 旧信号废弃标记
  └─ 旧 emit 仍然工作，不中断

Phase 3: 渲染层 (3 文件)
  [4] FloatingText 参数化改造
  [5] SimpleToast → ToastOverlay 改造
  └─ 各自独立可测试

Phase 4: 消费层 (2 文件)
  [6] PropertyOperator 接入飘字
  [7] TraitOperator 接入飘字
  └─ 改动最小，每个 operator 加 4-5 行

Phase 5: 清理 (2 文件)
  [8] pop_up 标记废弃
  [9] 迁移旧信号调用点到新信号
```

**预估总变更:** 新增 2 个文件 (~80 行)，修改 7 个文件 (~120 行)，标记废弃 2 个文件。
