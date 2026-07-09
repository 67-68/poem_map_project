# npc_place_picker

## 涉及文件
- [`model/npc_document.gd`](model/npc_document.gd) — 新增 `preferred_places: Array[String]` 字段
- `data/2_characters/npc_docs/*.tres` — 已有 NPC 补充 preferred_places 数据
- `core/operators/pick_npc_by_place_operator.gd` — 新建 Operator
- [`parser/micro_dsl_parser.gd`](parser/micro_dsl_parser.gd) — 注册新 DSL 解析

## 设计意图

### 1. NPCDocument.preferred_places
每个 NPC 带有自己偏好的出现地点列表。值来自 [`CHANGAN_PLACES`](model/enumerates.gd:75) 的 str key：`"xishi"` / `"pingkangfang"` / `"huangcheng"`。为一个数组，因为一个 NPC 可以出现在多个地点（如李白既可以在平康坊交游，也可以在皇城奉诏时出现）。

该字段由策划在 .tres 文件中手工填写。对于没有 .tres 动态创建的 NPCDocument（如 hushang, qingliu 等），`preferred_places` 默认为空数组，此时该 NPC 不会被任何地点匹配到。

### 2. PickNpcByPlaceOperator
在事件的 `on_enter` / `init` 阶段使用，根据**当前玩家驻留地点**（`PlayerState.stay_place`）筛选匹配的 NPC，再按可选参数 `state` 过滤 `person_state`，随机选一个存入 context。

- **选择阶段在 `init()` 完成**（参考 [`RandomPickOperator`](core/operators/random_pick_operator.gd:1) 的设计模式）
- `operate()` 为空操作
- 若没有符合条件的 NPC，写入 warning 日志 + context 置空，不阻断事件流程

### 3. 数据流
```
事件 on_enter / event_result.init()
  → PickNpcByPlaceOperator.init(context)
    1. 读取 PlayerState.stay_place → current_place
    2. 遍历 Database.npc_document 所有 NPCDocument
    3. 过滤：doc.preferred_places 包含 current_place
    4. 若 state 参数非空：过滤 doc.person_state == state
    5. 随机选一个 → npc_tag (如 "libai")
    6. context[key_stored_context] = npc_tag
  → ItemProvider 或其他下游逻辑读取 context["npc_target"]
```
