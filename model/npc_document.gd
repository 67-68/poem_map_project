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

## NPC 偏好出现的地点列表，值为 CHANGAN_PLACES 的 str key。
## 可选值： "xishi" / "pingkangfang" / "huangcheng"
## 空数组 = 不匹配任何地点（不会被 PickNpcByPlaceOperator 选中）。
## 示例： ["pingkangfang", "huangcheng"]
@export var preferred_places: Array[String] = []

## NPC 在一旬中出现的天数（0~9，对应 TimeService.current_day）。
## 空数组 = 始终可用（向后兼容）。
## 示例： [1, 4, 7] = 每旬第 2、5、8 天出现。
@export var appear_days: Array[int] = []

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

## 人物相识状态 — 五态状态机：uncharted → not_meet → know_about → inner_circle → blood_oath
## 原 flag: flag_gen_person_state_{TARGET_TAG}
## uncharted: 玩家不知道此人存在（默认态）
@export var person_state: String = "uncharted"

## 引荐信列表 — 玩家持有的该目标的引荐信 key
## 原 flag: flag_gen_intro_{TARGET_TAG}
@export var intro_keys: Array[String] = []

## NPC 的人脉关系列表 — 存储其他 NPC 的 target_tag。
## 用于宴席推荐信等场景：从主办者的 relate_to 中随机选一个 not_meet 的人。
## 示例：["gaoshi", "zhengqian", "wangwei"]
@export var relate_to: Array[String] = []

@export var normal_actions: Array[String] = [] # 普通等级的action, know_about 解锁

# effect per xun
@export var shi_upper_limit: String = ""
@export var shi_addition: String = ""

@export var xing_upper_limit: String = ""
@export var xing_addition: String = ""

@export var wang_upper_limit: String = ""
@export var wang_addition: String = ""

@export var overdraft_amount: int = 50 # 可以透支多少资源
@export var overdraft_cooldown_xun: int = 0