class_name PoemProcessResult extends RefCounted

var poems_to_emit: Array[String] = []
var new_target_year: int = -1 # -1 代表没有更新
var found_poems: bool = false