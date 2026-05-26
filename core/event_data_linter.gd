extends Node

# 事件数据Linter (重构版)
# 使用Rule流水线架构，拒绝反射，建立契约 🤓☝️
# 
# 重构核心：
# 1. 斩断反射，建立契约 - 所有Operator和Requirement通过契约方法声明依赖
# 2. Linter流水线化 - 分层检查官架构，职责单一，易于扩展
# 3. 抹平异构数据 - DataHelper提供统一事件迭代器，隐藏具体实现

## Linter Rule流水线
var linter_rules: Array[BaseLinterRule] = []

## 执行Linter检查
## 使用Rule流水线架构，每个Rule负责特定的检查领域
func execute_linter() -> void:
	print("===== 开始执行事件数据Linter (重构版) =====")
	
	# 🚨 调用DataHelper加载所有事件数据
	var event_data = DataHelper.load_event_data()
	
	if not event_data:
		push_error("事件数据加载失败！Linter终止 💀")
		return
	
	# 初始化Rule流水线
	_initialize_rule_pipeline()
	
	# 执行所有Rule检查
	var total_errors = 0
	var total_warnings = 0
	
	for rule in linter_rules:
		print("\n===== 执行 %s =====" % rule.rule_name)
		rule.execute(event_data)
		rule.print_result()
		
		var result = rule.get_result()
		total_errors += result.errors.size()
		total_warnings += result.warnings.size()
	
	# 汇总结果
	print("\n===== Linter执行汇总 🤓☝️ =====")
	print("总错误数: %d" % total_errors)
	print("总警告数: %d" % total_warnings)
	
	if total_errors == 0 and total_warnings == 0:
		print("✓ 所有检查通过，数据质量优秀！")
	elif total_errors == 0:
		print("⚠️  有一些警告，但无致命错误")
	else:
		print("❌ 发现错误，需要修复数据问题 💀")
	
	print("===== Linter执行完成 =====")

## 初始化Rule流水线
## 这里按顺序添加检查官，建立清晰的检查层次
func _initialize_rule_pipeline() -> void:
	linter_rules.clear()
	
	# Level 1: Schema检查官 - 数据结构验证
	linter_rules.append(SchemaLinterRule.new())
	
	# Level 2: 链接检查官 - Trait/Flag供需验证
	linter_rules.append(LinkerLinterRule.new())
	
	# Level 3: 业务规则检查官 - 策划业务逻辑验证
	linter_rules.append(BusinessLinterRule.new())
	
	print("✓ Rule流水线初始化完成，共 %d 个检查官" % linter_rules.size())