@tool
class_name AmbientAudioOperator extends BaseOperator

## 控制 constant_background_audio（环境背景音）
## action: "set_profile" → 激活指定 profile（会先 clear 旧的）
## action: "clear"       → 停止并清理所有 ambient 层

@export var action: String = ""       # "set_profile" / "clear"
@export var profile_key: String = ""  # 仅 set_profile 时使用


func operate() -> void:
	match action:
		"set_profile":
			if profile_key.is_empty():
				Logging.warn("AmbientAudioOperator: set_profile 缺少 profile_key")
				return
			AudioManager.set_ambient_profile(profile_key)
		"clear":
			AudioManager.clear_ambient_profile()
		_:
			if action.is_empty():
				Logging.warn("AmbientAudioOperator: action 为空，跳过")
			else:
				Logging.warn("AmbientAudioOperator: 未知 action [%s]" % action)
