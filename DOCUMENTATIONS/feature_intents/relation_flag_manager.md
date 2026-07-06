# RelationFlagManager — person_state 人物状态迁移

## 设计意图

将人物关系状态（HEARD → GOOD → CORE → HATE）从 Trait 系统完全迁移到 RelationFlagManager 的 person_state str flag 机制。

### 动机

1. **语义混淆**：Trait 的本职是「人物身上的持续效果/标签」（中毒、崴脚），用它表示「与某人的认识程度」是对 trait 系统的滥用
2. **O(N×4) 膨胀**：12 个 RELATION_TARGET × 4 状态 = 48 个 trait，新增 NPC 需配 4 行
3. **数据分散**：好感度(favor)已在 RelationFlagManager，关系状态却在 trait，查询需跨两个系统

### 状态机

```
not_meet ──(引入事件触发)──→ know_about
                                │
                    (未来扩展)   ├── good_terms
                                ├── close
                                └── hostile
```

## 变更清单

### 修改文件

| 文件 | 变更 |
|------|------|
| [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd) | 新增 PERSON_STATE dict + FLAG_PREFIX_PERSON_STATE + 5 个 API 方法 |
| [`core/model/trait.gd`](core/model/trait.gd) | topic 移除 RELATION 枚举项；specific_topic 移除 HATE/HEARD/GOOD/CORE |
| [`core/source_of_truth.gd`](core/source_of_truth.gd) | 移除 `"LIBAI": 'relation_libai_rumor'` 调试初始化 |
| [`data/1_core_rules/traits/_traits.csv`](data/1_core_rules/traits/_traits.csv) | 删除 46 行 RELATION topic traits |
| [`data/1_core_rules/state_transistors/_state_transistor.csv`](data/1_core_rules/state_transistors/_state_transistor.csv) | 删除 `relation_libai_rumor_transist_close` 行 |

### 保留字段

- `Trait._relate_to: ENUMS.RELATION_TARGET` — 保留，未来非 RELATION trait 可能仍需 NPC 关联
- `Trait.relate_to: String` — 同上
- `dsl_parser.gd parse_trait()` 中 `relate_to` 解析 — 保留，通用字段

## API

```gdscript
# Dict 模拟 Enum（仅允许 str 值）
RelationFlagManager.PERSON_STATE.NOT_MEET    # → "not_meet"
RelationFlagManager.PERSON_STATE.KNOW_ABOUT  # → "know_about"

# CRUD
RelationFlagManager.get_person_state("libai")        # → "not_meet" | "know_about"
RelationFlagManager.set_person_state("libai", RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
RelationFlagManager.is_person_state("libai", RelationFlagManager.PERSON_STATE.KNOW_ABOUT)  # → bool
RelationFlagManager.get_known_targets()               # → Array[String] 所有 ≥ know_about
RelationFlagManager.has_person_state_flag("libai")    # → bool 不触发懒初始化
RelationFlagManager.clear_person_state("libai")        # 重置为未初始化
```

## 底层存储

- flag_id：`flag_gen_person_state_{TARGET_TAG}`
- 类型：str virtual flag
- 默认值：`"not_meet"`（懒初始化）
- 校验：`_is_valid_person_state()` 拒绝非法值写入
