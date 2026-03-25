extends VBoxContainer


@export var decision: Decision

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func inititalization(decision_: Decision):
	decision = decision_
	$ActionPanel/V/TitleLabel.text = decision_.name
	$ActionPanel/V/DescriptionLabel.text = decision_.description
	


func _on_button_pressed() -> void:
	for r in decision.action_results:
		r.operate()
	decision.disabled = true
