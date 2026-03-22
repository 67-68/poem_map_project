@tool
extends EditorScript
# JsonToTresConverter.gd

func _run():
    # 1. 定义要扫描的目录
    var scan_dir = "res://data/"
    
    # 2. 扫描目录中的所有 .json 文件
    var dir = DirAccess.open(scan_dir)
    if not dir:
        print("❌ 无法打开目录: ", scan_dir)
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    var processed_files = []
    
    while file_name != "":
        if file_name.ends_with(".json") and not file_name.begins_with("tres_"):
            var json_path = scan_dir + file_name
            var base_name = file_name.get_basename()  # 去掉 .json 后缀
            var output_dir = scan_dir + "tres_" + base_name + "/"
            
            print("🔄 正在处理文件: ", file_name)
            process_json_file(json_path, output_dir)
            processed_files.append(file_name)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()
    
    if processed_files.is_empty():
        print("⚠️ 没有找到可处理的 JSON 文件")
    else:
        print("🎉 批量转换完毕！处理了 ", processed_files.size(), " 个文件:")
        for file in processed_files:
            print("   - ", file)

func process_json_file(json_path: String, output_dir: String):
    # 确保输出目录存在
    var dir = DirAccess.open("res://")
    if not dir.dir_exists(output_dir):
        dir.make_dir_recursive(output_dir)
        print("📁 创建目录: ", output_dir)

    # 读取并解析 JSON
    var file = FileAccess.open(json_path, FileAccess.READ)
    if not file:
        print("❌ 找不到 JSON 文件: ", json_path)
        return
        
    var json_text = file.get_as_text()
    var json = JSON.new()
    var error = json.parse(json_text)
    
    if error != OK:
        print("❌ JSON 格式错误 (", json_path, "): ", json.get_error_message())
        return
        
    var data = json.get_data()
    # 如果你的 json 是一个数组（包含多个对象），就遍历它。如果是一个对象，就包成数组。
    var data_array = data if data is Array else [data]

    # 核心炼金循环：把 JSON 变成 Tres
    var processed_count = 0
    for item in data_array:
        var res = create_resource_for_file(json_path, item)
        
        if not res:
            print("⚠️ 跳过无法处理的条目")
            continue
        
        # 暴力注入：把 JSON 字典里的值，塞进 Resource 的属性里
        for key in item.keys():
            if key in res:
                # 【重要】如果你的 JSON 里包含极其复杂的自定义类（比如 MultiplyOperator）
                # 你要么在 Resource 里把它声明为 Dictionary 暂时接收，
                # 要么在这里再写一个子级的实例化转换逻辑。
                res.set(key, item[key]) 
            else:
                print("⚠️ 忽略未知字段: ", key, " (文件: ", json_path.get_file(), ")")
                
        # 保存为 .tres 文件
        # 我们用 uuid 作为文件名，确保唯一性
        var file_id = item.get("uuid", item.get("id", "item_" + str(processed_count)))
        var save_path = output_dir + file_id + ".tres"
        var save_err = ResourceSaver.save(res, save_path)
        
        if save_err == OK:
            print("✅ 成功生成资源: ", save_path)
            processed_count += 1
        else:
            print("❌ 保存失败: ", save_path)
            
    print("📊 ", json_path.get_file(), " 处理完成，共 ", processed_count, " 个资源")

func create_resource_for_file(json_path: String, _item: Dictionary) -> Resource:
    var file_name = json_path.get_file().get_basename()
    
    # 根据不同的 JSON 文件类型创建对应的 Resource
    match file_name:
        "ambitions":
            return AmbitionData.new({})
        "factions":
            # 使用通用 Resource，如果需要可以创建 FactionData 类
            return Resource.new()
        "focused_chats":
            # 使用通用 Resource，如果需要可以创建 FocusedChatData 类
            return Resource.new()
        "history_event_data":
            return BaseEvent.new({})
        "msger_data":
            return MessagerData.new({})
        "path_points":
            # 使用通用 Resource，如果需要可以创建 PathPointData 类
            return Resource.new()
        "poem_data":
            return PoemData.new({})
        "poet_data":
            return PoetData.new({})
        "traits":
            # 使用通用 Resource，如果需要可以创建 TraitData 类
            return Trait.new({})
        _:
            print("⚠️ 未知的 JSON 文件类型: ", file_name, "，使用通用 Resource")
            return Resource.new()