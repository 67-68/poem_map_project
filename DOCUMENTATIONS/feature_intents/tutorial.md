# Tutorial — 青年杜甫泰山引导流程

## 涉及文件

- `core/tutorial_controller.gd` — Tutorial 线性状态机 Autoload（多信号驱动）
- `core/animation_controller.gd` — timeline_scripts 注入（UI 渐进揭示）
- `ui/left_player_panel.gd` — 左侧面板可见性 API（set_name/place/identity/ambition_section/bottom_decoration_visible）
- `ui/right_info_panel.gd` — 右侧面板可见性 API（set_time_panel/rumors_section/decisions_section/bottom_btn_bar_visible）
- `ui/hover_popup_manager.gd` — set_hover_enabled 全局开关
- `core/survival_manager.gd` — tutorial 期间跳过每旬扣钱
- `data/2_characters/npc_docs/tut_taoist.tres` — 道士 NPCDocument
- `data/4_eras/735_youth/events/` — tutorial 专属事件（.tres）

## 核心设计原则

**物理可见性引导 > 文字提示**：不告诉玩家「你应该做什么」，而是通过按钮/属性的物理隐藏/显示来引导行为。

## 入口流程

`TutorialController._ready()` 检测 `tutorial_completed` flag：
- **已存在**：静默跳过，确保全部 UI 可见
- **不存在**：等待 Main 场景加载 → 弹出 Modal → 「开始引导」或「跳过」

## 渐进式 UI 揭示时间线（完整）

### LeftPanel

| 步骤 | 事件 | 名字 | 地点 | 身份 | 健康 | 钱财 | 兴 | 势 | 望 | 才 | 府 | 定 | TraitGrid | 政略区 | 底层修饰 |
|------|------|:---:|:---:|:---:|:---:|:---:|:--:|:--:|:--:|:--:|:--:|:--:|:---------:|:------:|:--------:|
| P1 | tut_meet_taoist | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.1 | tut_dialogue_1 | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.3 | tut_dialogue_2 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.4 | tut_dialogue_3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| P2.5 | tut_dialogue_4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ |
| P6 | tut_defer_done | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ |
| P7b | tut_poem_review | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ |
| P7c | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### RightPanel

| 步骤 | 事件 | 时间面板 | 风闻区 | 决议区 | 社交按钮 | 理念按钮 | 写诗按钮 | 底部按钮栏 |
|------|------|:------:|:-----:|:-----:|:------:|:------:|:------:|:--------:|
| P1-2.1 | tut_meet_taoist/tut_dialogue_1 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.2 | tut_dialogue_time | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P2.3-5 | tut_dialogue_2/3/4 | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| P6 | tut_defer_done | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| P7b | tut_idea_unlock | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ |
| P7c | tut_final_reveal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### 全局控制

| 步骤 | Hover | 扣钱 | 健康/钱财值 |
|------|:-----:|:----:|:----------:|
| 开局-2.4 | ✗禁用 | ✗跳过 | 满值(100/满) |
| P2.5+ | ✓启用 | ✗跳过 | 满值 |
| END | ✓启用 | ✓恢复 | source_of_truth(50/45) |

## 状态转换

```
INIT → PHASE_1_MEET (事件 tut_meet_taoist)
  → PHASE_2_DIALOGUE (事件, 5步)
    → tut_dialogue_1 (名字+地点+身份)
    → tut_dialogue_time (时间面板)
    → tut_dialogue_2 (健康+钱财)
    → tut_dialogue_3 (政略主权区)
    → tut_dialogue_4 (TraitGrid + hover启用)
  → PHASE_3_TRAIT (事件 tut_trait_demo, trait+health+50)
  → PHASE_4_EXPLORE (行动驱动, 自由探索)
  → PHASE_5_DEFER (defer 驱雾)
  → PHASE_6_VISION (云开雾散+看山)
  → PHASE_7_POEM (创作+理念)
    → tut_final_reveal (最后UI揭示)
  → END (tut_goodbye 下山)
```

## 各 Phase 详细流程

### Phase 1: 遇道士
- `tut_meet_taoist` → 鸟语花香音效
- 所有 UI 完全隐藏，仅中间叙事栏可见
- 3 选项：游历天下 / 寻找灵感 / 就是觉得该来
- `event_confirmed` → Phase 2

### Phase 2: 对话+UI揭示（5步）
- **tut_dialogue_1**: 道士问大名 → left_panel 出现(名字+地点+身份)
- **tut_dialogue_time** 🆕: 道士问年月 → right_panel 出现(时间面板)
- **tut_dialogue_2**: 谈身体和盘缠 → 健康+钱财行可见
- **tut_dialogue_3**: 谈志向 → 政略主权区(兴/势/望)可见
- **tut_dialogue_4** 🆕: 建议强身 → TraitGrid 出现 + **hover 系统启用**（description 含系统提示）

### Phase 3: Trait展示
- `tut_trait_demo`: 道士拍肩 → trait_add(strong_body) + prop_add(health +50)
- `event_confirmed` → Phase 4

### Phase 4-6: 探索/驱雾/看山
- 同原设计，UI 在 tut_defer_done 时 poem_btn 出现

### Phase 7: 诗词创作+理念+最终揭示
- 创作系统检测兴=0 → `tut_no_inspiration` → 独酌 +40兴
- 创作成功 → `tut_poem_review`
- 理念解锁 → `tut_idea_unlock` (idea_btn 可见)
- → **`tut_final_reveal`** 🆕: 最后揭示（风闻区+决议区+底层修饰(才府定)+底部按钮栏全部出现）

### END: 下山
- `tut_goodbye` → era 切换 745_ambition + 道士移除
- health → 50, money → 45（恢复 source_of_truth）
- 恢复每旬扣钱，恢复 hover
- 「约好再见，没想到一别二十年」

## Tutorial 状态管理

| 阶段 | health | money | 每日扣钱 | hover |
|------|:------:|:-----:|:------:|:-----:|
| 开局 | 满值 | 满值 | ✗ | ✗ |
| P2.5+ | 满值 | 满值 | ✗ | ✓ |
| END 后 | 50 | 45 | ✓ | ✓ |
