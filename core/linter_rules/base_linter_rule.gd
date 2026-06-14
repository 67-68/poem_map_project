class_name BaseLinterRule extends RefCounted
## Linter检查规则的基类
## 所有具体的Rule都应该继承此类并实现execute方法

var rule_name: String = "BaseRule"
var errors: Array[String] = []
var warnings: Array[String] = []

## 执行检查规则
## 子类必须重写此方法
func execute(event_data: Node) -> void:
	Logging.err("%s: execute() method not implemented" % rule_name)

## 添加错误信息
func add_error(message: String) -> void:
	errors.append(message)

## 添加警告信息
func add_warning(message: String) -> void:
	warnings.append(message)

## 获取检查结果
func get_result() -> Dictionary:
	return {
		"rule_name": rule_name,
		"errors": errors,
		"warnings": warnings,
		"has_errors": not errors.is_empty(),
		"has_warnings": not warnings.is_empty()
	}

## 打印检查结果
func print_result() -> void:
	Logging.info("\n--- %s 检查结果 ---" % rule_name)
	if errors.is_empty() and warnings.is_empty():
		Logging.info("✓ 检查通过，无问题")
	else:
		if not errors.is_empty():
			Logging.info("❌ 发现 %d 个错误：" % errors.size())
			for error in errors:
				Logging.info("  - %s" % error)
		if not warnings.is_empty():
			Logging.info("⚠️  发现 %d 个警告：" % warnings.size())
			for warning in warnings:
				Logging.info("  - %s" % warning)
	Logging.info("--- 检查完成 ---\n")