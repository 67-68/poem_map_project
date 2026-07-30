# Tutorial — 青年杜甫泰山引导流程

## 涉及文件

- `core/tutorial_controller.gd` — Tutorial 线性状态机 Autoload（多信号驱动），使用白名单机制控制行动面板
- `core/action_manager.gd` — `_tutorial_whitelist` + `_tutorial_sub_whitelist` + `set_tutorial_visible_actions()` / `set_tutorial_visible_sub_actions()` / `is_action_tutorial_allowed()` / `is_sub_action_tutorial_allowed()`
- `core/animation_controller.gd` — timeline_scripts 注入（UI 渐进揭示 + refresh_time_panel + set_special_label_visible）
- `core/operators/set_stay_place_operator.gd` — PLACE_CN_MAP 含 `taishan_base`/`taishan_upper`
- `ui/action_panel_manager.gd` — `_rebuild_all_buttons()` 中使用 ActionManager.is_action_tutorial_allowed() 过滤
- `ui/left_player_panel.gd` — 左侧面板可见性 API
- `ui/right_info_panel.gd` — `_hide_for_tutorial()` 隐藏 SpecialLabel, `refresh_time_panel()`, `set_special_label_visible()`
- `ui/hover_popup_manager.gd` — set_hover_enabled 全局开关
- `data/2_characters/npc_docs/tut_taoist.tres` — 道士 NPCDocument（初始 person_state=not_meet）
- `data/4_eras/735_youth/events/` — tutorial 专属事件（.tres，含 tut_background_intro）
- `data/3_actions_pool/actions/jiao_you/` — tut_jiaoyou_talk, tut_jiaoyou_drink, tut_taoist_dispel_fog
- `data/3_actions_pool/actions/zhu_liu/` — tut_zhu_liu_base, tut_zhu_liu_upper
- `data/3_actions_pool/actions/tut_chuyou/` — tut_chuyou 4方向 + tut_chuyou_lookup
- `data/1_core_rules/archetypes/` — tut_zhu_liu_base_success, tut_zhu_liu_upper_success, tut_chuyou_lookup_success

## 行动可见性：双层白名单机制

**主白名单** (`_tutorial_whitelist`)：
- tutorial 未完成 + 空 = 全隐藏（如 Phase 7 写诗阶段，所有行动不可见）
- tutorial 未完成 + 非空 = 只显示列表内的主行动按钮
- tutorial 已完成 → 清空白名单，正常全显示

**子白名单** (`_tutorial_sub_whitelist`)：
- tutorial 未完成 + 空 = 全隐藏（所有子行动不可见）
- tutorial 未完成 + 非空 = 只显示列表内的子行动
- tutorial 已完成 → 清空白名单，正常全显示

两个白名单均由 `TutorialController` 在每个阶段转换时同步设置。

### NoActionLabel
当 ActionPanel 中没有任何 SceneActionPanel 按钮时（tutorial Phase 7 空白名单 + 全隐藏），[`NarrativeOverlay._switch_to_idle_mode()`](characters/narrative_overlay.gd:1050) 显示 `NoActionLabel`（"没有行动可用"）替代空的 ActionPanel。

## 渐进式 UI 揭示

### LeftPanel

| 步骤 | 事件 | 名字 | 地点 | 身份 | 健康 | 钱财 | TraitGrid | 底层修饰(才府定) |
|------|------|:---:|:---:|:---:|:---:|:---:|:---------:|:------------:|
| P1a | tut_background_intro | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P1b | tut_meet_taoist | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| | P2.1 | tut_dialogue_1 | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| | P2.2 | tut_dialogue_time | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| | P2.3 | tut_dialogue_2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| | P2.4 | tut_dialogue_4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| | P6 | tut_defer_done | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| | P7 | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

> 势/望/兴（政略区）在 P6 tut_defer_done 时揭示，早于诗词创作（P7），让玩家有上下文理解属性状态。

### RightPanel

| 步骤 | 事件 | 时间面板 | 风闻区 | 决议区 | 社交按钮 | 理念按钮 | 写诗按钮 | 底部按钮栏 | SpecialLabel |
|------|------|:------:|:-----:|:-----:|:------:|:------:|:------:|:--------:|:----------:|
| P1a | tut_background_intro | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P1b-2.1 | tut_meet_taoist/tut_dialogue_1 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| | P2.2 | tut_dialogue_time | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| | P2.3-4 | tut_dialogue_2/4 | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| | P4 BACK | tut_return_taoist | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ | ✗ |
| | P6 | tut_defer_done | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ | ✓ | ✗ |
| | P7a | tut_idea_unlock | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ |
| | P7b | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## 白名单随时间线变化

| 阶段 | 主白名单 | 子白名单 |
|------|---------|---------|
| | P1-P2 (叙事) | `[]` | `[]` |
| | P4 FREE_ROAM | `["jiao_you", "zhu_liu"]` | `["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper"]` |
| P4 FOG_FOUND | `["jiao_you", "zhu_liu", "tut_chuyou"]` | `["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper", "tut_chuyou_east"]` (仅东方向查看，其余方向 Phase 5 由 flag 解锁) |
| | P4 BACK_AT_TAOIST (→ OVERRIDE_LOCKED) | 同上 + tut_taoist_dispel_fog(override) | `["tut_jiaoyou_drink", "tut_zhu_liu_base", "tut_zhu_liu_upper"]` |
| | P5 DEFERRING | `["jiao_you", "zhu_liu", "tut_chuyou"]` | `[]` (出游4方向由 flag tut_lock_chuyou_subs/tut_unlock_chuyou_subs 控制) |
| | P6 VISION | 同上 | `[]` |
| | P7 DRINK_WINE | `["jiao_you", "zhu_liu", "tut_chuyou", "du_zhuo"]` | `["tut_duzhuo_heyaojiu"]` |
| | END | 清空 | 清空 |

## 状态转换

```
INIT → PHASE_1_MEET
    → tut_background_intro (第三人称背景介绍：青年杜甫泰山求道)
    → tut_meet_taoist (道士出场 + 鸟语花香音效)
  → PHASE_2_DIALOGUE (4步对话, 相遇时 upgrade_person_state: not_meet→know_about)
    → tut_dialogue_1 (名字+地点+身份)
    → tut_dialogue_time (时间面板 735年)
    → tut_dialogue_2 (健康+钱财)
    → tut_dialogue_4 (TraitGrid+hover+trait_add(strong_body)+prop_add(health+50))
  → PHASE_4_EXPLORE (行动白名单驱动)
    → VAST_WORLD: tut_vast_world (2个Lv3意象) → FREE_ROAM
    → FREE_ROAM: 仅交游+驻留。问道士话→tut_talk_no_response（打坐无回应）。驻留迁移→stay_place_changed→tut_move_away
    → FOG_FOUND: tut_move_away确认→出游解锁(仅东方向查看)(CHUYOU_VIEWED)
    → CHUYOU_VIEWED: 出游查看雾→tut_return_taoist (bottom_btn_bar+social_btn 可见, 道士 not_meet→know_about)
    → BACK_AT_TAOIST: tut_return_taoist确认→子白名单切共饮(OVERRIDE_LOCKED)
    → OVERRIDE_LOCKED: 共饮确认→upgrade_person_state→inner_circle→override解锁(OVERRIDE_READY)
    → OVERRIDE_READY: 点击override→_advance_to_phase_5()
  → PHASE_5_DEFER (SubActionExecutor 自动启动 defer 2旬, 出游4方向由flag解锁)
    → DEFERRING: 子白名单清空, 出游4方向由 tut_unlock_chuyou_subs flag 控制
    → DEFER_INTERRUPTED: 玩家中断 defer→tut_defer_interrupt→重新开始
  → PHASE_6_VISION (defer完成→on_xun_tick 检测 is_deferring("tut_taoist_dispel_fog")==false → _advance_to_phase_6)
    → tut_defer_done (poem_btn 可见) → 确认→LOOK_UP_READY（往上看可用）
    → 往上看→tut_chuyou_lookup_success(最后Lv3意象)→_advance_to_phase_7
  → PHASE_7_POEM
    → POEM_BTN_VISIBLE: poem_btn点击+兴=0 → tut_no_inspiration (NO_INSPIRATION)
    → 编钟确认→独酌解锁(DRINK_WINE)→喝药酒+40兴→写诗
    → poems_created → tut_poem_review (POEM_REVIEWED)
    → poem_review 确认 → tut_idea_unlock (IDEA_UNLOCKED)
    → idea_unlock 确认 → idee_btn可见, 推 tut_final_reveal (FINAL_REVEAL_DONE)
    → final_reveal 确认→rumor+decision+bottom_decoration+special_label→END (AWAIT_ENDING)
  → END (tut_goodbye, 属性恢复, SpecialLabel恢复)
```

## 子行动清单

| | uuid | 类型 | 说明 |
|------|------|------|------|
| | tut_jiaoyou_talk | 交游子行动 | FREE_ROAM: 问道士话, fallback→tut_talk_no_response |
| | tut_jiaoyou_drink | 交游子行动 | OVERRIDE_LOCKED: 共饮升级关系, fallback→tut_drink_together |
| | tut_taoist_dispel_fog | 交游 override | override=tut_jiaoyou_drink, defer_config.xun_defered=s_xun_cost(2旬), fallback→tut_defer_interrupt |
| | tut_zhu_liu_base | 驻留子行动 | 泰山脚下→taishan_base, archetype→set_stay_place(place=taishan_base) |
| | tut_zhu_liu_upper | 驻留子行动 | 泰山上→taishan_upper, archetype→set_stay_place(place=taishan_upper) |
| | tut_chuyou_east/west/south/north | 出游子行动 | Phase 5 defer期间探索四方（由flag tut_unlock_chuyou_subs 解锁） |
| | tut_chuyou_lookup | 出游子行动 | Phase 6: 往上看→archetype→roll_imaginary(level=3) |
| | tut_duzhuo_heyaojiu | 独酌子行动 | Phase 7: 喝药酒+40兴 |

> **意象策略**: 所有 tut 子行动通过显式 `imaginary_grants=[{obtain_possibility="no_success_rate"}]` 阻断父行动意象继承。tut 期间的意象获取仅由 archetype 级别 DSL 控制（`tut_taoist_dispel_fog_success: roll_imaginary(level=3)` / `tut_chuyou_lookup_success: imagery_add × 3`）。

## 信号矩阵

| | 信号 | 驱动阶段 |
|------|------|---------|
| event_confirmed | Phase 1内部(intro→meet→2), 2内部, 2→4, 4内部, 5内部, 6内部, 7内部 |
| | stay_place_changed | Phase 4 FREE_ROAM→MOVED_AWAY |
| | request_refresh_action_panel | Phase 4-7 行动执行检测 |
| | on_xun_tick | Phase 5 defer倒计时→_advance_to_phase_6（检查 is_deferring("tut_taoist_dispel_fog")） |
| | poems_created | Phase 7 创作检测 |
| | poem_start_clicked | Phase 7 兴=0检测→tut_no_inspiration |

## 全局控制

| | 步骤 | Hover | 扣钱 | 健康/钱财值 | SpecialLabel |
|------|------|:-----:|:----:|:----------:|:----------:|
| | 开局 | ✗ | ✗ | 满值 | ✗ |
| | P2.4(tut_dialogue_4)+ | ✓ | ✗ | 满值 | ✗ |
| | P7b(tut_final_reveal)+ | ✓ | ✗ | 满值 | ✓ |
| | END | ✓ | ✓ | 50/45 | ✓ |

## 道士关系状态机

```
NPCDocument 默认: not_meet
  ↓ tut_meet_taoist 确认 → _advance_to_phase_2() 中 upgrade_person_state
know_about (P2-4: 对话阶段)
  ↓ P4 FREE_ROAM → _set_taoist_meditating()
not_meet (P4: 打坐中)
  ↓ P4 BACK_AT_TAOIST → _set_taoist_available()
know_about (P4: 可交互 + override locked)
  ↓ P4 OVERRIDE_LOCKED 共饮确认 → upgrade_person_state
inner_circle (P4: override 解锁 → P5: 驱散云雾)
  ↓ P5 defer 完成后不再需要道士
```

## Defer 机制说明

`tut_taoist_dispel_fog` 带 `defer_config.xun_defered="s_xun_cost"`（解析为 2 旬）。

- **启动**: `SubActionExecutor.execute()` 检测到 defer_config 后自动调用 `ActionManager.start_defer(action, npc_target)`
- **轮询**: `TutorialController._on_xun_tick()` 每旬检查 `ActionManager.is_deferring("tut_taoist_dispel_fog")`
- **完成**: defer 到期后 `ActionManager._on_xun_settlement()` 清理 defer 状态并发射对应事件
- **中断**: 玩家执行其他行动导致资源不足时，中断 defer（由 ActionManager 内部处理）
- **兜底**: `fallback_event_uuid="tut_defer_interrupt"`（失败时道士抱怨，让玩家重试）
