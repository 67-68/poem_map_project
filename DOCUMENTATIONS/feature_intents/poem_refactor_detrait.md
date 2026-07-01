# 诗词系统去 Trait 枚举 + 按钮修复 — 功能意图

**状态**: ✅ 已完成（2026.07.01）

---

## 意图摘要（<200字）

1. 修复"开始创作"按钮因重名节点导致的 Godot 自动信号连接失效
2. **删除 `enumerates.gd` 中 `TRAITS` 枚举的 `POEM_*` 条目**（用 `_RESERVED_01~18` 占位保持整数值稳定）
3. 删除 UUID 末尾提取等级的 hack，改用 `Poem.poem_level` 字段
4. 所有创作的诗词自动追加到 `PlayerState.created_poems`，供墓碑等终局结算使用
5. `PoemRequirement` 和 `trait_choose_operator` 用 `is Poem` 类型判断替代 `topic == "POEM"` 字符串过滤

注意：**Poem 继续继承 Trait**，继续走 `add_trait()`/`get_traits()` 管道用于运行时诗词检测。`created_poems` 仅用于终局结算（墓碑展示）。

---

## 核心玩法

无玩法变化。纯粹的技术债清理：诗词的「类型判断」从字符串匹配升级为类型系统守卫。

---

## 涉及文件（实际改动）

| 文件 | 改动 |
|------|------|
| [`model/enumerates.gd`](model/enumerates.gd) | TRAITS 枚举 18 个 `POEM_*` → `_RESERVED_01~18` |
| [`core/source_of_truth.gd`](core/source_of_truth.gd) | 删除 `action_tracks` 中 3 条 poem 映射 |
| [`data/1_core_rules/traits/poem_*.tres`](data/1_core_rules/traits/) | 删除 9 个预置诗词 trait 文件 |
| [`data/tests/poem_events/test_s5_poem_choose.tres`](data/tests/poem_events/) | 删除 |
| [`ui/poem_crafter.tscn`](ui/poem_crafter.tscn) | `Button` → `CraftBtn` |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd) | `_ready()` 手动连接 + 创作成功时 `created_poems.append(poem)` |
| [`core/requirements/poem_requirement.gd`](core/requirements/poem_requirement.gd) | `topic != "POEM"` → `not (trait_data is Poem)`；UUID 解析 → `trait_data.poem_level` |
| [`core/operators/trait_choose_operator.gd`](core/operators/trait_choose_operator.gd) | 同上 |
| [`core/player_state.gd`](core/player_state.gd) | `created_poems: Array[String]` → `Array` |
| [`ui/tomb_stone_screen.gd`](ui/tomb_stone_screen.gd) | 适配 Poem 对象迭代 |
| [`tests/test_poem_crafting_comprehensive.gd`](tests/test_poem_crafting_comprehensive.gd) | 测试中补充 `Database.traits` 注册 |
| [`tools/generate_test_poem_events.gd`](tools/generate_test_poem_events.gd) | 动态创建 Poem 替代硬编码 trait UUID |

---

## 架构决策

- **Poem 继续继承 Trait**：保持 `add_trait()`/`get_traits()` 管道用于运行时诗词检测
- **类型判断：`is Poem` 替代 `topic == "POEM"`**：类型系统守卫比字符串过滤更安全
- **等级读取：`poem_level` 字段替代 UUID 解析**：Poem 创建时由 `PoemCraftingCalculator` 计算写入
- **`TRAITS` 枚举：占位符替代删除**：`_RESERVED_01~18` 保持后续枚举整数值不变，避免破坏 .tres 文件中的整型引用
- **`created_poems`：终局结算专用**：追加写入不替代 Trait 管道，墓碑界面读取展示
