class_name BaseEvent extends GameEntity
@export var options: Array[BaseOption] = [EventOption.new(),EventOption.new()]
@export var example: String
@export var requirement: BaseRequirements
@export var audio: AudioStream = null
@export var epitaph_text: String = ''