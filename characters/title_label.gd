@tool
extends Label

@export var debug := false:
	set(val):
		print("G_Pos: ", global_position, " | Vis_Tree: ", is_visible_in_tree(), " | Modulate: ", modulate, " | Scale: ", get_global_transform())
		TimeService.resume_world()
