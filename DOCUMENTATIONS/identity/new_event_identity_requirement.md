# 新建事件身份集成规范

> **强制要求**: 任何新建的 Config JSON 事件库，如果涉及**人与人的交互**，必须携带身份/NPC 虚拟维度。
> **状态**: v1.0 · 生效中
> **关联**: [`canonical_social_identities.md`](./canonical_social_identities.md) | [`tag_dictioinary.md`](../events/tag_dictioinary.md)

---

## 一、为什么？

社交系统依赖身份锚点来：
- 限制玩家交互目标（游戏机制）
- 维持世界观一致性（叙事逻辑）
- 通过 `TARGET_IDENTITY_*` tag 进行事件路由与匹配

没有身份维度的事件，社交系统无法判定"谁在跟谁说话"。

---

## 二、硬性要求

### 2.1 维度配置

在 Config JSON 的 `dimensions` 数组中，**必须**包含以下额外虚拟维度：

```json
{
  "id": "social_npc",
  "name": "社交NPC",
  "description": "事件中出现的具名历史人物",
  "values": [
    { "id": "npc_libai", "name": "李白", "virtual_dimension_ids": [["identity_qingliu_owner"]] },
    { "id": "npc_dufu", "name": "杜甫", "virtual_dimension_ids": [["identity_qingliu_official"]] },
    { "id": "npc_wangwei", "name": "王维", "virtual_dimension_ids": [["identity_zhuoliu_official"]] },
    { "id": "npc_gaoshi", "name": "高适", "virtual_dimension_ids": [["identity_qingliu_official"]] },
    { "id": "npc_zhengqian", "name": "郑虔", "virtual_dimension_ids": [["identity_qingliu_official"]] },
    { "id": "npc_lilinfu", "name": "李灵甫", "virtual_dimension_ids": [["identity_quangui"]] }
  ]
}
```

每个 NPC 节点通过 `virtual_dimension_ids` 指向其对应的身份维度 ID，生成时自动追加虚拟身份维度做笛卡尔积。

### 2.2 Tag 要求

输出的事件 CSV 中，`context` 列的 `trigger_tags` **必须**包含：

| 场景 | 必须包含的 Tag | 示例 |
|------|---------------|------|
| 与具名 NPC 交互 | `TARGET_NPC_*` + `TARGET_IDENTITY_*` | `TARGET_NPC_LIBAI|TARGET_IDENTITY_QINGLIU_OWNER` |
| 与无名身份角色交互 | `TARGET_IDENTITY_*` | `TARGET_IDENTITY_MENZI` |
| 同时涉及多个身份 | 每个身份各一个 Tag | `TARGET_IDENTITY_QUANGUI|TARGET_IDENTITY_VENDOR` |

### 2.3 Trigger_Tags 最小跨度

遵循[五维宪法](../events/tag_dictioinary.md)的最小跨度律（3-5 个 Tag），身份 Tag 计入计数：

```
✅ ACTION_SOCIAL_VISIT | ACTOR_EMOTION_ANXIETY | TARGET_NPC_LIBAI | TARGET_IDENTITY_QINGLIU_OWNER
   → 4 个 Tag，合规
```

---

## 三、配置模板

### 3.1 带身份维度的事件库模板

```json
{
  "dimensions": [
    {
      "id": "social_npc",
      "name": "社交NPC",
      "values": [
        {
          "id": "npc_<key>",
          "name": "<中文名>",
          "virtual_dimension_ids": [
            ["identity_<category>"]
          ]
        }
      ]
    },
    {
      "id": "social_scene",
      "name": "社交场景",
      "values": [
        { "id": "scene_<key>", "name": "<场景名>" }
      ]
    }
  ],
  "universal_trigger_tags": [
    "TARGET_IDENTITY_<身份>"
  ],
  "store_to": "<目标路径>"
}
```

### 3.2 virtual_dimension_ids 用法速查

| 语法 | 语义 |
|------|------|
| `"virtual_dimension_ids": []` | 不追加任何虚拟维度 |
| `"virtual_dimension_ids": [["id_a"]]` | 追加 1 个虚拟维度值 `id_a` |
| `"virtual_dimension_ids": [["id_a", "id_b"]]` | 追加 1 个维度，2 个可选值 → 该值展开 2 份 |
| `"virtual_dimension_ids": [["id_a"], ["id_b"]]` | 追加 2 个独立虚拟维度 → 笛卡尔积 2 份 |
| `"virtual_dimension_ids": [["id_a", "id_b"], ["id_c"]]` | 追加 2 个维度: 维度1有2值 × 维度2有1值 = 2 份 |

**与 `linked_value_ids` 的关系**: 两个字段可以**同时工作**。`linked_value_ids` 负责替换/追加到现有维度，`virtual_dimension_ids` 负责创建全新的虚拟维度。参见 [`event_library_config_guide.md`](../events/event_library_config_guide.md) 第 10 节。

---

## 四、例外豁免

以下情况可豁免身份/NPC 维度要求：

1. **自然景观/气象事件** — 如「秋雨连绵」「长安见雪」，不涉及人类交互
2. **纯内心独白/意识流事件** — 如「杜甫独坐思乡」，不涉及外部角色交互
3. **动物/器物视角事件** — 如「瘦马嘶鸣」「古琴自鸣」

任何豁免必须在 Config JSON 的 `description` 或 `notes` 字段中注明原因，以备审计。

---

## 五、Linter 检查

未来应当由 [`event_chain_linter.gd`](../../debuggers/event_chain_linter.gd) 或等效工具自动检查：

- [ ] 所有涉及人类交互的事件 CSV 行是否包含 `TARGET_IDENTITY_*` 或 `TARGET_NPC_*`
- [ ] `virtual_dimension_ids` 引用的 ID 是否在 `imagery_dimension_db.json` 中存在
- [ ] Tag 组合是否满足最小跨度律（3-5 个 Tag）
