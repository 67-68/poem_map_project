extends Label

var base_text = "flags: \n"

func _ready() -> void:
	EventBus.on_flag_change.connect(refresh_flags)
	refresh_flags()

func refresh_flags() -> void:
	text = base_text
	for flag_id in PlayerState.flags:
		var flag_val = PlayerState.flags[flag_id]
		var flag_def = Database.flags.get(flag_id)
		var flag_type = flag_def.type if flag_def else "?"
		text += "%s (%s): %s\n" % [flag_id, flag_type, str(flag_val)]
