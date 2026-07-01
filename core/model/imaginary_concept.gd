class_name ImaginaryConcept extends GameEntity

# uuid: 抽象概念的 key，如 "environment:snow"
# name: 展示名，如 "雪意"
# description: 展示描述

signal tier_changed(new_tier: int)

## 坍缩层级 (Tier 1-2)，默认 1 (V6: level 已删除，tier 仅 1/2 无 0)
@export var current_tier := 1:
	set(value):
		var clamped = clampi(value, 1, 2)
		if current_tier != clamped:
			current_tier = clamped
			tier_changed.emit(clamped)

## 合并坍缩所需的最小 Imaginary 碎片数（1 个即可 merge）
const l2_threshold := 1

## 合并坍缩后保留的概念标签备份
@export var merged: Array = []
