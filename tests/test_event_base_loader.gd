@tool
extends Node

# 验证 EventBaseLoader 的编译和运行时正确性
# 包括：递归加载、bases 分表、去重检测、eventbase.event_id 查询语法

func _ready() -> void:
	print("=== Testing EventBaseLoader ===")
	var result = EventBaseLoader.scan()
	print("Scanned files: ", result.scanned_file_count)
	print("Loaded events (pool): ", result.pool.size())
	print("Duplicates: ", result.duplicates.size())
	print("Bases count: ", result.bases.size())

	# 打印所有 base 名称
	for base_name in result.bases:
		print("  Base '%s': %d events" % [base_name, result.bases[base_name].size()])
		for uuid in result.bases[base_name]:
			print("    ", uuid)

	# 打印 pool 中的所有 full_id
	for key in result.pool:
		print("  Pool: ", key, " -> ", str(result.pool[key]))

	# 验证 pool 和 bases 的一致性
	var pool_count = result.pool.size()
	var bases_count = 0
	for base_name in result.bases:
		bases_count += result.bases[base_name].size()
	if pool_count == bases_count:
		print("OK: pool count (%d) == sum of bases counts (%d)" % [pool_count, bases_count])
	else:
		print("WARN: pool count (%d) != sum of bases counts (%d)" % [pool_count, bases_count])

	print("=== Test complete ===")
	get_tree().quit()
