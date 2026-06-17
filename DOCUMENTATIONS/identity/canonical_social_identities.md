# 大唐社交身份体系 — 基础身份规范

> **版本**: v1.0
> **关联系统**: Tag 字典 → `TARGET_IDENTITY_*` | 外部维度库 `imagery_dimension_db.json` → `social_identity` | 事件生成管线 → `virtual_dimension_ids`

---

## 一、核心原则

### 无必要不加新身份

大唐社交身份体系是一张**封闭的、审慎的名片**。新身份只在以下情况允许添加：

1. **新的可交互阵营出现** — 如新增一个具有独立社会地位的势力（例如太监集团、藩镇势力）
2. **现有身份的叙事支点不足** — 现有身份列表无法支撑关键剧情需要的冲突结构
3. **架构师书面批准** — 走宪法修正案流程，在本文档中记录理由

> **不在表上的身份词，事件中不允许作为独立 NPC 出现**。AI 生成事件时如果提到未注册身份，Linter 应当拦截。

---

## 二、基础身份清单

### 9 大基础身份 (9 Foundational Identities)

| 身份 ID | 身份名称 | 分类 | 子身份（代码层） | 原实体来源 |
|---------|---------|------|-----------------|-----------|
| `qingliu_owner` | 清流主人 | 清流上层 | — | 清流主人 |
| `qingliu_official` | 清流官 | 清流官僚 | 参军, 侍郎, 员外 | 参军(部分), 侍郎(部分), 员外(部分) |
| `zhuoliu_official` | 浊流官 | 浊流官僚 | 参军, 侍郎, 员外 | 参军(部分), 侍郎(部分), 员外(部分) |
| `quangui` | 权贵 | 浊流上层 | 紫袍胖子权贵 | 紫袍胖子权贵 → 权贵 |
| `qingke` | 清客 | 清流门客 | — | 清客 |
| `menzi` | 门子 | 底层吏员 | — | 门子 |
| `county_sheriff` | 县尉 | 地方吏员 | — | 县尉 |
| `vendor` | 商贩 | 市井商贩 | 主簿*, 掌柜, 摊主 | 主簿, 掌柜, 摊主 |
| `poor` | 穷人 | 底层流浪 | 乞丐, 流民 | 乞丐, 流民 |

> *主簿在体制内是县衙属官，但在事件中出现时多记录市井交易场景，归入商贩身份。如果未来需要区分"公务员商贩"与"职业商贩"，可拆分为独立的 `county_clerk` 身份。

### 子身份映射关系

```
qingliu_official ─┬─ 参军 (specific_personnel/strategic_advisor)
                  ├─ 侍郎 (central_official/mid_rank)
                  └─ 员外 (central_official/sinecure)

zhuoliu_official ─┬─ 参军 (specific_personnel/strategic_advisor)
                  ├─ 侍郎 (central_official/mid_rank)
                  └─ 员外 (central_official/sinecure)

vendor ───────────┬─ 掌柜 (shopkeeper)
                  ├─ 摊主 (stall_owner)
                  └─ 主簿 (county_clerk) [注：见上方说明]

poor ─────────────┬─ 乞丐 (beggar)
                  └─ 流民 (refugee)

quangui ──────────└─ 紫袍胖子权贵 (portly_purple_robed_QuanGui)
```

> **清流官 vs 浊流官 的分化逻辑**: 参军、侍郎、员外这三个官职本身是中性的。在事件上下文中，通过**清流/浊流的阵营上下文**来区分：同一篇事件描述中若提到"参军"且伴随清流人物/背景，则归入清流官；若伴随浊流背景，则归入浊流官。生成时由 `virtual_dimension_ids` 的配置上下文决定归属。

---

## 三、Tag 映射

所有身份在 [`tag_dictioinary.md`](../events/tag_dictioinary.md) 中以 `TARGET_IDENTITY_` 前缀注册。

| Tag | 对应身份 | 描述 |
|-----|---------|------|
| `TARGET_IDENTITY_QINGLIU_OWNER` | 清流主人 | 清流派的核心主人，精神领袖 |
| `TARGET_IDENTITY_QINGLIU_OFFICIAL` | 清流官 | 清流派系的官员（参军/侍郎/员外） |
| `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` | 浊流官 | 浊流派系的官员（参军/侍郎/员外） |
| `TARGET_IDENTITY_QUANGUI` | 权贵 | 依仗权势的浊流上层 |
| `TARGET_IDENTITY_QINGKE` | 清客 | 依附于权贵门下的文人门客 |
| `TARGET_IDENTITY_MENZI` | 门子 | 门房传话的低级吏员 |
| `TARGET_IDENTITY_COUNTY_SHERIFF` | 县尉 | 县级武装治安负责人 |
| `TARGET_IDENTITY_VENDOR` | 商贩 | 市井商贩（掌柜/摊主/主簿） |
| `TARGET_IDENTITY_POOR` | 穷人 | 底层流浪者（乞丐/流民） |

### 事件 Tag 使用规则

- 与身份角色交互的事件，Trigger_Tags 中**必须**包含对应的 `TARGET_IDENTITY_*`
- 与具体 NPC 交互的事件，Trigger_Tags 中**必须**包含对应的 `TARGET_NPC_*`
- 允许同时使用：`[TARGET_NPC_LIBAI, TARGET_IDENTITY_QINGLIU_OWNER]` — 表示"李白以清流主人的身份出现"

---

## 四、身份出现频率摘要（来自事件内容扫描）

基于对 `data/4_eras/747_kuangda/` 下所有 CSV 文件和 Config JSON 的模糊扫描 [v2 报告](../../plans/social_identity_library.md)：

| 身份 | 出现次数 | 跨文件数 | 主要分布 |
|------|---------|---------|---------|
| 清流主人(qingliu_owner) | ~1 | 1 | 清流事件上下文 |
| 参军/侍郎/员外 → 清流/浊流官 | 18（参军8+侍郎5+员外5） | 3~5 | 跨多个清流/浊流事件库 |
| 权贵(quangui) | 16 | 9 | 跨9个文件，清/浊流皆出现 |
| 清客(qingke) | 16 | 3 | 主要出现在多态屈辱事件中 |
| 门子(menzi) | 25 | 3 | 主要出现在多态屈辱事件中 |
| 县尉(county_sheriff) | ~1 | 1 | 清流事件上下文 |
| 商贩(vendor: 掌柜/摊主/主簿) | 14（掌柜3+摊主6+主簿5） | 3 | 跨多态屈辱/清流/浊流事件 |
| 穷人(poor: 乞丐) | 8 | 2 | 主要出现在多态屈辱事件中 |

> **结论**: 权贵(16次/9文件)、门子(25次/3文件)、清客(16次/3文件) 是当前事件中出现密度最高的身份；参军/侍郎/员外(18次) 官职类出现频率中等；县尉出现极少。穷人身份在当前事件库中仅出现在多态屈辱语境中。

---

## 五、与 NPC 的协作关系

身份体系与 NPC 体系是**正交的两套维度**，在事件生成管线中同时存在：

```
NPC 维度（具体的人）        身份维度（社会角色）
─────────────────          ─────────────────
TARGET_NPC_LIBAI            TARGET_IDENTITY_QINGLIU_OWNER
TARGET_NPC_DUFU             TARGET_IDENTITY_QINGLIU_OFFICIAL
TARGET_NPC_WANGWEI          TARGET_IDENTITY_ZHUOLIU_OFFICIAL
TARGET_NPC_GAOSHI           TARGET_IDENTITY_QUANGUI
TARGET_NPC_ZHENGQIAN        TARGET_IDENTITY_QINGKE
TARGET_NPC_LILINFU          TARGET_IDENTITY_MENZI
                            TARGET_IDENTITY_COUNTY_SHERIFF
                            TARGET_IDENTITY_VENDOR
                            TARGET_IDENTITY_POOR
```

- **NPC 维度**：「谁」— 具名历史人物，有独立的人格、关系和生平
- **身份维度**：「什么角色」— 社会角色，可以在不同事件中由不同 NPC/无名角色扮演
- **同时使用时**：`[TARGET_NPC_LIBAI, TARGET_IDENTITY_QINGLIU_OWNER]` 表示李白以清流主人身份出现
- **仅有身份时**：`[TARGET_IDENTITY_MENZI]` 表示一个无名的门子角色

---

## 六、事件身份集成规范

对于文档 [`new_event_identity_requirement.md`](./new_event_identity_requirement.md) 中定义的规范，本文档作为权威源头。

> 任何新增的 Config JSON，如果包含人类交互维度，必须引用本规范中的身份 ID。具体引用方式见集成规范文档。
