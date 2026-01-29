class_name Util extends RefCounted
## 绝对稳健的属性排序函数
## [data] 原始数据库字典
## [prop_name] 排序依据的属性名 (int 或 float)
## [uuid_list] 需要排序的 UUID 列表
static func get_sorted_keys_by_num_property(data: Dictionary, prop_name: String, uuid_list: Array) -> Array:
	# 1. 防御性检查：如果是空数据，直接原样返回，别浪费电 🤓☝️
	if uuid_list.is_empty():
		return []
	
	# 2. 浅拷贝列表：
	# 我们只复制 UUID 列表本身，不触碰内部庞大的数据对象
	# 这样既保护了原始数据不被篡改，又省下了内存
	var sorted_list = uuid_list.duplicate()
	
	# 3. 稳健排序
	sorted_list.sort_custom(func(a_id, b_id):
		# 安全取值逻辑：如果 ID 不存在，或者属性不存在，退化为 0.0
		# 这保证了即便数据残缺，程序也不会像豆腐渣工程一样崩塌 🏗️
		var val_a = 0.0
		var val_b = 0.0
		
		if data.has(a_id):
			var obj = data[a_id]
			# 兼容数据是 Dictionary 或者 Resource 的情况
			val_a = obj.get(prop_name) if obj.has_method("get") else obj.get(prop_name)
		
		if data.has(b_id):
			var obj = data[b_id]
			val_b = obj.get(prop_name) if obj.has_method("get") else obj.get(prop_name)
			
		# 处理 null 情况：如果 get 出来是 null，转为 0.0
		if val_a == null: val_a = 0.0
		if val_b == null: val_b = 0.0
		
		return val_a < val_b
	)
	
	return sorted_list