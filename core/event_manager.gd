extends Node
const _Action = preload("res://core/model/action.gd")
const _ActionTagFilter = preload("res://core/model/action_tag_filter.gd")
const _BaseEvent = preload("res://model/event.gd")
const _EraOperator = preload("res://core/operators/era_operator.gd")
const _EventBase = preload("res://core/model/event_base.gd")
const _EventTicket = preload("res://core/model/event_ticket.gd")
const _ImaginaryConcept = preload("res://core/model/imaginary_concept.gd")
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

# 🆕 EventBase AVERAGE 策略黑名单（会话级）
# key: base_uuid, value: Array[String] — 该 base 中已被封禁的事件 uuid 列表
var _event_base_blacklist: Dictionary = {}

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
    # 🆕 EventBase 管道：era 过滤 + AVERAGE 黑名单/权重再分配
    initial_tickets = _filter_tickets_by_event_bases(initial_tickets, context)
    _apply_event_base_blacklist(initial_tickets)
    scan_events_from_tickets(initial_tickets, nothing_multiplication_weight, fallback_uuid, context)

func scan_death_events():
    """
    在结局之后使用，扫描死亡/失败/结束事件。
    跳过 guarantee_next FIFO 队列 — 人都死了，别排队了。
    """
    if GameState.is_game_over:
        Logging.info("[EventManager] scan_death_events: GameState.is_game_over is true, skipping")
        return
    Logging.info("[EventManager] Starting death event scan (skip_guarantees)")
    var initial_tickets: Array[EventTicket] = []
    for e in Database.get_end_random_events_all().values():
        initial_tickets.append(_create_ticket(e))
    #breakpoint
    scan_events_from_tickets(initial_tickets, 0.0, '', {}, false, true)

func scan_events_from_tickets(initial_tickets: Array[EventTicket], nothing_multiplication_weight = 10.0, fallback_event_uuid: String = "", context: Dictionary = {}, return_only: bool = false, skip_guarantees: bool = false):
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
    var ev_name = roll_events(nothing_multiplication_weight, fallback_event_uuid, context, skip_guarantees)
    if return_only:
        if ev_name:
            _mark_event_base_triggered(ev_name)
        return ev_name if ev_name else ""
    if ev_name:
        # 🆕 标记触发：维护 AVERAGE 黑名单
        _mark_event_base_triggered(ev_name)
        var ev = Database.resolve(ev_name, "BaseEvent", true)
        if ev:
            context = SocialActionResolver.enrich_context(ev, ev_name, context)
        EventBus.request_event_key.emit(ev_name, context)
        Logging.info("[EventManager] 命运降临: " + ev_name)
    else:
        Logging.info("[EventManager] 这次抽取事件，岁月静好")
    

func roll_events(nothing_multiplication_weight = 10.0, fallback_event_uuid: String = "", context: Dictionary = {}, skip_guarantees: bool = false):
    Logging.info("[EventManager] Starting event roll (skip_guarantees=%s)" % skip_guarantees)

    # ── 优先检查 guarantee_next FIFO 队列 ──
    # 必须在 pool 空检查之前，因为无 main_tag 的 guarantee 可以旁路 pool
    # death scan 等场景跳过 guarantees — 人要死了别排队了
    if not skip_guarantees:
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
    else:
        Logging.info("[EventManager] roll_events: skipping guarantee queue (death/dev scan)")

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


# ════════════════════════════════════════════════════════════════
# 🆕 EventBase 管道方法
# ════════════════════════════════════════════════════════════════

## Era 过滤：移除 era 不匹配的 EventBase 所包含的所有事件 ticket
func _filter_tickets_by_event_bases(tickets: Array[EventTicket], context: Dictionary) -> Array[EventTicket]:
    var current_era = context.get('era', GameState.current_era)
    if current_era.is_empty():
        Logging.info("[EventManager] _filter_tickets_by_event_bases: current_era is empty, skipping era filter")
        return tickets

    var all_bases = Database.get_all_event_bases()
    if all_bases.is_empty():
        Logging.info("[EventManager] _filter_tickets_by_event_bases: no EventBases registered, skipping")
        return tickets

    # 收集需要排除的 event uuid 集合
    var excluded_events: Array[String] = []
    for base_uuid in all_bases:
        var base: EventBase = all_bases[base_uuid]
        if base.era.is_empty():
            continue
        if base.era != current_era:
            Logging.info("[EventManager] _filter_tickets_by_event_bases: era 不匹配，排除 base '%s' (base.era='%s', current='%s')，移除 %d 个事件" % [base_uuid, base.era, current_era, base.events.size()])
            for ev_uuid in base.events:
                excluded_events.append(ev_uuid)

    if excluded_events.is_empty():
        return tickets

    var filtered: Array[EventTicket] = []
    var removed_count := 0
    for ticket in tickets:
        if ticket.event_uuid in excluded_events:
            Logging.info("[EventManager] _filter_tickets_by_event_bases: 移除 ticket '%s'（base era 不匹配）" % ticket.event_uuid)
            removed_count += 1
        else:
            filtered.append(ticket)

    Logging.info("[EventManager] _filter_tickets_by_event_bases: 过滤完成，移除 %d 个 ticket，剩余 %d" % [removed_count, filtered.size()])
    return filtered


## AVERAGE 黑名单 + 权重再分配
func _apply_event_base_blacklist(tickets: Array[EventTicket]) -> void:
    var all_bases = Database.get_all_event_bases()
    if all_bases.is_empty():
        return

    for base_uuid in all_bases:
        var base: EventBase = all_bases[base_uuid]
        if base.draw_strategies != "AVERAGE":
            continue
        if base.events.is_empty():
            continue

        var blacklist: Array = _event_base_blacklist.get(base_uuid, [])

        # 收集该 base 在 tickets 中的 ticket
        var all_base_tickets: Array[EventTicket] = []
        var banned_tickets: Array[EventTicket] = []
        var active_tickets: Array[EventTicket] = []

        for ticket in tickets:
            var ticket_base = Database.get_event_base_for_event(ticket.event_uuid)
            if ticket_base == null or ticket_base.uuid != base_uuid:
                continue
            all_base_tickets.append(ticket)
            if ticket.event_uuid in blacklist:
                banned_tickets.append(ticket)
            else:
                active_tickets.append(ticket)

        if all_base_tickets.is_empty():
            continue

        # 全封禁 → 移除所有
        if active_tickets.is_empty():
            Logging.info("[EventManager] _apply_event_base_blacklist: base '%s' 所有 %d 个事件均在黑名单，全部移除" % [base_uuid, all_base_tickets.size()])
            for t in all_base_tickets:
                tickets.erase(t)
            continue

        # 无封禁 → 不变
        if banned_tickets.is_empty():
            Logging.info("[EventManager] _apply_event_base_blacklist: base '%s' 无封禁事件" % base_uuid)
            continue

        # 部分封禁 → 移除封禁 ticket，权重再分配
        var banned_total_weight := 0.0
        for t in banned_tickets:
            banned_total_weight += t.weight
            tickets.erase(t)

        var weight_per_active: float = 0.0
        if active_tickets.size() > 0:
            weight_per_active = banned_total_weight / float(active_tickets.size())
            for t in active_tickets:
                t.weight += weight_per_active

        Logging.info("[EventManager] _apply_event_base_blacklist: base '%s' 移除 %d 个封禁 ticket（权重=%.1f），权重分配给 %d 个活跃 ticket（各+%.1f）" % [base_uuid, banned_tickets.size(), banned_total_weight, active_tickets.size(), weight_per_active])


## 标记事件已触发：若事件属于 AVERAGE 策略的 EventBase，加入黑名单
func _mark_event_base_triggered(event_uuid: String) -> void:
    if event_uuid.is_empty():
        return

    var base = Database.get_event_base_for_event(event_uuid)
    if base == null:
        return

    if base.draw_strategies != "AVERAGE":
        return

    if not _event_base_blacklist.has(base.uuid):
        _event_base_blacklist[base.uuid] = []
    var blacklist: Array = _event_base_blacklist[base.uuid]
    if event_uuid not in blacklist:
        blacklist.append(event_uuid)
        Logging.info("[EventManager] _mark_event_base_triggered: '%s' 加入 base '%s' 黑名单（%d/%d）" % [event_uuid, base.uuid, blacklist.size(), base.events.size()])

    if base.reset_on_empty and blacklist.size() >= base.events.size():
        _event_base_blacklist.erase(base.uuid)
        Logging.info("[EventManager] _mark_event_base_triggered: base '%s' 全部 %d 个事件已触发，reset_on_empty=true，清空黑名单" % [base.uuid, base.events.size()])


