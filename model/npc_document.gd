class_name NPCDocument extends Resource
@export var taste_id: String # poem-taste的urn id
@export var name: String
@export var uuid: String # loc_name_key

## NPC 属性字典，key=属性名（如 "TALENT"、"HEALTH"），value=属性值
## 供 NpcBatchCheckOperator 进行批量检定时使用
##
## 示例：
##   prop = {
##     "TALENT": 80,
##     "HEALTH": 50,
##     "DRUNK": 30
##   }
@export var prop: Dictionary = {}