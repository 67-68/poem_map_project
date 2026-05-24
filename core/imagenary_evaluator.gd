class_name ImagenaryEvaluator
static func _get_discounted_threshold(base_threshold, talent_val):
    if talent_val > 50: return 0.5 * base_threshold
    if talent_val > 30: return 0.75 * base_threshold

static func evaluate_single_config(local_config: EmotionConfigs, player_state: PlayerState) -> String: # 使用property requirement
    for req in local_config.requirements:
        # 检查是否为 talent 属性的 PropertyRequirement
        if req is PropertyRequirement and req.property == 'talent':
            var talent_val = player_state.get_stat_val('talent')
            if talent_val:
                var original_value = req.value
                # 使用打折后的阈值
                req.value = _get_discounted_threshold(original_value, talent_val)
                var result = req.compare(player_state)
                # 恢复原始值，不修改原本的数据
                req.value = original_value
                if not result:
                    return ''
            else:
                if not req.compare(player_state):
                    return ''
        else:
            if not req.compare(player_state):
                return ''
    return local_config.imagenary_uid

static func evaluate_local_configs(local_configs: Array[EmotionConfigs], player_state: PlayerState) -> Array[String]:
    var result: Array[String]  = []
    for conf in local_configs:
        var res = evaluate_single_config(conf, player_state)
        if not res: continue
        else: result.append(res)
    return result