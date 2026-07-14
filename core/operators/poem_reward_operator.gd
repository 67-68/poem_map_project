@tool
class_name PoemRewardOperator extends BaseOperator

## V11: 诗词奖励操作符 — 选择一首诗词消耗，根据 mode 产出对应资源
##
## V11 变更:
##   - 新增 xing_wang 模式：双属性输出（灵感+声望）+ npc_trade_tier 集成
##
## mode 决定产出资源类型:
##   - money  → money（金钱）
##   - fame   → prestige（文学声望）
##   - baiye  → progress（仕途进度）
##   - xing_wang → inspiration（兴）+ prestige（望），npc_trade_tier 提升等级
##
## 诗词 level 映射到 named_amounts 档位 (xing_wang/money 高一档: 1→medium, 2→large, 3→extra_large)。
## 消费时复用 PoemCraftingCalculator.calculate_level_upgrade_probability
## 进行概率升级（L1→L2 48%, L2→L3 48%, L3 无升级）。

@export_enum("money", "fame", "baiye", "xing_wang") var mode: String = "money"
@export var show_hint_on_reward: bool = true

## V10.1: money 模式升一级 — 1→medium, 2→large, 3→extra_large
const LEVEL_TO_SIZE_BASE := {
	1: "small",
	2: "medium",
	3: "large",
}

const LEVEL_TO_SIZE_MONEY := {
	1: "medium",
	2: "large",
	3: "extra_large",
}

## V11: xing_wang 模式 — 双属性产出对应 prop 名称
const XING_WANG_PROPS := ["inspiration", "prestige"]

const MODE_TO_PROP := {
	"money": "money",
	"fame": "prestige",
	"baiye": "progress",
}

const SIZE_DISPLAY := {
	"small": "少量",
	"medium": "中等",
	"large": "大量",
	"extra_large": "巨额",
}

const MODE_DISPLAY := {
	"money": "金钱",
	"fame": "文学声望",
	"baiye": "仕途进度",
	"xing_wang": "灵感+声望",
}


## 🆕 静态可行性检查：当前是否有任何 Poem trait 可用。
## 用于 sub-action picker 构建阶段决定隐藏/显示。
static func is_viable() -> bool:
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			continue
		if trait_ is Poem:
			Logging.info('[PoemRewardOperator] is_viable: 发现 Poem trait %s' % t)
			return true
	Logging.info('[PoemRewardOperator] is_viable: 没有任何 Poem trait 可用')
	return false


func operate():
	Logging.debug('PoemRewardOperator: Starting operate() — mode=%s' % mode)
	if not is_viable():
		Logging.warn('PoemRewardOperator: No Poem traits available, nothing to show')
		return

	var data = []
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			Logging.err('PoemRewardOperator: can not found trait %s' % t)
			continue
		if not (trait_ is Poem):
			Logging.debug('PoemRewardOperator: Skipping non-Poem trait %s' % t)
			continue
		Logging.debug('PoemRewardOperator: Found Poem trait %s (level=%d)' % [t, trait_.level])
		data.append(trait_)

	Logging.debug('PoemRewardOperator: Pushing picker to stack with %d poem traits' % data.size())
	EventBus.push_picker.emit(data, _on_poem_picked, null, Callable())


func _on_poem_picked(poem_picked):
	#breakpoint
	if not poem_picked:
		Logging.warn('PoemRewardOperator: No poem picked, skipping reward')
		return

	var poem = poem_picked as Poem
	if not poem:
		Logging.err('PoemRewardOperator: picked item is not a Poem')
		return

	Logging.info('PoemRewardOperator: Poem picked — uuid=%s, name=%s, level=%d' % [poem.uuid, poem.name, poem.level])

	# ── 1. 计算升级概率 ──
	var base_level: int = poem.level
	var upgrade_prob: float = PoemCraftingCalculator.calculate_level_upgrade_probability(base_level)
	Logging.info('PoemRewardOperator: base_level=%d, upgrade_probability=%.3f' % [base_level, upgrade_prob])

	# ── 2. 掷骰子 ──
	var effective_level: int = base_level
	var upgrade_succeeded: bool = false
	if upgrade_prob > 0.0:
		var roll: float = randf()
		Logging.info('PoemRewardOperator: randf()=%.3f vs upgrade_prob=%.3f' % [roll, upgrade_prob])
		if roll < upgrade_prob:
			effective_level = mini(base_level + 1, 3)
			upgrade_succeeded = true
			Logging.info('PoemRewardOperator: 升级成功！%d → %d' % [base_level, effective_level])
		else:
			Logging.info('PoemRewardOperator: 升级失败，保持 level=%d' % base_level)
	else:
		Logging.info('PoemRewardOperator: level=%d 无升级空间' % base_level)

	# ── 3. npc_trade_tier 等级提升（V11: xing_wang 模式） ──
	if mode == "xing_wang":
		var trade_boost: int = ModifierRegistry.get_npc_trade_tier_boost("zhengqian")
		if trade_boost > 0:
			var original_level := effective_level
			effective_level = mini(effective_level + trade_boost, 3)
			Logging.info('PoemRewardOperator: npc_trade_tier boost=%d → effective_level %d → %d' % [trade_boost, original_level, effective_level])

	# ── 4. level → size（money/xing_wang 模式高一档: 1→medium, 2→large, 3→extra_large）──
	var size_key: String
	if mode == "money" or mode == "xing_wang":
		size_key = LEVEL_TO_SIZE_MONEY.get(effective_level, "medium")
	else:
		size_key = LEVEL_TO_SIZE_BASE.get(effective_level, "small")
	Logging.info('PoemRewardOperator: effective_level=%d → size=%s (mode=%s)' % [effective_level, size_key, mode])

	# ── 5. 执行收益 ──
	if mode == "xing_wang":
		# V11: 双属性输出 — 灵感(兴) + 声望(望)
		for prop_name in XING_WANG_PROPS:
			var prop_op := PropertyOperator.new()
			prop_op.property = prop_name
			prop_op.ranked_value = size_key
			prop_op.init({})
			Logging.info('PoemRewardOperator: xing_wang reward — property=%s, ranked_value=%s, resolved_value=%d' % [prop_name, size_key, prop_op.value])
			prop_op.operate()
	else:
		# 原有单属性输出
		var prop_name: String = MODE_TO_PROP.get(mode, "money")
		Logging.info('PoemRewardOperator: mode=%s → property=%s' % [mode, prop_name])

		var prop_op := PropertyOperator.new()
		prop_op.property = prop_name
		prop_op.ranked_value = size_key
		prop_op.init({})  # 触发 ranked_value → value 解析
		Logging.info('PoemRewardOperator: PropertyOperator created — property=%s, ranked_value=%s, resolved_value=%d' % [prop_name, size_key, prop_op.value])

		prop_op.operate()
		Logging.info('PoemRewardOperator: Reward applied — %s += %d (from Poem level=%d, effective=%d, upgrade=%s)' % [prop_name, prop_op.value, base_level, effective_level, upgrade_succeeded])

	# ── 6. 消耗诗词 ──
	PlayerState.remove_trait(poem.uuid)
	Database.traits.erase(poem.uuid)
	var idx := PlayerState.created_poems.find(poem)
	if idx != -1:
		PlayerState.created_poems.remove_at(idx)
	Logging.info('PoemRewardOperator: 诗词已被消耗: %s (traits=%d, created_poems=%d, db_traits=%d)' % [poem.uuid, PlayerState.traits.size(), PlayerState.created_poems.size(), Database.traits.size()])

	# ── 7. Show hint ──
	if show_hint_on_reward:
		if mode == "xing_wang":
			var size_display: String = SIZE_DISPLAY.get(size_key, "")
			var hint: String = "向郑虔展示《%s》，获%s灵感+声望" % [poem.name, size_display]
			if upgrade_succeeded:
				hint += "（灵感迸发！）"
			show_hint(hint)
		else:
			var prop_display: String = MODE_DISPLAY.get(mode, "")
			var size_display: String = SIZE_DISPLAY.get(size_key, "")
			var hint: String = "《%s》换得%s%s" % [poem.name, size_display, prop_display]
			if upgrade_succeeded:
				hint += "（灵感迸发！）"
			show_hint(hint)


func describe_preview() -> String:
	var prop_display: String = MODE_DISPLAY.get(mode, "")
	var size_hint := ""
	match mode:
		"money":
			size_hint = "（平庸→中等 佳作→大量 绝唱→巨额）"
		"xing_wang":
			size_hint = "（平庸→中等灵感+声望 佳作→大量 绝唱→巨额）"
		"fame":
			size_hint = "（平庸→少量 佳作→中等 绝唱→大量）"
		"baiye":
			size_hint = "（平庸→少量 佳作→中等 绝唱→大量）"
		_:
			size_hint = "（平庸→少量 佳作→中等 绝唱→大量）"
	var text: String = "选择一首诗词换取%s%s" % [prop_display, size_hint]
	Logging.debug('PoemRewardOperator.describe_preview: mode=%s → "%s"' % [mode, text])
	return text
