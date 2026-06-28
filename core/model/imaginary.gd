class_name ImaginaryTag extends GameEntity

# uuid: 一个标签的领域，类似social:wealth
# name: 展示
# description: 展示

signal level_changed(new_level: int)
signal tier_changed(new_tier: int)

@export var current_level := 0: # 0-2
	set(value):
		if current_level != value:
			current_level = value
			level_changed.emit(value)
@export var current_tier := 0: # 1-3 (Tier 1/2/3), 0 = 未坍缩/未分配
	set(value):
		if current_tier != value:
			current_tier = value
			tier_changed.emit(value)
@export var basic_imaginaries: Array[Dictionary] = [] # 存储结构化数据: [{ "blueprint_id": String, "contexts": Array[String] }]
@export var l3_threshold := 4 # 需要四个意象来达到l3

const l2_threshold := 2

@export var merged: Array = []