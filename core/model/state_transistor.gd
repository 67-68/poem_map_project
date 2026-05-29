class_name StateTransistor extends Resource

@export var uuid: String
@export var target_resource_urn: String
@export var current_resource_urn: String
@export var triggered_event_key: String
@export var requirements: BaseRequirements
@export var operators: Array[BaseOperator]

func transition():
	if requirements.compare(PlayerState):
		var target_resource_key = URN.parse_urn(target_resource_urn).get('resouce_id')
		var current_resource_key = URN.parse_urn(current_resource_urn).get("resouce_id")
		if not target_resource_key:
			Logging.err('state transistor: can not find next resource: %s' % target_resource_urn)
			return
		修改flag