extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TimeService.on_xun_tick.connect(_on_stat_changed)
	_on_stat_changed()

func _on_stat_changed() -> void:
	$MoneyItem.apply_prop_key("money")
	$HealthItem.apply_prop_key("health")
	$Fatigue.apply_prop_key('fatigue')
	$Burnout.apply_prop_key('burnout')
	$Drunk.apply_prop_key('drunk')
	$Sick.apply_prop_key('sick')
