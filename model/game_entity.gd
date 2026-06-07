@tool
# @deprecated 与 core/game_entity.gd 的 class_name GameEntity 冲突。
# core/game_entity.gd 的版本包含 owner_uuids/tags 字段，
# 被 base_repository.gd / poem_repository.gd 使用，因此保留 core 版。
# 此文件保留但禁用 class_name，Godot 会使用 core/game_entity.gd。
#extends Resource

@export var uuid: String
@export var name: String
@export var description: String
@export var icon: Texture2D

# 默认参数 = {} 防止无参实例化时崩溃
func _init(data: Dictionary = {}):
    if data.is_empty(): return

    # 1. 预处理：统一获取内层属性字典
    # 兼容 JSON 里有时候写 'property' 有时候写 'properties' 的混乱情况
    var props = data.get("properties", data.get("property", {}))
    
    # 2. 解析 UUID (优先看外层，没有再看内层)
    uuid = data.get('id',data.get("uuid", props.get("uuid", "")))
    
    # 3. 解析名字 (支持 name 或 title)
    name = data.get("name", data.get("title", props.get("title", "")))
    
    # 4. 解析描述 (支持 description 或 text)
    description = data.get("description", data.get("text", props.get("text", "")))

    # 6. 加载图标 (TextureResLoader 最好是静态工具类)
    var icon_path = data.get('icon',props.get(icon))
    icon = TextureResLoader.get_icon(icon_path,uuid,name)
