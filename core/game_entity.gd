class_name GameEntity extends Resource

@export var uuid: String
@export var name: String
@export var description: String
@export var icon: Texture2D
@export var owner_uuids: Array = [] # 默认值很重要
@export var tags: Array = []

# 默认参数 = {} 防止无参实例化时崩溃
func _init(data: Dictionary = {}):
    if data.is_empty(): return

    # 1. 预处理：统一获取内层属性字典
    # 兼容 JSON 里有时候写 'property' 有时候写 'properties' 的混乱情况
    var props = data.get("properties", data.get("property", {}))
    
    # 2. 解析 UUID (优先看外层，没有再看内层)
    uuid = data.get("uuid", props.get("uuid", ""))
    
    # 3. 解析名字 (支持 name 或 title)
    name = data.get("name", data.get("title", props.get("title", "")))
    
    # 4. 解析描述 (支持 description 或 text)
    description = data.get("description", data.get("text", props.get("text", "")))
    
    # 5. 解析数组 (使用 assign 确保类型安全，且处理 null)
    var raw_owners = data.get("owner_uuids", props.get("owner_uuids", []))
    owner_uuids.assign(raw_owners)
    
    var raw_tags = data.get("tags", props.get("tags", []))
    tags.assign(raw_tags)

    # 6. 加载图标 (IconLoader 最好是静态工具类)
    if not name.is_empty():
        # 这里假设你有这个工具类，如果没有，请删掉这行
        icon = IconLoader.get_icon(name)