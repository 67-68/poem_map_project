# 叙事信息传递原则 — Narrative Information Transfer

**状态**: ✅ 已落地（2026.06.10）

---

## 意图摘要（<200字）

定义事件叙事中「信息传递」的结构化约束体系。核心主张：**动作与结果解耦**——玩家执行一个动作时，叙事文本不应提前揭示系统层面的成败状态。解决 AI 生成事件时惯于「把底牌亮在桌面上」的问题，实现类似 TRPG 暗骰/盲检定的沉浸式体验。通过 [`NarrativeConstraint`](/tools/config.py:51) 数据模型固化三层约束（索取层→执行层→揭晓层），在 AI 工作流的 prompt 中以独立「📜 写作契约」区块呈现，比纯文本指令更难被忽略。

---

## 核心理念

### 问题陈述

AI 生成的事件 consistently 犯一个错误：在 **description（事件描述）** 或 **option.text（选项文本）** 中提前揭示玩家是否有某种资源。例如：

```text
❌ "门卫收了你的钱，又看向了你准备好的干谒诗。"
   → 提前暴露「玩家有诗」的信息，failed_hint 分支永无出场机会

❌ "你拿出仅有的20文钱递给门卫。"
   → 直接揭示玩家剩余的货币数量，破坏沉浸感
```

这在叙事上等同于「电影开头旁白告诉你凶手是谁」——信息不对称被打破，悬念消失。

### 核心原则

| 原则 | 定义 | 类比 |
|------|------|------|
| **信息不对称 (Information Asymmetry)** | 玩家和 NPC 之间存在信息差，叙事文本不替任何一方做全知披露 | 你递上一个信封，你知道里面装了什么，对方不知道；或对方知道里面该有什么，你不知道自己是否满足 |
| **动作与结果解耦 (Action-Result Decoupling)** | 选项文本只描述**物理动作**，不揭示**系统判定结果** | TRPG 中你喊「我推开那扇门」，GM 暗骰力量检定，然后描述门纹丝不动或轰然倒下——你喊的时候不知道结果 |
| **薛定谔的检定 (Schrödinger's Check)** | 在揭晓之前，检查结果同时处于「成功」和「失败」的叠加态 | 系统已有结果（玩家库存里到底有没有诗），但叙事文本假装不知道，直到 NPC 打开包裹才「坍缩」为一种 |

### 三层叙事模型 (The Three-Layer Model)

```
┌──────────────────────────────────────────────────┐
│                 1. 索取层 (Demand)                │
│    NPC 在事件 description 中提出要求 / 设定门槛     │
│    例: "门卫伸手拦住你：'令帖可带？诗稿可有？'"   │
│    约束: 只说明要求，不暗示玩家是否满足              │
├──────────────────────────────────────────────────┤
│                 2. 执行层 (Action)                 │
│    玩家在 option.text 中的动作描写                  │
│    例: "你从怀中取出一物，递了过去"                │
│    约束: 纯物理动作，不揭示包裹内容 / 库存状态       │
├──────────────────────────────────────────────────┤
│                 3. 揭晓层 (Resolution)             │
│    failed_hint / success_text 揭示结果             │
│    例: "门卫接过，翻看两眼，冷笑一声：'这写的什么玩意？'"│
│    约束: 此时才能揭示系统判定结果                    │
└──────────────────────────────────────────────────┘
```

---

## 盲盒交割法 (Blind-Box Transaction)

这是三层叙事模型的具体化命名，适合用于 AI prompt 以建立直觉：

> **盲盒交割法** = NPC 索取（提出条件）→ 玩家动作（盲盒交付）→ 系统揭晓（打开盲盒）

### 写作约束

| 层级 | 在什么字段约束 | 禁止 | 允许 |
|------|---------------|------|------|
| 索取层 | `description` (event 核心描述) | 暗示玩家是否满足条件；提示解法 | NPC 明确索要，给玩家施压 |
| 执行层 | `option.text` | 出现"你拿出xx钱""你展示诗词"等揭示库存动作 | "递上一物""呈上名帖""献上包裹" |
| 揭晓层 | `failed_hint` / `success_text` | 平淡的"你没有诗"等无情绪陈述 | NPC 带有情感色彩的直接反应（直接引语） |

### 示例对比

```text
❌ 传统写法（信息不对等被打破）:
  description: "门卫收了你的干谒诗，瞄了一眼，让你进去。"
  → 完全跳过"玩家是否有诗"的悬念

✅ 盲盒交割法:
  description: "门卫伸手拦住你：'令帖可带？干谒之诗可备好？'"
  option.text: "从怀中取出一卷文稿递上"
  failed_hint: "门卫接过去展开，皱眉咧嘴：'这写的什么狗屁不通的东西，也敢拿来糊弄老爷？滚！'"
```

---

## 结构化实现：NarrativeConstraint

### 数据模型

定义在 [`tools/config.py`](/tools/config.py:51) 的 `NarrativeConstraint` 模型：

```python
class NarrativeConstraint(BaseModel):
    """叙事约束：硬性写作规则"""
    type: str = ""              # 约束类型标签（metadata，用于管线 debug / 日志）
    demand_context: str = ""    # 📣 索取层: 约束 event description 中 NPC 如何提出需求
    action_style: str = ""      # 🎭 执行层: 约束 option.text 的写法
    resolution_style: str = ""  # 💀 揭晓层: 约束 failed_hint 的写法
```

### 关键特性

1. **所有字段独立可选**：可单独使用 `action_style`（仅约束选项动作），也可只用 `resolution_style`（仅约束失败反应），任意组合
2. **可扩展**：未来可新增字段（如 `environment_cue` 约束场景描写），不影响已有配置
3. **非 null 即生效**：只要 `narrative_constraint` 不为 null，管线就会渲染独立的「📜 写作契约」区块

### 在 Pipeline 中的渲染

定义在 [`tools/generate_orthogonal_events.py`](/tools/generate_orthogonal_events.py:565) 的 `build_user_prompt()`：

当选项的 `narrative_constraint` 不为 null 且有非空字段时，在 AI 的 user prompt 末尾追加：

```
## 📜 写作契约 (Narrative Constraint)

### 选项 "option_accept" [blind_box_transaction]
- 📣 索取层 (NPC Demand): NPC 必须在事件 description 中明确索要诗词...
- 🎭 执行层 (Player Action): 选项文本只写中性物理动作...
- 💀 揭晓层 (System Resolution): failed_hint 必须是 NPC 验货后的嘲讽反应...
```

### 在 Config JSON 中的写法

参照 [`tools/event_base_config_bai_ye_real_appearance.json`](/tools/event_base_config_bai_ye_real_appearance.json:22)：

```json
{
  "id": "option_accept",
  "prompt": "用20字以内描述玩家回应的动作（递上某物/呈上名帖/献上包裹）",
  "result": "use_template(urn=event_option:poem_type_choose_zhuoliu) | prop_add(name=progress; val=3)",
  "requirement": "poem_has(type=GAN_YE; min_level=1; failed_hint=\"{failed_hint}\")",
  "narrative_constraint": {
    "type": "blind_box_transaction",
    "demand_context": "NPC 必须在事件 description 中明确索要诗词，让玩家感受到'没钱尚可通融，无诗休想进门'的压迫感",
    "action_style": "选项文本只写中性物理动作（递上/呈上/献上/奉上），绝对禁止在文本中揭示玩家是否携带了诗词。使用模糊且中性的动作描写",
    "resolution_style": "failed_hint 必须是 NPC 验货后发现没有诗词时的嘲讽反应。使用直接引语，控制在20字以内"
  },
  "fixed": false
}
```

---

## 配套设施

### prompt_feature: `ambiguous_narrative`

在 [`tools/text_features_registry.json`](/tools/text_features_registry.json:27) 注册，用于在 `prompt_features` 列表中引用：

```json
{
  "id": "ambiguous_narrative",
  "text": "【薛定谔的检定】玩家与 NPC 互动时，叙事文本不揭示玩家是否拥有特定物品/诗词。玩家动作描写必须保持中性模糊（递上某物/呈上某个东西），由 NPC 的反应（failed_hint）来揭示结果。禁止在 description 或 option.text 中使用如\"你拿出诗稿\"\"你递上早已准备好的诗词\"等暴露库存状态的描写。"
}
```

### 插件: `ganye_failed_hint`

在 [`tools/plugins/ganye_failed_hint_plugin.py`](/tools/plugins/ganye_failed_hint_plugin.py) 实现，专门为千谒事件生成 NPC 的失败反应：

- `get_prompt_fragment()`: 注入 prompt，要求 AI 生成带直接引语的 NPC 嘲讽反应
- `get_extra_output_fields()`: 声明 `failed_hint` 字段
- `enrich_context()`: 运行时将 `failed_hint` 注入 CSV context

---

## 事件配置导引

### 何时使用 NarrativeConstraint

| 场景 | 需要 NarrativeConstraint | 理由 |
|------|------------------------|------|
| NPC 明确要某物 + 玩家可能没有 | ✅ 必须 | 三层模型天然适配「检查库存」场景 |
| 纯对话/信息交换 | ❌ 不需要 | 没有"检查-通过/失败"机制 |
| 资源交易（只看玩家有没有足够资源） | ⚠️ 可选 | 如果纯数值交易（扣钱），不需要；如果想营造「搜遍全身才凑够」的叙事感，可用 action_style |
| 诡计/欺骗（玩家假装有某物） | ✅ 强烈推荐 | 三层模型完美适配 bluff 机制 |

### 部署步骤

1. 在 `option_features` 中为目标选项添加 `narrative_constraint` JSON 块
2. 在 `prompt_features` 中按需添加 `ambiguous_narrative`
3. 如果需要自定义 failed_hint 行为，注册或编写插件
4. 在 [`tools/text_features_registry.json`](/tools/text_features_registry.json) 中注册新的 prompt_feature（如需全局复用）
5. 运行管线生成事件，检查 CSV 输出是否符合三层模型
