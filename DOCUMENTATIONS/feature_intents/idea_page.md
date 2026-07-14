# IdeaPage — 理念总览页

## 涉及文件

| 文件 | 作用 |
|------|------|
| [`core/idea_page.gd`](/core/idea_page.gd) | 页面脚本，`class_name IdeaPage`，全屏覆盖层，含 show/hide 动画 |
| [`ui/idea_page.tscn`](/ui/idea_page.tscn) | 场景文件，宣纸背景 + 右上角 X 关闭按钮 |
| [`ui/right_info_panel.gd`](/ui/right_info_panel.gd) | 右下角 LinianBtn（理念按钮）点击发射 `idea_page_toggled` |
| [`core/eventbus.gd`](/core/eventbus.gd) | 提供 `signal idea_page_toggled()` |
| [`main.tscn`](/main.tscn) | `UI` 节点下实例化 `IdeaPage`（`visible = false` 初始隐藏） |
| [`main.gd`](/main.gd) | 提供 `slide_panels_out()` / `slide_panels_in()` 供 IdeaPage 调用 |

## 打开流程

1. **触发**：点击 RightInfoPanel 右下角的「理念按钮」（LinianBtn，纹理 `linian_stamp.png`）
2. **信号**：`right_info_panel.gd` → `EventBus.idea_page_toggled.emit()`
3. **响应**：`IdeaPage._ready()` 监听到信号，调用 `show_page()`

### show_page() 动画序列（1:1 镜像 SocialConnectionPage）

```
EventBus.narrative_tape_hide_requested.emit()   # 隐藏纸带
BlurManager.show_cinematic_blur()               # 全屏模糊幕布
await 0.5s
Main.slide_panels_out()                         # 左右面板向外滑出
await 0.65s
BlurManager.hide_cinematic_blur()               # 取消全屏模糊
BlurManager.trigger_event_blur()                # 切换为地图模糊
show()                                          # 显示 IdeaPage（恢复原始 offsets）
```

## 关闭流程

有两种关闭方式：
- **X 按钮**：右上角 `Button.text = "X"` → `hide_page()`
- **重复点击理念按钮**：`IdeaPage.expand == true` → `hide_page()`

### hide_page() 动画序列

```
EventBus.narrative_tape_show_requested.emit()   # 恢复纸带
BlurManager.return_to_hub()                     # 取消地图模糊
Main.slide_panels_in()                          # 左右面板滑回原位
Tween: 缩小 size + 移动到固定位置 (520, 565) → hide()
```

## 状态转换

```
         idea_page_toggled (expand=false)
初始 ───────────────────────────────→ 已打开 (expand=true)
                                         │
                           ┌─────────────┴─────────────┐
                           │ X 按钮                    │ 重复点击理念按钮
                           │ hide_page()               │ hide_page()
                           ▼                           ▼
                         已关闭 (expand=false)
```

## 与 SocialConnectionPage 的差异

| 维度 | SocialConnectionPage | IdeaPage |
|------|---------------------|----------|
| 信号 | `social_connection_toggled` | `idea_page_toggled` |
| 按钮纹理 | `renmai.png`（人脉） | `linian_stamp.png`（理念） |
| 右侧信息面板 | 有 Tree + 信息面板 | 暂无子内容（骨架占位） |
| 动画 | 全一致 | 全一致（镜像） |

## 后续扩展

IdeaPage 当前为纯骨架页面（只有背景 + X 按钮），后续需填充理念相关 UI 组件。
