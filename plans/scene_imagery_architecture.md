# 场景-意象 双轨架构 (Scene-Imagery Dual-Track Architecture)

> **状态：** ✅ 方案最终确认
> **约束文档：** [`tag_dictioinary.md`](../DOCUMENTATIONS/events/tag_dictioinary.md)（五维宪法）
> **标签格式：** [`tag_pattern_confliction.md`](../DOCUMENTATIONS/events/tag_pattern_confliction.md)（四段式 `domain:category:type:specific`）
> **动态维度：** [`dynamic_dimension_refactor.md`](dynamic_dimension_refactor.md)（`linked_value_ids` 值级引用）

---

## 0. 核心概念

### 标签格式演进（来自 `tag_pattern_confliction.md`）

```
三段式（旧）:    domain:category:value             如 actor:health:drunk
四段式（新）:    domain:category:type:specific       如 actor:health:drunk:poetic_sorrow
```

本方案使用**五维宪法 + 四段式**，即 `DIMENSION_CATEGORY_TYPE_SCENE`：

```
TARGET_PLACE_JADESTEP_DAILOU
↑       ↑       ↑       ↑
维度    分类    类型    场景标识（第4段）
```

第 4 段（`specific`）是场景实例化标识，让同一个意象概念在不同场景产生不同的 trigger tag，运行时前缀匹配按 colon/underscore 分段匹配。

### 数据流总览

```
[独立意象数据库]                [场景配置JSON]
  imagery_jade_step              scene_dailou
  imagery_giant_roc              scene_jixian
  imagery_cloud_and_sun  ←───   scene_huaqing  ...
                                  │
                            linked_value_ids 引用
                                  │
                                  ▼
                          运行时加载 imagery 维度
                          与 scene 维度做匹配
```

---

## 1. 文件清单

| 文件 | 类型 | 用途 |
|------|------|------|
| `tools/event_base_config_scene_imagery.json` | 🆕 创建 | 12 场景定义，包含 `stored_to` + `tags`(4段) + `linked_value_ids` |
| `tools/event_base_config_scene_imagery_sandbox.json` | 🆕 创建 | 每个 scene×imagery 的手工关键词 |
| `tools/config.py` | 📝 修改 | `PipelineDimensionValue` 加 `stored_to: str = ""` 字段 |
| `plans/scene_imagery_architecture.md` | 📝 修改 | 本文档更新 |

**不创建：** 翻译表（用户已撤回该设计）、意象维度不在此配置中（从独立数据库加载）

---

## 2. 配置结构

### 2.1 [`tools/event_base_config_scene_imagery.json`](../tools/event_base_config_scene_imagery.json)

```json
{
  "id": "scene_imagery_library",
  "name": "场景-意象获取事件库",
  "dimensions": [
    {
      "id": "scene",
      "name": "场景",
      "description": "物理场景定义 (stored_to 标记存档路由)",
      "values": [
        {
          "id": "scene_dailou",
          "name": "待漏院听更",
          "description": "大明宫外的破晓，凌晨寒风，百官按品级站在院外等候早朝",
          "stored_to": "fengzhao",
          "tags": ["TARGET_PLACE_JADESTEP_DAILOU", "ENV_POLITICS_CLOUD_DAILOU"],
          "linked_value_ids": ["imagery_jade_step", "imagery_cloud_and_sun"]
        }
      ]
    }
  ]
}
```

### 2.2 Scene 值的字段说明

| 字段 | 值 | 说明 |
|------|-----|------|
| `id` | `scene_dailou` | 唯一标识，Godot 用此 ID 加载场景 |
| `stored_to` | `fengzhao` | 标记该场景所属的存档文件夹/action entry key |
| `tags` | `["TARGET_PLACE_JADESTEP_DAILOU", ...]` | 4 段式 tag，给插件生成选项中获取意象的 operator DSL 用 |
| `linked_value_ids` | `["imagery_jade_step", ...]` | 引用独立意象数据库中的意象维度节点 ID |

### 2.3 `stored_to` 枚举值

| key | 含义 | 场景 |
|-----|------|------|
| `fengzhao` | 奉召 | 待漏院/集贤院/华清池 |
| `denggao` | 登高 | 终南山/乐游原/大雁塔 |
| `duzhuo` | 独酌 | 客舍/酒肆/灞桥 |
| `jiaoyou` | 交游 | 曲江池/宅邸/胡姬酒肆 |

---

## 3. 12 场景 × 意象完整排期

| stored_to | 场景 | 场景 ID | tags (4段) | linked_value_ids |
|-----------|------|---------|-----------|------------------|
| fengzhao | 待漏院听更 | `scene_dailou` | `TARGET_PLACE_JADESTEP_DAILOU`, `ENV_POLITICS_CLOUD_DAILOU` | `imagery_jade_step`, `imagery_cloud_and_sun` |
| fengzhao | 集贤院修书 | `scene_jixian` | `TARGET_PLACE_JADESTEP_JIXIAN`, `ENV_POLITICS_CLOUD_JIXIAN` | `imagery_jade_step`, `imagery_cloud_and_sun` |
| fengzhao | 华清池扈从 | `scene_huaqing` | `TARGET_PLACE_JADESTEP_HUAQING`, `ENV_POLITICS_CLOUD_HUAQING` | `imagery_jade_step`, `imagery_cloud_and_sun` |
| denggao | 终南山绝顶 | `scene_zhongnan` | `TARGET_MYTH_GIANTROC_ZHONGNAN`, `ENV_POLITICS_CLOUD_ZHONGNAN` | `imagery_giant_roc`, `imagery_cloud_and_sun` |
| denggao | 乐游原残阳 | `scene_leyou` | `TARGET_MYTH_GIANTROC_LEYOU`, `ENV_POLITICS_CLOUD_LEYOU` | `imagery_giant_roc`, `imagery_cloud_and_sun` |
| denggao | 慈恩寺大雁塔 | `scene_dayan` | `TARGET_MYTH_GIANTROC_DAYAN`, `ENV_POLITICS_CLOUD_DAYAN` | `imagery_giant_roc`, `imagery_cloud_and_sun` |
| duzhuo | 破败客舍寒夜 | `scene_keshe` | `TARGET_MYTH_GIANTROC_KESHE` | `imagery_giant_roc` |
| duzhuo | 繁华酒肆暗角 | `scene_jiusi` | `TARGET_MYTH_GIANTROC_JIUSI` | `imagery_giant_roc` |
| duzhuo | 灞桥风雪酒亭 | `scene_baqiao` | `TARGET_MYTH_GIANTROC_BAQIAO` | `imagery_giant_roc` |
| jiaoyou | 曲江池流觞亭 | `scene_qujiang` | `TARGET_MYTH_GIANTROC_QUJIANG`, `ENV_POLITICS_CLOUD_QUJIANG` | `imagery_giant_roc`, `imagery_cloud_and_sun` |
| jiaoyou | 权贵宅邸外院 | `scene_zhaidi` | `TARGET_MYTH_GIANTROC_ZHAIDI`, `ENV_POLITICS_CLOUD_ZHAIDI` | `imagery_giant_roc`, `imagery_cloud_and_sun` |
| jiaoyou | 胡姬酒肆狂欢 | `scene_huji` | `TARGET_MYTH_GIANTROC_HUJI`, `ENV_POLITICS_CLOUD_HUJI` | `imagery_giant_roc`, `imagery_cloud_and_sun` |

---

## 4. Sandbox 关键词机制

### 4.1 文件格式

[`tools/event_base_config_scene_imagery_sandbox.json`](../tools/event_base_config_scene_imagery_sandbox.json)

```json
{
  "scene_dailou": {
    "imagery_jade_step": [
      "紫袍踏过汉白玉御道",
      "品级站位如天堑",
      "仰望宫门的膝盖"
    ],
    "imagery_cloud_and_sun": [
      "初阳被官服遮挡",
      "琉璃瓦在仪仗间闪烁",
      "朝晖被层层遮蔽"
    ]
  }
}
```

### 4.2 运行时使用

```
SandboxManager 加载 sandbox.json
根据当前 scene_id × 目标 imagery_id 查找关键词
注入 LLM prompt 作为创作种子
```

---

## 5. 实施清单

### 5.1 [`tools/config.py`](../tools/config.py) — 模型修改

```python
class PipelineDimensionValue(BaseModel):
    ...
    stored_to: str = ""  # 🆕 标记场景所属存档路由
```

### 5.2 新文件

1. `tools/event_base_config_scene_imagery.json` — 12 场景（含上述完整排期）
2. `tools/event_base_config_scene_imagery_sandbox.json` — 场景×意象关键词

### 5.3 验证

1. 所有 4 段 tag（如 `TARGET_PLACE_JADESTEP_DAILOU`）的前 3 段（`TARGET_PLACE_JADESTEP`）必须存在于 `tag_dictioinary.md`
2. 每个场景的 `stored_to` 必须是合法枚举值
3. `linked_value_ids` 引用的 ID 必须存在于意象数据库
4. Sandbox 覆盖所有 scene×imagery 组合
