class_name SceneAction extends Action

@export var _main_tag: ENUMS.ACTION_TAGS = -1
var main_tag: String: 
    get: return ENUMS.to_action_str(_main_tag)