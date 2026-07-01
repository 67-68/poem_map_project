# 数值精确展示 — 干掉模糊展示系统

## 目标
所有模糊文本展示（如"你有点累"、"睥睨天下"）降级为括号内补充，前方追加精确数值。

## 格式规范
`旧格式: 标签: 模糊文本` → `新格式: 标签: 数值(模糊文本)`

## 涉及模块

### 1. 左侧面板属性网格 (left_player_panel.gd)
- 属性行: `「文学声望」：初露锋芒` → `「文学声望」：42(初露锋芒)`

### 2. 左侧面板情绪展示 (left_player_panel.gd)
- 情绪行: `愤懑：意难平` → `愤懑：59(意难平)`

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
