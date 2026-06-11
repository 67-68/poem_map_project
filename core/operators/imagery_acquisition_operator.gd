@tool
class_name ImageryAcquisitionOperator extends BaseOperator
## 意象获取操作符 — 由 imagery_add DSL 解析生成。
##
## 在 operate() 时通过 EventBus.request_add_imaginary 广播意象 tag，
## 触发游戏内意象获取逻辑（AddImaginaryHandler 监听并处理）。
##
## DSL 语法: imagery_add(name=ENV_POLITICS_CLOUD_LEYOU)

@export var imagery_name: String  # 4 段式意象 tag（如 ENV_POLITICS_CLOUD_LEYOU）


func operate():
    Logging.info("ImageryAcquisitionOperator.operate: 开始执行，imagery_name='%s'" % imagery_name)

    if imagery_name.is_empty():
        Logging.err("ImageryAcquisitionOperator.operate: imagery_name 为空，跳过")
        return

    # 可选：校验 imagery_name 是否在 Database.imaginaries 中存在
    if not Database.imaginaries.has(imagery_name):
        Logging.warn("ImageryAcquisitionOperator.operate: imagery_name '%s' 在 Database.imaginaries 中不存在，但将继续广播" % imagery_name)

    EventBus.request_add_imaginary.emit(imagery_name)
    Logging.info("ImageryAcquisitionOperator.operate: 已广播 request_add_imaginary('%s')" % imagery_name)
