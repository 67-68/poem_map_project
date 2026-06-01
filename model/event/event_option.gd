class_name EventOption extends BaseOption

# 使用description作为button text
@export var choice_result: ChoiceResult
@export var requirement: BaseRequirements = null
# 从 context DSL 解析出的自定义参数，init 时 merge 进 context
@export var custom_context_params: Dictionary = {}

# 🔒 transient 字段：存储解析后的 button text，不污染原始 description 字段
# 每次 init() 时重新计算，避免复用 EventOption 时展示被前一次解析污染的内容
var _resolved_description: String = ""

func init(context: Dictionary) -> Dictionary:
    var context_ = context.duplicate()
    _resolved_description = ""
    
    # 合并自定义参数（乘法叠加，与 RandomEvent 行为一致）
    if not custom_context_params.is_empty():
        Util.merge_context(context_, custom_context_params)
    
    # 解析 description 中的动态差值占位符
    # {some_prop}  → 从当前选项对象上取属性
    # {@some_prop} → 从 context 字典中取属性
    # 🔒 不直接修改 self.description（会污染 Resource 的永久属性），
    #    而是存入 transient 字段 _resolved_description，
    #    渲染时优先读取 _resolved_description
    if not description.is_empty():
        # 使用 tr_and_resolve：CONSTANT 先 tr() 查表再插值，普通文本直接返回
        _resolved_description = Util.tr_and_resolve(description, context_, self)
        if _resolved_description != description:
            Logging.info("[EventOption] 解析后 description: %s" % _resolved_description)
    
    if requirement:
        requirement.init(context_)
    if choice_result:
        choice_result.init(context_)
    return context_
