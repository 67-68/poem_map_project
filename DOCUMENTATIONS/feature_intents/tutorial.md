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
- `data/2_characters/npc_docs/tut_taoist.tres` — 道士 NPCDocument
- `data/4_eras/735_youth/events/` — tutorial 专属事件（.tres）
- `data/3_actions_pool/actions/jiao_you/` — tut_jiaoyou_talk, tut_jiaoyou_drink, tut_taoist_dispel_fog
- `data/3_actions_pool/actions/zhu_liu/` — tut_zhu_liu_base, tut_zhu_liu_upper
- `data/3_actions_pool/actions/tut_chuyou/` — tut_chuyou 4方向 + tut_chuyou_lookup
- `data/1_core_rules/archetypes/` — tut_zhu_liu_base_success, tut_zhu_liu_upper_success, tut_chuyou_lookup_success

## 行动可见性：双层白名单机制

**主白名单** (`_tutorial_whitelist`)：空=正常模式，非空=只显示列表内的主行动按钮。

**子白名单** (`_tutorial_sub_whitelist`)：空=正常模式（所有子行动可见），非空=只显示列表内的子行动。

两个白名单均由 `TutorialController` 在每个阶段转换时同步设置。

## 渐进式 UI 揭示

### LeftPanel

| 步骤 | 事件 | 名字 | 地点 | 身份 | 健康 | 钱财 | TraitGrid | 底层修饰(才府定) |
|------|------|:---:|:---:|:---:|:---:|:---:|:---------:|:------------:|
| P1 | tut_meet_taoist | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.1 | tut_dialogue_1 | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| P2.2 | tut_dialogue_time | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| P2.3 | tut_dialogue_2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| P2.4 | tut_dialogue_4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| P7 | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

> 兴/势/望/政略区不在 tutorial 期间揭示。

### RightPanel

| 步骤 | 事件 | 时间面板 | 风闻区 | 决议区 | 社交按钮 | 理念按钮 | 写诗按钮 | 底部按钮栏 | SpecialLabel |
|------|------|:------:|:-----:|:-----:|:------:|:------:|:------:|:--------:|:----------:|
| P1-2.1 | tut_meet_taoist/tut_dialogue_1 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.2 | tut_dialogue_time | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.3-4 | tut_dialogue_2/4 | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P6 | tut_defer_done | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| P7b | tut_idea_unlock | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ |
| P7c | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## 白名单随时间线变化

| 阶段 | 主白名单 | 子白名单 |
|------|---------|---------|
| P1-P2 (叙事) | `[]` | `[]` |
| P4 FREE_ROAM | `["jiao_you", "zhu_liu"]` | `["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper"]` |
| P4 FOG_FOUND | `["jiao_you", "zhu_liu", "tut_chuyou"]` | 同上 |
| P4 BACK_AT_TAOIST (→ OVERRIDE_LOCKED) | 同上 | `["tut_jiaoyou_drink", "tut_zhu_liu_base", "tut_zhu_liu_upper"]` |
| P5 DEFERRING | `["jiao_you", "zhu_liu", "tut_chuyou"]` | `[]` (正常模式，出游4方向由flag控制) |
| P6 VISION | 同上 | `[]` |
| P7 DRINK_WINE | `["jiao_you", "zhu_liu", "tut_chuyou", "du_zhuo"]` | `["tut_duzhuo_heyaojiu"]` |
| END | 清空 | 清空 |

## 状态转换

```
INIT → PHASE_1_MEET (tut_meet_taoist, 鸟语花香)
  → PHASE_2_DIALOGUE (4步对话)
    → tut_dialogue_1 (名字+地点+身份)
    → tut_dialogue_time (时间面板 735年)
    → tut_dialogue_2 (健康+钱财)
    → tut_dialogue_4 (TraitGrid+hover+trait_add(strong_body)+prop_add(health+50))
  → PHASE_4_EXPLORE (行动白名单驱动)
    → VAST_WORLD: tut_vast_world (2个Lv3意象) → FREE_ROAM
    → FREE_ROAM: 仅交游+驻留。问道士话→tut_talk_no_response（打坐无回应）。驻留迁移→stay_place_changed→tut_move_away
    → FOG_FOUND: tut_move_away确认→出游解锁(CHUYOU_VIEWED)
    → CHUYOU_VIEWED: 出游查看雾→tut_return_taoist
    → BACK_AT_TAOIST: tut_return_taoist确认→子白名单切共饮(OVERRIDE_LOCKED)
    → OVERRIDE_LOCKED: 共饮确认→关系升级→override解锁(OVERRIDE_READY)
  → PHASE_5_DEFER (defer 2旬, 出游4方向)
    → OVERRIDE_CLICKED→子白名单清空，defer开始
  → PHASE_6_VISION (defer完成→tut_defer_done→poem_btn可见)
    → tut_defer_done确认→LOOK_UP_READY（往上看可用）
    → 往上看→tut_chuyou_lookup_success(最后Lv3意象)→_advance_to_phase_7
  → PHASE_7_POEM
    → poem_btn点击+兴=0 → tut_no_inspiration → 独酌解锁(DRINK_WINE)
    → poems_created → tut_poem_review → tut_idea_unlock → tut_final_reveal
  → END (tut_goodbye, 属性恢复, SpecialLabel恢复)
```

## 子行动清单

| uuid | 类型 | 说明 |
|------|------|------|
| tut_jiaoyou_talk | 交游子行动 | FREE_ROAM: 问道士话, fallback→tut_talk_no_response |
| tut_jiaoyou_drink | 交游子行动 | OVERRIDE_LOCKED: 共饮升级关系, fallback→tut_drink_together |
| tut_taoist_dispel_fog | 交游 override | override=tut_jiaoyou_drink, fallback→tut_defer_done, 触发defer |
| tut_zhu_liu_base | 驻留子行动 | 泰山脚下→taishan_base, archetype→set_stay_place(place=taishan_base) |
| tut_zhu_liu_upper | 驻留子行动 | 泰山上→taishan_upper, archetype→set_stay_place(place=taishan_upper) |
| tut_chuyou_east/west/south/north | 出游子行动 | Phase 5 defer期间探索四方 |
| tut_chuyou_lookup | 出游子行动 | Phase 6: 往上看→archetype→roll_imaginary(level=3) |
| tut_duzhuo_heyaojiu | 独酌子行动 | Phase 7: 喝药酒+40兴 |

## 信号矩阵

| 信号 | 驱动阶段 |
|------|---------|
| event_confirmed | Phase 1→2, 2内部, 2→4, 4内部, 5内部, 6内部, 7内部 |
| stay_place_changed | Phase 4 FREE_ROAM→MOVED_AWAY |
| request_refresh_action_panel | Phase 4-7 行动执行检测 |
| on_xun_tick | Phase 5 defer倒计时→_advance_to_phase_6 |
| poems_created | Phase 7 创作检测 |
| poem_start_clicked | Phase 7 兴=0检测→tut_no_inspiration |

## 全局控制

| 步骤 | Hover | 扣钱 | 健康/钱财值 | SpecialLabel |
|------|:-----:|:----:|:----------:|:----------:|
| 开局 | ✗ | ✗ | 满值 | ✗ |
| P2.4(tut_dialogue_4)+ | ✓ | ✗ | 满值 | ✗ |
| P7c(tut_final_reveal)+ | ✓ | ✗ | 满值 | ✓ |
| END | ✓ | ✓ | 50/45 | ✓ |
