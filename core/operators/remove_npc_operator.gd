@tool
class_name RemoveNpcOperator extends BaseOperator

## 要移除的 NPC uuid（如 "tut_taoist"）
@export var npc_uuid: String = ""

func operate() -> void:
	if npc_uuid.is_empty():
		Logging.err("RemoveNpcOperator.operate: npc_uuid 为空")
		return
	if not Database.npc_document.has(npc_uuid):
		Logging.warn("RemoveNpcOperator.operate: NPC '%s' 不存在于数据库，跳过" % npc_uuid)
		return
	Database.npc_document.erase(npc_uuid)
	Logging.info("RemoveNpcOperator.operate: NPC '%s' 已从 Database.npc_document 移除" % npc_uuid)
