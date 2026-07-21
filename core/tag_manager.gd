class_name TagManager extends RefCounted
## TagManager — 管理 persistant_tags 的增删逻辑
##
## 两条规则（冥等/确定性映射）：
## 1. NPC 相识：person_state 进入 know_about+ → 追加 actor:npc:{target}
##    person_state 退回 not_meet/uncharted → 移除 actor:npc:{target}
## 2. 诗风站队（V11.1）：基于已创作诗词使用的意象分类
##    遍历 created_poems，从 poem.used_imaginary_types 累加三大类计数
##    功名 > (隐逸+狂放)   → "浊流诗人" (actor:poem:stance:zhuoliu)
##    (隐逸+狂放) > 功名   → "清流诗人" (actor:poem:stance:qingliu)
##    功名 == (隐逸+狂放)  → "中立诗人" (actor:poem:stance:neutral)
##    无任何已创作诗词 → 删除所有 stance tag
##
## 生命周期：PlayerState._ready() 创建 → init() 连接信号 → full_sync() 全量同步

## 诗风 stance tag 三态映射
const STANCE_TAGS := {
	"zhuoliu": "actor:poem:stance:zhuoliu",
	"qingliu": "actor:poem:stance:qingliu",
	"neutral": "actor:poem:stance:neutral",
}

## 相识状态集合（触发 NPC tag 追加）
const KNOWN_STATES := ["know_about", "inner_circle", "blood_oath"]

## 已初始化标记（防止重复 connect）
var _initialized: bool = false


## 连接 EventBus 信号。幂等：重复调用无害。
func init() -> void:
	if _initialized:
		Logging.warn("TagManager.init: already initialized, skipping duplicate connect")
		return
	EventBus.on_person_state_changed.connect(_on_person_state_changed)
	EventBus.on_trait_change.connect(_on_trait_change)
	_initialized = true
	Logging.info("TagManager.init: connected on_person_state_changed + on_trait_change")


## 全量同步：遍历所有 RELATION_TARGET + created_poems，重建 persistant_tags。
## 仅在初始化（读档/新游戏 _ready）时调用一次。
func full_sync() -> void:
	Logging.info("TagManager.full_sync: starting — persistant_tags before: %s" % str(PlayerState.persistant_tags))
	_sync_npc_tags()
	_sync_poem_stance()
	Logging.info("TagManager.full_sync: complete — persistant_tags after: %s" % str(PlayerState.persistant_tags))


# ════════════════════════════════════════════════════════════════
# 信号处理
# ════════════════════════════════════════════════════════════════

func _on_person_state_changed(target_tag: String, new_state: String) -> void:
	Logging.info("TagManager._on_person_state_changed: target=%s, new_state=%s" % [target_tag, new_state])
	var npc_tag := "actor:npc:" + target_tag

	if new_state in KNOWN_STATES:
		if not PlayerState.persistant_tags.has(npc_tag):
			PlayerState.persistant_tags.append(npc_tag)
			Logging.info("TagManager._on_person_state_changed: +%s → persistant_tags now %d tags" % [npc_tag, PlayerState.persistant_tags.size()])
		else:
			Logging.info("TagManager._on_person_state_changed: %s already present, skipping append" % npc_tag)
	else:
		if PlayerState.persistant_tags.has(npc_tag):
			PlayerState.persistant_tags.erase(npc_tag)
			Logging.info("TagManager._on_person_state_changed: -%s → persistant_tags now %d tags" % [npc_tag, PlayerState.persistant_tags.size()])
		else:
			Logging.info("TagManager._on_person_state_changed: %s not present, nothing to remove" % npc_tag)


func _on_trait_change() -> void:
	Logging.info("TagManager._on_trait_change: trait 变动，重新计算诗风 stance")
	_sync_poem_stance()


# ════════════════════════════════════════════════════════════════
# 内部同步逻辑
# ════════════════════════════════════════════════════════════════

## 遍历所有 RELATION_TARGET，为已相识的 NPC 补/删 actor:npc:{target} tag
func _sync_npc_tags() -> void:
	var added := 0
	var removed := 0

	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		if target_tag.is_empty():
			Logging.warn("TagManager._sync_npc_tags: 空 target_tag for enum_value=%d, skipping" % target_enum_value)
			continue

		var state := RelationFlagManager.get_person_state(target_tag)
		var npc_tag := "actor:npc:" + target_tag

		if state in KNOWN_STATES:
			if not PlayerState.persistant_tags.has(npc_tag):
				PlayerState.persistant_tags.append(npc_tag)
				added += 1
				Logging.info("TagManager._sync_npc_tags: +%s (state=%s)" % [npc_tag, state])
		else:
			if PlayerState.persistant_tags.has(npc_tag):
				PlayerState.persistant_tags.erase(npc_tag)
				removed += 1
				Logging.info("TagManager._sync_npc_tags: -%s (state=%s)" % [npc_tag, state])

	Logging.info("TagManager._sync_npc_tags: done — added=%d, removed=%d, total persistant=%d" % [added, removed, PlayerState.persistant_tags.size()])


## V11.1: 遍历 created_poems，从 poem.used_imaginary_types 累加三大类计数 → stance tag
func _sync_poem_stance() -> void:
	var gongming_count := 0
	var yinyi_count := 0
	var kuangfang_count := 0

	for entry in PlayerState.created_poems:
		if not entry is Poem:
			Logging.info("TagManager._sync_poem_stance: non-Poem element in created_poems, skipping")
			continue
		var poem: Poem = entry as Poem
		var types: Dictionary = poem.used_imaginary_types
		if types.is_empty():
			Logging.info("TagManager._sync_poem_stance: poem '%s' used_imaginary_types empty, skipped" % poem.uuid)
			continue
		gongming_count += types.get("功名", 0)
		yinyi_count += types.get("隐逸", 0)
		kuangfang_count += types.get("狂放", 0)
		Logging.info("TagManager._sync_poem_stance: poem='%s' types=%s" % [poem.name, str(types)])

	var qingliu_side := yinyi_count + kuangfang_count

	var stance: String
	if gongming_count == 0 and qingliu_side == 0:
		stance = ""
	elif gongming_count > qingliu_side:
		stance = "zhuoliu"
	elif qingliu_side > gongming_count:
		stance = "qingliu"
	else:
		stance = "neutral"

	Logging.info("TagManager._sync_poem_stance(V11.1): 功名=%d, 隐逸=%d, 狂放=%d → stance=%s" % [gongming_count, yinyi_count, kuangfang_count, stance])
	_replace_stance_tag(stance)


## 互斥替换：先清空所有 stance 族 tag，再放入当前 stance
func _replace_stance_tag(new_stance: String) -> void:
	# 1. 移除所有已有的 stance tag
	for stance_key in STANCE_TAGS.values():
		if PlayerState.persistant_tags.has(stance_key):
			PlayerState.persistant_tags.erase(stance_key)
			Logging.info("TagManager._replace_stance_tag: removed %s" % stance_key)

	# 2. 无诗 → 不放任何 stance tag（已清空，直接返回）
	if new_stance.is_empty():
		Logging.info("TagManager._replace_stance_tag: 无诗创作，所有 stance tag 已清除")
		return

	# 3. 放入当前 stance
	var new_tag: String = STANCE_TAGS[new_stance]
	PlayerState.persistant_tags.append(new_tag)
	Logging.info("TagManager._replace_stance_tag: added %s" % new_tag)


# ════════════════════════════════════════════════════════════════
# 🆕 死亡标签注入 — 死亡前由 SurvivalManager 调用
# ════════════════════════════════════════════════════════════════

static func inject_death_tags() -> void:
	Logging.info("[TagManager] inject_death_tags: 开始死亡标签注入")

	if PlayerState.has_trait("poisoned"):
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_POISONED))

	if _last_action_contains("action:baiye:threaten"):
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_THREATEN))

	var drain_src: String = PlayerState.get_last_health_drain_source()
	if not drain_src.is_empty():
		Logging.info("[TagManager] inject_death_tags: last_health_drain_source='%s'" % drain_src)
		if _is_poem_related_drain(drain_src):
			_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_POEM_IMPLOSION))
		elif _is_fangshi_related_drain(drain_src):
			_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_OVERWORK))

	if PlayerState.has_trait("sprained_ankle"):
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_SPRAINED))

	if PlayerState.get_stat_val("money") > 60:
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_RICH_FUNERAL))

	if _has_known_npc():
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_HAS_FRIENDS))

	_inject_poem_stance_death_tag()

	if PlayerState.get_stat_val("money") < 10:
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_POOR))

	Logging.info("[TagManager] inject_death_tags: 完成, current_action_tags=%s" % str(PlayerState.current_action_tags))


static func _append_death_tag(tag: String) -> void:
	if not PlayerState.current_action_tags.has(tag):
		PlayerState.current_action_tags.append(tag)
		Logging.info("[TagManager] _append_death_tag: +%s" % tag)


static func _last_action_contains(substr: String) -> bool:
	for tag in PlayerState.last_action_tags:
		if tag.contains(substr):
			return true
	return false


static func _is_poem_related_drain(src: String) -> bool:
	return src.contains("poem") or src.contains("imaginary")


static func _is_fangshi_related_drain(src: String) -> bool:
	return src.contains("fangshi")


static func _has_known_npc() -> bool:
	var known := RelationFlagManager.get_known_targets()
	return not known.is_empty()


static func _inject_poem_stance_death_tag() -> void:
	# V11.1: 基于已创作诗词使用的意象分类（而非当前持有）
	var gongming_count: int = 0
	var yinyi_count: int = 0
	var kuangfang_count: int = 0
	for entry in PlayerState.created_poems:
		if not entry is Poem:
			continue
		var poem: Poem = entry as Poem
		var types: Dictionary = poem.used_imaginary_types
		if types.is_empty():
			continue
		gongming_count += types.get("功名", 0)
		yinyi_count += types.get("隐逸", 0)
		kuangfang_count += types.get("狂放", 0)

	var qingliu_side := yinyi_count + kuangfang_count

	if gongming_count == 0 and qingliu_side == 0:
		return

	if qingliu_side > gongming_count:
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_GOOD_POET))
	elif gongming_count > qingliu_side:
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_BAD_POET))
	else:
		_append_death_tag(ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTOR_DEATH_NEUTRAL_POET))
