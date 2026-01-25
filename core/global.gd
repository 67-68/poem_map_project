extends Node

var year: float = 618.0
var mood: float = 0.5
var ratio_time: float = 0
signal poet_clicked(PoetData)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	ratio_time = remap(year,618,907,0,1)
	ratio_time = clampf(ratio_time, 0.0, 1.0)
	
