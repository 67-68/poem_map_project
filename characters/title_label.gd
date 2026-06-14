@tool
extends Label

@export var debug := false:
	set(val):
		Logging.info("G_Pos:  %s | Vis_Tree:  %s | Modulate:  %s | Scale:  %s" % [global_position, is_visible_in_tree(), modulate, get_global_transform()])
		TimeService.resume_world()
