extends Node
## GameSave — Autoload，持有 GameSaveData 的唯一实例
##
## 所有需要持久化的运行时状态均通过 GameSave.data 访问。
## 此 Node 本身不在场景树上做任何操作，仅作为 data 的容器。

const _GameSaveData = preload("res://core/model/game_save_data.gd")

## 运行时状态的唯一真源 (SSOT)
var data: GameSaveData

func _init() -> void:
	data = GameSaveData.new()

func _ready() -> void:
	Logging.info("GameSave: Autoload ready, data initialized")
