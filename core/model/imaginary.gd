class_name ImaginaryTag extends GameEntity

# uuid: 一个标签的领域，类似social:wealth
# name: 展示
# description: 展示

signal level_changed(new_level: int)

@export var current_level := 0: # 0-2
	set(value):
		if current_level != value:
			current_level = value
			level_changed.emit(value)
@export var basic_imaginaries: Array[String] = [] # tag uuid
@export var l3_threshold := 4 # 需要四个意象来达到l3

const l2_threshold := 2
