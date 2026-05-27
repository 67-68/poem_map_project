extends Node

func get_available_scene_actions() -> Dictionary:
    #breakpoint
    print("[ActionManager] 开始获取可用场景动作")
    var actions := {}
    
    # 统一去 base_prov 里拿位置数据
    var loc = Database.base_province.get(PlayerState.current_location)
    if not loc:
        Logging.err("当前位置幽灵化: %s" % PlayerState.current_location)
        return actions

    for a_id in Database.actions:
        var a = Database.actions[a_id]
        var is_valid = true # 🤓☝️ 设立拦截签证！
        
        # 1. 检查硬性需求 (Requirements)
        if a.aciton_requirements:
            for req in a.aciton_requirements:
                if not req.compare(PlayerState):
                    is_valid = false # 签证拒签！
                    break # 💀 打断内层循环，直接判死刑
                    
        if not is_valid:
            print("[ActionManager] 动作 %s 不满足需求条件，被拦截" % a_id)
            continue # 这个 continue 才会跳过外层的 a_id！
            
        # 2. 检查标签匹配 (Tags)
        if a.area_tags and not a.area_tags.is_empty():
            var tag_matched = false
            if loc.area_tags:
                for tag in loc.area_tags:
                    if tag in a.area_tags:
                        tag_matched = true
                        break
                        
            if not tag_matched:
                print("[ActionManager] 动作 %s 标签不匹配当前位置" % a_id)
                continue # 没有交集，直接滚蛋
                
        # 3. 活到最后的才是合法动作
        print("[ActionManager] 动作 %s 完全合法，允许装载" % a_id)
        append_counter(actions, a_id, a)
        
    return actions

func append_counter(counter: Dictionary, item_name: String, _item) -> Dictionary:
    if counter.has(item_name):
        counter[item_name] += 1
    else:
        counter[item_name] = 1
    return counter

func get_total_weight_power2(actions: Dictionary) -> float:
    var total_weight = 0.0
    for action_id in actions:
        total_weight += pow(actions[action_id], 2)
    return total_weight

# 伪代码演示，这就是你要的终极算法
func pick_top_actions(action_pool: Dictionary, pick_count: int = 6) -> Array[SceneAction]:
    var selected_actions: Array[SceneAction] = []
    var available_pool = action_pool.duplicate() # 复制一份，避免污染原池
    
    while selected_actions.size() < pick_count and available_pool.size() > 0:
        var total_weight = get_total_weight_power2(available_pool)
        
        # 2. 转动命运的轮盘
        var roll = randf_range(0.0, total_weight)
        var cursor = 0.0
        
        # 3. 寻找中奖者
        for action_id in available_pool:
            cursor += pow(available_pool[action_id], 2)
            if roll <= cursor:
                selected_actions.append(Database.actions[action_id] as SceneAction)
                available_pool.erase(action_id) # 拿走，不放回！
                break # 必须 break，进入下一轮抽取
                
    return selected_actions
