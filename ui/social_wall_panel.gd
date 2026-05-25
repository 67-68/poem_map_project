extends PanelContainer

@export var current_status: Dictionary = {}
@export var current_bamboo_slips: Dictionary = {}

func on_trait_chnage():
	var traits = PlayerState.get_traits()
	for t in traits:
		var traits_inst = Database.traits.get(t) as Trait
		if not traits_inst:
			Logging.err('[social wall panel] can not find this trait')
			continue
		if traits_inst.topic == "RELATION":
			var relation = traits_inst.relate_to
			if not relation in current_status:
				current_status[relation] = traits_inst.specific_topic
				var bamboo_slip = preload("res://ui/bamboo_slip.tscn")
				current_bamboo_slips[relation] = bamboo_slip
				$VBoxContainer/ScrollContainer/MarginContainer/HFlowContainer.add_child(bamboo_slip)
				bamboo_slip.apply_relation(relation)
			else:
				if current_status[relation] != traits_inst.specific_topic:
					var bamboo_slip = current_bamboo_slips[relation]
					bamboo_slip.apply_state(traits_inst.specific_topic)

func _ready():
	EventBus.on_trait_change.connect(on_trait_chnage)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		visible = not visible