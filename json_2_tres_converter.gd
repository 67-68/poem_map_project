@tool
extends EditorScript
# JsonToTresConverter.gd

func _run():
    # 1. 定义你的路径
    var json_path = "res://data/ambitions.json.json" # 你的 JSON 文件路径
    var output_dir = "res://data/tres_ambitions/"    # 你的 tres 存放目录
    
    # 确保输出目录存在
    var dir = DirAccess.open("res://")
    if not dir.dir_exists(output_dir):
        dir.make_dir_recursive(output_dir)

    # 2. 读取并解析 JSON
    var file = FileAccess.open(json_path, FileAccess.READ)
    if not file:
        print("❌ 找不到 JSON 文件!")
        return
        
    var json_text = file.get_as_text()
    var json = JSON.new()
    var error = json.parse(json_text)
    
    if error != OK:
        print("❌ JSON 格式错误: ", json.get_error_message())
        return
        
    var data = json.get_data()
    # 如果你的 json 是一个数组（包含多个对象），就遍历它。如果是一个对象，就包成数组。
    var data_array = data if data is Array else [data]

    # 3. 核心炼金循环：把 JSON 变成 Tres
    for item in data_array:
        var res = AmbitionData.new({}) # 实例化你的强类型 Resource
        
        # 暴力注入：把 JSON 字典里的值，塞进 Resource 的属性里
        for key in item.keys():
            if key in res:
                # 【重要】如果你的 JSON 里包含极其复杂的自定义类（比如 MultiplyOperator）
                # 你要么在 Resource 里把它声明为 Dictionary 暂时接收，
                # 要么在这里再写一个子级的实例化转换逻辑。
                res.set(key, item[key]) 
            else:
                print("⚠️ 忽略未知字段: ", key)
                
        # 4. 保存为 .tres 文件
        # 我们用 uuid 作为文件名，确保唯一性
        var save_path = output_dir + item.get("uuid", "unknown_id") + ".tres"
        var save_err = ResourceSaver.save(res, save_path)
        
        if save_err == OK:
            print("✅ 成功生成资源: ", save_path)
        else:
            print("❌ 保存失败: ", save_path)
            
    print("🎉 批量转换完毕！去爽吧！")