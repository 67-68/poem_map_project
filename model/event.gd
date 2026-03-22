class_name BaseEvent extends GameEntity
@export var options: Array[EventOption] = []
@export var example: String
@export var requirement: BaseRequirements
@export var audio: AudioStream = null
# 会被使用time operator中的source tag匹配
@export var target_tags: Array[String] = []