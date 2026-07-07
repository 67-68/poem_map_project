# RelationFlagManager — v3: NPCDocument 属性驱动重构

## 设计意图

将 RelationFlagManager 的全部 5 种关系数据（leverage / help / favor / person_state / intro）从 PlayerState virtual flag 机制迁移到 NPCDocument 的 @export 属性。

### 动机

1. **flag 污染**：每个 target 产生 5 个 `flag_gen_*_{TARGET_TAG}`，12 个 target = 60 个虚拟 flag，污染 flag 命名空间且与正常 flag 混淆
2. **数据归属不清**：关系数据本质上是 NPC/目标自身的属性，却存在 PlayerState.flags 全局字典中
3. **持久化脆弱**：flag 机制依赖 `register_virtual_flag` 懒注册，且 flag type 校验路径过长
4. **语义清晰**：NPCDocument 本身就是"关于某个 NPC/目标的文档"，关系数据天然应该附着于此

### 数据流

```
写入: Operator → RelationFlagManager (API 不变) → NPCDocument.属性
读取: UI/Requirement → RelationFlagManager (API 不变) → NPCDocument.属性
持久化: GameSaveData._snapshot_npc_relations() → to_dict() → JSON
        GameSaveData.restore_npc_relations_to_documents() ← from_dict() ← JSON
```

对于没有 .tres 文件的 target（如身份/群体），`_get_or_create_npc_doc()` 动态创建 NPCDocument 并注册到 `Database.npc_document`。

## 变更清单

### 修改文件

| 文件 | 变更 |
|------|------|
| [`model/npc_document.gd`](model/npc_document.gd) | 新增 5 个 @export 属性：leverage_keys, help_count, favor, person_state, intro_keys |
| [`core/model/game_save_data.gd`](core/model/game_save_data.gd) | 新增 npc_relations 字典 + to_dict()/from_dict() 序列化 + restore_npc_relations_to_documents() / _snapshot_npc_relations() |
| [`core/relation_flag_manager.gd`](core/relation_flag_manager.gd) | 全部内部实现从 flag 读写切换到 NPCDocument 属性读写；删除 FLAG_PREFIX_* / VIRTUAL_FLAG_TYPE_* 常量；删除 _build_flag_id() / _ensure_virtual_flag()；新增 _get_or_create_npc_doc() |
| [`tests/test_relation_flag_manager.gd`](tests/test_relation_flag_manager.gd) | before_each() 适配：清理 Database.npc_document 代替清理 PlayerState.flags |

### 未修改（调用方零改动）

所有 Operator、UI、Resolver 的调用代码**完全不变**，因为 RelationFlagManager 的公开 API 签名保持一致。

### 保留字段

- `ENUMS.RELATION_TARGET` — 不变
- `ENUMS.to_relation_str()` — 不变
- `RelationFlagManager.PERSON_STATE` dict — 不变
- `RelationFlagManager.RELATION_TARGET_TIER` — 不变

## NPCDocument 新属性

```gdscript
@export var leverage_keys: Array[String] = []   # 原 flag_gen_leverage_{TAG}
@export var help_count: int = 0                  # 原 flag_gen_help_{TAG}
@export var favor: int = 30                      # 原 flag_gen_favor_{TAG}
@export var person_state: String = "not_meet"    # 原 flag_gen_person_state_{TAG}
@export var intro_keys: Array[String] = []       # 原 flag_gen_intro_{TAG}
```

## API

API 签名不变，但底层存储已切换：

```gdscript
# 把柄
RelationFlagManager.add_leverage("libai", "secret_key")
RelationFlagManager.get_leverage_keys("libai")
RelationFlagManager.has_leverage("libai")
RelationFlagManager.consume_leverage("libai", "secret_key")
RelationFlagManager.try_use_leverage("libai")
RelationFlagManager.clear_leverage("libai")

# 帮助
RelationFlagManager.add_help("libai", 2)
RelationFlagManager.get_help("libai")
RelationFlagManager.has_help("libai")
RelationFlagManager.clear_help("libai")

# 好感度
RelationFlagManager.get_favor("libai")          # 懒初始化 → 30
RelationFlagManager.set_favor("libai", 50)
RelationFlagManager.add_favor("libai", 10)

# 人物状态
RelationFlagManager.get_person_state("libai")
RelationFlagManager.set_person_state("libai", RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
RelationFlagManager.is_person_state("libai", RelationFlagManager.PERSON_STATE.KNOW_ABOUT)
RelationFlagManager.get_known_targets()

# 引荐信
RelationFlagManager.add_intro("libai", "intro_key")
RelationFlagManager.get_intro_keys("libai")
RelationFlagManager.has_intro("libai")
RelationFlagManager.consume_intro("libai", "intro_key")

# 聚合查询
RelationFlagManager.get_all_relations(["libai", "hushang"])
```

## 持久化

存档时 `GameSaveData.to_dict()` 调用 `_snapshot_npc_relations()` 从所有已加载的 NPCDocument 实例快照关系数据到 `npc_relations` 字典。

读档时 `GameSaveData.from_dict()` 恢复 `npc_relations`，外部调用方需在 Database 就绪后调用 `GameSaveData.restore_npc_relations_to_documents()` 将快照推回 NPCDocument 实例。

对于动态创建的 NPCDocument（无 .tres），读档时会先通过 `_get_or_create_npc_doc()` 创建空实例，再由 `restore_npc_relations_to_documents()` 填充数据。
