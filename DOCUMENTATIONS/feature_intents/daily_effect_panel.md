# 日常效果面板 (Daily Effect Panel)

与 [`hover_display_flow.md`](hover_display_flow.md) 共享 HoverContainer UI 空间但独立功能。

## 文件

- `characters/narrative_overlay.gd` — 日常面板逻辑 + hover 面板逻辑共存

## 设计

HoverContainer（`TapeContainer/VBox` 内，与 EventHistory 平级）永久可见并占位。两套内容通过快照切换：

| 模式 | 标题 | 内容来源 | 触发方式 |
|------|------|----------|----------|
| 日常面板 | "独白" | `refresh_daily_panel()` → survival goal + subconscious murmur | 每 10 分钟 / 属性 trait flag 变动 |
| Hover 面板 | "效果"（原样恢复） | `show_hover_text(narrative, vector)` 写入 | hover action/picker/event |

## 快照机制

两套独立快照属性：

```
_daily_snapshot_text / _daily_snapshot_sep / _daily_snapshot_title  ← 日常内容
_hover_snapshot_text  / _hover_snapshot_sep  / _hover_snapshot_title  ← hover 覆盖前的内容
```

- `show_hover_text()`: `_store_hover_snapshot()` → 写 hover 内容 → `_is_hover_displaying = true`
- `hide_hover_text()`: `_restore_hover_snapshot()` → `_is_hover_displaying = false` → 检查 `_daily_refresh_pending`

## 延迟刷新

属性/特质/flag 变动时 `refresh_daily_panel()` 被调用。若当前正在显示 hover (`_is_hover_displaying=true`)，设置 `_daily_refresh_pending=true`，等 `hide_hover_text()` 后执行。

## 内容函数

### 1. `_check_survival_goal()` — 生计检查
- 当前 `money >= 0` → 返回 `""`
- `money` 不足 → 以杜甫口吻返回一句（hardcoded 三档）

### 2. `_subconscious_murmur()` — 身体不适碎碎念
- `poisoned` → "腹中隐隐作痛…"
- `sprained_ankle` → "脚踝还在隐隐发疼…"
- 均无 → 返回 `""`

### 3. Fallback — 杜甫日常独白（5 句随机）
两个函数均返回空时，从硬编码 pool 随机选一句。

## 信号监听

`EventBus.on_trait_change` / `imaginary_changed` / `on_flag_change` → `_on_daily_refresh_signal()` → `refresh_daily_panel()`
