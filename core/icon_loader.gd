class_name IconLoader extends RefCounted
static func get_icon(...names) -> Texture2D:
    """
    允许传入多个name来获取icon
    """
    for name in names:
        if not name:
            continue
        # 支持直接写路径，也支持写名字
        if not name.ends_with(".png"):
            name = name + ".png"
            
        if not name.begins_with("res://"):
            if FileAccess.file_exists(Global.ICON_PATH + name):
                name = Global.ICON_PATH + name
                
        if ResourceLoader.exists(name):
            return load(name) # Godot 的 load 自带缓存，不用担心性能
    
    var name_str = ""
    for name in names:
        if name:
            name_str += name + ","
    Logging.warn("图标丢失: %s" % name_str)
    
    return load(Global.DEFAULT_ICON_PATH)
