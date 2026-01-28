class_name Util extends RefCounted

static func get_sorted_keys_by_num_property(data: Dictionary,prop_name: String, uuid_list: Array[String]) -> Array[String]:
    """
    data: dict, 这两个uuid本来的数据库
    prop_name: 需要排序的属性，比如year
    uuid_list: uuid to sort
    """
    var keys = uuid_list
    keys.sort_custom(
        func(a_uuid, b_uuid):
        var poet_a = data[a_uuid]
        var poet_b = data[b_uuid]
        return poet_a.get(prop_name) > poet_b.get(prop_name)
    )
    return keys