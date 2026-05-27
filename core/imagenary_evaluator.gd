class_name ImagenaryEvaluator
static func _get_discounted_threshold(base_threshold, talent_val):
    if talent_val > 50: return 0.5 * base_threshold
    if talent_val > 30: return 0.75 * base_threshold

static func evaluate_single_config(local_config: EmotionConfigs, player_state: PlayerState) -> Dictionary: # 返回结构化数据
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
                    return {}
            else:
                if not req.compare(player_state):
                    return {}
        else:
            if not req.compare(player_state):
                return {}
    # 校验通过，返回结构化数据
    return {
        "blueprint": local_config.target_imagenary_blueprint,
        "context_tags": local_config.context_tags
    }

static func evaluate_local_configs(local_configs: Array[EmotionConfigs], player_state: PlayerState) -> Array[Dictionary]:
    var result: Array[Dictionary]  = []
    for conf in local_configs:
        var res = evaluate_single_config(conf, player_state)
        if res.is_empty(): continue
        else: result.append(res)
    return result
