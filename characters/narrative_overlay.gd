class_name NarrativeOverlay extends Control


var current_event_data: HistoryEventData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_galgame_event.connect(apply_narrative)
	hide()

func apply_narrative(data: HistoryEventData):
	TimeService.pause_world()
	current_event_data = data
	for option in data.options:
		var btn = EventBtn.new(option)
		$BtnContainer.add_child(btn)
		btn.option_made.connect(end_narrative)
	$Background.texture = data.icon

	$TitleLabel.text = data.name
	$ContentLabel.text = data.description
	$ExampleLabel.text = data.example

	show()
	

func end_narrative():
	hide()
	TimeService.resume_world()
	Global.faction_renderer.special_state.merge(current_event_data.provs_state_after,true)
	Global.faction_renderer.refresh_lut_image(Global.map.prov_2_fac)
	Logging.done('narrative')

		

	
