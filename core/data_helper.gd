@tool
class_name DataHelper extends RefCounted

## 查找所有匹配条件的项，并返回指定属性的列表
## 对应 Python 的 list(generator)
static func find_all_values_by_filter(
	data: Dictionary,
    match_key: String, 
	match_value: Variant, 
	result_key: String
) -> Array:
	# 在 Godot 4 里，我们可以用函数式写法，虽然它不是惰性的，但很整洁
	# 注意：data.values() 会创建一个数组拷贝，如果数据量极大，建议用下面的手动循环
	return data.values().filter(
		func(p): return p.get(match_key) == match_value
	).map(
		func(p): return p.get(result_key)
	)


## 查找第一个匹配条件的项，找到即停止（这才是真正的高效）
## 对应 Python 的 next(generator, default)
static func find_value_by_filter(
    data: Dictionary,
	match_key: String, 
	match_value: Variant, 
	result_key: String, 
	default: Variant = null
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data.values():
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p.get(result_key)
			
	return default

static func find_item_by_filter(
    data: Dictionary,
	match_key: String, 
	match_value: Variant, 
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data.values():
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p
	return

static func find_item_by_filter_list(
    data: Array,
	match_key: String, 
	match_value: Variant, 
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data:
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p
	return

## 查找所有项，判断 match_value 是否在对象的 match_key 数组中
static func find_all_values_by_membership(
	data,
	match_key: String, 
	match_value: Variant, 
	result_key: String
) -> Array:
	# 使用函数式写法。注意：p.get(match_key) 拿出来必须是个 Array 或 Dictionary
	return data.values().filter(
		func(p): 
			var list = p.get(match_key)
			# 这里的 in 相当于 Python 的 in，支持 Array, Dict, String
			return list != null and match_value in list
	).map(
		func(p): return p.get(result_key)
	)


## 查找第一个匹配项，一旦发现 match_value 在 list 中就立即返回
static func find_value_by_membership(
	data,
	match_key: String, 
	match_value: Variant, 
	result_key: String, 
	default: Variant = null
) -> Variant:
	# 还是那句话，找第一个请务必使用手动循环，拒绝性能浪费 😡
	for p in data.values():
		var list = p.get(match_key)
		
		# 防御性编程：确保 list 存在且确实包含目标
		if list != null and match_value in list:
			return p.get(result_key)
			
	return default
