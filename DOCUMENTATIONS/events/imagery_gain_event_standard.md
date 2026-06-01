# 意象获取事件标准规范 (Imagery Gain Event Standard)

## 概述

意象（Imaginary）是玩家拼凑诗句的"手牌/战利品"，属于离散资源。本文档定义**意象获取事件**的标准结构——即当玩家触发某个事件时，系统如何判定是否给予意象、给予什么意象。

---

## 核心数据流

### 完整链路

```
事件触发 → EventBus.event_shown → ImaginaryManager.add_imagenary(ev)
                                           ↓
                                   检查 ev.emotion_configs
                                           ↓
                               ┌──────────┴──────────┐
                               │                     │
                           有配置                 无配置
                               │                     │
                               ↓                     ↓
                   ImagenaryEvaluator.evaluate   跳过（输出警告）
                               │
                               ↓
                   返回结构化数据:
                   [{ blueprint: ImaginaryTag, context_tags: [...] }]
                               │
                               ↓
                   构造 entry: { "blueprint_id": String, "contexts": Array[String] }
                               │
                               ↓
                   ImaginaryTag.basic_imaginaries.append(entry)
                               │
                               ↓
                   根据阈值更新 current_level
                               │
                               ↓
                   EventBus.imaginary_changed.emit()
```

### 关键触发点

| 环节 | 位置 | 说明 |
|------|------|------|
| 信号发射 | `characters/narrative_overlay.gd:324` | 事件初始化完成后 emit `event_shown` |
| 意象管理 | `core/imaginary_manager.gd` | `add_imagenary()` 处理所有意象逻辑 |
| 条件校验 | `core/imagenary_evaluator.gd` | `evaluate_local_configs()` 批量校验 |
| 数据模型 | `core/model/imaginary.gd` | `ImaginaryTag` 数据结构 |

---

## EmotionConfigs 结构（核心配置）

每个事件可以挂载多个 `EmotionConfigs`，每个配置定义一个意象的掉落条件和上下文。

### 数据结构

```gdscript
class EmotionConfigs:
    blueprint: ImaginaryTag       # 目标意象（强类型引用，废除字符串 UID）
    context_tags: Array[String]   # 叙事上下文，如 ["with_li_bai", "sad"]
    requirements: Array           # 校验条件数组（基于玩家状态）
```

### 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `blueprint` | `ImaginaryTag` | ✅ | 要掉落的意象对象，直接引用 .tres 资源 |
| `context_tags` | `Array[String]` | ❌ | 本次获得的叙事上下文标签 |
| `requirements` | `Array[Dict]` | ❌ | 获取条件，见下文 |

### Requirements 条件格式

```json
[
  {
    "stat": "drunk_level",
    "op": ">=",
    "val": 30
  },
  {
    "stat": "talent",
    "op": ">=",
    "val": 80
  }
]
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `stat` | `String` | 玩家属性名（如 `drunk_level`, `talent`, `sorrow`） |
| `op` | `String` | 比较运算符：`>=`, `<=`, `>`, `<`, `==` |
| `val` | `int`/`float` | 比较阈值 |

---

## 三种意象获取模式

### 模式 1：情绪门槛模式（最常用）

**原理：** 意象掉落与玩家的情绪状态挂钩。情绪值达到门槛才掉落对应意象。

**适用场景：** 送别 → 悲伤达到阈值 → 获得"断肠"意象

**配置示例：**

```gdscript
# 送别事件中，sorrow > 10 获得 despair 意象
[sub_resource type="Resource" id="Resource_emotion_cfg_despair"]
script = ExtResource("7_emotion_cfg")
blueprint = ExtResource("9_imaginary_despair")
context_tags = Array[String](["farewell"])

[sub_resource type="Resource" id="Resource_emotion_req_sorrow"]
script = ExtResource("8_emotion_req")
volatile_stat = "sorrow"
value = 10
operator = 0  # GREATER_THAN

# requirements 挂载到 emotion_cfg
Resource_emotion_cfg_despair.requirements = SubResource("Resource_emotion_req_sorrow")
```

### 模式 2：复合属性模式

**原理：** 多个属性联合判定，支持天赋折扣（高 talent 降低门槛）。

**适用场景：** 醉酒场景中，根据 talent 高低给予不同意象

**配置示例：**

```json
// 诗人专属意象（高 talent 低门槛）
{
  "imagery": "emotion:sorrow:poetic_sorrow",
  "requirements": [
    {"stat": "drunk_level", "op": ">=", "val": 30},
    {"stat": "talent", "op": ">=", "val": 80}
  ]
}

// 蠢货兜底意象（低 talent 也能拿，但质量差）
{
  "imagery": "emotion:sorrow:cursing",
  "requirements": [
    {"stat": "drunk_level", "op": ">=", "val": 30},
    {"stat": "talent", "op": "<", "val": 80}
  ]
}
```

### 模式 3：环境被动渲染模式

**原理：** 不依赖玩家选择，基于时间/季节/地点自动获得意象。

**适用场景：** 秋风起时自动积累秋日意象

**配置示例：**

```gdscript
# 在回合结算 Operator 中
if season == "autumn":
    var entry = {
        "blueprint_id": "nature:autumn:leaves",
        "contexts": ["seasonal"]
    }
    imaginary_tag.basic_imaginaries.append(entry)
```

---

## 创建一个新意象获取事件的完整步骤

### Step 1：确认意象蓝图

确认 `ImaginaryTag` 资源是否存在。如果不存在，先创建：

| 字段 | 值示例 |
|------|--------|
| `uuid` | `emotion:despair` |
| `name` | 断肠 |
| `l3_threshold` | 4（默认） |

### Step 2：确定获取条件

根据事件叙事，回答：

1. **这个意象在什么情绪下获得？** → 对应 `requirements` 中的情绪门槛
2. **需要什么附加属性？** → 如 talent、drunk_level 等
3. **这个意象的上下文是什么？** → 如 `farewell`、`battle` 等

### Step 3：创建 EmotionConfigs

在事件资源的 `emotion_configs` 数组中添加配置：

```gdscript
[sub_resource type="Resource" id="Resource_emotion_cfg_despair"]
script = ExtResource("7_emotion_cfg")
blueprint = ExtResource("9_imaginary_despair")
context_tags = Array[String](["farewell"])

# 在事件资源中引用
[resource]
emotion_configs = Array[ExtResource("7_emotion_cfg")]([
    SubResource("Resource_emotion_cfg_despair"),
    # ... 其他意象配置
])
```

### Step 4：配置事件选项的情绪操作

在事件选项的 `ChoiceResult` 中添加 `EmotionOperator`，让玩家选择后改变情绪：

```gdscript
[sub_resource type="Resource" id="Resource_emotion_sorrow"]
script = ExtResource("6_emotion_op")
_emotion = 0  # ENUMS.EMOTION.SORROW
str_emotion = "sorrow"
value = 15

[sub_resource type="Resource" id="Resource_choice_result"]
script = ExtResource("3_fttgn")
operators = Array[ExtResource("1_ykdg5")]([
    SubResource("Resource_fcovv"),           # 原有的 stat_operator
    SubResource("Resource_emotion_sorrow")    # 新增的情绪操作符
])
```

### Step 5：配置 Tag 匹配

使用 [Tag 幂等性创建原则](tag_idempotent_creation.md) 为事件配置 `Trigger_Tags`，确保事件能在合适的时机被触发。

### Step 6：验证

1. 事件是否能被正确触发（通过 Tag 匹配）
2. 情绪操作符是否能正确改变玩家情绪
3. 情绪门槛校验是否生效
4. 意象是否按预期添加到 `basic_imaginaries`
5. 意象等级是否按阈值更新

---

## 等级晋升机制

每个意象有累积计数，达到阈值自动升级：

| 等级 | 条件 | 效果 |
|------|------|------|
| **Level 1** | `basic_imaginaries.size() < l2_threshold` | 默认 |
| **Level 2** | `l2_threshold <= basic_imaginaries.size() <= l3_threshold` | 可用作诗词创作 |
| **Level 3** | `basic_imaginaries.size() > l3_threshold` | 高质量意象，解锁传奇诗词 |

### 天赋折扣

| talent 值 | 门槛折扣 | 说明 |
|-----------|---------|------|
| `talent > 50` | 5 折 | 天赋异禀，更易获得意象 |
| `talent > 30` | 7.5 折 | 有点天赋，略占优势 |
| `talent <= 30` | 无折扣 | 普通人 |

---

## 创建清单 (Checklist)

创建意象获取事件时，逐项确认：

- [ ] `ImaginaryTag` 蓝图资源已存在
- [ ] `EmotionConfigs.blueprint` 指向正确的 `ImaginaryTag` 资源
- [ ] 情绪门槛数值合理（不太高也不太低）
- [ ] `context_tags` 包含了叙事上下文（如地点、人物）
- [ ] 事件选项的 `ChoiceResult` 包含 `EmotionOperator`
- [ ] 事件已配置正确的 `Trigger_Tags`
- [ ] 意象消耗逻辑已在 `PoemCrafter` 中处理（阈值提升 + 等级重置）

---

## 常见错误

| 错误 | 症状 | 修复 |
|------|------|------|
| `emotion_configs` 为空 | 意象管理器输出警告，意象不生效 | 添加至少一个 `EmotionConfigs` |
| `blueprint` 引用 null | 运行时错误 | 确认 `.tres` 资源路径正确 |
| 情绪门槛过高 | 玩家永远达不到条件 | 检查 `requirements` 数值是否合理 |
| 缺少 `EmotionOperator` | 玩家情绪不变，意象获取条件永远不满足 | 在选项结果中添加情绪操作符 |
| Tag 匹配不到事件 | 事件永远不会被拉起 | 检查 `Trigger_Tags` 是否在词典范围内 |

---

## 相关文档

| 文档 | 内容 |
|------|------|
| [情绪-意象系统设计](../imaginary/emotion_imaginary_system.md) | 情绪与意象连接机制 |
| [Imaginary 系统技术报告](../imaginary/imaginary_system_report.md) | 完整系统架构 |
| [环境情绪注入设计](./design_get_emotion_in_event.md) | on_enter 情绪注入模式 |
| [情绪获取系统](./emotion_get_system.md) | 情绪三大获取通道 |
| [Tag 幂等性创建原则](./tag_idempotent_creation.md) | 事件 Tag 规范 |
| [Imaginary Manager](../../core/imaginary_manager.gd) | 意象管理器源码 |
| [Imagenary Evaluator](../../core/imagenary_evaluator.gd) | 条件校验器源码 |
