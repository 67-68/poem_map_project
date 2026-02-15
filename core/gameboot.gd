extends Node
"""
总初始化
singleton第一项
为了管理sinleton的创建顺序而诞生
"""

func _ready():
	Global.init()
	# 删除了navigation service init, 因为需要懒加载，否则没有地图可用
	"不要在开场阶段调用它"
	Logging.done('gameboot')
