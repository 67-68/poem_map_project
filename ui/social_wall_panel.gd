extends PanelContainer

@export var current_status: Dictionary = {}
@export var current_bamboo_slips: Dictionary = {}

func on_trait_chnage():
	Logging.info('[social wall panel] on_trait_change called')
	var traits = PlayerState.get_traits()
	Logging.info('[social wall panel] got traits count: %s' % traits.size())
	for t in traits:
		var traits_inst = Database.traits.get(t) as Trait
		if not traits_inst:
			Logging.err('[social wall panel] can not find this trait: %s' % t)
			continue
		if traits_inst.topic == "RELATION":
			Logging.info('[social wall panel] found RELATION trait: %s' % t)
			var relation = traits_inst.relate_to
			Logging.info('[social wall panel] relation: %s, specific_topic: %s' % [relation, traits_inst.specific_topic])
			if not relation in current_status:
				Logging.info('[social wall panel] adding new relation to social wall: %s' % relation)
				current_status[relation] = traits_inst.specific_topic
				var bamboo_slip = preload("res://ui/bamboo_slip.tscn").instantiate()
				current_bamboo_slips[relation] = bamboo_slip
				$VBoxContainer/ScrollContainer/MarginContainer/HFlowContainer.add_child(bamboo_slip)
				bamboo_slip.apply_relation(relation)
				bamboo_slip.apply_state(traits_inst.specific_topic)
			else:
				Logging.info('[social wall panel] relation exists in current_status: %s' % relation)
				if current_status[relation] != traits_inst.specific_topic:
					Logging.info('[social wall panel] updating relation state: %s from %s to %s' % [relation, current_status[relation], traits_inst.specific_topic])
					var bamboo_slip = current_bamboo_slips[relation]
					bamboo_slip.apply_state(traits_inst.specific_topic)
				else:
					Logging.info('[social wall panel] relation state unchanged: %s' % relation)

func _ready():
	Logging.info('[social wall panel] _ready called')
	EventBus.on_trait_change.connect(on_trait_chnage)
	on_trait_chnage()
	Logging.info('[social wall panel] connected to EventBus.on_trait_change')

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		Logging.info('[social wall panel] toggling visibility, current: %s' % visible)
		visible = not visible
