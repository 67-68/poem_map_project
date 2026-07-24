@tool
class_name BackhomeEndingRouterOperator extends BaseOperator
## 回家结局路由 Operator
## 在 event_backhome_ending_router 的 choice_result 中执行，
## 调用 ExamEndingRouter.evaluate_backhome()

const _ExamEndingRouter = preload("res://core/exam_ending_router.gd")

func operate():
	Logging.info("[BackhomeEndingRouterOperator] operate: 触发回家结局路由")
	_ExamEndingRouter.evaluate_backhome()

func init(context: Dictionary) -> Dictionary:
	Logging.info("[BackhomeEndingRouterOperator] init: 准备回家结局路由, context keys=%s" % str(context.keys()))
	return context
