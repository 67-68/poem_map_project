# Action Blacklist (行动全局黑名单)

## 设计意图

提供一个全局持久化的行动过滤机制，支持通过 UUID 隐藏特定 Action（父/子），不随 Era/旬变化。tutorial 结束后自动 ban 掉 tutorial 特有行动。

## 核心文件

| 文件 | 类型 | 说明 |
|------|------|------|
| [`core/model/game_save_data.gd`](core/model/game_save_data.gd) | 修改 | 新增 `hidden_action_uuids: Array[String]` 持久化字段 |
| [`core/action_manager.gd`](core/action_manager.gd) | 修改 | 新增 `add_hidden_action` / `remove_hidden_action` / `is_action_hidden` / `get_hidden_actions` API |
| [`ui/action_panel_manager.gd`](ui/action_panel_manager.gd) | 修改 | `_rebuild_all_buttons()` 中插入父 Action 黑名单检查 |
| [`ui/main_action_button.gd`](ui/main_action_button.gd) | 修改 | `_on_clicked()` picker 构建中插入子 Action 黑名单检查 |
| [`core/tutorial_controller.gd`](core/tutorial_controller.gd) | 修改 | `_skip_tutorial()` / `_advance_to_end()` 中调用 `_ban_tutorial_actions()` |

## 过滤行为

| 填入类型 | 效果 |
|----------|------|
| 父 Action UUID（如 `fang_shi`、`tut_chuyou`） | 整个父行动按钮不显示 |
| 子 Action UUID（如 `banzhuan`、`tut_chuyou_east`） | 父按钮可见，但该子行动不出现在 Picker 中 |

## 特性

- **全局持久**：不随 Era/旬/月变化，写入 [`GameSave.data.hidden_action_uuids`](core/model/game_save_data.gd)
- **存档持久**：`to_dict()` / `from_dict()` 完整序列化
- **即时生效**：`add_hidden_action` / `remove_hidden_action` 自动 emit `request_refresh_action_panel` 触发面板重建

## Tutorial 黑名单清单

tutorial 结束后自动 ban 以下 11 个 tutorial 特有 UUID：

- `tut_chuyou`（父行动 + 5 方向：`east`/`west`/`south`/`north`/`lookup`）
- `tut_duzhuo_heyaojiu`（独酌喝药酒）
- `tut_jiaoyou_talk` / `tut_jiaoyou_drink`（交游-说话/共饮）
- `tut_zhu_liu_base` / `tut_zhu_liu_upper`（驻留-泰山两地）
