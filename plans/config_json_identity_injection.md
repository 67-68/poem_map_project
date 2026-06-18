# Config JSON 身份注入执行计划

> 范围: 12 个 Config JSON 文件（747_kuangda 时代）
> 目标: 添加 `virtual_dimension_ids` + `TARGET_IDENTITY_*` tag
> 排除: leverage 注入（待后续确认）
> 排除: sandbox 版本
> 排除: `denggao.json`（自然场景豁免）、`scene_imagery.json`（非 747 era）
> 排除: `bai_ye_honeymoon_config.json`、`text_features_registry.json`、`test_config_emotion_imagery_v2.json`、`scene_tag_library_config.json`

---

## 机械执行清单

对于每个 Config JSON 文件，需要对每个 `dimensions[].values[]` 元素：

1. **如果该 value 对应一个身份 NPC/角色** → 在 value 的 `tags` 中添加 `TARGET_IDENTITY_*` tag
2. **如果该 value 对应一个具名 NPC（李白/王维/高适/郑虔/李灵甫）** → 添加 `virtual_dimension_ids` 指向对应的身份值 ID
3. **如果该 value 不涉及人类交互**（纯内心、自然场景）→ 跳过

⚠️ **绝对不要改 values 的 `id`、`name`、`description`、`linked_value_ids`、`operator_dsl`、`option_results`、`scale`、`stored_to`、`narrative_constraint` 字段！**

⚠️ **如果 value 已有 `tags`** → 追加到末尾，不要替换

---

## NPC→身份映射表

| NPC ID | 中文 | virtual_dimension_ids | TARGET_IDENTITY tag |
|--------|------|----------------------|---------------------|
| `npc_libai` (LIBAI) | 李白 | `[["identity_qingliu_owner"]]` | `TARGET_IDENTITY_QINGLIU_OWNER` |
| `npc_wangwei` (WANGWEI) | 王维 | `[["identity_zhuoliu_official"]]` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| `npc_gaoshi` (GAOSHI) | 高适 | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| `npc_zhengqian` (ZHENGQIAN) | 郑虔 | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| `npc_lilinfu` (LILINFU) | 李灵甫 | `[["identity_quangui"]]` | `TARGET_IDENTITY_QUANGUI` |

## 身份 role→identity 映射表

| 身份关键词 | identity ID | TARGET_IDENTITY tag |
|-----------|-------------|---------------------|
| 权贵/紫袍胖子/大员(权贵) | `identity_quangui` | `TARGET_IDENTITY_QUANGUI` |
| 参军(清流) | `identity_qingliu_official` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| 侍郎(清流)/员外(清流) | `identity_qingliu_official` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| 参军(浊流) | `identity_zhuoliu_official` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| 侍郎(浊流)/员外(浊流) | `identity_zhuoliu_official` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| 主簿/掌柜/摊主 | `identity_vendor` | `TARGET_IDENTITY_VENDOR` |
| 清客 | `identity_qingke` | `TARGET_IDENTITY_QINGKE` |
| 门子 | `identity_menzi` | `TARGET_IDENTITY_MENZI` |
| 县尉 | `identity_county_sheriff` | `TARGET_IDENTITY_COUNTY_SHERIFF` |
| 乞丐/流民 | `identity_poor` | `TARGET_IDENTITY_POOR` |

---

## 逐文件规格

### 1. kuangke_qingliu — `tools/event_base_config_kuangke_qingliu.json`

已有 `qingliu_npc` dimension，每个 NPC value 已有 tags。

**改动：** 在每个 NPC value 中添加 `virtual_dimension_ids` 和追加 TARGET_IDENTITY tag

| Value ID | 追加 virtual_dimension_ids | 追加 tag |
|----------|---------------------------|---------|
| `LIBAI` | `[["identity_qingliu_owner"]]` | `TARGET_IDENTITY_QINGLIU_OWNER` |
| `WANGWEI` | `[["identity_zhuoliu_official"]]` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| `ZHENGQIAN` | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| `GAOSHI` | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |

### 2. kuangke_zhuoliu — `tools/event_base_config_kuangke_zhuoliu.json`

已有 `kuangke_zhuoliu_scenario` single dimension，6 个 value。

需扫描每个 description，根据出现的身份关键词追加。

基于 NPC 扫描结果，只出现「清客」1 次。将清客身份标注到对应 value 上。

**改动：** 在涉清客的 value 中追加 tag `TARGET_IDENTITY_QINGKE`

### 3. qingliu_daoxin_posui — `tools/event_base_config_qingliu_daoxin_posui.json`

已有 `daoxin_posui_scenario` single dimension，10 个 value。

扫描出现的身份：侍郎(1), 掌柜(1), 清客(1), 门子(2)

**改动：** 在对应 value 中追加 virtual_dimension_ids + TARGET_IDENTITY tag

| 出现词 | 目标 value (根据 description 判断) | 追加 |
|--------|-----------------------------------|------|
| 侍郎 | 涉及官场场景的 value | `virtual_dimension_ids: [["identity_qingliu_official"]]`, tag: `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| 掌柜 | 涉及商业/店铺场景的 value | `virtual_dimension_ids: [["identity_vendor"]]`, tag: `TARGET_IDENTITY_VENDOR` |
| 清客 | 涉及依附文人场景的 value | tag: `TARGET_IDENTITY_QINGKE` |
| 门子 | 涉及门禁/通报场景的 value | tag: `TARGET_IDENTITY_MENZI` |

### 4. qingliu_fengying — `tools/event_base_config_qingliu_fengying.json`

已有 `fengying_scenario` single dimension，6 个 value。

出现的身份：参军(1), 掌柜(1), 门子(1)

**改动：** 在对应 value 中追加

| 出现词 | 追加 |
|--------|------|
| 参军 | `virtual_dimension_ids: [["identity_qingliu_official"]]`, tag: `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| 掌柜 | `virtual_dimension_ids: [["identity_vendor"]]`, tag: `TARGET_IDENTITY_VENDOR` |
| 门子 | tag: `TARGET_IDENTITY_MENZI` |

### 5. qingliu_jiaolv — `tools/event_base_config_qingliu_jiaolv.json`

已有 `jiaolv_scenario` single dimension，4 个 value。

出现的身份：县尉(1) — 涉及官府追逼场景

**改动：** 在对应的 value 中追加 `virtual_dimension_ids: [["identity_county_sheriff"]]`, tag: `TARGET_IDENTITY_COUNTY_SHERIFF`

### 6. qingliu_passive_benefits — `tools/event_base_config_qingliu_passive_benefits.json`

已有 `qingliu_npc` dimension，NPC: LIBAI, WANGWEI, ZHENGQIAN, GAOSHI。

每个 NPC value 已有 tags。需添加 `virtual_dimension_ids` 和 TARGET_IDENTITY tag。

| Value ID | 追加 virtual_dimension_ids | 追加 tag |
|----------|---------------------------|---------|
| `LIBAI` | `[["identity_qingliu_owner"]]` | `TARGET_IDENTITY_QINGLIU_OWNER` |
| `WANGWEI` | `[["identity_zhuoliu_official"]]` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| `ZHENGQIAN` | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| `GAOSHI` | `[["identity_qingliu_official"]]` | `TARGET_IDENTITY_QINGLIU_OFFICIAL` |

### 7. qingliu_zuanying — `tools/event_base_config_qingliu_zuanying.json`

已有 `qingliu_zuanying_scenario` single dimension，6 个 value。

出现的身份：参军(2) — 清流军官场钻营

**改动：** 在涉参军的 value 中追加 `virtual_dimension_ids: [["identity_qingliu_official"]]`, tag: `TARGET_IDENTITY_QINGLIU_OFFICIAL`

### 8. zhuoliu_fengying — `tools/event_base_config_zhuoliu_fengying.json`

已有 `zhuoliu_fengying_scenario` single dimension，6 个 value。

出现的身份：侍郎(1), 主簿(1)

**改动：**

| 出现词 | 追加 |
|--------|------|
| 侍郎 | `virtual_dimension_ids: [["identity_zhuoliu_official"]]`, tag: `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| 主簿 | `virtual_dimension_ids: [["identity_vendor"]]`, tag: `TARGET_IDENTITY_VENDOR` |

### 9. zhuoliu_lieqi — `tools/event_base_config_zhuoliu_lieqi.json`

已有 `lieqi_scenario` single dimension，5 个 value。

出现的身份：权贵(3 events), 浊流大员(2 events)

| Value ID | 追加 virtual_dimension_ids | 追加 tag |
|----------|---------------------------|---------|
| `cockfight_ode` | `[["identity_quangui"]]` | `TARGET_IDENTITY_QUANGUI` |
| `poverty_tourism` | —（不涉及特定身份NPC） | — |
| `swill_gambit` | `[["identity_quangui"]]` | `TARGET_IDENTITY_QUANGUI` |
| `ghostwriter_blood` | `[["identity_zhuoliu_official"]]` | `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| `hijacked_grief` | `[["identity_quangui"]]` | `TARGET_IDENTITY_QUANGUI` |

### 10. zhuoliu_zuanying — `tools/event_base_config_zhuoliu_zuanying.json`

已有 `zuanying_scenario` single dimension，6 个 value。

出现的身份：侍郎(1), 摊主(1)

**改动：**

| 出现词 | 追加 |
|--------|------|
| 侍郎 | `virtual_dimension_ids: [["identity_zhuoliu_official"]]`, tag: `TARGET_IDENTITY_ZHUOLIU_OFFICIAL` |
| 摊主 | `virtual_dimension_ids: [["identity_vendor"]]`, tag: `TARGET_IDENTITY_VENDOR` |

### 11. zize — `tools/event_base_config_zize.json`

已有 `zize_scenario` single dimension，6 个 value。

出现的身份：权贵(1 event: wine_boy)

**改动：** 在 `wine_boy` value 中追加 `virtual_dimension_ids: [["identity_quangui"]]`, tag: `TARGET_IDENTITY_QUANGUI`

其他 value 均为自理/内心戏（家书、年轻士子、故交、冻尸、玉佩），不涉及特定身份NPC。

### 12. duotai_humiliation — `tools/event_base_config_duotai_humiliation.json`

已有 `humiliation_type` dimension（8 个 value）+ `gateway` dimension（6 个 value）。

出现的身份：侍郎(1), 员外(1), 主簿(2), 掌柜(1), 摊主(1), 乞丐(2), 清客(1), 门子(11), 郑虔(1)

注意：多态凌辱的 description 中「门子」出现 11 次，但门子多为背景角色（开门、通报、引路），不一定是特定交互对象。谨慎标注。

**改动：** 在 `humiliation_type` 的对应 value 中追加身份信息

| 出现词 | 推测 value | 追加 |
|--------|-----------|------|
| 侍郎/员外 | `class_bullying` 或 `peer_gap` | `virtual_dimension_ids: [["identity_qingliu_official"]]`, tag: `TARGET_IDENTITY_QINGLIU_OFFICIAL` |
| 主簿/掌柜/摊主 | `cheap_labor` 或 `hidden_charity` | `virtual_dimension_ids: [["identity_vendor"]]`, tag: `TARGET_IDENTITY_VENDOR` |
| 乞丐/流民 | `weak_harm_weak` | `virtual_dimension_ids: [["identity_poor"]]`, tag: `TARGET_IDENTITY_POOR` |
| 清客 | `aesthetic_violation` | tag: `TARGET_IDENTITY_QINGKE` |
| 门子 | `class_bullying` | tag: `TARGET_IDENTITY_MENZI` |
| 郑虔 | `talent_commodification` | `virtual_dimension_ids: [["identity_qingliu_official"]]`, tag: `TARGET_IDENTITY_QINGLIU_OFFICIAL` + `TARGET_NPC_ZHENGQIAN` |

---

## 操作步骤

1. 对每个 Config JSON 文件：读取 → 在对应 value 中添加 `virtual_dimension_ids` 和/或 `tags` → 保存
2. 执行 `python3 tools/event_generator/main.py --config <file>` 验证 parse 不报错
3. 执行 `python3 -c "import json; json.load(open('tools/event_base_*.json'))"` 核对 JSON 合法性

## 警告

- **绝对不要改 sandbox 版本**（`*_sandbox.json`）
- **绝对不要改 `denggao.json`**（自然场景豁免）
- **绝对不要动 value 的 `id`、`name`、`description` 等已有字段**
- 每个文件修改后立即保存并验证 JSON 合法性
- 如果某个 value 的 description 中出现了身份关键词但无法确定（如「门子」出现了 11 次但多为背景角色），**保守处理，不要强行标注**
