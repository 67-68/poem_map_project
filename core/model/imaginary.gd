class_name ImaginaryTag extends GameEntity

# uuid: 一个标签的领域，类似social:wealth
# name: 展示
# description: 展示

@export var current_level := 0 # 0-2
@export var basic_imaginaries: Array[String] = [] # tag uuid
@export var l3_threshold := 4 # 需要四个意象来达到l3

const l2_threshold := 2
