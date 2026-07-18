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

var SIZE_DISPLAY := {
	"small": tr("CODE_POEM_REWARD_OPERATOR_7BEB46C6C3"),
	"medium": tr("CODE_POEM_REWARD_OPERATOR_C7092C51FD"),
	"large": tr("CODE_POEM_REWARD_OPERATOR_F5C239DF75"),
	"extra_large": tr("CODE_POEM_REWARD_OPERATOR_932A98F687"),
}

var MODE_DISPLAY := {
	"money": tr("CODE_POEM_REWARD_OPERATOR_5CA4682D5D"),
	"fame": tr("CODE_POEM_REWARD_OPERATOR_23C1E43C42"),
	"baiye": tr("CODE_POEM_REWARD_OPERATOR_7C67E3E689"),
	"xing_wang": tr("CODE_POEM_REWARD_OPERATOR_FF9D757A8F"),
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

	# 随机选取一首诗词
	var poem: Poem = _pick_random_poem()
	if not poem:
		Logging.warn('PoemRewardOperator: No Poem traits available, nothing to do')
		return

	Logging.info('PoemRewardOperator: Random poem picked — uuid=%s, name=%s, level=%d' % [poem.uuid, poem.name, poem.level])

	# ── 1. 计算升级概率 ──
	var base_level: int = poem.level
	var upgrade_prob: float = PoemCraftingCalculator.calculate_level_upgrade_probability(base_level)

	# ── 2. 掷骰子 ──
	var effective_level: int = base_level
	var upgrade_succeeded: bool = false
	if upgrade_prob > 0.0:
		var roll: float = randf()
		if roll < upgrade_prob:
			effective_level = mini(base_level + 1, 3)
			upgrade_succeeded = true
			Logging.info('PoemRewardOperator: 升级成功！%d → %d' % [base_level, effective_level])

	# ── 3. npc_trade_tier 等级提升（V11: xing_wang 模式） ──
	if mode == "xing_wang":
		var trade_boost: int = ModifierRegistry.get_npc_trade_tier_boost("zhengqian")
		if trade_boost > 0:
			effective_level = mini(effective_level + trade_boost, 3)

	# ── 4. level → size ──
	var size_key: String
	if mode == "money" or mode == "xing_wang":
		size_key = LEVEL_TO_SIZE_MONEY.get(effective_level, "medium")
	else:
		size_key = LEVEL_TO_SIZE_BASE.get(effective_level, "small")

	# ── 5. 执行收益 ──
	if mode == "xing_wang":
		for prop_name in XING_WANG_PROPS:
			var prop_op := PropertyOperator.new()
			prop_op.property = prop_name
			prop_op.ranked_value = size_key
			prop_op.init({})
			prop_op.operate()
	else:
		var prop_name: String = MODE_TO_PROP.get(mode, "money")
		var prop_op := PropertyOperator.new()
		prop_op.property = prop_name
		prop_op.ranked_value = size_key
		prop_op.init({})
		prop_op.operate()

	# ── 6. 消耗诗词 ──
	PlayerState.remove_trait(poem.uuid)
	Database.traits.erase(poem.uuid)
	var idx := PlayerState.created_poems.find(poem)
	if idx != -1:
		PlayerState.created_poems.remove_at(idx)

	# ── 7. Show hint ──
	if show_hint_on_reward:
		if mode == "xing_wang":
			var size_display: String = SIZE_DISPLAY.get(size_key, "")
			var hint: String = tr("CODE_POEM_REWARD_OPERATOR_9DF9932972") % [poem.name, size_display]
			if upgrade_succeeded:
				hint += tr("CODE_POEM_REWARD_OPERATOR_F88651B977")
			show_hint(hint)
		else:
			var prop_display: String = MODE_DISPLAY.get(mode, "")
			var size_display: String = SIZE_DISPLAY.get(size_key, "")
			var hint: String = tr("CODE_POEM_REWARD_OPERATOR_D206220AA1") % [poem.name, size_display, prop_display]
			if upgrade_succeeded:
				hint += tr("CODE_POEM_REWARD_OPERATOR_F88651B977")
			show_hint(hint)


## 从 PlayerState 中随机选取一首诗词
static func _pick_random_poem() -> Poem:
	var poems: Array[Poem] = []
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			continue
		if trait_ is Poem:
			poems.append(trait_)

	if poems.is_empty():
		return null

	return poems[randi() % poems.size()]


func describe_preview() -> String:
	var prop_display: String = MODE_DISPLAY.get(mode, "")
	var size_hint := ""
	match mode:
		"money":
			size_hint = tr("CODE_POEM_REWARD_OPERATOR_857EF83274")
		"xing_wang":
			size_hint = tr("CODE_POEM_REWARD_OPERATOR_7DA42E20E7")
		"fame":
			size_hint = tr("CODE_POEM_REWARD_OPERATOR_C1599FB99A")
		"baiye":
			size_hint = tr("CODE_POEM_REWARD_OPERATOR_C1599FB99A")
		_:
			size_hint = tr("CODE_POEM_REWARD_OPERATOR_C1599FB99A")
	var text: String = tr("CODE_POEM_REWARD_OPERATOR_DCEF4BD7C0") % [prop_display, size_hint]
	Logging.debug('PoemRewardOperator.describe_preview: mode=%s → "%s"' % [mode, text])
	return text
