@tool
class_name ConsumeRandomPoemOperator extends BaseOperator
## 随机消耗一首已拥有的诗词（Poem trait）。
## 收益（势/望/钱财）由 archetype DSL 控制，此 operator 仅负责诗词消耗。
## 若无任何诗词，打 err 并静默返回。
##
## DSL 语法: consume_random_poem
##
## 参照: ConsumeRandomLeverageOperator / ConsumeOldestImaginaryOperator


## 静态可行性检查：当前是否有任何诗词。
static func is_viable() -> bool:
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if trait_ is Poem:
			Logging.info("[ConsumeRandomPoemOperator] is_viable: 发现诗词 '%s'" % trait_.name)
			return true
	Logging.info("[ConsumeRandomPoemOperator] is_viable: 没有诗词可用")
	return false


func operate():
	Logging.info("[ConsumeRandomPoemOperator] operate: 开始收集所有可用诗词")

	# 1. 收集所有 Poem trait
	var poems: Array[Poem] = []
	for t in PlayerState.get_traits():
		var trait_ = Database.get_trait(t)
		if trait_ is Poem:
			poems.append(trait_ as Poem)
			Logging.info("[ConsumeRandomPoemOperator] 发现诗词: uuid=%s name=%s" % [trait_.uuid, trait_.name])

	if poems.is_empty():
		Logging.err("[ConsumeRandomPoemOperator] 没有任何诗词可用，操作中止")
		return

	# 2. 随机选一首
	var chosen: Poem = poems[randi() % poems.size()]
	Logging.info("[ConsumeRandomPoemOperator] 随机选中诗词: uuid=%s name=%s (共 %d 首)" % [chosen.uuid, chosen.name, poems.size()])

	# 3. 从 PlayerState 移除
	var removed: bool = PlayerState.remove_trait(chosen.uuid)
	if not removed:
		Logging.err("[ConsumeRandomPoemOperator] PlayerState.remove_trait('%s') 失败" % chosen.uuid)
		return

	Logging.info("[ConsumeRandomPoemOperator] 已消耗诗词: uuid=%s name=%s, 剩余估计 %d 首" % [chosen.uuid, chosen.name, poems.size() - 1])

	# 4. 通知 UI（诗词数变化）
	EventBus.on_trait_change.emit()


func describe_preview() -> String:
	return tr("CODE_CONSUME_RANDOM_POEM_OPERATOR_PREVIEW")
