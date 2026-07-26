@tool
class_name ConsumeOldestImaginaryOperator extends BaseOperator
## 消耗最旧的意象（created_at_day 最小）。
## 用于说书人等行动：将心中最旧的故事讲给人听，换取赏钱。
## 收益/惩罚由 archetype DSL 控制，此 operator 仅负责意象消耗。
## 若无任何意象，打 err 并静默返回。

## 🆕 静态可行性检查：当前是否有任何可用意象。
## 用于 sub-action picker 构建阶段决定隐藏/显示。
static func is_viable() -> bool:
	if Database.imaginaries_detail.is_empty():
		Logging.info("[ConsumeOldestImaginaryOperator] is_viable: 没有任何意象可用")
		return false
	Logging.info("[ConsumeOldestImaginaryOperator] is_viable: 有 %d 个意象可用" % Database.imaginaries_detail.size())
	return true


func operate():
	Logging.info("[ConsumeOldestImaginaryOperator] operate: 开始查找最旧意象")

	var imaginaries := Database.imaginaries_detail
	if imaginaries.is_empty():
		Logging.err("[ConsumeOldestImaginaryOperator] 没有任何意象可用，操作中止")
		return

	# 遍历找 created_at_day 最小的意象
	var oldest_uuid: String = ""
	var oldest_day: int = 0x7FFFFFFF  # INT32_MAX
	var oldest_type: String = ""
	var oldest_name: String = ""

	for uuid in imaginaries:
		var imag = imaginaries[uuid]
		if not imag is Imaginary:
			Logging.warn("[ConsumeOldestImaginaryOperator] 跳过非 Imaginary 条目: %s (type=%s)" % [uuid, typeof(imag)])
			continue
		var day: int = (imag as Imaginary).created_at_day
		Logging.info("[ConsumeOldestImaginaryOperator] 检查意象: uuid=%s name=%s type=%s created_at_day=%d" % [uuid, imag.name, imag.imaginary_type, day])
		if day < oldest_day:
			oldest_day = day
			oldest_uuid = uuid
			oldest_type = imag.imaginary_type
			oldest_name = imag.name

	if oldest_uuid.is_empty():
		Logging.err("[ConsumeOldestImaginaryOperator] 遍历后未找到任何有效 Imaginary，操作中止")
		return

	Logging.info("[ConsumeOldestImaginaryOperator] 最旧意象: uuid=%s name=%s type=%s created_at_day=%d" % [oldest_uuid, oldest_name, oldest_type, oldest_day])

	# 从 Database 中移除
	imaginaries.erase(oldest_uuid)
	Logging.info("[ConsumeOldestImaginaryOperator] 已消耗最旧意象: uuid=%s name=%s type=%s, 剩余 %d 个意象" % [oldest_uuid, oldest_name, oldest_type, imaginaries.size()])

	# 通知 UI 更新
	EventBus.imaginary_changed.emit()


func describe_preview() -> String:
	return tr("CODE_CONSUME_OLDEST_IMAGINARY_OPERATOR_7F3A2B1C")
