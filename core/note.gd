class_name Note extends GameEntity

@export var requirement: BaseRequirements = BaseRequirements.new()
# name and description use parent
# name: the title of the note
# description: some part of a poem to demonstrate the situation
@export var description_explanation: String = "" # explain the poem in plain text

@export var note_narrative: String = "" # narrative,literary text as a after note to previous life
@export var note_explanation: String = "" # small grey text to explain the note using game mechanic
@export var triggered: bool = false # if triggered then can not be trigger again and should be demonstrated