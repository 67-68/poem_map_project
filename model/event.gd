@tool
class_name BaseEvent extends GameEntity
@export var options: Array[BaseOption] = []
@export var provider: BaseProvider
@export var example: String
@export var audio: AudioStream = null
@export var epitaph_text: String = ''
@export var emotion_configs: Array[EmotionConfigs] = []

# ──────────────────────────────────────────────
# Pre-event Interruption Sequence（前置中断序列）
# ──────────────────────────────────────────────
# 按优先级排列的中断处理器列表。每个 step 包含一个 requirement（守卫）
# 和一个 operator（应为 PushEventOperator / PopEventOperator）。
#
# check_interruption(context) 按优先级顺序检查：
#   1. init requirement + operator（从 context 解析参数）
#   2. requirement.compare(PlayerState) 检查
#      - ✅ 通过 → 执行 operator（push/pop 替代事件到栈），然后 break
#      - ❌ 失败 → 跳过，尝试下一个 step
#   3. 首个通过的 step 胜出（first-match-wins），后续 steps 不再检查
#
# 典型场景：事件触发前检查多个条件，按优先级决定是否用另一个事件替代。
# ──────────────────────────────────────────────
class InterruptionStep:
    var requirement: BaseRequirements
    var operator: BaseOperator  # 应为 PushEventOperator 或 PopEventOperator

    func _init(p_requirement: BaseRequirements = null, p_operator: BaseOperator = null):
        requirement = p_requirement
        operator = p_operator

var pre_event_interrupter_sequence: Array[InterruptionStep] = []

func check_interruption(context: Dictionary) -> void:
    """
    按优先级执行前置中断序列（first-match-wins）。
    
    遍历 steps：
    - requirement 通过 ✅ → 执行 operator（push/pop 替代事件），然后 break
    - requirement 失败 ❌ → 跳过，尝试下一步
    
    首个通过的 step 胜出并结束检查。全部失败则无操作。
    该方法不阻断事件本身触发。
    """
    Logging.debug('check_interruption: %d steps in sequence' % pre_event_interrupter_sequence.size())

    for i in range(pre_event_interrupter_sequence.size()):
        var step = pre_event_interrupter_sequence[i]
        if not step:
            Logging.warn('check_interruption: found null step at index %d, skipping' % i)
            continue

        # 1. init 阶段：让 requirement 和 operator 从 context 解析参数
        if step.requirement:
            step.requirement.init(context)
        if step.operator:
            step.operator.init(context)

        # 2. 检查 requirement —— 守卫逻辑
        var passed: bool = true
        if step.requirement:
            passed = step.requirement.compare(PlayerState)

        if not passed:
            Logging.debug('check_interruption: step %d requirement failed, trying next step' % i)
            continue

        # 3. requirement 通过 → 执行 operator（push/pop event），然后结束
        Logging.debug('check_interruption: step %d passed, executing operator and breaking' % i)
        if step.operator:
            step.operator.operate()
        else:
            Logging.warn('check_interruption: step %d passed but operator is null, no action taken' % i)

        Logging.debug('check_interruption: resolved at step %d, sequence done' % i)
        return  # first-match-wins

    Logging.debug('check_interruption: no step passed, no interruption triggered')

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
