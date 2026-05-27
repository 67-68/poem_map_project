class_name ManualBuffer extends RefCounted

var items: Array
var callback: Callable

func _init(callback_: Callable, items_: Array):
	callback = callback_
	items.append_array(items_)

func add_items(items_:Array):
	items.append_array(items_)

func pop_item():
	callback.call(items[0])
	items.pop_front()
