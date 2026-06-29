class_name ImaginaryConcept extends GameEntity

# uuid: 抽象概念的三段式 key，如 "env:nature:autumn"
# name: 展示名，如 "秋意"
# description: 展示描述

signal level_changed(new_level: int)
signal tier_changed(new_tier: int)

@export var current_level := 0: # 0-2，由 ImaginaryComprehender 动态计算
	set(value):
		if current_level != value:
			current_level = value
			level_changed.emit(value)
@export var current_tier := 0: # 1-3 (Tier 1/2/3), 0 = 未坍缩/未分配
	set(value):
		if current_tier != value:
			current_tier = value
			tier_changed.emit(value)

@export var l3_threshold := 4 # 需要四个意象来达到 l3

const l2_threshold := 2

## 合并坍缩后保留的原始四段式 Tag 备份
@export var merged: Array = []
