# 诗词意象匹配 — 功能意图

**状态**: 🔴 执行中（V8: 动态 Slot + 模式切换 + C(N,3) 组合枚举）

---

## 意图摘要（<200字）

PoemSlot 变为纯展示控件，不再可点击。面板动态创建 Slot，超过 `max_imaginary_managable`（默认 3）时随机截断 +「过多…」灰色占位 Slot。Toggle 按钮（登高抒怀/干谒权贵）决定 `current_mode`，覆盖管道乘数。创作时自动使用所有拥有的 Imaginary，Calculator 内部枚举 C(N,3) 组合匹配食谱。成功时仅消耗命中的 3 个 Imaginary，失败不消耗。

---

## 核心玩法

### 匹配流程（V8）

```
玩家打开诗词面板
        │
        ├─ 自动从 Database.imaginaries_detail 获取所有 Imaginary
        ├─ 动态创建 PoemSlot（超过 max_imaginary_managable 随机截断 + 溢出 Slot）
        ├─ Toggle 选择 mode: 登高抒怀(deng_gao) | 干谒权贵(gan_ye)
        │
        └─ 点击「开始创作」
                │
                ▼
    ┌──────────────────────────────────────┐
    │  自动全选所有拥有的 Imaginary           │
    │  N = imaginaries_detail.size()        │
    └──────────────────────────────────────┘
                │
                ▼
    ┌──────────────────────────────────────┐
    │  PoemCraftingCalculator               │
    │  C(N,3) 枚举所有 3-组合               │
    │  任一命中食谱 → 匹配成功               │
    │  全未命中 → 失败（不消耗）              │
    └──────────────────────────────────────┘
                │
         ┌───────┴───────┐
         ▼               ▼
     匹配成功          无匹配
         │               │
         ▼               ▼
  按 mode 覆盖 channel   ❌ 失败
  secular/literary 算子   不消耗 Imaginary
  仅消耗命中的 3 个
```

### mode → Channel 映射

| Toggle | mode | channel | secular_mult | history_mult | 效果 |
|--------|------|---------|-------------|-------------|------|
| 登高抒怀 | `deng_gao` | BROADCAST | ×0 | ×1.2 | money=0, literary_fame=48 |
| 干谒权贵 | `gan_ye` | SECULAR | ×1.5 | ×1.0 | money=30, literary_fame=40 |

### Dynamic Slot 规则

- 上限 `PlayerState.max_imaginary_managable`（默认 3）
- 刷新时全量重建（`imaginary_changed` 信号触发）
- 随机截断：shuffle 后取前 N 个
- 溢出时追加灰色「过多…」Slot（不可用，纯视觉提示）
- PoemSlot `mouse_filter = MOUSE_FILTER_IGNORE`，不可交互

### 更改文件

| 文件 | 改动 |
|------|------|
| [`ui/poem_slot.gd`](ui/poem_slot.gd:1) | 移除 `slot_clicked` 信号和 gui_input；新增 `set_greyed()`；mouse_filter=IGNORE |
| [`core/player_state.gd`](core/player_state.gd:15) | 新增 `max_imaginary_managable: int = 3` |
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd:1) | 移除 size≠3 硬限制；新增 `mode` 参数；C(N,3) 枚举；新增 `MODE_CHANNEL_MAP` |
| [`ui/poem_crafter.tscn`](ui/poem_crafter.tscn:1) | 删除固定 3 个 PoemSlot 子节点 |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd:1) | 修复路径（去掉 VBoxContainer 冗余）；动态 `_rebuild_slots`；toggle mode 管理；`_consume_matched_imaginaries` 精确消耗 |
