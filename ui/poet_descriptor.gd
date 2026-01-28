extends NinePatchRect

func on_user_clicked(data: PoetData):
	if not data == null:
		var profile_path: String = ("res://assets/profile/%s.png" % data.uuid)
		if not FileAccess.file_exists(profile_path):
			print('do not found file %s' % profile_path)
			return
		$DescriptorContainer/PoetProfile.texture = load(profile_path)
		$DescriptorContainer/PoetNameLabel.text = data.name
		$DescriptorContainer/PoetDescription.text = data.description
		position = get_global_mouse_position()
		show()
	else:
		hide()

func _ready() -> void:
	Global.user_clicked.connect(on_user_clicked)

func _process(delta: float) -> void:
	pass
