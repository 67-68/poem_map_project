class_name IconLoader extends RefCounted
static func get_icon(name: String) -> Texture2D:
    if name.is_empty():
        return load(Global.DEFAULT_ICON)
        
    # 支持直接写路径，也支持写名字
    var final_path = name
    if not name.begins_with("res://"):
        final_path = Global.ICON_PATH + name + ".png"
    
    if ResourceLoader.exists(final_path):
        return load(final_path) # Godot 的 load 自带缓存，不用担心性能
    else:
        Logging.warn("图标丢失: " + final_path)
        return load(Global.DEFAULT_ICON)