# Lock / Reserve / Block Operator 家族

## 问题描述

有些游戏流程需要"锁住"某个行动，迫使玩家执行它；在某个故事节点之后再"释放"——但该行动仍然需要每回合保证出现（reserve），只是不再阻止其他行动。

反之，有些场景需要"阻塞"某个行动，让它**暂时不可用**（比如角色受伤后不能练武），等到条件满足后再恢复。

本系统提供了两对互斥的操作符（Operator）来管理行动的出现/隐藏逻辑，以及一个便捷的组合操作符（FocusActionOperator）。

---

## 一、数据模型：三种独立机制

[`ActionManager`](../core/action_manager.gd) 维护**三种互相独立**的数据结构：

| 机制 | 数据结构 | 持久性 | 作用 | 清空时机 |
|------|---------|--------|------|---------|
| `_reserved_action_ids` | `Array[String]` | **本回合** | 即时预留，确保本回合必定出现 | `pick_top_actions()` 后自动 `clear_reservations()` |
| `_locked_in_actions` | `Dictionary[action_id xun_duration]` | **跨回合** | 持久锁定，每回合自动触发 `reserve_action()` | `unlock_action()` 或 `process_xun_tick()` 到期 |
| `_blocked_actions` | `Dictionary[action_id xun_duration]` | **跨回合** | 持久阻塞，每次 `get_available_scene_actions()` 时过滤掉 | `unblock_action()` 或 `process_xun_tick()` 到期 |

### 三种机制的关系图

```
get_available_scene_actions()
│
├── 1. _locked_in_actions 遍历
│     └── 对每个 locked action 调用 reserve_action()
│
├── 2. _blocked_actions 遍历
│     └── 如果被 blocked 的 action 在 _reserved 中，移除
│
├── 3. 遍历 Database.actions（跳过 _blocked 中的）
│     └── 需求检查 + 标签匹配
│
└── 4. pick_top_actions()
      ├── Phase 1: 先取出所有 reserved actions
      ├── Phase 2: 随机权重填充剩余席位
      └── 自动 clear_reservations()
```

---

## 二、`_reserved_action_ids` 数据流全貌

这是整个系统的核心数据管道。所有修改操作都集中在 [`core/action_manager.gd`](../core/action_manager.gd) 中：

```
_reserved_action_ids 的 CRUD：
│
├── 追加 append
│   ├── reserve_action(action_id)              [line 34]
│   │   ├── 被 lock_action() 调用              [line 81]
│   │   │   └── lock 时本回合立即生效
│   │   ├── 被 get_available_scene_actions() 调用  [line 181]
│   │   │   └── 每旬自动为 locked actions 预留
│   │   └── ❌ 没有公开的 Operator 直接调用它
│   │
│   └── （无其他追加入口）
│
├── 移除单条 erase
│   ├── unreserve_action(action_id)            [line 41]
│   │   └── 被 block_action() 调用              [line 105]
│   │       └── block 时立即移除预留
│   └── get_available_scene_actions()           [line 189]
│       └── blocked 过滤误预留
│
└── 清空 clear
    └── clear_reservations()                   [line 46]
        └── 被 pick_top_actions() 末尾自动调用    [line 295]
            └── 抽取完成自动清空，防跨回合污染
```

### 关键发现

**没有任何 Operator 直接调用 `reserve_action()`。** 现有的两条写入路径都是间接的：
- `LockActionsOperator` → `lock_action()` → `reserve_action()` — 但这也锁住了 UI
- 每旬 `get_available_scene_actions()` → `reserve_action()` — 这只是对已 locked actions 的维护

**如果需要"塞一个 action 到面板但不锁定其他行动"（纯即时预留），答案是：目前没有对应的 Operator。**

---

## 三、Operator 家族总览

### 3.1 现有 Operator

#### [`LockActionsOperator`](../core/operators/lock_actions_operator.gd) — 锁住行动，强制出现

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_types` | `Array[ENUMS.ACTION_TYPE]` | 要锁定的行动枚举值列表 |
| `xun_duration` | `int` | 持续旬数，-1 = 无限期 |

**operate() 流程：**

```
LockActionsOperator.operate()
  ├── ActionManager.lock_action(at, xun_duration)
  │     ├── 冲突解决：如果已被 blocked 移除 blocked
  │     ├── 写入 _locked_in_actions[action_id] = xun_duration
  │     └── 本回合立即生效：reserve_action(action_id)
  ├── 收集所有 locked SceneAction
  ├── EventBus.selected_actions_change.emit()   UI 刷新
  └── EventBus.locked_actions_selected.emit()   按钮闪光
```

**效果**：锁定后的行动在锁定期间**必定出现在6格行动面板中**，其他行动被隐藏。

**副作用**：触发 `locked_actions_selected` 信号，ActionMap 会禁用其他按钮。

#### [`BlockActionOperator`](../core/operators/block_action_operator.gd) — 阻塞行动，阻止出现

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_types` | `Array[ENUMS.ACTION_TYPE]` | 要阻塞的行动枚举值列表 |
| `xun_duration` | `int` | 持续旬数，-1 = 无限期 |

**operate() 流程：**

```
BlockActionOperator.operate()
  ├── ActionManager.block_action(at, xun_duration)
  │     ├── 冲突解决：如果已被 locked 移除 locked
  │     ├── 写入 _blocked_actions[action_id] = xun_duration
  │     └── 本回合立即生效：unreserve_action(action_id)
  └── EventBus.selected_actions_change.emit([])   UI 刷新
```

**效果**：阻塞后的行动在阻塞期间**绝对不会出现在可用列表中**。

#### [`FocusActionOperator`](../core/operators/focus_action_operator.gd) — 聚焦行动（Lock + Block 语义糖）

| 参数 | 类型 | 说明 |
|------|------|------|
| `action_types` | `Array[ENUMS.ACTION_TYPE]` | 聚焦的行动枚举值列表 |
| `click_count` | `int` | 聚焦持续点击次数，到期后自动解除并刷新行动列表 |

**语义**：Focus = Lock(指定) + Block(其余全部)，按**点击次数**（非旬）计。点击 N 次聚焦 action 后自动释放。

**operate() 流程：**

```
FocusActionOperator.operate()
  └── ActionManager.start_focus_session(action_types, click_count)
        ├── 1. Block 所有非聚焦 action（先 block，-1 无限期）
        ├── 2. Lock 所有聚焦 action（后 lock，冲突解除）
        ├── 3. 记录 _focus_action_ids + _focus_click_remaining
        ├── 4. 发射 selected_actions_change
        └── 5. 发射 locked_actions_selected（按钮闪光）
```

**点击后递减（由 [`action_button.gd`](../ui/action_button.gd) 驱动）：**

```
action_button.gd::_on_button_pressed()
  └── ActionManager.on_focus_action_clicked()
        ├── _focus_click_remaining -= 1
        └── 如果归零 → _end_focus_session()
              ├── unlock_action() for each focus
              ├── unblock_action() for each other
              ├── _focus_action_ids.clear()
              └── EventBus.request_refresh_action_panel.emit()  ← 刷新行动列表
```

**效果**：
- 聚焦的行动**必定出现在6格行动面板中**，其他行动全部被阻塞
- UI 锁定：ActionMap 禁用非聚焦按钮，聚焦按钮闪光
- 点击 `click_count` 次聚焦 action 后自动解除 lock/block 并刷新 UI

**与 LockActionsOperator 的关键区别：**

| 维度 | LockActionsOperator | FocusActionOperator |
|------|-------------------|---------------------|
| 计数方式 | 旬（xun） | **点击次数** |
| 非指定 action | 照常随机抽取 | **全部 Block** |
| 底层操作 | 仅 Lock | Block(others) + Lock(focus) |
| 解除触发 | process_xun_tick() 递减 | 每次点击自动递减 → 归零释放 |
| 适用场景 | 限时强制出现 | 聚光灯模式（限制执行次数） |

---

### 3.2 缺失的 Operator（待实现）

> 以下 Operator 目前不存在，但 ActionManager 已有对应的底层方法。

#### ReserveActionOperator — 纯即时预留（不锁 UI）

```
@tool
class_name ReserveActionOperator extends BaseOperator

## 要即时预留的行动 ID（是 action_id 字符串，如 "bai_ye"，不是枚举值）
## 注意：这是纯本回合生效，抽取后自动清空，不锁定 UI。
@export var action_ids: Array[String] = []

func operate():
  for action_id in action_ids:
    ActionManager.reserve_action(action_id)
  # 预留后需要刷新 UI 才能看到变化
  EventBus.request_refresh_action_panel.emit()
```

**与 `LockActionsOperator` 的关键区别：**

| 维度 | LockActionsOperator | ReserveActionOperator |
|------|-------------------|---------------------|
| 持久性 | 跨回合（直到 unlock 或到期） | 本回合（pick 后自动清空） |
| UI 锁定 | 禁用其他按钮，闪光 | 不锁定，其他按钮正常 |
| 底层调用 | `lock_action()` → `_locked_in_actions` + `reserve_action()` | 仅 `reserve_action()` |
| 参数类型 | `ENUMS.ACTION_TYPE` 枚举 | `String` action_id |

#### UnlockActionsOperator

```
@tool
class_name UnlockActionsOperator extends BaseOperator

@export var action_types: Array[ENUMS.ACTION_TYPE] = []

func operate():
  for at in action_types:
    ActionManager.unlock_action(at)
  EventBus.request_refresh_action_panel.emit()
```

#### UnblockActionsOperator

```
@tool
class_name UnblockActionsOperator extends BaseOperator

@export var action_types: Array[ENUMS.ACTION_TYPE] = []

func operate():
  for at in action_types:
    ActionManager.unblock_action(at)
  EventBus.request_refresh_action_panel.emit()
```

---

### 3.3 UI 刷新 Operator

#### [`RefreshActionPanelOperator`](../core/operators/refresh_action_panel_operator.gd) — 请求 UI 刷新

| 参数 | 类型 | 说明 |
|------|------|------|
| （无） | — | 纯粹触发信号，不做数据修改 |

**operate() 流程：**

```
RefreshActionPanelOperator.operate()
  └── EventBus.request_refresh_action_panel.emit()
      └── SceneActionScroll.refresh()
          ├── ActionManager.get_available_scene_actions()
          │   └── _locked_in  auto-reserve each round
          ├── ActionManager.pick_top_actions()   [6 actions]
          └── EventBus.selected_actions_change (all 6)
              └── ActionMap._on_selected_actions_changed
                  └── 启用所有匹配按钮
```

**适用场景**：
- 事件链结束后恢复 UI（例如 `LockActionsOperator` 锁住后，到某个节点只需要刷新 UI 而不需要改数据）
- 纯视觉恢复，不改变 `_locked_in_actions` / `_blocked_actions` 中的数据

---

### 3.4 辅助方法（ActionManager 层）

| 方法 | 作用 |
|------|------|
| [`reserve_action(action_id)`](../core/action_manager.gd:21) | 即时预留单个 action（Array 级，本回合有效） |
| [`unreserve_action(action_id)`](../core/action_manager.gd:40) | 取消即时预留 |
| [`clear_reservations()`](../core/action_manager.gd:46) | 清空所有即时预留（`pick_top_actions` 末尾自动调用） |
| [`lock_action(action_type, xun_duration)`](../core/action_manager.gd:65) | 持久锁定（Dictionary 级，跨回合） |
| [`block_action(action_type, xun_duration)`](../core/action_manager.gd:89) | 持久阻塞（Dictionary 级，跨回合） |
| [`unlock_action(action_type)`](../core/action_manager.gd:110) | 手动解锁 |
| [`unblock_action(action_type)`](../core/action_manager.gd:119) | 手动解阻塞 |
| [`is_action_locked(action_type)`](../core/action_manager.gd:127) | 查询是否已锁定 |
| [`is_action_blocked(action_type)`](../core/action_manager.gd:132) | 查询是否已阻塞 |
| [`process_xun_tick()`](../core/action_manager.gd:139) | 每旬结算，递减计数器，到期自动清除 |
| [`action_type_to_id(enum_val)`](../core/action_manager.gd:55) | 枚举值  action_id（如 BAI_YE  "bai_ye"） |

---

## 四、Lock vs Block：对偶关系与冲突解决

### 4.1 概念对比

| 维度 | Lock | Block |
|------|------|-------|
| **语义** | 保证出现 | 阻止出现 |
| **默认优先级** | 后调用的赢（last-write-wins） | 后调用的赢 |
| **生效时机** | `lock_action()` 内部立即 `reserve_action()` | `block_action()` 内部立即 `unreserve_action()` |
| **每旬自动行为** | `get_available_scene_actions()` 头部自动 reserve | `get_available_scene_actions()` 头部自动过滤 |
| **过期机制** | `process_xun_tick()` 递减 | `process_xun_tick()` 递减 |
| **UI 表现** | 闪光（`locked_actions_selected` 信号） | 不显示 |

### 4.2 冲突解决规则

当同一个 action 同时被 lock 和 block 时，**后调用的赢**：

```
时间线：

LockActionsOperator.operate()        # bai_ye 被 locked
  └─ _locked_in_actions["bai_ye"] = -1
  └─ _blocked_actions 中若有  erase

BlockActionOperator.operate()        # bai_ye 被 blocked（后调用，覆盖 lock）
  └─ _blocked_actions["bai_ye"] = -1
  └─ _locked_in_actions 中若有  erase

最终结果：bai_ye 被 blocked，不出现
```

反之亦然：**lock 后调用会解除 block，block 后调用会解除 lock。**

⚠️ **工程警告**：不要在同一个事件链里同时传 lock 和 block 给同一个 action type，你会获得一个"最后一调用者决定"的不确定行为。这不是 bug，但精神正常的人不会这么写 🤡。

---

## 五、使用场景与示例

### 场景 1：主线锁定  两阶段释放

**需求**：主线剧情需要玩家必须选择"拜谒"行动，其他所有按钮禁用。等剧情推进到某个节点后，释放其他按钮，但"拜谒"仍然必须每回合出现在选项中。

```
Phase 1: LockActionsOperator
  action_types = [BAI_YE]
  xun_duration = -1
  只有 bai_ye 可用，按钮禁用，只亮 bai_ye

事件链: intro  ambition_start  first_blood

Phase 2: RefreshActionPanelOperator
  UI 恢复 6 格面板
  bai_ye 仍然在 _locked_in_actions 中
  每回合自动预留 bai_ye（占 1/6）
```

### 场景 2：完全解锁（移除 lock 语义）

**需求**：主线过了之后，"拜谒"应该和其他行动一样参与随机权重抽取，**不再自动预留**。

```
LockActionsOperator (intro 事件)
   ... 事件链 ...
  UnlockActionsOperator (完成解锁事件)   需要实现

    ┌─ ActionManager.unlock_action(BAI_YE)
    │   └─ _locked_in_actions 移除 "bai_ye"
    └─ RefreshActionPanelOperator
        └─ bai_ye 不再自动预留，恢复常规抽取
```

### 场景 3：纯即时预留（不锁定 UI）

**需求**：某个特殊回合必须让"赏花"出现，但其他按钮保持正常可用，也不需要跨回合持久化。

```
ReserveActionOperator   需要实现
  action_ids = ["shang_hua"]
  shang_hua 本回合必定出现在 6 格中
  其他 5 个席位正常随机抽取
  pick_top_actions() 末尾自动 clear_reservations()
  下回合恢复正常（无持久状态）
```

### 场景 4：临时阻塞（角色受伤）

**需求**：玩家受伤后，"饮酒"行动被 blocking，3 旬后自动恢复。

```
BlockActionOperator (受伤事件)
  action_types = [JIU_ZHOU, YIN_JIU]
  xun_duration = 3
  连续 3 旬 "饮酒" 和 "酒筹" 不出现
  3 旬后 process_xun_tick() 自动清除
  恢复可用（无需额外 operator）
```

---

## 六、Operator 选择决策树

```
需要控制行动的出否？
│
├── 需要强制行动出现？
│   ├── 需要 UI 锁定（其他按钮禁用）+ 跨回合持久？
│   │   ├── 只锁定指定行动，其他照常？
│   │   │   └── LockActionsOperator
│   │   │
│   │   └── 锁定指定行动 + 阻塞其余全部（聚光灯），按点击次数释放？
│   │       └── FocusActionOperator（click_count）
│   │
│   └── 只需要确保本回合出现在6格中，不锁UI？
│       └── 待实现 ReserveActionOperator
│
├── 需要阻止行动出现？
│   ├── 有持续时间？
│   │   └── BlockActionOperator（设 xun_duration > 0）
│   │
│   └── 永久阻塞？
│       └── BlockActionOperator（xun_duration = -1）
│
├── 需要恢复被锁定的行动（移除 lock）？
│   └── 待实现 UnlockActionsOperator
│
├── 需要恢复被阻塞的行动（移除 block）？
│   └── 待实现 UnblockActionsOperator
│
└── 只需要刷新 UI，不改数据？
    └── RefreshActionPanelOperator
```

---

## 七、生命周期场景图

```
时间  第1旬        第2旬        第3旬        第4旬
      │             │             │             │
Lock  ├──── bai_ye locked ────────────────── unlock()
      │   (auto-reserve每旬)                   │
      │             │             │             │
Reserve│  shang_hua  │             │             │
      │  (仅本回合)  │             │             │
      │             │             │             │
Block │             ├── jiu_zhou blocked ── 到期自动清除
      │             │  (xun=2)     │
      │             │             │             │
Panel │  6格全满     │  1锁定+5随机│  1锁定+5随机│  正常6随机
      │  (被锁)      │  (正常)     │  (正常)     │  (lock已移除)
```

---

## 八、注意事项

1. **不要同时用 `LockActionsOperator` + `RefreshActionPanelOperator` 在同一事件中**。如果需要在锁定的同时刷新 UI，它们会互相覆盖。
2. **`RefreshActionPanelOperator` 只修复 UI，不修改 ActionManager 数据**。它依赖 `_locked_in_actions` 已在之前的事件操作符中正确设置。
3. **Phase 2 中 bai_ye 仍然在 `_locked_in_actions` 中**。这意味着它每回合自动预留（占 1/6 槽位），且如果有冲突操作符（如 `BlockActionOperator`），lock 的优先级高于 block。
4. **如果你需要完全取消 lock 语义**（从 `_locked_in_actions` 移除），需要在对应事件中使用 `UnlockActionsOperator`（待实现），不能仅靠 `RefreshActionPanelOperator`。
5. **`lock_action()` 内部会调用 `reserve_action()`**，所以 lock 在本回合即生效。`_locked_in_actions` 的自动 reserve 是在 `get_available_scene_actions()` 头部触发的——这保证了即使 UI 被销毁重建，lock 语义仍然保持。
6. **`block_action()` 内部会调用 `unreserve_action()`**，且 `get_available_scene_actions()` 会跳过 `_blocked_actions` 中的 action——双重保险。
7. **`ReserveActionOperator` 和 `LockActionsOperator` 的核心区别**：前者只操作 `_reserved_action_ids`（Array，本回合即焚），后者操作 `_locked_in_actions`（Dictionary，跨回合持久）且附带 UI 锁定副作用。

---

## 九、关键文件索引

| 文件 | 作用 |
|------|------|
| [`core/action_manager.gd`](../core/action_manager.gd) | 核心数据结构和 lock/block/reserve/unlock/unblock 逻辑 |
| [`core/operators/lock_actions_operator.gd`](../core/operators/lock_actions_operator.gd) | LockActionsOperator — 锁定行动 + UI 锁定 |
| [`core/operators/focus_action_operator.gd`](../core/operators/focus_action_operator.gd) | FocusActionOperator — 聚焦行动（Lock + Block 语义糖） |
| [`core/operators/block_action_operator.gd`](../core/operators/block_action_operator.gd) | BlockActionOperator — 阻塞行动 |
| [`core/operators/refresh_action_panel_operator.gd`](../core/operators/refresh_action_panel_operator.gd) | RefreshActionPanelOperator — UI 刷新 |
| `core/operators/reserve_action_operator.gd` | ReserveActionOperator — **待实现** |
| `core/operators/unlock_actions_operator.gd` | UnlockActionsOperator — **待实现** |
| `core/operators/unblock_actions_operator.gd` | UnblockActionsOperator — **待实现** |
| [`ui/scene_action_scroll.gd`](../ui/scene_action_scroll.gd) | 行动面板刷新入口 |
| [`world/action_map.gd`](../world/action_map.gd) | 大地图按钮启用/禁用逻辑 |
| [`core/eventbus.gd`](../core/eventbus.gd) | 信号总线（含 `request_refresh_action_panel`、`locked_actions_selected`） |
| [`tests/test_action_reserve.gd`](../tests/test_action_reserve.gd) | Reserve 单元测试覆盖 |

---

## 十、测试覆盖现状

| 测试 | 文件位置 | 状态 |
|------|---------|------|
| 基本预定 + 抽取 | [`test_action_reserve.gd:59`](../tests/test_action_reserve.gd:59) | ✅ |
| 6 个席位全满 | [`test_action_reserve.gd:105`](../tests/test_action_reserve.gd:105) | ✅ |
| 重复预定 | [`test_action_reserve.gd:150`](../tests/test_action_reserve.gd:150) | ✅ |
| 预定不在可用池 | [`test_action_reserve.gd:167`](../tests/test_action_reserve.gd:167) | ✅ |
| 预定数量超过可用池 | [`test_action_reserve.gd:193`](../tests/test_action_reserve.gd:193) | ✅ |
| 自动清空（跨回合污染防护） | [`test_action_reserve.gd:217`](../tests/test_action_reserve.gd:217) | ✅ |
| 无预定正常随机抽取 | [`test_action_reserve.gd:256`](../tests/test_action_reserve.gd:256) | ✅ |
| LockActionsOperator 集成 | 暂无 | ❌ |
| BlockActionOperator 集成 | 暂无 | ❌ |
| ReserveActionOperator | 待实现 | ❌ |
| UnlockActionsOperator | 待实现 | ❌ |
| UnblockActionsOperator | 待实现 | ❌ |
