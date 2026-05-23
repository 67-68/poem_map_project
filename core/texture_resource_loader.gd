class_name TextureResLoader extends RefCounted

static func get_icon_simpler(name: String) -> Texture2D:
    return _load_texture_with_fallback(name, GameConfig.ICON_PATH, GameConfig.DEFAULT_ICON_PATH)

static func _load_texture_with_fallback(name: String, folder_path: String, fallback_path: String) -> Texture2D:
    if not name: 
        Logging.warn("纹理名称为空")
        return load(fallback_path)
        
    name = name + ".png"
    name = folder_path + name
            
    if ResourceLoader.exists(name): 
        return load(name)
    
    # 尝试jpg格式
    name = name.replace(".png", ".jpg")
    if ResourceLoader.exists(name):
        return load(name)
    
    Logging.warn("纹理不存在: %s, 尝试使用default background" % name)
    return load(fallback_path)

static func get_background(background_name: String) -> Texture2D:
    return _load_texture_with_fallback(background_name, GameConfig.BG_PATH, GameConfig.DEFAULT_BG_PATH)

static func get_character(character_name: String) -> Texture2D:
    return _load_texture_with_fallback(character_name, GameConfig.CHARACTER_PATH, GameConfig.DEFAULT_BG_PATH)

static func get_icon(...names) -> Texture2D:
    """
    DEPRECIATED!
    DEPRECIATED!
    DEPRECIATED!
    允许传入多个name来获取icon
    """
    for name in names:
        if not name:
            continue
        # 支持直接写路径，也支持写名字
        if not name.ends_with(".png"):
            name = name + ".png"
            
        if not name.begins_with("res://"):
            if FileAccess.file_exists(GameConfig.ICON_PATH + name):
                name = GameConfig.ICON_PATH + name
                
        if ResourceLoader.exists(name):
            return load(name) # Godot 的 load 自带缓存，不用担心性能
        
        if not ResourceLoader.exists(name):
            name = name.replace(".png", ".jpg")
            if ResourceLoader.exists(name):
                return load(name) # Godot 的 load 自带缓存，不用担心性能
    
    var name_str = ""
    for name in names:
        if name:
            name_str += name + ","
    Logging.warn("图标丢失: %s" % name_str)
    
    return load(GameConfig.DEFAULT_ICON_PATH)