# UI 消息流转契约 (Notification Contract)

> **原则 (Paradox of Constraint)：** 必须严格遵循对应场景！乱用 UI 会导致玩家认知混乱，绝不允许把普通信息用红字警告弹出 😡。

1. **严重阻断与警告 (Red Alert):** 
   - 视觉：红色、弹跳、屏幕居中强干预。
   - 场景：用户操作被拒（如：行动力不足）、底层严重错误提示。
   - 承载：`SimpleToast`

2. **普通状态机更新 (Info Stream):** 
   - 视觉：默认底色、底部滑入、弱干预自动消失。
   - 场景：获得新诗词、年代更迭、时间推进。
   - 承载：`TextPopup`

3. **空间位置解说 (Spatial Label):**
   - 视觉：跟随具体地图 Node 上浮淡出。
   - 场景：信使抵达具体省份、点击某个具体的诗人 NPC 产生的气泡。
   - 承载：`FloatingText` (强制过对象池 `PoolManager`)