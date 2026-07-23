@tool
class_name ExamEndingRouterOperator extends BaseOperator
## 大考结局路由 Operator
## 在 event_exam_30 的 choice_result 中执行，调用 ExamEndingRouter.evaluate()

const _ExamEndingRouter = preload("res://core/exam_ending_router.gd")

func operate():
	Logging.info("[ExamEndingRouterOperator] operate: 触发结局路由")
	_ExamEndingRouter.evaluate()

func init(context: Dictionary) -> Dictionary:
	Logging.info("[ExamEndingRouterOperator] init: 准备结局路由, context keys=%s" % str(context.keys()))
	return context
