@tool
class_name AmbientAudioOperator extends BaseOperator

## 控制环境背景音（Ambient / AmbientMusic）
## action:
##   "set_profile"       → 激活 ambient profile（先 clear 旧的，同时清除 AmbientMusic）
##   "set_music_profile" → 激活 ambient music profile（先 clear 旧的，同时清除 Ambient）
##   "clear"             → 停止并清理 ambient 层
##   "clear_music"       → 停止并清理 ambient music

@export var action: String = ""       # "set_profile" / "set_music_profile" / "clear" / "clear_music"
@export var profile_key: String = ""  # 仅 set_profile / set_music_profile 时使用


func operate() -> void:
	match action:
		"set_profile":
			if profile_key.is_empty():
				Logging.warn("AmbientAudioOperator: set_profile 缺少 profile_key")
				return
			AudioManager.set_ambient_profile(profile_key)
		"set_music_profile":
			if profile_key.is_empty():
				Logging.warn("AmbientAudioOperator: set_music_profile 缺少 profile_key")
				return
			AudioManager.set_ambient_music_profile(profile_key)
		"clear":
			AudioManager.clear_ambient_profile()
		"clear_music":
			AudioManager.clear_ambient_music_profile()
		_:
			if action.is_empty():
				Logging.warn("AmbientAudioOperator: action 为空，跳过")
			else:
				Logging.warn("AmbientAudioOperator: 未知 action [%s]" % action)
