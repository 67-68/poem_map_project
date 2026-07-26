@tool
class_name PoemConversionOperator extends BaseOperator

## 诗词转化操作符 — 选择一首诗词消耗，按 level 产出指定资源
##
## 与 PoemRewardOperator 的核心差异:
##   - 无升级概率，严格按 poem.level 对应资源档位
##   - 支持 type_prefered 按诗词类型过滤（基于 used_imaginary_types）
##   - poem_lowest_level 控制 level→size 的整体偏移
##
## level → size 偏移公式:
##   effective_index = poem.level - poem_lowest_level + 1
##   size_key = LEVEL_TO_SIZE_BASE[effective_index]
##
## type_prefered 过滤:
##   展平 poem.used_imaginary_types → sorted Array → 与 type_prefered sorted 比较
##   strict (!allow_fuzzy):  数组严格相等
##   fuzzy  (allow_fuzzy):   仅比较计数分布（keys 可不同，values 必须相同）
##   type_prefered 无匹配时直接 return，不回落全量随机

const LEVEL_TO_SIZE_BASE := {
	-1: "xxs",
	0: "xs",
	1: "s",
	2: "m",
	3: "l",
	4: "xl",
	5: "xxl"
}

## size_key → PropertyOperator.ranked_value 映射（s/m/l/xl 档位走 ranked_value）
const SIZE_KEY_TO_RANKED := {
	"xs": "extra_small",
	"s": "small",
	"m": "medium",
	"l": "large",
	"xl": "extra_large",
}

## 这些档位在 ranked_value 枚举中不存在，需要直接查 named_amounts → 设置 value
const SIZE_NEEDS_DIRECT_VALUE := ["xxs", "xxl"]

@export var poem_lowest_level: int = 1  ## 诗词等级偏移基准，1 级诗词对应 poem_lowest_level 级奖励
@export var resource_uuid: String = 'money'  ## 产出资源名（如 money, prestige, progress, inspiration）
@export var type_prefered: Array[String] = []  ## 偏好诗词类型（对应 PoemType.composition），空则不限制
@export var allow_fuzzy_type: bool = false  ## 模糊匹配：仅比较 used_imaginary_types 的计数分布
@export var show_hint_on_convert: bool = true  ## 是否在转化后展示 hint


## 🆕 静态可行性检查：当前是否有任何 Poem trait 可用。
static func is_viable() -> bool:
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			continue
		if trait_ is Poem:
			Logging.info('[PoemConversionOperator] is_viable: 发现 Poem trait %s' % t)
			return true
	Logging.info('[PoemConversionOperator] is_viable: 没有任何 Poem trait 可用')
	return false


func operate():
	Logging.info('PoemConversionOperator.operate: start — resource_uuid=%s poem_lowest_level=%d type_prefered=%s allow_fuzzy=%s' % [resource_uuid, poem_lowest_level, str(type_prefered), str(allow_fuzzy_type)])

	# ── 1. 选取诗词 ──
	var poem: Poem
	if not type_prefered.is_empty():
		Logging.info('PoemConversionOperator.operate: type_prefered 非空，使用类型过滤选取')
		poem = _pick_poem_by_type()
		if not poem:
			Logging.warn('PoemConversionOperator.operate: type_prefered=%s 无匹配 Poem，直接返回' % str(type_prefered))
			return
	else:
		Logging.info('PoemConversionOperator.operate: type_prefered 为空，全量随机选取')
		poem = _pick_random_poem()
		if not poem:
			Logging.warn('PoemConversionOperator.operate: 没有可用的 Poem trait，直接返回')
			return

	Logging.info('PoemConversionOperator.operate: 选中 poem — uuid=%s name=%s level=%d used_imaginary_types=%s' % [poem.uuid, poem.name, poem.level, str(poem.used_imaginary_types)])

	# ── 2. level → size_key ──
	var effective_index: int = poem.level - poem_lowest_level + 1
	var size_key: String = LEVEL_TO_SIZE_BASE.get(effective_index, "s")
	Logging.info('PoemConversionOperator.operate: poem.level=%d - poem_lowest_level=%d + 1 → effective_index=%d → size_key=%s' % [poem.level, poem_lowest_level, effective_index, size_key])

	# ── 3. 创建 PropertyOperator ──
	var prop_op := PropertyOperator.new()
	prop_op.property = resource_uuid

	if size_key in SIZE_NEEDS_DIRECT_VALUE:
		# xxs / xxl 档位：ranked_value 枚举不包含，直接查 named_amounts
		Logging.info('PoemConversionOperator.operate: size_key=%s 需直接查 named_amounts' % size_key)
		var amounts = NamedDSLParser._load_named_amounts()
		var prop_lower := resource_uuid.to_lower()
		var found := false
		for key in amounts:
			if key.begins_with(size_key + "_") and prop_lower in key:
				var entry_val = amounts[key]
				if entry_val > 0:
					prop_op.value = entry_val
					found = true
					Logging.info('PoemConversionOperator.operate: direct lookup %s → %s = %d' % [size_key, key, entry_val])
					break
		if not found:
			Logging.err('PoemConversionOperator.operate: 找不到 %s_*_gain 的 named_amount for resource=%s，size_key=%s 无法解析' % [size_key, resource_uuid, size_key])
			return
	else:
		# s/m/l/xl 档位：走 ranked_value → PropertyOperator.init 自动解析 named_amounts
		prop_op.ranked_value = SIZE_KEY_TO_RANKED.get(size_key, "small")
		Logging.info('PoemConversionOperator.operate: ranked_value=%s' % prop_op.ranked_value)

	prop_op.init({})
	prop_op.operate()

	# ── 4. 消耗诗词 ──
	# 先删 created_poems 再 remove_trait：确保 TagManager._on_trait_change 统计时诗词已不在列表
	var idx := PlayerState.created_poems.find(poem)
	if idx != -1:
		PlayerState.created_poems.remove_at(idx)
		Logging.info("PoemConversionOperator.operate: removed poem '%s' from created_poems (idx=%d)" % [poem.uuid, idx])
	else:
		Logging.warn("PoemConversionOperator.operate: poem '%s' not found in created_poems" % poem.uuid)
	PlayerState.remove_trait(poem.uuid)
	Database.traits.erase(poem.uuid)
	Logging.info("PoemConversionOperator.operate: 已消耗诗词 '%s'" % poem.uuid)

	# ── 5. Show hint ──
	if show_hint_on_convert:
		var size_display := _size_key_to_display(size_key)
		var prop_cn := _resource_uuid_to_display(resource_uuid)
		var hint := tr("CODE_POEM_CONVERSION_OPERATOR_9A2F1B7C3D") % [poem.name, size_display, prop_cn]
		Logging.info('PoemConversionOperator.operate: hint=%s' % hint)
		show_hint(hint)


## ──────────────────────────────────────────────
## 类型匹配辅助
## ──────────────────────────────────────────────

## 从 used_imaginary_types Dictionary 提取排序后的计数分布
## 例: {"功名": 2, "隐逸": 1} → [1, 2]
static func _get_count_distribution(d: Dictionary) -> Array:
	var counts: Array = []
	for key in d:
		var v = d[key]
		if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
			counts.append(int(v))
		else:
			Logging.warn("PoemConversionOperator._get_count_distribution: 非数值 value for key=%s: %s" % [key, str(v)])
	counts.sort()
	Logging.info("PoemConversionOperator._get_count_distribution: input=%s → counts=%s" % [str(d), str(counts)])
	return counts


## 判断一首 Poem 是否匹配 type_prefered
func _poem_matches_type(poem: Poem) -> bool:
	if type_prefered.is_empty():
		Logging.info('PoemConversionOperator._poem_matches_type: type_prefered 为空，判定为匹配')
		return true

	if poem.used_imaginary_types.is_empty():
		Logging.info('PoemConversionOperator._poem_matches_type: poem %s used_imaginary_types 为空，跳过' % poem.uuid)
		return false

	# 展平 used_imaginary_types → sorted Array
	var poem_types: Array[String] = []
	for key in poem.used_imaginary_types:
		var count: int = poem.used_imaginary_types[key]
		for _i in range(count):
			poem_types.append(key)
	poem_types.sort()
	Logging.info('PoemConversionOperator._poem_matches_type: poem %s sorted_types=%s' % [poem.uuid, str(poem_types)])

	var prefered_sorted := type_prefered.duplicate()
	prefered_sorted.sort()
	Logging.info('PoemConversionOperator._poem_matches_type: type_prefered sorted=%s' % str(prefered_sorted))

	if allow_fuzzy_type:
		# 模糊匹配：仅比较计数分布
		var poem_counts := _get_count_distribution(poem.used_imaginary_types)
		var target_dict: Dictionary = {}
		for t in type_prefered:
			target_dict[t] = target_dict.get(t, 0) + 1
		var target_counts := _get_count_distribution(target_dict)
		Logging.info('PoemConversionOperator._poem_matches_type: fuzzy — poem_counts=%s target_counts=%s → %s' % [str(poem_counts), str(target_counts), str(poem_counts == target_counts)])
		return poem_counts == target_counts
	else:
		# 严格匹配：展平后的 sorted 数组必须完全相等
		var matched := poem_types == prefered_sorted
		Logging.info('PoemConversionOperator._poem_matches_type: strict — poem_types=%s prefered=%s → %s' % [str(poem_types), str(prefered_sorted), str(matched)])
		return matched


## ──────────────────────────────────────────────
## 诗词选取
## ──────────────────────────────────────────────

## 从 PlayerState 中按 type_prefered 过滤选取一首诗词
func _pick_poem_by_type() -> Poem:
	Logging.info('PoemConversionOperator._pick_poem_by_type: type_prefered=%s allow_fuzzy=%s' % [str(type_prefered), str(allow_fuzzy_type)])
	var matching: Array[Poem] = []
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			Logging.info('PoemConversionOperator._pick_poem_by_type: trait %s 在 Database 中不存在，跳过' % t)
			continue
		if trait_ is Poem:
			Logging.info('PoemConversionOperator._pick_poem_by_type: 检查 Poem %s (%s) level=%d' % [trait_.name, trait_.uuid, trait_.level])
			if _poem_matches_type(trait_):
				Logging.info('PoemConversionOperator._pick_poem_by_type: Poem %s 匹配!' % trait_.uuid)
				matching.append(trait_)
			else:
				Logging.info('PoemConversionOperator._pick_poem_by_type: Poem %s 不匹配' % trait_.uuid)

	if matching.is_empty():
		Logging.warn('PoemConversionOperator._pick_poem_by_type: type_prefered=%s 无匹配 Poem' % str(type_prefered))
		return null

	Logging.info('PoemConversionOperator._pick_poem_by_type: 匹配到 %d 首 Poem，随机选取' % matching.size())
	return matching[randi() % matching.size()]


## 从 PlayerState 中随机选取一首诗词（不限制类型）
static func _pick_random_poem() -> Poem:
	Logging.info('PoemConversionOperator._pick_random_poem: 收集所有 Poem traits')
	var poems: Array[Poem] = []
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if not trait_:
			continue
		if trait_ is Poem:
			poems.append(trait_)

	if poems.is_empty():
		Logging.info('PoemConversionOperator._pick_random_poem: 无 Poem trait 可用')
		return null

	Logging.info('PoemConversionOperator._pick_random_poem: 共 %d 首 Poem，随机选取' % poems.size())
	return poems[randi() % poems.size()]


## ──────────────────────────────────────────────
## 显示辅助
## ──────────────────────────────────────────────

## size_key → 中文展示名
static func _size_key_to_display(key: String) -> String:
	match key:
		"xxs": return "极微"
		"xs":  return "微"
		"s":   return "小"
		"m":   return "中"
		"l":   return "大"
		"xl":  return "巨"
		"xxl": return "超巨"
		_:     return "?"


## resource_uuid → 中文展示名
func _resource_uuid_to_display(uuid: String) -> String:
	match uuid:
		"money":       return tr("CODE_POEM_CONVERSION_OPERATOR_MONEY_DISPLAY")
		"prestige":    return tr("CODE_POEM_CONVERSION_OPERATOR_PRESTIGE_DISPLAY")
		"progress":    return tr("CODE_POEM_CONVERSION_OPERATOR_PROGRESS_DISPLAY")
		"inspiration": return tr("CODE_POEM_CONVERSION_OPERATOR_INSPIRATION_DISPLAY")
		_:             return uuid


func describe_preview() -> String:
	var prop_display := _resource_uuid_to_display(resource_uuid)
	var text := tr("CODE_POEM_CONVERSION_OPERATOR_E4F2A1B5D8") % [prop_display]
	Logging.info('PoemConversionOperator.describe_preview: → "%s"' % text)
	return text
