@tool
class_name BaseEvent extends GameEntity
@export var options: Array[BaseOption] = [EventOption.new(),EventOption.new()]
@export var example: String
@export var audio: AudioStream = null
@export var epitaph_text: String = ''
@export var emotion_configs: Array[EmotionConfigs] = []