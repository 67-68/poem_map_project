class_name IconLoader extends RefCounted
static func get_icon(...names) -> Texture2D:
    """
    允许传入多个name来获取icon
    """
    for name in names:
        if not name:
            continue
        name as String
        # 支持直接写路径，也支持写名字
        var final_path = name
        if not name.begins_with("res://"):
            if FileAccess.file_exists(Global.ICON_PATH + name):
                final_path = Global.ICON_PATH + name
        
        if not final_path.ends_with(".png"):
            final_path = final_path + ".png"
        
        if ResourceLoader.exists(final_path):
            return load(final_path) # Godot 的 load 自带缓存，不用担心性能
    
    var name_str = ""
    for name in names:
        if name:
            name_str += name + ","
    Logging.warn("图标丢失: %s" % name_str)
    
    return load(Global.DEFAULT_ICON_PATH)
