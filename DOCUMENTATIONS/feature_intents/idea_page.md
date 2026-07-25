# IdeaPage — 理念总览页

## 涉及文件

| 文件 | 作用 |
|------|------|
| [`core/idea_page.gd`](/core/idea_page.gd) | 页面脚本，`class_name IdeaPage`，全屏覆盖层，含 show/hide 动画 + 双池令牌系统 |
| [`ui/idea_page.tscn`](/ui/idea_page.tscn) | 场景文件，宣纸背景 + 右上角 X 关闭按钮，InfoContainer 含 4 个令牌状态 Label |
| [`core/model/game_save_data.gd`](/core/model/game_save_data.gd) | `used_momentum_tokens` / `used_prestige_tokens` 持久化 |
| [`ui/right_info_panel.gd`](/ui/right_info_panel.gd) | 右下角 LinianBtn（理念按钮）点击发射 `idea_page_toggled` |
| [`core/eventbus.gd`](/core/eventbus.gd) | 提供 `signal idea_page_toggled()` / `signal idea_upgraded()` |
| [`main.tscn`](/main.tscn) | `UI` 节点下实例化 `IdeaPage`（`visible = false` 初始隐藏） |
| [`main.gd`](/main.gd) | 提供 `slide_panels_out()` / `slide_panels_in()` 供 IdeaPage 调用 |

## 令牌系统（2026-07-25 重构）

理念解锁/升级不再直接消耗属性点数，改为令牌制：

```
势 (momentum) → 阈值 [10, 40, 90, 180] → crossed 计数
望 (prestige)  → 阈值 [10, 40, 90, 180] → crossed 计数

available = crossed - used_*_tokens
```

- 势令牌只能用于 `idea_cost_name == "momentum"` 的理念
- 望令牌只能用于 `idea_cost_name == "prestige"` 的理念
- `idea_cost_name == "xing"` 的理念已废弃，不再作为消耗使用
- 令牌全局共享，每次解锁或升级消耗 1 个，不可退还（槽位满等异常情况除外）
- `idea_cost_amount` 字段保留但不参与扣除判定

### 状态流转

```
                    势/望增长 (PlayerState.append_stat)
                           │
            ┌──────────────┴──────────────┐
            ▼                              ▼
    crossed_thresholds 增加          crossed 不变
    available_tokens 增加               │
            │                              │
            └──────────────┬──────────────┘
                           ▼
                IdeaPage._refresh_info_labels()
                           │
                玩家点击升级/获取按钮
                           │
                   available > 0 ?
                    │          │
                   是          否
                    │          │
                    ▼          ▼
          consume_token()   按钮灰 + 令牌不足提示
          used_* += 1
          idea level +1
          EventBus.idea_upgraded.emit()
                    │
                    ▼
          _on_idea_upgraded_refresh()
          → _refresh_info_labels()
```

## InfoContainer 4-Label 布局

| 节点名 | 动态内容示例 | 说明 |
|--------|-------------|------|
| `ShiLeft` | `"势: 25 ｜ 可用令牌: 1"` | 当前势值 + 可用令牌数 |
| `ShiTarget` | `"10✅ 40🔒 90🔒 180🔒"` | 势的里程碑条 |
| `WangLeft` | `"望: 60 ｜ 可用令牌: 2"` | 当前望值 + 可用令牌数 |
| `WangTarget` | `"10✅ 40✅ 90🔒 180🔒"` | 望的里程碑条 |

### 刷新时机
- `show_page()` → `refresh_all()` → `_refresh_info_labels()`
- `PlayerState.player_stat_changed` 信号（prop_name == "momentum" 或 "prestige"）
- `EventBus.idea_upgraded` 信号（令牌消耗后）

## 打开/关闭流程

与旧版一致，1:1 镜像 [`SocialConnectionPage`](/features/social_connection_page.gd)。

## 升级按钮逻辑

| 状态 | 按钮文本 | 禁用条件 |
|------|---------|---------|
| 未拥有 | `获取「理念名」（消耗 1 势令牌）` | 对应池令牌 == 0 或 槽位满 |
| 已拥有，可升级 | `升级至 Lv.2（消耗 1 势令牌）` | 对应池令牌 == 0 |
| 已满级 | `已满级` | 始终禁用 |
| 未选中 | 空白 | 始终禁用 |
