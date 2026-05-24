class_name ImagenaryEvaluator
func _get_discounted_threshold(base_threshold, talent_val):
    if talent_val > 50: return 0.5 * base_threshold
    if talent_val > 30: return 0.75 * base_threshold

func evaluate_single_config(local_config: EmotionRequirements) -> String: # 使用property requirement
    for req in local_config.requirements:
        if not req.compare():
            return ''
    return local_config.imagenary_uid

func evaluate_local_configs(local_configs: Array[EmotionRequirements]) -> Array[String]:
    var result: Array[String]  = []
    for conf in local_configs:
        var res = evaluate_single_config(conf)
        if not res: continue
        else: result.append(res)
    return result