# 15个社交实体事件分布报告

> 生成时间: 2026-06-17

---

## 1. Tag 字典现状

| 实体 | 类型 | 预期 TARGET tag | 是否有 TARGET tag |
|------|------|----------------|-------------------|
| 高适 | NPC | `TARGET_NPC_GAOSHI` | ❌ 缺失 |
| 王维 | NPC | `TARGET_NPC_WANGWEI` | ✅ |
| 郑虔 | NPC | `TARGET_NPC_ZHENGQIAN` | ❌ 缺失 |
| 李白 | NPC | `TARGET_NPC_LIBAI` | ✅ |
| 李灵甫 | NPC | `TARGET_NPC_LILINFU` | ❌ 缺失 |
| 清流 | 势力 | `TARGET_FACTION_QINGLIU` | ✅ |
| 浊流 | 势力 | `TARGET_FACTION_ZHUOLIU` | ✅ |

> **身份类实体**: 身份类不使用 TARGET tag（身份不是对象，而是角色属性），因此不在此表中。

## 2. Config JSON 分布

### 2.1 按 Config 详细分布

#### bai_ye_real_appearance

**缺失实体 (15):** 
浊流, 清流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### duotai_humiliation

| 实体 | 出现位置 |
|------|---------|
| 门子 (IDENTITY_MENZI) | ai_persona |

**缺失实体 (14):** 
浊流, 清流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### kuangke_qingliu

| 实体 | 出现位置 |
|------|---------|
| 清流 (FACTION_QINGLIU) | universal_tags; background_context; ai_persona |
| 李白 (NPC_LIBAI) | dim:qingliu_npc/val.id=LIBAI; dim:qingliu_npc/tags.contains=TARGET_NPC_LIBAI; background_context; ai_persona |
| 王维 (NPC_WANGWEI) | dim:qingliu_npc/val.id=WANGWEI; background_context; ai_persona |
| 郑虔 (NPC_ZHENGQIAN) | dim:qingliu_npc/val.id=ZHENGQIAN; background_context; ai_persona |
| 高适 (NPC_GAOSHI) | dim:qingliu_npc/val.id=GAOSHI; background_context; ai_persona |

**缺失实体 (10):** 
浊流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫


#### kuangke_zhuoliu

| 实体 | 出现位置 |
|------|---------|
| 浊流 (FACTION_ZHUOLIU) | universal_tags; background_context; ai_persona |
| 清流 (FACTION_QINGLIU) | universal_tags |

**缺失实体 (13):** 
县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### qingliu_daoxin_posui

| 实体 | 出现位置 |
|------|---------|
| 清流 (FACTION_QINGLIU) | universal_tags |

**缺失实体 (14):** 
浊流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### qingliu_fengying

| 实体 | 出现位置 |
|------|---------|
| 清流 (FACTION_QINGLIU) | universal_tags |

**缺失实体 (14):** 
浊流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### qingliu_jiaolv

| 实体 | 出现位置 |
|------|---------|
| 清流 (FACTION_QINGLIU) | universal_tags |
| 李白 (NPC_LIBAI) | dim:jiaolv_scenario/tags.contains=TARGET_NPC_LIBAI |

**缺失实体 (13):** 
浊流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 王维, 郑虔, 高适


#### qingliu_passive_benefits

| 实体 | 出现位置 |
|------|---------|
| 清流 (FACTION_QINGLIU) | universal_tags; background_context; ai_persona |
| 李白 (NPC_LIBAI) | dim:qingliu_npc/val.id=LIBAI; dim:qingliu_npc/tags.contains=TARGET_NPC_LIBAI; background_context |
| 王维 (NPC_WANGWEI) | dim:qingliu_npc/val.id=WANGWEI; background_context |
| 郑虔 (NPC_ZHENGQIAN) | dim:qingliu_npc/val.id=ZHENGQIAN; background_context |
| 高适 (NPC_GAOSHI) | dim:qingliu_npc/val.id=GAOSHI; background_context |

**缺失实体 (10):** 
浊流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫


#### qingliu_zuanying

| 实体 | 出现位置 |
|------|---------|
| 浊流 (FACTION_ZHUOLIU) | background_context |
| 清流 (FACTION_QINGLIU) | universal_tags; background_context; ai_persona |

**缺失实体 (13):** 
县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### scene_imagery

**缺失实体 (15):** 
浊流, 清流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### zhuoliu_fengying

| 实体 | 出现位置 |
|------|---------|
| 浊流 (FACTION_ZHUOLIU) | universal_tags; background_context; ai_persona |
| 清流 (FACTION_QINGLIU) | universal_tags |

**缺失实体 (13):** 
县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### zhuoliu_lieqi

| 实体 | 出现位置 |
|------|---------|
| 浊流 (FACTION_ZHUOLIU) | universal_tags; background_context; ai_persona |

**缺失实体 (14):** 
清流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### zhuoliu_zuanying

| 实体 | 出现位置 |
|------|---------|
| 浊流 (FACTION_ZHUOLIU) | universal_tags |
| 清流 (FACTION_QINGLIU) | background_context |
| 掮客 (IDENTITY_BROKER) | dim:zuanying_scenario/val.id=dinner_party_broker |

**缺失实体 (12):** 
县尉, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


#### zize

**缺失实体 (15):** 
浊流, 清流, 县尉, 掮客, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵, 门子, 集贤院学士, 李灵甫, 李白, 王维, 郑虔, 高适


### 2.2 Config × 实体 覆盖矩阵

| Config \ 实体 | 高适 | 王维 | 郑虔 | 李白 | 李灵甫 | 清流 | 浊流 | 清流主 | 集贤院 | 县尉 | 掮客 | 紫袍胖 | 清客 | 门子 | 浊流官 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bai_ye_real_appearance | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| duotai_humiliation | — | — | — | — | — | — | — | — | — | — | — | — | — | ✓ | — |
| kuangke_qingliu | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | — | — | — | — | — | — | — | — |
| kuangke_zhuoliu | — | — | — | — | — | ✓ | ✓ | — | — | — | — | — | — | — | — |
| qingliu_daoxin_posui | — | — | — | — | — | ✓ | — | — | — | — | — | — | — | — | — |
| qingliu_fengying | — | — | — | — | — | ✓ | — | — | — | — | — | — | — | — | — |
| qingliu_jiaolv | — | — | — | ✓ | — | ✓ | — | — | — | — | — | — | — | — | — |
| qingliu_passive_benefits | ✓ | ✓ | ✓ | ✓ | — | ✓ | — | — | — | — | — | — | — | — | — |
| qingliu_zuanying | — | — | — | — | — | ✓ | ✓ | — | — | — | — | — | — | — | — |
| scene_imagery | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| zhuoliu_fengying | — | — | — | — | — | ✓ | ✓ | — | — | — | — | — | — | — | — |
| zhuoliu_lieqi | — | — | — | — | — | — | ✓ | — | — | — | — | — | — | — | — |
| zhuoliu_zuanying | — | — | — | — | — | ✓ | ✓ | — | — | — | ✓ | — | — | — | — |
| zize | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |

## 3. CSV 事件分布

### duotai_humiliation (共 108 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 门子 (IDENTITY_MENZI) | 10 | 9.3% |
| 清客 (IDENTITY_QINGKE) | 1 | 0.9% |
| 郑虔 (NPC_ZHENGQIAN) | 1 | 0.9% |

### kuangke_qingliu (共 16 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 高适 (NPC_GAOSHI) | 3 | 18.8% |
| 李白 (NPC_LIBAI) | 2 | 12.5% |
| 郑虔 (NPC_ZHENGQIAN) | 2 | 12.5% |
| 王维 (NPC_WANGWEI) | 1 | 6.2% |

### kuangke_zhuoliu (共 24 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 浊流 (FACTION_ZHUOLIU) | 1 | 4.2% |
| 清客 (IDENTITY_QINGKE) | 1 | 4.2% |

### qingliu_daoxin_posui (共 20 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 清客 (IDENTITY_QINGKE) | 1 | 5.0% |
| 门子 (IDENTITY_MENZI) | 1 | 5.0% |

### qingliu_fengying (共 24 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 门子 (IDENTITY_MENZI) | 1 | 4.2% |

### qingliu_jiaolv (共 8 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 县尉 (IDENTITY_COUNTY_SHERIFF) | 1 | 12.5% |

### qingliu_passive_benefits (共 32 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 郑虔 (NPC_ZHENGQIAN) | 2 | 6.2% |
| 高适 (NPC_GAOSHI) | 2 | 6.2% |
| 李白 (NPC_LIBAI) | 1 | 3.1% |
| 王维 (NPC_WANGWEI) | 1 | 3.1% |

### qingliu_zuanying (共 24 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 清流 (FACTION_QINGLIU) | 3 | 12.5% |
| 清流主人 (IDENTITY_QINGLIU_OWNER) | 1 | 4.2% |

### zhuoliu_fengying (共 24 事件)

*无实体提及*


### zhuoliu_lieqi (共 20 事件)

| 实体 | 出现次数 | 覆盖率 |
|------|---------|--------|
| 浊流 (FACTION_ZHUOLIU) | 1 | 5.0% |

### zhuoliu_zuanying (共 24 事件)

*无实体提及*


### zize (共 12 事件)

*无实体提及*


## 4. Sandbox 提及情况

| Sandbox 文件 | 提及的实体 |
|-------------|-----------|
| bai_ye_real_appearance_sandbox | 门子 |
| duotai_humiliation_sandbox | 王维, 清客, 门子 |
| kuangke_qingliu_sandbox | 高适, 王维, 郑虔, 李白 |
| kuangke_zhuoliu_sandbox | 清客, 门子 |
| qingliu_daoxin_posui_sandbox | 清客, 门子 |
| qingliu_fengying_sandbox | 清客, 门子 |
| qingliu_jiaolv_sandbox | *(无)* |
| qingliu_passive_benefits_sandbox | 高适, 王维, 郑虔, 李白 |
| qingliu_zuanying_sandbox | 清流, 清流主人 |
| scene_imagery_sandbox | *(无)* |
| zhuoliu_fengying_sandbox | 县尉 |
| zhuoliu_lieqi_sandbox | 王维, 浊流 |
| zhuoliu_zuanying_sandbox | 清客, 门子 |
| zize_sandbox | *(无)* |

## 5. 总结与建议

### 5.1 充分覆盖的实体

*没有任何一个实体在所有 Config 中都有提及。*


### 5.2 需要添加 TARGET tag 的实体

| 实体 | 预期 tag |
|------|---------|
| 高适 | `TARGET_NPC_GAOSHI` |
| 郑虔 | `TARGET_NPC_ZHENGQIAN` |
| 李灵甫 | `TARGET_NPC_LILINFU` |

### 5.3 身份类实体分析

身份类实体（identity）不使用 TARGET tag，而应通过 `virtual_dimension_ids` 或 `AI_PERSONA`/`BACKGROUND_CONTEXT` 注入。

| 身份实体 | 在 Config 中出现次数 | 在 CSV 中出现总次数 | 建议 |
|---------|---------------------|-------------------|------|
| 清流主人 (IDENTITY_QINGLIU_OWNER) | 0/14 | 1 | ⚠️ 未在任何 Config 中出现，建议添加 |
| 集贤院学士 (IDENTITY_JIXIAN_ACADEMIC) | 0/14 | 0 | ⚠️ 未在任何 Config 中出现，建议添加 |
| 县尉 (IDENTITY_COUNTY_SHERIFF) | 0/14 | 1 | ⚠️ 未在任何 Config 中出现，建议添加 |
| 掮客 (IDENTITY_BROKER) | 1/14 | 0 | 仅出现在 Config 文本中 |
| 紫袍胖子权贵 (IDENTITY_PURPLE_ROBE_NOBLE) | 0/14 | 0 | ⚠️ 未在任何 Config 中出现，建议添加 |
| 清客 (IDENTITY_QINGKE) | 0/14 | 3 | ⚠️ 未在任何 Config 中出现，建议添加 |
| 门子 (IDENTITY_MENZI) | 1/14 | 12 | 已在 CSV 中有实际出现 |
| 浊流官僚 (IDENTITY_ZHUOLIU_OFFICIAL) | 0/14 | 0 | ⚠️ 未在任何 Config 中出现，建议添加 |

### 5.4 建议优先处理的 Config

| Config | 缺失实体数 | 缺失列表 | 建议操作 |
|--------|-----------|---------|---------|
| event_base_config_bai_ye_real_appearance.json | 15 | 浊流, 清流, 县尉, 掮客, 浊流官僚 +10 more | 补充 dimensions 或 universal_tags |
| event_base_config_duotai_humiliation.json | 14 | 浊流, 清流, 县尉, 掮客, 浊流官僚 +9 more | 补充 dimensions 或 universal_tags |
| event_base_config_kuangke_qingliu.json | 10 | 浊流, 县尉, 掮客, 浊流官僚, 清客 +5 more | 补充 dimensions 或 universal_tags |
| event_base_config_kuangke_zhuoliu.json | 13 | 县尉, 掮客, 浊流官僚, 清客, 清流主人 +8 more | 补充 dimensions 或 universal_tags |
| event_base_config_qingliu_daoxin_posui.json | 14 | 浊流, 县尉, 掮客, 浊流官僚, 清客 +9 more | 补充 dimensions 或 universal_tags |
| event_base_config_qingliu_fengying.json | 14 | 浊流, 县尉, 掮客, 浊流官僚, 清客 +9 more | 补充 dimensions 或 universal_tags |
| event_base_config_qingliu_jiaolv.json | 13 | 浊流, 县尉, 掮客, 浊流官僚, 清客 +8 more | 补充 dimensions 或 universal_tags |
| event_base_config_qingliu_passive_benefits.json | 10 | 浊流, 县尉, 掮客, 浊流官僚, 清客 +5 more | 补充 dimensions 或 universal_tags |
| event_base_config_qingliu_zuanying.json | 13 | 县尉, 掮客, 浊流官僚, 清客, 清流主人 +8 more | 补充 dimensions 或 universal_tags |
| event_base_config_scene_imagery.json | 15 | 浊流, 清流, 县尉, 掮客, 浊流官僚 +10 more | 补充 dimensions 或 universal_tags |
| event_base_config_zhuoliu_fengying.json | 13 | 县尉, 掮客, 浊流官僚, 清客, 清流主人 +8 more | 补充 dimensions 或 universal_tags |
| event_base_config_zhuoliu_lieqi.json | 14 | 清流, 县尉, 掮客, 浊流官僚, 清客 +9 more | 补充 dimensions 或 universal_tags |
| event_base_config_zhuoliu_zuanying.json | 12 | 县尉, 浊流官僚, 清客, 清流主人, 紫袍胖子权贵 +7 more | 补充 dimensions 或 universal_tags |
| event_base_config_zize.json | 15 | 浊流, 清流, 县尉, 掮客, 浊流官僚 +10 more | 补充 dimensions 或 universal_tags |

---

*报告由 `analysis_entity_distribution.py` 自动生成*
