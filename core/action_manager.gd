extends Node

func get_available_scene_actions() -> Dictionary:
    """
    返回一个名称: 权重的字典
    如果需要额外计算叠加权重，自己根据出现了多少次算！可以整一个x^3的
    如果权重 = -1: 一般意味着必然出现
    """
    var actions := {}
    for a_id in Global.actions:
        var a = Global.actions[a_id]

        if a.aciton_requirements:
            for req in a.aciton_requirements:
                if not req.compare():
                    continue

        if a.action_tags:
            var loc = Global.provinces.get(PlayerState.current_location)
            if loc.area_tags:
                for tag in loc.area_tags:
                    if tag in a.action_tags:
                        append_counter(actions, a_id, a)
        else: append_counter(actions, a_id, a)
    return actions

func append_counter(counter: Dictionary, item_name: String, _item) -> Dictionary:
    if counter.has(item_name):
        counter[item_name] += 1
    else:
        counter[item_name] = 1
    return counter

func get_total_weight_power2(actions: Array) -> float:
    var total_weight = 0.0
    for action in actions:
        total_weight += pow(action.match_count, 2)
    return total_weight

# 伪代码演示，这就是你要的终极算法
func pick_top_actions(action_pool: Array, pick_count: int = 6) -> Array:
    var selected_actions = []
    var available_pool = action_pool.duplicate() # 复制一份，避免污染原池
    
    while selected_actions.size() < pick_count and available_pool.size() > 0:
        var total_weight = get_total_weight_power2(action_pool)
        
        # 2. 转动命运的轮盘
        var roll = randf_range(0.0, total_weight)
        var cursor = 0.0
        
        # 3. 寻找中奖者
        for i in range(available_pool.size()):
            cursor += pow(available_pool[i].match_count, 2)
            if roll <= cursor:
                selected_actions.append(available_pool[i])
                available_pool.remove_at(i) # 拿走，不放回！
                break # 必须 break，进入下一轮抽取
                
    return selected_actions