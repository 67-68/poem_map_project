class_name ManualBuffer extends RefCounted

var items: Array
var callback: Callable

func _init(callback_: Callable, items_: Array):
	callback = callback_
	items.append_array(items_)
	Logging.info("ManualBuffer._init: %d items added: %s" % [items_.size(), items_.map(func(i): return i.uuid if i.has_method("get") else "?" )])

func add_items(items_:Array):
	items.append_array(items_)
	Logging.info("ManualBuffer.add_items: added %d items" % items_.size())

func pop_item():
	Logging.info("ManualBuffer.pop_item: popping items[0]=%s, remaining=%d" % [items[0].uuid if items[0].has_method("get") else "?", items.size()-1])
	callback.call(items[0])
	items.pop_front()

## 根据具体 item 弹出，而非总是弹 items[0]
## 解决多个事件共享同一回调时弹出错误对象的问题
func pop_specific(item):
	var idx = items.find(item)
	if idx >= 0:
		Logging.info("ManualBuffer.pop_specific: popping item=%s at index=%d, remaining=%d" % [item.uuid if item.has_method("get") else "?", idx, items.size()-1])
		callback.call(item)
		items.remove_at(idx)
	else:
		Logging.err("ManualBuffer.pop_specific: item not found in buffer!")
