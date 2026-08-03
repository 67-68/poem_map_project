# Settings — 系统设置面板

## 涉及文件

- `ui/settings.tscn` — 设置面板场景，含音量 HSlider、语言切换按钮、自动滚动 CheckButton
- `ui/settings.gd` — 设置面板脚本，双向绑定存档数据
- `characters/event_ui.gd` — 叙事纸带 UI，`scroll_to_bottom()` 受 flag 门控

## 预期效果

设置面板提供三项可调选项，均持久化到 `GameSave.data`：

1. **音量**：HSlider（0~100）↔ `GameSave.data.music_volume_ratio`（0.0~1.0），切曲时 AudioManager 自动读取
2. **语言**：LinkButton（中文/English）→ `TranslationServer.set_locale()` + `GameSave.data.locale`
3. **事件自动滚动**：CheckButton ↔ `GameSave.data.flags["auto_scroll_enabled"]`（bool），新游戏默认 false。EventUI.scroll_to_bottom() 受此 flag 门控，false 时跳过滚动

## 状态转换

### CheckButton 自动滚动

1. `_ready()` 从 `GameSave.data.flags.get("auto_scroll_enabled", false)` 读取初始值 → `button_pressed = 该值`
2. 玩家点击 → `toggled` 信号 → 写入 `GameSave.data.flags["auto_scroll_enabled"] = button_pressed`
3. EventUI.scroll_to_bottom() 被调用时 → 检查 flag → false 则 `return`（不滚动）

### 存档兼容

- 旧存档 flags 中无此 key → `get(..., false)` 返回 false → 不滚动，需手动开启
- 新游戏 flags 初始为空 → 同上 → 默认不滚动

## 关键设计决策

- **flag 只控制视觉滚动，不控制 auto_advance**：两者语义独立
- **中心化门控**：在 `EventUI.scroll_to_bottom()` 内部检查，所有 10+ 调用方无需逐处修改
- **不新增 GameSaveData 字段**：`flags` 是 Dictionary，天然支持任意 key
