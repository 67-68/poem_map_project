# persistant_tags — TagManager 持久化 Tag 管理

## 文件
- `core/tag_manager.gd` — **新增** TagManager 类（RefCounted），负责 NPC 相识 tag + 诗风站队 tag 的增删
- `core/player_state.gd` — `_ready()` 中实例化 TagManager → init → full_sync；`persistant_tags` / `_rebuild_persistant_tags()` 已有
- `core/model/game_save_data.gd` — `persistant_tags: Array[String]` + to_dict/from_dict 序列化（已有）
- `core/model/action_tag_filter.gd` — `current_action_tags` → `PlayerState.get_all_action_tags()`（已有）
- `core/operators/poem_reward_operator.gd` — 先删 `created_poems` 再 `remove_trait`，确保 TagManager 统计时序正确

## 想要实现的效果

### 规则 1：NPC 相识 Tag

当玩家认识某个 NPC（`person_state` 进入 `know_about` / `inner_circle` / `blood_oath`）时，自动在 `persistant_tags` 中追加 `actor:npc:{target_tag}`。退回到 `not_meet` / `uncharted` 时自动移除。

### 规则 2：诗风站队 Tag（三态互斥）

每当 `created_poems` 变动（新增/删除诗词），统计 `Poem.intent` 的 `official`（干谒）vs `literary`（登高）数量：

```
official > literary  → "浊流诗人" tag: actor:poem:stance:zhuoliu
literary > official  → "清流诗人" tag: actor:poem:stance:qingliu
official == literary → "中立诗人" tag: actor:poem:stance:neutral
无诗创作             → 删除所有 stance tag（不放任何 tag）
```

三态互斥：每次计算后先清除所有已有 stance tag，再放入当前对应的一个。

## 状态转换

```
NPC 相识:
  RelationFlagManager.set_person_state(target, "know_about")
    → EventBus.on_person_state_changed.emit(target, "know_about")
    → TagManager._on_person_state_changed()
    → persistant_tags 追加 actor:npc:{target}

  退回 not_meet/uncharted:
    → EventBus.on_person_state_changed.emit(target, "not_meet")
    → TagManager._on_person_state_changed()
    → persistant_tags 移除 actor:npc:{target}

诗风站队:
  PoemCrafter._on_button_pressed()
    → PlayerState.created_poems.append(poem)
    → PlayerState.add_trait(poem.uuid)
    → _rebuild_persistant_tags() (trait tags)
    → EventBus.on_trait_change.emit()
    → TagManager._on_trait_change()
    → _sync_poem_stance() → 替换 stance tag

  PoemRewardOperator.operate()
    → PlayerState.created_poems.remove_at(idx)  ← 先删！
    → PlayerState.remove_trait(poem.uuid)
    → EventBus.on_trait_change.emit()
    → TagManager._on_trait_change()
    → _sync_poem_stance() → 重新计算 stance tag

初始化 (PlayerState._ready):
  init_npc_person_states()
  → TagManager.new() → init() (connect signals) → full_sync()
    → _sync_npc_tags()  — 遍历 RELATION_TARGET 补上已相识 NPC tag
    → _sync_poem_stance() — 遍历 created_poems 计算 stance tag
```

## 技术架构

```
TagManager (RefCounted, 非 autoload)
  │  init() ──→ connect EventBus.on_person_state_changed
  │          ──→ connect EventBus.on_trait_change
  │  full_sync() ──→ _sync_npc_tags() + _sync_poem_stance()
  │
  ├──_on_person_state_changed(target, state)
  │     └→ persistant_tags += / -= actor:npc:{target}
  │
  └──_on_trait_change()
        └→ _sync_poem_stance()
             └→ 统计 Poem.intent → _replace_stance_tag()

persistant_tags (GameSave.data)  ← TagManager 增量/替换写入
                                    ↑
                          get_all_action_tags() 合并 persistant + transient
                                    ↓
                          ActionTagFilter.filter()
```

## 注意事项
- `TagManager` 为 `RefCounted` 非 autoload，由 `PlayerState._ready()` 实例化为局部变量，靠 EventBus 信号维持活性。
- 全量同步（`full_sync`）仅在 `_ready` 时调用一次。后续所有更新通过信号驱动增量。
- `PoemRewardOperator` 必须先删 `created_poems` 再调 `remove_trait`，否则 `on_trait_change` 信号触发时 TagManager 统计到已删除的诗词。
- `init_npc_person_states()` 直接操作 `doc.person_state`，不经过 `RelationFlagManager.set_person_state()`，因此不发射 `on_person_state_changed`——必须靠 `full_sync()` 补上初始化时的 NPC tag。
- stance tag 三态互斥使用「先全删再放入」策略，避免脏数据残留。
- 所有 tag 遵循四段式 `domain:category:type:specific` 格式。
