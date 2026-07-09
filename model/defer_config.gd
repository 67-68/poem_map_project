class_name DeferConfig extends Resource

## Named amounts key for defer duration (e.g. s_xun_cost=2, m_xun_cost=4, l_xun_cost=6)
## 解析 NamedDSLParser._load_named_amounts() 获取整数值。
@export var xun_defered: String = ''

## 🔗 资源消耗源：指向 Database.action_archetypes 中的 key。
## 每旬 tick 时，从对应 archetype 的 universal_result (pre-parsed operators) 中
## 提取 PropertyOperator 并执行（自动识别属性名和数值）。
## 示例："baiye" → archetype baiye.operators → prop_sub(money, -30) 等。
@export var used_resource_archetype: String = ''

## Named amounts key for AP/time cost per xun (e.g. s_ap_cost=1, m_ap_cost=2, l_ap_cost=3)
## 每旬 tick 时从 PlayerState._time 扣除。
@export var ap_cost: String = ''

## 🆕 资源不足中断时的兜底事件 UUID。
## 当 defer 期间某旬资源无法支付 used_resource 时，强制中断 defer，
## 如果此字段非空则通过 EventBus.push_event 推送此事件。
@export var failed_fallback: String = ''
