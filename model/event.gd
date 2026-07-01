@tool
class_name BaseEvent extends GameEntity

# 命名空间前缀：由 EventBaseLoader 扫描目录结构自动写入
# 格式为 "story_arcs.changan_rainfall."（纯目录路径，不含 uuid）
# 用于 NarrativeOverlay 的路由拦截器判断显示模式
@export var _namespace: String = ""

## 🔒 每个 choice_result 的原始（TRES）operators 快照。
## key = choice_result.get_instance_id()，value = original operators 深拷贝。
## 每次 init() 时恢复到此快照，保证子类追加 operator 时不会累加。
var _base_operators_snapshot: Dictionary = {}

@export var options: Array[BaseOption] = []
@export var provider: BaseProvider

# ──────────────────────────────────────────────
# on_returned — 回归叙事文本
# ──────────────────────────────────────────────
# 当子事件通过 pop_event 弹出栈后，玩家"回归"到此事件时，
# NarrativeOverlay 会将 pop_event 的 transition_text 与此 on_returned
# 合并打印为一个 NarrativeText 条目（叙事过渡），随后创建全新的事件条目
# （而非复活旧条目的选项按钮）。
#
# 留空则回归时只打印 transition_text（若 transition_text 也为空则不打印）。
# 对应 CSV 中的 on_returned 列。
@export var on_returned: String = ''
# ──────────────────────────────────────────────
# Pre-event Interruption Sequence（前置中断序列）
# ──────────────────────────────────────────────
# 每个 step 是一个 ConditionalOperator，包含：
#   - condition:               BaseRequirements（守卫条件）
#   - condition_success_result: Array[BaseOperator]（条件通过后执行的操作）
#
# check_interruption(context) 按优先级顺序检查（first-match-wins）：
#   1. init condition + success operators（从 context 解析参数）
#   2. condition.compare(PlayerState) 检查
#      - ✅ 通过 → 执行 success operators，然后 break
#      - ❌ 失败 → 跳过，尝试下一个 step
#   3. 首个通过的 step 胜出，后续不再检查
#
# 典型场景：事件触发前检查多个条件，按优先级决定是否用另一个事件替代。
# ──────────────────────────────────────────────
# ⚡ 移除 :Array 类型标注，避免 @tool 模式下 .tres 序列化为 null 后赋值 Array 被拒绝 💀
@export var pre_event_interrupter_sequence = []


# ╔══════════════════════════════════════════════════════════════════╗
# ║  三层铁幕契约 · 第一层：Event on_enter（舞台置景）               ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# 职责：
#   构建当前事件的绝对上下文。所有前置计算、flag 初始化、依赖注入
#   必须在此完成。玩家甚至还没看到 UI，一切准备工作必须在此刻结束。
#
# 执行时机：
#   init() 最开头，provider.init / provider.provide / options.init
#   之前执行。确保所有选项的 requirement/choice_result 在初始化时
#   就能读取到 on_enter 设置好的 context 和 PlayerState。
#
# 合法操作：
#   FlagOperator(set), EmotionOperator, ImaginaryOperator,
#   TraitReplaceOperator, PropertyRangeOperator (用在 ConditionalOperator 内)
#
# 契约红线：
#   - ❌ PushEventOperator / PopEventOperator（那是 interruption 的职责）
#   - ❌ 任何"因为玩家选了某个特定选项才应该发生"的后果操作
#   - ❌ 在 on_enter 中放置 choice_result 级别的消耗逻辑
#
# 隐喻：
#   话剧开场前，场务把李白的酒杯摆好，把灯光打亮。观众还没入场，
#   台上的一切都应该处于"就绪"状态。
#
# 参见 DOCUMENTATIONS/events/operator_variable_lifecycle.md §9.3
# ──────────────────────────────────────────────

# 事件级入场结果（即使不选任何选项也会执行）。
# 常用于 flag 初始化、情感值预设、imagenary 置景。
# 这是 on_enter 阶段的核心执行载体。
# 对应 CSV 中的 on_enter 列。
@export var on_enter_result: ChoiceResult


# ──────────────────────────────────────────────
# on_enter — 舞台置景
# ──────────────────────────────────────────────
# 子类可重写此方法以添加自定义的 on_enter 逻辑（如合入 custom_context_params），
# 但必须调用 super.on_enter(context) 以确保事件级结果被执行。
# ──────────────────────────────────────────────
func on_enter(context: Dictionary) -> void:
	if on_enter_result:
		on_enter_result.init(context)
		on_enter_result.operate()
		Logging.info("BaseEvent.on_enter: on_enter_result executed for event '%s'" % name)


func check_interruption(context: Dictionary) -> void:
	"""
	按优先级执行前置中断序列（first-match-wins）。
	
	遍历 steps：
	- requirement 通过 ✅ → 执行 operator（push/pop 替代事件），然后 break
	- requirement 失败 ❌ → 跳过，尝试下一步
	
	首个通过的 step 胜出并结束检查。全部失败则无操作。
	该方法不阻断事件本身触发。
	"""
	if not pre_event_interrupter_sequence:
		Logging.debug('do not found pre_event_interrupter_sequence')
		return
	Logging.debug('check_interruption: %d steps in sequence' % pre_event_interrupter_sequence.size())

	for i in range(pre_event_interrupter_sequence.size()):
		var step: ConditionalOperator = pre_event_interrupter_sequence[i]
		if not step:
			Logging.warn('check_interruption: found null step at index %d, skipping' % i)
			continue

		# 1. init 阶段：让 condition 和 success operators 从 context 解析参数
		if step.condition:
			step.condition.init(context)
		for op in step.condition_success_result:
			if op:
				op.init(context)

		# 2. 检查 condition —— 守卫逻辑
		var passed: bool = true
		if step.condition:
			passed = step.condition.compare(PlayerState)

		if not passed:
			Logging.debug('check_interruption: step %d condition failed, trying next step' % i)
			continue

		# 3. condition 通过 → 执行 success operators（push/pop event），然后结束
		Logging.debug('check_interruption: step %d passed, executing %d operators and breaking' % [i, step.condition_success_result.size()])
		for op in step.condition_success_result:
			if op:
				op.operate()
			else:
				Logging.warn('check_interruption: step %d contains null operator in success_result' % i)

		Logging.debug('check_interruption: resolved at step %d, sequence done' % i)
		return  # first-match-wins

	Logging.debug('check_interruption: no step passed, no interruption triggered')


func init(context: Dictionary) -> Array:
	# Phase 0: on_enter — 舞台置景，构建绝对上下文
	on_enter(context)
	
	# Phase 0.25: lasting_time — 自动推进超时（context 显式传入才覆盖 ui_decl 中的 @export 值）
	if context.has("lasting_time"):
		if not ui_decl:
			ui_decl = UIDecl.new()
		ui_decl.lasting_time = context.get("lasting_time", 0.0)
	var _lt = ui_decl.lasting_time if ui_decl else 0.0
	Logging.debug("BaseEvent.init: lasting_time=%s for event '%s'" % [_lt, name])
	
	# Phase 0.5: 疾病选项劫持 — 扫描玩家是否拥有带 hijack_provider 的 Disease trait
	var hijack_prov: BaseProvider = null
	for t_key in PlayerState.get_traits():
		var t = Database.get_trait(t_key)
		if t is Disease and t.hijack_provider:
			hijack_prov = t.hijack_provider
			Logging.info('[BaseEvent] Disease hijack active: ' + t_key + ' hijacking event: ' + name)
			break
	
	var all_options: Array[BaseOption] = options.duplicate()
	
	if hijack_prov:
		# ── 劫持路径：疾病 provider 接管 ──
		# 1. hijack_provider.init 修改 context + 给原生选项增加额外消耗
		context = hijack_prov.init(context)
		# 2. hijack_provider.provide 产出狂症选项
		var crazy_options: Array = hijack_prov.provide(context)
		if crazy_options.size() > 0:
			all_options.insert(0, crazy_options[0])  # 插到最前面
		# 3. 跳过原始 provider（被劫持）
	else:
		# ── 正常路径：原始 provider ──
		# Phase 1: provider.init 修改 context
		if provider:
			context = provider.init(context)
		
		# Phase 2: provider.provide 产出额外选项
		if provider:
			var extra_options: Array = provider.provide(context)
			if extra_options.size() > 0:
				all_options.append_array(extra_options)
	
	# Phase 3: 所有选项统一初始化（幂等守卫：先恢复 choice_result operators）
	for o in all_options:
		if o:
			if "choice_result" in o and o.choice_result != null:
				var cr = o.choice_result
				var cr_id = cr.get_instance_id()
				if not _base_operators_snapshot.has(cr_id):
					_base_operators_snapshot[cr_id] = cr.operators.duplicate(true)
				cr.operators.clear()
				for base_op in _base_operators_snapshot[cr_id]:
					cr.operators.append(base_op.duplicate())
			o.init(context)
	
	# 返回合并后的全量选项数组
	return all_options
