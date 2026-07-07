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

# ═══════════════════════════════════════════════════════════
# 关系数据 — 原 RelationFlagManager 虚拟 flag 迁移
# 这些属性替代了 flag_gen_{category}_{TARGET_TAG} 的 flag 机制。
# 运行时由 RelationFlagManager 读写，GameSaveData 负责持久化。
# ═══════════════════════════════════════════════════════════

## 把柄列表 — 玩家掌握的该目标的把柄 key（JSON 数组编码的语义列表）
## 原 flag: flag_gen_leverage_{TARGET_TAG}
@export var leverage_keys: Array[String] = []

## 帮助次数 — 玩家帮助该目标的累计次数
## 原 flag: flag_gen_help_{TARGET_TAG}
@export var help_count: int = 0

## 好感度 — 玩家对该目标的好感度数值，默认 30（中性起点）
## 原 flag: flag_gen_favor_{TARGET_TAG}
@export var favor: int = 30

## 人物相识状态 — 两态状态机：not_meet → know_about
## 原 flag: flag_gen_person_state_{TARGET_TAG}
@export var person_state: String = "not_meet"

## 引荐信列表 — 玩家持有的该目标的引荐信 key
## 原 flag: flag_gen_intro_{TARGET_TAG}
@export var intro_keys: Array[String] = []