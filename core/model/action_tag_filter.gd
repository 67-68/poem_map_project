class_name ActionTagFilter extends BaseEventPoolFilter

static func filter(tickets: Array[EventTicket], _context: Dictionary) -> Array[EventTicket]:
	var new_events = {}
	var current_tags = PlayerState.current_action_tags
	var main_tag = _context.get('main_tag', '')
	var tag_match_mode: String = _context.get('tag_match_mode', 'any')

	# 前缀匹配：用 main_tag 找对应桶（如 action:main:baiye:general 匹配 action:main:baiye）
	var matched_bucket: Dictionary = {}
	if main_tag:
		matched_bucket = Database.get_random_events(main_tag)

	for ticket in tickets:
		var e: BaseEvent

		# 优先使用 context 中的 main_tag 前缀匹配路由到对应桶
		if not matched_bucket.is_empty():
			e = matched_bucket.get(ticket.event_uuid)

		# 如果没有 main_tag 或对应桶中没有，尝试从所有事件中查找
		if not e:
			e = Database.resolve(ticket.event_uuid)

		if not e:
			Logging.err("[ActionTagFilter] Event not found: " + ticket.event_uuid)
			continue

		# 1. 天地法则：没有标签的全局事件
		if not e.target_tags or e.target_tags.is_empty():
			if tag_match_mode == 'all':
				# AND 模式下，全局事件无标签 → 不满足双 tag 要求，跳过
				Logging.info("[ActionTagFilter] AND mode: event '%s' has no target_tags, skipping" % ticket.event_uuid)
				continue
			new_events[ticket.event_uuid] = ticket
			Logging.warn('放行没有标签的全局事件')
			continue

		# 2. 专属拦截：玩家现在闲着（无tag），那带有专属标签的事件直接略过！
		if not current_tags or current_tags.is_empty():
			Logging.warn("检查自己是不是又忘记给玩家加current tags了！！！又筛选掉了")
			continue

		if tag_match_mode == 'all':
			# ── AND 模式：仅 required_tags（actor:npc + social:X）必须全部匹配 ──
			#    current_tags 中其余 tag（sub_uuid 等）仅做 bucket 路由，不参与强制匹配
			var required_tags: Array = _context.get('required_tags', current_tags)
			if required_tags.is_empty():
				required_tags = current_tags
			var all_match := true
			for required_tag in required_tags:
				if not e.target_tags.has(required_tag):
					all_match = false
					break
			if all_match:
				if new_events.has(ticket.event_uuid):
					new_events[ticket.event_uuid].weight += ticket.original_weight * 3
				else:
					new_events[ticket.event_uuid] = ticket
					new_events[ticket.event_uuid].weight *= 9
				Logging.info("[ActionTagFilter] AND mode: event '%s' 匹配全部 required_tags: %s" % [ticket.event_uuid, str(current_tags)])
			continue  # AND 模式下跳过下方的 OR 匹配

		# 3. 🚀 革新匹配：前缀匹配（短 tag 做前缀，匹配长 tag） — OR 模式
		for tag in current_tags:
			for target_tag in e.target_tags:
				if tag == target_tag:
					if new_events.has(ticket.event_uuid):
						# 多个 tag 命中，继续追加原始权重
						new_events[ticket.event_uuid].weight += ticket.original_weight * 3
					else:
						new_events[ticket.event_uuid] = ticket
						# 首次命中，权重起飞！
						new_events[ticket.event_uuid].weight *= 9
					break  # 一个事件匹配一个当前 tag 就够了，跳出 target_tag 内层循环
					
	# 将字典的值强转回 Array[EventTicket]
	var result: Array[EventTicket] = []
	result.assign(new_events.values())
	PlayerState.current_action_tags.clear()
	if not result:
		Logging.err('filter 把所有事件都干掉了，很可能出问题了')
		#breakpoint
	return result
