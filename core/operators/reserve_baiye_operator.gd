@tool
class_name ReserveBaiYeOperator extends BaseOperator

func operate():
	# 1. 立即预定拜谒行动
	var ok := ActionManager.reserve_action("bai_ye")
	if ok:
		Logging.info("[ReserveBaiYeOperator] 已预定拜谒行动")
	else:
		Logging.warn("[ReserveBaiYeOperator] 预定拜谒失败（可能席位已满或重复）")

	# 2. 添加持久化 trait，后续 ActionManager 会据此自动预定
	PlayerState.add_trait("reserve_baiye")
	Logging.info("[ReserveBaiYeOperator] 已添加 reserve_baiye trait")
