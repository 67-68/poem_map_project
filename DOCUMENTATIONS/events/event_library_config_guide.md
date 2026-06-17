# 正交事件库配置指南

> 本文档说明如何使用 [`tools/generate_orthogonal_events.py`](../../tools/generate_orthogonal_events.py) 生成管线创建新的事件库（Event Library）所需的 JSON 配置。

---

## 目录

1. [管线架构概览](#1-管线架构概览)
2. [配置文件结构](#2-配置文件结构)
3. [维度系统 (Dimensions)](#3-维度系统-dimensions)
4. [标签系统 (Tags)](#4-标签系统-tags)
5. [插件系统 (Plugins)](#5-插件系统-plugins)
6. [黑名单 (Blacklist)](#6-黑名单-blacklist)
7. [Store To 路由](#7-store-to-路由)
8. [沙盒模式 (Sandbox)](#8-沙盒模式-sandbox)
9. [选项系统 (Option Features)](#9-选项系统-option-features)
10. [跨维度引用 (linked_value_ids)](#10-跨维度引用-linked_value_ids)
11. [虚拟维度追加 (virtual_dimension_ids)](#11-虚拟维度追加-virtual_dimension_ids)
12. [通用全局字段](#12-通用全局字段)
13. [配置场景速查表](#13-配置场景速查表)

---

## 1. 管线架构概览

```
┌──────────────────────────────────────────────────────────────┐
│                     JSON Config (Source of Truth)             │
│  id, name, era, dimensions, plugins, universal_*, ...        │
└──────────┬───────────────────────────────────────────────────┘
           │ --config <json_path>
           ▼
┌──────────────────────────────────────────────────────────────┐
│                tools/event_generator/main.py                  │
│                                                              │
│  Phase 0: 加载配置 → 初始化插件 (init) + 沙盒 + 黑名单       │
│  Phase 1: 展开维度组合 (expand_combinations)                  │
│  Phase 2: 对每组合 → 构建 Prompt → 调 LLM → 解析响应        │
│  Phase 3: 插件富化 (enrich_context) → 写 CSV                 │
└──────────┬───────────────────────────────────────────────────┘
           ▼
┌──────────────────────────────────────────────────────────────┐
│              CSV 文件 (data/generated_events/)                │
│  random_event 行 + >option 子行                               │
│  context 列含: trigger_tags|weight|era|store_to|plugin_extras │
└──────────┬───────────────────────────────────────────────────┘
           ▼ (通过 csv_cloud_loader.gd 同步)
┌──────────────────────────────────────────────────────────────┐
│              Godot Runtime (RandomEvent.tres)                 │
│  STORE_TO_PATH_MAP 根据 store_to=<key> 路由到 era/action 目录 │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. 配置文件结构

一个 JSON 配置文件的顶层结构如下：

```jsonc
{
  // ── 基础标识 ──
  "id": "my_event_library",              // 唯一 ID，用于 debug 日志
  "name": "我的事件库",                   // 人类可读名称
  "era": "745_ambition",                 // 所属时代，注入 CSV context 列的 |era=<value>

  // ── AI Prompt 组件 ──
  "background_context": "天宝年间...",    // 时代/场景背景描述
  "ai_persona": "你是一位精通...",       // AI 角色设定

  // ── 特征库引用（可选，从中央 registry 按 key 加载）──
  "prompt_features": ["stateless_narrative", "tone_cautious"],
  "fact_features": ["bai_ye_venue"],
  "option_features": ["opt_accept", "opt_refuse"],

  // ── 内联特征定义（与 registry 引用二选一，也可混合使用）──
  // "prompt_features": [
  //   {"id": "my_style", "text": "保持克制..."}
  // ],

  // ── 正交维度 ──
  "dimensions": [ /* 见 §3 */ ],

  // ── 插件系统 ──
  "plugins": ["failed_hint", "imagery_acquisition"],

  // ── 通用全局配置 ──
  "universal_tags": ["scene_imagery"],
  "universal_requirement": "prop_gt(name=ambition,val=0)",
  "universal_result": "prop_add(name=career_progress; val=1)",
  "universal_option_requirement": "poem_has(type=GAN_YE; min_level=1; failed_hint=\"{failed_hint}\")",

  // ── 生成参数 ──
  "word_count_min": 80,
  "word_count_max": 200,
  "option_word_count_max": 30,
  "max_retries": 3,
  "api_model": "deepseek-chat",
  "output_dir": "data/generated_events/",

  // ── 可选高级功能 ──
  "apply_dimension_imagery": false,
  "emotion_pairs": { /* 见 §5.3 */ },
  "final_directive": "禁止使用心理动词...",
  "sandbox_feature": {"id": "", "text": "附加创作指引..."}
}
```

### 配置文件的存放位置

- 放在 `tools/` 目录下
- 命名约定：`event_base_config_<library_name>.json`
- 沙盒文件自动派生：`event_base_config_<library_name>_sandbox.json`

---

## 3. 维度系统 (Dimensions)

维度是正交事件生成的核心：「维度 × 维度」的正交组合决定了事件的数量和差异性。

### 3.1 基本结构

```jsonc
{
  "dimensions": [
    {
      "id": "power_level",              // 维度唯一 ID
      "name": "权力阻击位",              // 人类可读名称
      "description": "拜谒时的门槛等级", // 注入 Prompt 的背景说明
      "values": [
        {
          "id": "L0",
          "name": "门子/家奴",
          "description": "最底层的门卫...",
          "scale": 1.0,                 // 此值对 operator_dsl 的缩放系数
          "operator_dsl": "prop_sub(name=money; val=10)",  // 选中此值时执行的 DSL
          "tags": [],                   // 见 §4
          "stored_to": "",              // 见 §7
          "linked_value_ids": [],       // 见 §10
          "narrative_constraint": {     // 结构化叙事约束（可选）
            "demand_context": "NPC 如何提出需求",
            "action_style": "玩家动作描写",
            "resolution_style": "NPC 揭晓反应",
            "negative_examples": [
              {"field": "action_style", "bad": "坏例子", "reason": "为什么坏"}
            ]
          }
        }
      ],
      "blacklist_config": null          // 见 §6
    }
  ]
}
```

### 3.2 维度数量与组合爆炸

- **2 个维度**：最常见。如 `power_level × extraction_type`（3×3=9 种组合）
- **3 个维度**：如 `humiliation_type × gateway × option_style`（6×3×3=54 种组合）
- **≥4 个维度**：组合爆炸风险高，谨慎使用

### 3.3 scale 与 operator_dsl 的协作

组合中所有维度值的 `scale` **相乘** = `combined_scale`，然后对每个 operator 的数值参数执行缩放：

```
operator_dsl = "prop_sub(name=money; val=10)"
combined_scale = 1.0 × 1.5 × 2.0 = 3.0
→ 实际 DSL = "prop_sub(name=money; val=30)"
```

### 3.4 维度设计原则

| 原则 | 说明 |
|------|------|
| **正交性** | 维度之间应尽量独立，避免语义重叠 |
| **互斥性** | 同一维度的不同值应在同一个轴上变化 |
| **覆盖性** | 维度值应覆盖该轴上的主要变体，避免明显遗漏 |
| **数量控制** | 每个维度的值数量建议 2~6 个，过多会影响质量 |

---

## 4. 标签系统 (Tags)

每个 [`PipelineDimensionValue`](../../tools/config.py:268) 可以携带 `tags` 列表。标签有不同的命名空间前缀，管线根据前缀做不同处理：

### 4.1 标签类型一览

| 标签前缀 | 示例 | 用途 | 消费者 |
|---------|------|------|--------|
| `action:` | `action:fangshi` | 触发标签，写入 CSV `context` 列的 `trigger_tags` | Godot EventManager |
| `emotion_pair:` | `emotion_pair:pair_rebellion` | 标记多态事件的情绪对 ID | `emotion_pair_imagery` 插件 |
| 无前缀意象 tag | `ENV_NATURE_NIGHTMOON` | 意象池 tag，供 `imagery_acquisition` 插件提取 | `imagery_acquisition` 插件 |
| 其他自定义 | `scene_type:indoor` | 自定义分类标签 | 自定义逻辑 |

### 4.2 tag 在 context 列中的最终呈现

```
# action: 前缀的 tag 会聚合为 trigger_tags
trigger_tags=[fangshi/jiaoyou]|weight=10|era=745_ambition

# 其他 tag 不会出现在 context 列中，仅在插件内部使用
```

### 4.3 标签设计原则

- **`action:` 标签用于决定「该事件在什么行动下被触发」**。如果维度值的 tag 中没有任何 `action:` 前缀的标签，管线会自动回退使用 `universal_tags`（默认 `["bai_ye"]`）
- **意象标签用于 `imagery_acquisition` 插件**，不写前缀，纯意象 ID
- **`emotion_pair:` 标签专供 `emotion_pair_imagery` 插件**，格式固定

---

## 5. 插件系统 (Plugins)

插件通过 [`EventPromptPlugin`](../../tools/plugin_base.py) 基类实现，在 4 个 Hook 点注入自定义行为。插件 ID 需在顶层 `plugins` 列表中启用。

### 5.1 插件注册方式

所有插件放在 [`tools/plugins/`](../../tools/plugins/) 目录下，`__init__.py` 会自动发现并 import 所有 `.py` 文件，触发 `register_plugin()` 调用。

### 5.2 现有插件

| 插件 ID | 类 | 文件 | 功能 | 适用场景 |
|---------|---|------|------|---------|
| `failed_hint` | [`FailedHintPlugin`](../../tools/plugins/failed_hint_plugin.py) | [`plugins/failed_hint_plugin.py`](../../tools/plugins/failed_hint_plugin.py) | 让 AI 输出 `failed_hint` 字段，注入到选项 requirement 模板 | 有验证失败反馈的事件库（如验诗） |
| `imagery_acquisition` | [`ImageryAcquisitionPlugin`](../../tools/plugins/imagery_acquisition_plugin.py) | [`plugins/imagery_acquisition_plugin.py`](../../tools/plugins/imagery_acquisition_plugin.py) | 从维度值 `tags` 提取意象，生成 `imagery_add` DSL 追加到选项结果 | 场景-意象事件库 |
| `emotion_pair_imagery` | [`EmotionPairImageryPlugin`](../../tools/plugins/emotion_pair_imagery_plugin.py) | [`plugins/emotion_pair_imagery_plugin.py`](../../tools/plugins/emotion_pair_imagery_plugin.py) | 多态事件 per-option 意象打分 | 多态羞辱事件库 |

#### 5.2.1 `failed_hint` 插件

**作用**：让 AI 在响应中额外输出 `failed_hint` 字段（NPC 的拒绝/嘲讽反应文本），然后注入到选项的 `requirement` 列中，供 Godot 在验证失败时显示。

**用法**：

```jsonc
{
  "plugins": ["failed_hint"],
  "option_features": [
    {
      "id": "option_accept",
      "plugins": {
        "failed_hint": {
          "style": "mock_direct_speech",   // 可选: mock_direct_speech | direct_speech | objective_fact | inner_monologue
          "max_chars": 20,                 // 字数上限
          "context": "NPC 验货后发现没有诗词时的嘲讽反应"
        }
      }
    }
  ],
  // 然后在 universal_option_requirement 中使用 {failed_hint} 模板变量
  "universal_option_requirement": "poem_has(type=GAN_YE; min_level=1; failed_hint=\"{failed_hint}\")"
}
```

#### 5.2.2 `imagery_acquisition` 插件

**作用**：扫描维度值的 `tags` 字段，找到第一个非 `action:` 前缀的 tag，生成 `imagery_add(name=<tag>)` DSL 追加到选项结果。

**适用于**：场景维度值携带意象 tag 的事件库，每条事件获得场景对应的意象。

**用法**：

```jsonc
{
  "plugins": ["imagery_acquisition"],
  "dimensions": [
    {
      "id": "scene",
      "values": [
        {
          "id": "night_market",
          "tags": ["action:fangshi", "ENV_NATURE_NIGHTMOON"]  // ENV_NATURE_NIGHTMOON 会被提取为 imagery_add
        }
      ]
    }
  ]
}
```

#### 5.2.3 `emotion_pair_imagery` 插件（复杂场景）

**作用**：每个 `humiliation_type` 维度值绑定一个 `emotion_pair_id`（通过 tags），每个选项绑定 `pair_role`（`branch_A`/`branch_B`/`fallback`），管线据此从意象池中按情绪亲缘度打分，挑选最合适的意象。

**适用于**：多态羞辱事件——不同羞辱类型 × 不同应对策略 × 不同情绪 → 不同意象。

**用法**：

```jsonc
{
  "plugins": ["emotion_pair_imagery"],
  "emotion_pairs": {
    "pair_rebellion": {
      "branch_A":  {"emotion": "ARROGANCE",  "desc": "狂傲"},
      "branch_B":  {"emotion": "TRANQUILITY", "desc": "静谧"},
      "fallback":  {"emotion": "FATIGUE",    "desc": "疲惫"}
    }
  },
  "dimensions": [
    {
      "id": "humiliation_type",
      "values": [
        {
          "id": "rebellion",
          "tags": ["action:fangshi", "emotion_pair:pair_rebellion"]  // ← 标记情绪对 ID
        }
      ]
    },
    {
      "id": "gateway",           // 场景维度，提供意象池
      "values": [
        {
          "id": "court",
          "tags": ["action:fangshi", "ENV_POLITICS_COURT_SHIJUN"]
        }
      ]
    }
  ],
  "option_features": [
    {
      "id": "opt_kuangke",
      "pair_role": "branch_A",   // ← 绑定 emotion_pairs.pair_rebellion.branch_A → emotion=ARROGANCE
      "result": "prop_add(name=fatigue; val=10)"
    }
  ]
}
```

### 5.3 插件 Hook 生命周期

```
Phase 0: init(cfg)           — 管线启动时调用一次，插件在此扫描配置构建内部状态
Phase 1: get_prompt_fragment — 每组合调用，注入 User Prompt
Phase 2: get_extra_output_fields — 每组合调用，声明额外解析字段
Phase 3: enrich_context      — 每组合调用，富化 CSV context 列
Phase 4: get_option_result_extras — 每选项调用，追加选项结果 DSL
```

### 5.4 创建新插件

1. 在 [`tools/plugins/`](../../tools/plugins/) 下创建 `.py` 文件
2. 继承 [`EventPromptPlugin`](../../tools/plugin_base.py)
3. 实现需要的 Hook 方法
4. 文件末尾调用 `register_plugin(YourPlugin())`
5. 在 JSON 配置的 `plugins` 列表中加入插件 ID

---

## 6. 黑名单 (Blacklist)

黑名单机制防止 AI 为同一维度值重复生成语义相似的内容。

### 6.1 适用场景

- **维度值数量少但期望生成多条事件**：如某个 `power_level=L0` 要生成多条不同的「门子索贿」事件
- **内容差异敏感**：需要保证同一维度值下各事件的剧情隔离

### 6.2 配置方式

```jsonc
{
  "dimensions": [
    {
      "id": "humiliation_type",
      "values": [ /* ... */ ],
      "blacklist_config": {
        "tracked_field": "description",        // 追踪字段（默认 description）
        "tracked_field_description": "事件描述", // 中文语义描述
        "max_items": 20                         // 滑动窗口大小
      }
    }
  ]
}
```

### 6.3 约束

- **一个配置中最多只有一个维度**可以挂载 `blacklist_config`
- 如果超过一个，管线启动时会抛出 [`ValueError`](../../tools/event_generator/state_managers.py:56)

### 6.4 运行时行为

1. **Phase 1**：LLM 生成后，黑名单从 `parsed` 中提取 `summary.description`（或其他 `tracked_field`）
2. **Phase 2**：下次遇到同一维度值时，黑名单将历史摘要注入 Prompt，要求 AI 生成差异化内容
3. **Phase 3**：超过 `max_items` 时自动丢弃最老条目（滑动窗口）

---

## 7. Store To 路由

`stored_to` 控制生成的 `.tres` 文件在 Godot 中的存放路径。它是 CSV `context` 列中的一个 key=value 对，Godot 端的 [`csv_cloud_loader.gd`](../../core/csv_cloud_loader.gd) 根据 [`STORE_TO_PATH_MAP`](../../core/csv_cloud_loader.gd:122) 做路径路由。

### 7.1 适用场景

`stored_to` 的**核心语义**是：「这个事件属于哪个时代的哪个行动」。

- ✅ **横跨多个行动的事件库**（如场景-意象库中场景覆盖 fengzhao/denggao/duzhuo 等多个行动）：需要对不同维度值设置不同的 `stored_to`，让事件路由到对应的行动目录
- ❌ **单一行动的事件库**（如只属于 fangshi 的事件）：可以不设 `stored_to`，默认使用 `output_dir` 路径

### 7.2 两种配置模式

#### 模式 A：按维度值各自路由（横跨多行动）

每个维度值的 `stored_to` 独立指定。管线取**第一个非空值**作为路由。

```jsonc
// 场景-意象库：不同场景值路由到不同行动
{
  "dimensions": [
    {
      "id": "scene",
      "values": [
        {"id": "scene_01", "stored_to": "745_ambition.fengzhao", "tags": ["action:fengzhao"]},
        {"id": "scene_02", "stored_to": "745_ambition.fengzhao", "tags": ["action:fengzhao"]},
        {"id": "scene_03", "stored_to": "745_ambition.denggao", "tags": ["action:denggao"]},
        {"id": "scene_04", "stored_to": "745_ambition.denggao", "tags": ["action:denggao"]},
        {"id": "scene_05", "stored_to": "745_ambition.duzhuo",  "tags": ["action:duzhuo"]}
      ]
    }
  ]
}
```

#### 模式 B：维度值共享同一路由（单一行动）

所有或大部分维度值指向同一个 `stored_to`。

```jsonc
// 拜谒事件：无论权力层级如何，最终都路由到 baiye 目录
{
  "dimensions": [
    {
      "id": "power_level",
      "values": [
        {"id": "L0", "stored_to": "747_kuangda.baiye"},
        {"id": "L1", "stored_to": "747_kuangda.baiye"},
        {"id": "L2", "stored_to": "747_kuangda.baiye"}
      ]
    },
    {
      "id": "extraction_type",
      "values": [
        {"id": "TypeA", "stored_to": ""},   // 空字符串 = 不参与路由
        {"id": "TypeB", "stored_to": ""},
        {"id": "TypeC", "stored_to": ""}
      ]
    }
  ]
}
```

### 7.3 STORE_TO_PATH_MAP 映射表

Godot 端 [`csv_cloud_loader.gd`](../../core/csv_cloud_loader.gd:122) 维护了 [`STORE_TO_PATH_MAP`](../../core/csv_cloud_loader.gd:122)：

```gdscript
const STORE_TO_PATH_MAP: Dictionary = {
    "745_ambition.fengzhao": "res://data/4_eras/745_ambition/fengzhao",
    "745_ambition.denggao":  "res://data/4_eras/745_ambition/denggao",
    // ...
}
```

**如果在映射表中找不到 key**：直接使用 raw key 作为 `res://` 路径。例如 `store_to=data/mydir` → `res://data/mydir`。

### 7.4 添加新的 store_to 路由

当新建事件库需要新的路由目标时，**需要同时修改两处**：

1. **Godot 端**：在 [`core/csv_cloud_loader.gd`](../../core/csv_cloud_loader.gd:122) 的 `STORE_TO_PATH_MAP` 中添加映射条目
2. **数据目录**：在 `data/4_eras/` 下创建对应的目录结构

---

## 8. 沙盒模式 (Sandbox)

沙盒模式是生成管线的预生成阶段：在正式生成事件之前，先调一次 LLM 为每个维度值组合生成创作关键词，然后在正式 Prompt 中注入这些关键词作为约束。

### 8.1 何时需要

- **需要 AI 生成更精准、更有时代/地域特色的事件文本**：沙盒关键词可以为 AI 提供具体的人物名、地点、物品等实体参考
- **事件库内容差异大**：沙盒关键词帮助 AI 区分不同维度值的叙事方向

### 8.2 启用方式

沙盒模式**自动启用**：管线运行时检测是否存在 `<config_path>_sandbox.json` 文件。

- 如果文件存在且不为空，管线加载它作为缓存
- 如果文件不存在或为空，管线自动进入沙盒生成模式，预生成关键词后保存到该文件

### 8.3 配置沙盒创作指引

通过顶层字段 `sandbox_feature` 提供附加创作指引：

```jsonc
{
  "sandbox_feature": {
    "id": "",
    "text": "场景设定在长安西市，请参考唐代商业文化、胡商、市集交易等历史背景来生成关键词"
  }
}
```

---

## 9. 选项系统 (Option Features)

每个事件可以有 1~3 个选项，由 `option_features` 定义。

### 9.1 基本选项

```jsonc
{
  "option_features": [
    {
      "id": "option_accept",              // 选项唯一 ID
      "text": "接受请求",                  // 固定文本（fixed=true 时使用）
      "prompt": "生成接受请求的选项文本",   // AI 生成指引
      "result": "prop_add(name=career_progress; val=1)",  // 选项结果 DSL
      "requirement": "poem_has(type=GAN_YE; min_level=1)", // 选项需求 DSL
      "fixed": false                       // true=固定文本，跳过 AI 生成
    }
  ]
}
```

### 9.2 固定选项 (Fixed)

当 `fixed: true` 时，选项文本不经过 AI 生成，直接使用 `text` 字段。适用于「拂袖而去」类选项。

### 9.3 维度影响白名单 (accept_influence)

控制选项是否接受维度值的 `scale` 和 `operator_dsl` 影响：

```jsonc
{
  "option_features": [
    {
      "id": "opt_leave",
      "text": "拂袖而去",
      "fixed": true,
      "accept_influence": [],       // [] = 拒绝所有维度影响
      "result": "prop_add(name=reputation; val=1)"
    }
  ]
}
```

- `None`：接受全部维度影响（默认，向后兼容）
- `[]`：拒绝所有维度影响（如「拂袖而去」不受资源掠夺影响）
- `["dim_A", "dim_B"]`：只接受指定维度的 `scale` + `operator_dsl`

### 9.4 选项级插件配置

插件可以在 per-option 级别挂载配置（如 `failed_hint` 插件的样式配置）：

```jsonc
{
  "option_features": [
    {
      "id": "option_accept",
      "plugins": {
        "failed_hint": {
          "style": "mock_direct_speech",
          "max_chars": 20
        }
      }
    }
  ]
}
```

### 9.5 情绪对角色 (pair_role)

用于 `emotion_pair_imagery` 插件，详见 [§5.2.3](#523-emotion_pair_imagery-插件复杂场景)。

---

## 10. 跨维度引用 (linked_value_ids)

当维度 A 的某个值被选中时，强制维度 B 固定为某个值。用于打破正交性、实现条件逻辑。

### 10.1 使用场景

- **互斥维度值**：某个 `evil_motive=M0` 必然对应 `extraction_type=TypeA`
- **强制路由**：某个羞辱类型固定为某种情绪对

### 10.2 配置方式

```jsonc
{
  "dimensions": [
    {
      "id": "evil_motive",
      "values": [
        {
          "id": "M0",
          "name": "媚上邀功",
          "linked_value_ids": ["TypeA"],  // 选中 M0 时，extraction_type 强制为 TypeA
          "operator_dsl": ""
        }
      ]
    },
    {
      "id": "extraction_type",
      "values": [
        {"id": "TypeA", "name": "金钱掠夺"},
        {"id": "TypeB", "name": "健康损耗"},
        {"id": "TypeC", "name": "精神PUA"}
      ]
    }
  ]
}
```

### 10.3 约束

- 所有 `linked_value_ids` 必须指向**同一目标维度**
- 不能指向自身所属的维度
- 未指定 `linked_value_ids` 的值保持正常正交组合

---

## 11. 虚拟维度追加 (virtual_dimension_ids)

`virtual_dimension_ids` 是 `linked_value_ids` 的互补机制：当某个维度值被选中时，以**虚拟追加**的方式引入额外维度参与笛卡尔积，而非替换已有维度。

### 11.1 使用场景

- **身份/角色注入**：某个场景值触发后在事件组合中追加 NPC/身份维度，让每条事件携带不同的交互角色
- **叙事分支细化**：某个羞辱类型被选中后，追加情绪或应对策略为虚拟维度

### 11.2 语法

```jsonc
{
  "dimensions": [
    {
      "id": "scene",
      "values": [
        {
          "id": "tavern_night",
          "name": "酒肆夜饮",
          "linked_value_ids": ["emotion_arrogance", "emotion_tranquility"],
          "virtual_dimension_ids": [["npc_libai"], ["identity_qingliu_owner", "identity_shangren_guest"]]
        }
      ]
    }
  ]
}
```

### 11.3 语义对照表

| 语法 | 语义 |
|------|------|
| `"virtual_dimension_ids": []` | 不追加任何虚拟维度 |
| `"virtual_dimension_ids": [["id_a"]]` | 追加 1 个虚拟维度，含 1 个可选值 `id_a` |
| `"virtual_dimension_ids": [["id_a", "id_b"]]` | 追加 1 个虚拟维度，含 2 个可选值 `id_a` 和 `id_b` |
| `"virtual_dimension_ids": [["id_a"], ["id_b"]]` | 追加 2 个独立虚拟维度，各含 1 个可选值 |

**核心规则**：每个 inner list（如 `["npc_libai"]`）作为一个独立的虚拟维度，与所有原始维度做笛卡尔积，追加到组合 tuple 末尾。

### 11.4 与 linked_value_ids 的关系

两者可以**同时存在于同一个维度值**上，互不冲突：

- [`linked_value_ids`](#10-跨维度引用-linked_value_ids)：**替换语义**——当值被选中时，引用维度值替换目标维度槽位（打破正交性）。
- [`virtual_dimension_ids`](#11-虚拟维度追加-virtual_dimension_ids)：**追加语义**——当值被选中时，引用的值作为新维度追加到组合末尾（扩展维度空间）。

```
原始组合: (scene=tavern_night, emotion=ARROGANCE)
linked_value_ids 作用: 替换 emotion 槽位为 TRANQUILITY
virtual_dimension_ids 作用: 追加虚拟维度到末尾
最终组合: (scene=tavern_night, emotion=TRANQUILITY, vdim_0=npc_libai)
```

### 11.5 外部维度自动注入

如果 [`virtual_dimension_ids`](#11-虚拟维度追加-virtual_dimension_ids) 引用的值 ID 不在当前配置的任何维度中，管线会从 [`tools/imagery_dimension_db.json`](../../tools/imagery_dimension_db.json) 自动注入该值所属的完整维度。注入逻辑与 [`linked_value_ids`](#10-跨维度引用-linked_value_ids) 的外部维度解析共用同一函数 [`_resolve_linked_value_ids()`](../../tools/event_generator/dimensions.py)。

### 11.6 虚拟专用维度 (virtual-only)

自动注入的外部维度如果**只被** [`virtual_dimension_ids`](#11-虚拟维度追加-virtual_dimension_ids) 引用（不被任何 [`linked_value_ids`](#10-跨维度引用-linked_value_ids) 引用），会被标记为 **virtual-only**：

- virtual-only 维度**不参与基础笛卡尔积**
- 仅当触发其引用来源的维度值时，才作为虚拟维度追加到该组合

这避免了不必要的组合爆炸，确保外部身份/NPC 维度只在需要时才出现。

### 11.7 约束

- 每个 inner list 引用的值 ID 必须存在（本地维度或 [`imagery_dimension_db.json`](../../tools/imagery_dimension_db.json) 中）
- 与 [`linked_value_ids`](#10-跨维度引用-linked_value_ids) 可共存，语义独立
- 虚拟维度追加顺序与 inner list 在数组中的顺序一致

---

## 12. 通用全局字段

这些字段作用于事件库的**所有事件**，用于减少重复配置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `universal_tags` | `list[str]` | `["bai_ye"]` | 兜底触发标签。当维度值无 `action:` 前缀 tag 时回退使用 |
| `universal_requirement` | `str` | `""` | 全局事件 requirement，如 `"prop_gt(name=ambition,val=0),prop_lt(name=ambition,val=70)"` |
| `universal_result` | `str` | `""` | 全局选项结果 DSL，多个表达式用 `\|` 分隔（OR 逻辑），会与维度缩放后的 DSL 合并 |
| `universal_option_requirement` | `str` | `""` | 全局选项 requirement，支持 `{failed_hint}` 模板变量 |
| `final_directive` | `str` | `""` | 渲染到 system prompt 绝对末尾的最后指令。利用 Recency Bias 强化约束 |
| `apply_dimension_imagery` | `bool` | `false` | 启用意象正交剪枝/打分功能 |

---

## 13. 配置场景速查表

### 场景 A：单一行动的事件库（如「拜谒 - 门子索贿」）

```
┌────────────────────────────────────────────┐
│  特点：同一行动内的不同变体                  │
│  stored_to: 全维度值指向同一路由             │
│  plugins: 可不用或少用                      │
│  示例: event_base_config_bai_ye_honeymoon   │
└────────────────────────────────────────────┘
```

**关键配置**：
- 所有维度值的 `stored_to` 指向同一 key（如 `747_kuangda.baiye`）
- `universal_tags` 设为一个 action tag
- 不需要 `emotion_pairs`
- 不需要沙盒

### 场景 B：横跨多个行动的事件库（如「场景-意象」）

```
┌────────────────────────────────────────────┐
│  特点：不同维度值路由到不同行动目录           │
│  stored_to: 按维度值各自指定                 │
│  plugins: 需要 imagery_acquisition          │
│  示例: event_base_config_scene_imagery      │
└────────────────────────────────────────────┘
```

**关键配置**：
- 每个维度值设置不同的 `stored_to`（如 `745_ambition.fengzhao`、`745_ambition.denggao`）
- 各维度值的 `tags` 同时包含 `action:` 前缀 tag 和意象 tag
- `universal_tags` 设为一个兜底 tag（如 `scene_imagery`）
- 启用 `imagery_acquisition` 插件

### 场景 C：多态羞辱事件库

```
┌────────────────────────────────────────────┐
│  特点：羞辱类型 × 场景 × 应对策略 × 情绪    │
│  stored_to: 按羞辱类型路由到不同行动目录     │
│  plugins: 需要 emotion_pair_imagery        │
│  示例: event_base_config_duotai_humiliation │
└────────────────────────────────────────────┘
```

**关键配置**：
- `plugins: ["emotion_pair_imagery"]`
- 定义 `emotion_pairs` mapping
- `humiliation_type` 维度各值用 `emotion_pair:` 前缀 tag 标记配对
- 各 `option_feature` 设置 `pair_role`
- 场景维度值提供意象 tag
- 可能需要黑名单（`blacklist_config`）

### 场景 D：需要失败反馈的事件库（如「验诗 - 干谒」）

```
┌────────────────────────────────────────────┐
│  特点：选项需要失败时的 NPC 反应文本         │
│  stored_to: 单一行动路由                    │
│  plugins: 需要 failed_hint                 │
│  示例: 暂无标准化配置，参考 failed_hint      │
└────────────────────────────────────────────┘
```

**关键配置**：
- `plugins: ["failed_hint"]`
- 各个 `option_feature` 在 `plugins.failed_hint` 中配置样式和字数
- `universal_option_requirement` 中使用 `{failed_hint}` 模板变量

### 场景 E：需要沙盒预生成的事件库

```
┌────────────────────────────────────────────┐
│  特点：需要预生成创作关键词                  │
│  配置: sandbox_feature 提供创作指引          │
│  文件: 自动生成 _sandbox.json 缓存          │
└────────────────────────────────────────────┘
```

**关键配置**：
- 无需在 plugins 中声明
- `sandbox_feature` 提供创作指引文本
- 管线首次运行时自动生成沙盒文件

---

## 附录：端到端配置检查清单

新建事件库时，对照此清单确认没有遗漏：

- [ ] `id` 和 `name` 已设置
- [ ] `era` 已设置为正确的时代 ID（如 `745_ambition`）
- [ ] `background_context` 和 `ai_persona` 已撰写
- [ ] 维度定义完整，每个值都有 `id`、`name`、`description`
- [ ] 各维度值的 `operator_dsl` 和 `scale` 已设置
- [ ] 需要在 Godot 端添加的 `STORE_TO_PATH_MAP` 条目已确认
- [ ] `data/4_eras/` 下的目标目录已创建
- [ ] 插件列表已确定，需要 per-option 配置的插件已配置
- [ ] `universal_tags`、`universal_requirement`、`universal_result` 已设置
- [ ] `option_features` 中每个选项的 `result` 和 `requirement` 已定义
- [ ] 如果选项有固定文本，`fixed: true` 已设置
- [ ] 如果维度值需要跨维度引用，`linked_value_ids` 已配置
- [ ] 如果维度值需要追加虚拟维度，`virtual_dimension_ids` 已配置
- [ ] 如果需要黑名单，确认只有一个维度挂载了 `blacklist_config`
- [ ] `final_directive` 已撰写（利用 Recency Bias）
- [ ] 沙盒文件已存在或允许管线首先生成
- [ ] 已配置 `apply_dimension_imagery`（如果需要意象打分）
- [ ] 已配置 `emotion_pairs`（如果使用 `emotion_pair_imagery` 插件）

---

> 相关文件：
> - 管线入口：[`tools/generate_orthogonal_events.py`](../../tools/generate_orthogonal_events.py)
> - 管线主逻辑：[`tools/event_generator/main.py`](../../tools/event_generator/main.py)
> - 数据模型：[`tools/config.py`](../../tools/config.py)
> - 插件基类：[`tools/plugin_base.py`](../../tools/plugin_base.py)
> - 插件实现：[`tools/plugins/`](../../tools/plugins/)
> - CSV 输出：[`tools/event_generator/io_csv.py`](../../tools/event_generator/io_csv.py)
> - 状态管理：[`tools/event_generator/state_managers.py`](../../tools/event_generator/state_managers.py)
> - Godot 端路由：[`core/csv_cloud_loader.gd`](../../core/csv_cloud_loader.gd)
> - 现有配置参考：[`tools/event_base_config_scene_imagery.json`](../../tools/event_base_config_scene_imagery.json)
> - 现有配置参考：[`tools/event_base_config_duotai_humiliation.json`](../../tools/event_base_config_duotai_humiliation.json)
