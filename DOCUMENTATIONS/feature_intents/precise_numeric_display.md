# 数值精确展示 — 干掉模糊展示系统

## 目标
所有模糊文本展示（如"你有点累"、"睥睨天下"）降级为括号内补充，前方追加精确数值。

## 格式规范
旧格式（动态 PropGrid）: `「文学声望」：初露锋芒` → 新格式（固定 prop_label 预制体）: `文学声望 42(初露锋芒)`

## 涉及模块

### 1. 左侧面板属性展示 (left_player_panel.gd)
使用 [`prop_label.tscn`](ui/prop_label.tscn) / [`smaller_prop_label.tscn`](ui/smaller_prop_label.tscn) 固定预制体实例，不再动态生成 Label。

- **健康 / 钱财**（`prop_label.tscn`，大字号）：`Label2` 显示 `"50 健"`，`Label` 显示 `"「奄奄一息」"`
- **兴、势、望**（`smaller_prop_label.tscn`，小字号 → 政略主权下）：`Label2` 显示 `"兴 42"`，`Label` 显示 `"(初露锋芒)"`
- **才华、城府、定力**（`smaller_prop_label.tscn`，小字号 → 底层修饰下）：同上格式

所有属性的数值和感知文本通过 `_refresh_all_props()` 统一刷新，格式由 `_PROP_FORMAT` 常量控制。

### 2. ~~左侧面板情绪展示 (left_player_panel.gd)~~
- **已删除**。情绪 UI 展示从左侧面板移除，`_EMOTION_CFG`、`_refresh_emotions()`、所有 emotion RichTextLabel @onready 均已清理。

### 3. 野心HUD追踪属性 (ambition_hud.gd)
- 进度行追加数值: `●●◐○○  成长中` → `42(成长中)  ●●◐○○`

### 4. 右上角时间面板 (time_control_panel.gd)
- 剩余时间圆点: `●◐○○○` → `5(●◐○○○)`

### 5. 事件选项预览 (各 operator describe_preview)
- PropertyOperator: `文学声望 ↑↑：初露锋芒` → `文学声望 ↑↑：+30(初露锋芒)`
- ForceSetPropertyOperator: `文学声望 → 初露锋芒` → `文学声望 → 80(初露锋芒)`
- EmotionOperator: `愁苦↑` → `愁苦↑(+20)`
- AllEmoSubOperator: `全情↓(10)` → 保持不变（已有数值）

### 6. 需求描述 (各 requirement describe_requirement)
- PropertyRequirement: `需要「初露锋芒」` → `需要「80(初露锋芒)」`
- PropRangeRequirement: 同上
- EmotionRequirement: `需要情绪: 愁苦` → `需要情绪: 愁苦(≥30)`

### 7. 顶部属性项 (top_stat_item.gd)
- `文学声望: 初露锋芒` → `文学声望: 42(初露锋芒)`
