@tool
class_name RefreshActionPanelOperator extends BaseOperator

## 请求 ActionPanelManager 刷新行动面板。
## 用于事件链结束后恢复正常的 UI 状态（例如在 LockActionsOperator 锁住其他按钮后解锁 UI）。

func operate():
	Logging.info("[RefreshActionPanelOperator] 请求刷新行动面板")
	EventBus.request_refresh_action_panel.emit()
