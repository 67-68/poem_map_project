extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TimeService.on_xun_tick.connect(_on_stat_changed)


func _on_stat_changed() -> void:
	$MoneyItem.apply_prop_key("money")
	$EmotionItem.apply_prop_key("emotion")
	$HealthItem.apply_prop_key("health")
	if PlayerState.ambition:
		$UnderscoredItem.apply_prop_key(PlayerState.ambition.underscored_prop[0])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
