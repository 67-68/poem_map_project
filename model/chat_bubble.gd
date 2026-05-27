class_name ChatBubble extends MapMarker

var attached_node: Node2D

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))
	attached_node = data.get('attached_node',props.get("attached_node"))