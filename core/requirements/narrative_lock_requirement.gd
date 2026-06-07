@tool
class_name NarrativeLockRequirement extends BaseRequirements
# 叙事锁 Requirement — 替代 ComplexEventOption.is_disabled 硬编码
#
# 用法：在 EventOption.requirements 数组中添加此 Requirement，
#       设置 failed_hint 为禁用原因（对应原来的 disabled_reason）。
#       compare() 永远返回 false（无条件锁定），
#       调用方（EventBtn）读取 failed_hint 展示给玩家。
#
# 未来扩展：可添加 lock_flag_id / lock_flag_value 实现动态条件锁，
#           只在特定叙事条件下才锁定选项。

func compare(_data) -> bool:
	# 叙事锁：只要存在就代表被锁定
	# （可未来扩展为检查特定 flag 的条件锁）
	return false
