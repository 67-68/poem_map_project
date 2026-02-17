class_name PropParser extends RefCounted
"""
用来解析属性
"""

static func parse_any(data, get_properties = true, ...target_names):
	"""
	也可以用来parse str
	"""
	var sources = [data]

	if get_properties:
		var props = data.get("properties", data.get("property", {}))
		if props: sources.append(props)
	
	for name in target_names:
		for source in sources:
			if source.get(name):
				return source[name]

static func parse_and_create_cls(cls, data, get_properties = true, ...target_names):
	var result = parse_any(data,get_properties,target_names)
	return cls.new(result)
