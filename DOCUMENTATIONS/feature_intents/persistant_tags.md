# persistant_tags — Trait 持久化 Tag 参与事件匹配

## 文件
- `core/model/game_save_data.gd` — 新增 `persistant_tags: Array[String]` + to_dict/from_dict 序列化
- `core/player_state.gd` — 新增 `persistant_tags` 属性（代理到 GameSave）、`get_all_action_tags()`、`_rebuild_persistant_tags()`，hook `add_trait`/`remove_trait`/`_ready`
- `core/model/action_tag_filter.gd` — `current_action_tags` → `PlayerState.get_all_action_tags()`

## 想要实现的效果

当玩家拥有某个 trait 时，该 trait 的 `tags` 字段中的 tag 可以**持续参与**每次行动后的事件匹配（`ActionTagFilter.filter()`），不需要每次行动时重新注入。

### 典型用例
- 玩家获得 `disease_dongshang_frostbite` → 该 trait 携带 tag `actor:status:disease:frostbite` → 此后每次事件扫描都会匹配到需要此 tag 的冻伤相关事件
- 玩家失去此 trait → 该 tag 立即从匹配池中移除

## 状态转换

```
add_trait(trait_uuid)
  → traits.append()
  → _rebuild_persistant_tags()  # 遍历所有 traits → Database.get_trait().tags → 去重汇合
  → on_trait_change

remove_trait(trait_uuid)
  → traits.erase()
  → _rebuild_persistant_tags()
  → on_trait_change

ActionTagFilter.filter()
  → current_tags = PlayerState.get_all_action_tags()  # transient + persistant 去重合并
  → 事件匹配 ...
  → PlayerState.current_action_tags.clear()  # 只清 transient，persistant 不受影响
```

## 技术架构

```
persistant_tags (GameSave.data)  ← _rebuild_persistant_tags() 全量重建
                                       ↑
                              add_trait / remove_trait / _ready

get_all_action_tags()  ←  合并 persistant_tags + current_action_tags
        ↓
ActionTagFilter.filter()
```

## 注意事项
- `persistant_tags` 全量重建而非增量同步，避免脏数据。traits < 20，O(n) 开销可忽略。
- `persistant_tags` 可持久化到存档，读档后自动恢复，但 `_ready` 中仍会重建确保一致性。
- Trait 的 `tags` 字段继承自 `GameEntity`，目前 CSV 中 trait 没有 tags 列，管线已就绪，数据后续补。
- `current_action_tags` 的 getter 保持不变（返回 GameSave 底层数组引用），确保 `.append()` / `.clear()` 语义不被破坏。
