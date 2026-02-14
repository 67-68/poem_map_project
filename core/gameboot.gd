extends Node
"""
总初始化
singleton第一项
为了管理sinleton的创建顺序而诞生
"""

func _ready():
	Global.init()
	NavigationService.init()
