# Tutorial — 青年杜甫泰山引导流程

## 涉及文件

- `core/tutorial_controller.gd` — Tutorial 线性状态机 Autoload（多信号驱动）
- `core/animation_controller.gd` — timeline_scripts 注入（UI 渐进揭示）
- `data/2_characters/npc_docs/tut_taoist.tres` — 道士 NPCDocument
- `data/4_eras/735_youth/` — tutorial era 资源目录
- `data/4_eras/735_youth/events/` — tutorial 专属事件（.tres）
- `data/3_actions_pool/actions/jiao_you/tut_jiaoyou_drink.tres` — 交游子行动「共饮」
- `data/3_actions_pool/actions/tut_chuyou.tres` — 出游父行动
- `data/3_actions_pool/actions/tut_chuyou/` — 出游 4 子行动
- `project.godot` — `TutorialController` autoload（已注册）

## 核心设计原则

**物理可见性引导 > 文字提示**：不告诉玩家「你应该做什么」，而是通过按钮/属性的物理隐藏/显示来引导行为。

## 入口流程

`TutorialController._ready()` 检测 `tutorial_completed` flag：
- **已存在**：静默跳过，确保全部 UI 可见
- **不存在**：等待 Main 场景加载 → 弹出 Modal → 「开始引导」或「跳过」

## 渐进式 UI 揭示时间线

### LeftPanel 属性行揭示

| Phase | 名字 | 健康 | 钱财 | 兴 | 势 | 望 | 才 | 府 | 定 | TraitGrid |
|-------|:--:|:---:|:---:|:-:|:-:|:-:|:-:|:-:|:-:|:---------:|
| 1_MEET | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| 2a_DIALOGUE | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| 2b_DIALOGUE | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ |
| 3_TRAIT | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| 4-5_EXPLORE | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| 6_VISION | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| 7a_DRINK | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |
| 7b_POEM | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 7c_IDEA | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### RightPanel 揭示

| Phase | 时间 | 地点 | 身份 | 社交按钮 | 理念按钮 | 写诗按钮 |
|-------|:--:|:--:|:--:|:------:|:------:|:------:|
| 1_MEET | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| 2a_DIALOGUE | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| 6_VISION | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| 7c_IDEA | ✓ | ✓ | ✓ | ✓ | ✓(可解锁) | ✓ |

### 行动按钮揭示

| Phase | 交游 | 驻留 | 出游 | 独酌 |
|-------|:--:|:--:|:--:|:--:|
| 4_EXPLORE 初期 | ✓(仅共饮) | ✓ | ✗ | ✗ |
| 4_EXPLORE 迁移后 | ✓ | ✓ | ✓(仅查看) | ✗ |
| 5_DEFER 中 | ✓ | ✓ | ✓(4 sub) | ✗ |
| 7a 兴不足后 | ✓ | ✓ | ✓ | ✓(仅喝药酒) |

## 状态转换

```
INIT → PHASE_1_MEET (事件) → PHASE_2_DIALOGUE (事件, 3步)
  → PHASE_3_TRAIT (事件) → PHASE_4_EXPLORE (行动驱动)
  → PHASE_5_DEFER (defer) → PHASE_6_VISION (行动+事件)
  → PHASE_7_POEM (创作+理念) → END (下山)

信号驱动:
  event_confirmed              → Phase 1→2, 2内部3步, 3→4
  stay_place_changed           → Phase 4 迁移检测
  request_refresh_action_panel → Phase 4-5 行动执行检测
  on_xun_tick                  → Phase 5 defer 倒计时
  poems_created                → Phase 7 创作检测
```

## 各 Phase 详细流程

### Phase 1: 遇道士
- `tut_meet_taoist` → 鸟语花香音效
- 3 选项：游历天下 / 寻找灵感 / 就是觉得该来
- `event_confirmed` → Phase 2

### Phase 2: 对话+UI揭示（3步）
- `tut_dialogue_1`: small talk，道士问来意 → left_panel(名字+健康+钱财) + right_panel(时间+地点+身份) + social_btn + 道士关系→not_meet
- `tut_dialogue_2`: 继续闲聊，谈泰山 → talent/astuteness/composure 可见
- `tut_dialogue_3`: 道士建议强身 → trait_grid 可见（空）+ description 内含系统提示 hover trait

### Phase 3: Trait展示
- `tut_trait_demo`: 道士拍肩说底子不错 → trait_add(strong_body) + prop_add(health +50)
- `event_confirmed` → Phase 4

### Phase 4: 自由探索（行动驱动）
- `tut_vast_world` → 2个 Lv3 意象 → 道士说打坐 → 仅交游+驻留可见
- 玩家交游 → fallback 无回应 → 被迫驻留迁移
- `stay_place_changed` → `tut_move_away`（雾锁泰山）
- 出游解锁（仅查看）→ 提示回找道士
- `tut_return_taoist` → override 可见但锁定（not_meet）
- 交游共饮 → 关系升级 → override 解锁

### Phase 5: Defer 驱雾
- 玩家点 override → defer 2旬
- 出游 4 子行动解锁（东/西/南/北麓，各 1 天 + 随机增益）
- defer 完成 → Phase 6
- 玩家中断 defer → `tut_defer_interrupt` → 重新开始

### Phase 6: 泰山显现
- `tut_defer_done` → 最后 Lv3 意象 → poem_btn 可见
- 玩家出游 → "往上看" → 获得意象 → SpecialLabel → idea_btn

### Phase 7: 诗词创作+理念
- 创作系统检测兴=0 → `tut_no_inspiration`
- 独酌(喝药酒)解锁 → +40兴 → 兴属性行显示
- 创作成功 → `tut_poem_review` (+40名) → 望属性行显示
- 理念解锁 → 势属性行显示 → idea_btn
- → END

### END: 下山
- `tut_goodbye` → era 切换 745_ambition + 道士移除 + days_per_xun 恢复
- 「约好再见，没想到一别二十年」
