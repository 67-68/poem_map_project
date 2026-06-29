extends Node
const _Action = preload("res://core/model/action.gd")
const _ActionTagFilter = preload("res://core/model/action_tag_filter.gd")
const _BaseEvent = preload("res://model/event.gd")
const _EraOperator = preload("res://core/operators/era_operator.gd")
const _EventTicket = preload("res://core/model/event_ticket.gd")
const _ImaginaryTag = preload("res://core/model/imaginary.gd")
const _RelationFlagManager = preload("res://core/relation_flag_manager.gd")
const _RequirementFilter = preload("res://core/model/requirement_filter.gd")
const _SocialActionResolver = preload("res://core/social_action_resolver.gd")
const _TagManager = preload("res://core/tag_manager.gd")
const _RandomEvent = preload("res://model/random_event.gd")

## 硬编码 fallback 映射：archetype → fallback event uuid
const FALLBACK_MAP: Dictionary = {
	"baiye": "baiye_fallback",
	"denggao": "denggao_fallback",
	"duzhuo": "duzhuo_fallback",
	"fangshi": "fangshi_fallback",
	"jiaoyou": "jiaoyou_fallback",
}
## 通用兜底 fallback（当 main_tag 无法匹配任何 archetype 时使用）
const GENERIC_FALLBACK: String = "event_cooldown_wall"

@export var current_event_pool: Array[EventTicket] = []
## 过滤器链：前置函数式过滤器 → 意向匹配
var filters: Array[Callable] = [RequirementFilter.filter, ActionTagFilter.filter]

## 外部通过此信号注入一个事件 key，下一次抽取强制命中该事件（单次消费）
## 新增 main_tag 参数：非空时仅在对应的 main_tag 抽奖中生效；空字符串为通用保证。
signal guarantee_next(event_key: String, main_tag: String)

## 存储被保证的事件 key 队列（FIFO），抽取后 pop_front
var _guaranteed_events: Array[Dictionary] = []

func _ready():
    Logging.info("[EventManager] EventManager initialized")
    # TimeService.on_xun_tick.connect(scan_events)
    Logging.info("[EventManager] Connected to TimeService.on_xun_tick")
    guarantee_next.connect(_on_guarantee_next)

func _on_guarantee_next(event_key: String, main_tag: String) -> void:
    _guaranteed_events.push_back({"event_key": event_key, "main_tag": main_tag})
    Logging.info("[EventManager] Guaranteed next event (FIFO push): " + event_key + " (main_tag: '" + main_tag + "') queue_size=" + str(_guaranteed_events.size()))

## 从 main_tag 推导硬编码 fallback event uuid。
## main_tag 形如 "action:main:baiye" → 提取 "baiye" → 查 FALLBACK_MAP → "baiye_fallback"
## 如果 main_tag 为空或无法匹配 archetype，返回 GENERIC_FALLBACK。
func _resolve_hardcoded_fallback(main_tag: String) -> String:
    var result: String = GENERIC_FALLBACK
    if not main_tag.is_empty():
        # 提取 archetype: "action:main:baiye" → "baiye"
        var archetype: String = main_tag
        if main_tag.begins_with("action:"):
            archetype = main_tag.substr(main_tag.rfind(":") + 1)
        if FALLBACK_MAP.has(archetype):
            result = FALLBACK_MAP[archetype]
    
    Logging.info("[EventManager] _resolve_hardcoded_fallback: main_tag='%s' → '%s'" % [main_tag, result])
    return result


func _create_ticket(event: BaseEvent) -> EventTicket:
    var ticket = EventTicket.new()
    ticket.event_uuid = event.uuid
    ticket.weight = event.weight
    ticket.original_weight = event.weight
    return ticket

func scan_events(nothing_multiplication_weight = 10.0, context: Dictionary = {}):
    """
    扫描事件池，根据权重进行事件抽取

    参数:
        nothing_multiplication_weight: 无事发生的权重倍数，默认为10
        context: 上下文字典，包含main_tag、era等信息
    """
    # 🆕 游戏结束状态锁：如果已触发 game_over，不再扫描新事件
    if GameState.is_game_over:
        Logging.info("[EventManager] scan_events: GameState.is_game_over is true, skipping scan")
        return
    
    #breakpoint
    Logging.info("[EventManager] Starting event scan")

    var initial_tickets: Array[EventTicket] = []
    var main_tag = context.get('main_tag', '')
    # context 可主动指定 era；若未指定则使用 GameState.current_era（由 EraOperator 维护）
    var era = context.get('era', GameState.current_era)
    var events_to_scan = Database.get_random_events(main_tag, era)

    # 🆕 从 context 读取 fallback_event_uuid（由 Action.fallback_event_uuid 传递）
    var fallback_uuid = context.get('fallback_event_uuid', '')
    Logging.info("[EventManager] scan_events: main_tag='%s', fallback_event_uuid='%s'" % [main_tag, fallback_uuid])

    for e in events_to_scan.values():
        initial_tickets.append(_create_ticket(e))
    scan_events_from_tickets(initial_tickets, nothing_multiplication_weight, fallback_uuid, context)

func scan_poem_events(imaginaries: Array[ImaginaryTag]):
    if GameState.is_game_over:
        Logging.info("[EventManager] scan_poem_events: GameState.is_game_over is true, skipping")
        return
    #breakpoint
    var imas = {}
    for i in imaginaries:
        imas[i.uuid] = i

    for p in Database.get_legendary_poems_all().values():
        if Database.get_legendary_poems_all().is_empty():
            Logging.err('the legendary poems is somehow contain nothing! this will cause error!!')
        var created = true
        for d in p.imagenary_demand:
            if not (d.imagenary_name in imas and imas[d.imagenary_name].current_level >= d.level):
                created = false
                break
        if created:
            return p
        
    var tags = []
    for i in imaginaries:
        for entry in i.basic_imaginaries:
            var blueprint_id = entry.get("blueprint_id", "")
            if not blueprint_id.is_empty():
                tags.append(blueprint_id)
    
    # create tickets
    var tickets: Array[EventTicket] = []
    for t in tags:
        for e in Database.get_normal_poem_events_all().values():
            for target_tag in e.target_tags:
                # 🚀 革新匹配：前缀匹配（短 tag 做前缀，匹配长 tag）
                if TagManager.prefix_match(target_tag, t):
                    tickets.append(_create_ticket(e))
    #breakpoint
    scan_events_from_tickets(tickets, 0.0, 'da_you_shi', {})


func scan_death_events():
    """
    在结局之后使用，扫描死亡/失败/结束事件
    """
    if GameState.is_game_over:
        Logging.info("[EventManager] scan_death_events: GameState.is_game_over is true, skipping")
        return
    Logging.info("[EventManager] Starting death event scan")
    var initial_tickets: Array[EventTicket] = []
    for e in Database.get_end_random_events_all().values():
        initial_tickets.append(_create_ticket(e))
    #breakpoint
    scan_events_from_tickets(initial_tickets, 0.0, '', {})

func scan_events_from_tickets(initial_tickets: Array[EventTicket], nothing_multiplication_weight = 10.0, fallback_event_uuid: String = "", context: Dictionary = {}, return_only: bool = false):
    """
    从给定的事件票据池中扫描事件的核心逻辑

    参数:
        initial_tickets: 初始事件票据数组
        nothing_multiplication_weight: 无事发生的权重倍数，默认为10
        fallback_event_uuid: 当无事发生时使用的事件UUID，可选
        context: 上下文字典，包含main_tag等信息
        return_only: 为 true 时不发射 request_event_key，直接返回选中事件的 UUID
    """
    if GameState.is_game_over:
        Logging.info("[EventManager] scan_events_from_tickets: GameState.is_game_over is true, skipping")
        return
    Logging.info("[EventManager] Starting event scan from " + str(initial_tickets.size()) + " initial tickets")
    # 致命修复 1：每次重新算命前，必须清空上一次的签筒！
    current_event_pool.clear()
    Logging.info("[EventManager] Cleared previous event pool")

    current_event_pool.assign(initial_tickets)

    #breakpoint
    for f in filters:
        current_event_pool = f.call(current_event_pool, context) as Array[EventTicket]

    Logging.info("[EventManager] Event pool populated with " + str(current_event_pool.size()) + " eligible events")
    
    # 开始命运抽奖
    var ev_name = roll_events(nothing_multiplication_weight, fallback_event_uuid, context)
    if return_only:
        return ev_name if ev_name else ""
    if ev_name:
        var ev = Database.resolve(ev_name, "BaseEvent", true)
        if ev:
            context = SocialActionResolver.enrich_context(ev, ev_name, context)
        EventBus.request_event_key.emit(ev_name, context)
        Logging.info("[EventManager] 命运降临: " + ev_name)
    else:
        Logging.info("[EventManager] 这次抽取事件，岁月静好")
    

func roll_events(nothing_multiplication_weight = 10.0, fallback_event_uuid: String = "", context: Dictionary = {}):
    Logging.info("[EventManager] Starting event roll")

    # ── 优先检查 guarantee_next FIFO 队列 ──
    # 必须在 pool 空检查之前，因为无 main_tag 的 guarantee 可以旁路 pool
    while _guaranteed_events.size() > 0:
        var entry = _guaranteed_events[0]  # peek front
        var g_key = entry.event_key
        var g_tag = entry.main_tag
        var current_main_tag = context.get('main_tag', '')

        # 分支 A: 无 main_tag → 通用保证，直接旁路所有 filter
        if g_tag.is_empty():
            _guaranteed_events.pop_front()
            var item = Database.resolve(g_key)
            if item is BaseEvent:
                Logging.info("[EventManager] 🎯 Guaranteed (no tag) event (FIFO): " + g_key)
                return g_key
            else:
                Logging.warn("[EventManager] Guaranteed (no tag) key '" + g_key + "' not found or not a BaseEvent, popping and continuing")
                continue  # pop happened above, try next

        # 分支 B: 带 main_tag → 检查是否匹配当前抽奖的 main_tag
        elif g_tag == current_main_tag:
            _guaranteed_events.pop_front()
            for ticket in current_event_pool:
                if ticket.event_uuid == g_key:
                    Logging.info("[EventManager] 🎯 Guaranteed event (" + g_tag + ") (FIFO): " + g_key)
                    return g_key
            Logging.warn("[EventManager] Guaranteed event '" + g_key + "' not in pool after filters, popping and continuing")
            continue  # pop happened above, try next

        # 分支 C: main_tag 不匹配 → 保留 guarantee 供后续抽奖使用，不再继续遍历
        else:
            Logging.warn("[EventManager] Guarantee main_tag '" + g_tag + "' != current main_tag '" + current_main_tag + "', preserving for later draw")
            break  # 跳出 while，进入正常抽奖

    # ── 正常轮盘抽取 ──
    if current_event_pool.is_empty():
        if fallback_event_uuid != "":
            Logging.info("[EventManager] Event pool is empty, using fallback: " + fallback_event_uuid)
            return fallback_event_uuid
        # 🆕 无 context fallback 时，使用硬编码 fallback
        var hardcoded_fallback = _resolve_hardcoded_fallback(context.get('main_tag', ''))
        var fb_event = Database.resolve(hardcoded_fallback)
        if fb_event is _RandomEvent:
            Logging.info("[EventManager] Event pool is empty, using hardcoded fallback: " + hardcoded_fallback)
            return hardcoded_fallback
        Logging.warn("[EventManager] Event pool is empty, hardcoded fallback '" + hardcoded_fallback + "' not found, returning null")
        return null

    var total_weight := 0.0
    for ticket in current_event_pool:
        total_weight += ticket.weight
        Logging.info("[EventManager] Event '" + ticket.event_uuid + "' weight: " + str(ticket.weight))
    
    Logging.info("[EventManager] Total event weight: " + str(total_weight))
        
    # 🎲 工业级无事发生算法：
    # 设定一个空转权重。比如定死为 200，或者设为总权重的 50%。
    # 如果总权重是 100，空转是 50，那么触发真实事件的概率就是 66%
    var null_weight = total_weight * nothing_multiplication_weight
    var final_total = total_weight + null_weight
    Logging.info("[EventManager] Null weight: " + str(null_weight) + ", final total weight: " + str(final_total))

    var roll: float = randf() * final_total
    var current_accumulated := 0.0
    Logging.info("[EventManager] Rolled value: " + str(roll))
    
    for ticket in current_event_pool:
        current_accumulated += ticket.weight
        Logging.info("[EventManager] Checking event '" + ticket.event_uuid + "', accumulated weight: " + str(current_accumulated))
        if roll <= current_accumulated:
            Logging.info("[EventManager] Event selected: " + ticket.event_uuid)
            return ticket.event_uuid
            
    # 如果 roll 出来的数字落在了 null_weight 的区间里，说明抽中了"无事发生"
    if fallback_event_uuid != "":
        Logging.info("[EventManager] Roll fell in null weight range, using fallback event: " + fallback_event_uuid)
        return fallback_event_uuid
    # 🆕 无 context fallback 时，使用硬编码 fallback
    var hardcoded_fallback = _resolve_hardcoded_fallback(context.get('main_tag', ''))
    var fb_event = Database.resolve(hardcoded_fallback)
    if fb_event is _RandomEvent:
        Logging.info("[EventManager] Roll fell in null weight range, using hardcoded fallback: " + hardcoded_fallback)
        return hardcoded_fallback
    Logging.warn("[EventManager] Roll fell in null weight range, hardcoded fallback '" + hardcoded_fallback + "' not found, returning null")
    return null


