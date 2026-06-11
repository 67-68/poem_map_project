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
    if imagery_name.is_empty():
        Logging.err("ImageryAcquisitionOperator: imagery_name 为空")
        return

    EventBus.request_add_imaginary.emit(imagery_name)
