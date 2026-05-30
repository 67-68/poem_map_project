@tool
class_name BaseEvent extends GameEntity
@export var options: Array[BaseOption] = []
@export var provider: BaseProvider
@export var example: String
@export var audio: AudioStream = null
@export var epitaph_text: String = ''
@export var emotion_configs: Array[EmotionConfigs] = []

func init(context: Dictionary) -> Array:
    # Phase 1: provider.init 先执行，修改 context
    if provider:
        context = provider.init(context)
    
    # Phase 2: provider.provide 产出额外选项
    # 🔒 使用临时数组合并，不修改永久属性 options（防止重复触发时选项累积）
    var all_options: Array[BaseOption] = options.duplicate()
    if provider:
        var extra_options: Array = provider.provide(context)
        if extra_options.size() > 0:
            all_options.append_array(extra_options)
    
    # Phase 3: 所有选项（原生 + provider 产出的）统一初始化
    for o in all_options:
        if o:
            o.init(context)
    
    # 返回合并后的全量选项数组，供调用方（NarrativeOverlay）渲染按钮
    return all_options
