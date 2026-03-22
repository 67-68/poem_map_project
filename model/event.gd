class_name HistoryEventData extends WorldEvent
@export var options: Array[EventOption] = []
# target prov-uuid: parent - location_uuid
@export var provs_state_after: Array[ProvStateOwnerData]
# audio 也用父类的
# 需要texture; 使用父类的icon
@export var example: String
@export var weight: float
@export var requirement: ComplexRequirements