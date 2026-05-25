@tool
extends Node

@export var download: bool = false:
    set(val):
        if val == true:
            download = false
            notify_property_list_changed()
            fetch_events_from_cloud(SHEET_CSV_URL)

# 填入你刚刚发布的纯 CSV 直链
const SHEET_CSV_URL: String = "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?output=csv"

# 简化的重试逻辑 - 最多重试3次原始URL
const MAX_RETRIES = 3

func _ready():
    fetch_events_from_cloud()

var retry_count = 0

# 简单的CSV行解析，处理引号
func parse_csv_line(line: String) -> Array[String]:
    var result: Array[String] = []
    var current = ""
    var in_quotes = false

    for i in range(line.length()):
        var ch = line[i]
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ',' and not in_quotes:
            result.append(current)
            current = ""
        else:
            current += ch

    result.append(current)
    return result

func fetch_events_from_cloud(url: String = SHEET_CSV_URL) -> void:
    print("开始请求云端数据: %s (尝试 %d/%d)" % [url, retry_count + 1, MAX_RETRIES + 1])
    
    # 使用 curl 进行同步网络请求，避免 @tool 脚本中的异步问题 💀
    var output = []
    var exit_code = OS.execute("curl", ["-s", "-L", url], output)
    
    if exit_code != 0:
        push_error("网络请求发起失败！错误代码: %d, 大唐的信使死在路上了 💀" % exit_code)
        if retry_count < MAX_RETRIES:
            retry_count += 1
            print("Warning: 第 %d 次重试原始URL..." % retry_count)
            fetch_events_from_cloud(SHEET_CSV_URL)
        return
    
    var raw_csv_string: String = output[0] if output.size() > 0 else ""
    
    if raw_csv_string.is_empty():
        push_error("网络请求返回空数据")
        if retry_count < MAX_RETRIES:
            retry_count += 1
            print("Warning: 第 %d 次重试原始URL..." % retry_count)
            fetch_events_from_cloud(SHEET_CSV_URL)
        return
    
    print("成功获取数据，大小: %d 字节" % raw_csv_string.length())
    print("\n===== 原始CSV文件内容 =====")
    print(raw_csv_string)
    print("===== CSV文件内容结束 =====\n")
    
    # 重置重试计数器
    retry_count = 0
    
    # 将包含几百行文本的 raw_csv_string 交给你之前写好的微语法解析器
    var csv_lines = raw_csv_string.split("\n")
    if csv_lines.size() < 2:
        push_error("CSV 数据不足，至少需要表头和一行数据")
        return
    
    # 解析表头
    var csv_headers = csv_lines[0].strip_edges().split(",")

    # 解析每一行数据
    var csv_data: Array[Dictionary] = []
    for i in range(1, csv_lines.size()):
        var line = csv_lines[i].strip_edges()
        if line.is_empty():
            continue

        # 简单的CSV解析，处理引号包裹的字段
        var values = parse_csv_line(line)
        var row_data = {}

        for j in range(csv_headers.size()):
            if j < values.size():
                var key = csv_headers[j].strip_edges()
                var value = values[j].strip_edges()
                # 去除字段值的引号
                if value.begins_with('"') and value.ends_with('"'):
                    value = value.substr(1, value.length() - 2)
                row_data[key] = value

        if not row_data.is_empty():
            csv_data.append(row_data)
    
    # 使用 DSL 解析器解析事件数据
    var events = DSLParser.parse_csv_data(csv_data)

    # 将解析成功的事件注入到 Database.random_events 中
    for event in events:
        # Database.random_events[event.uuid] = event
        print("云端事件注入成功: %s" % event.uuid)

    print("云端数据注入完成！共注入 %d 个事件 🤓☝️" % events.size())

    # 保存为.tres文件到tests/文件夹
    save_resources_to_tres(events, "res://tests/")

    print("云端数据注入成功！系统活过来了 🤓☝️")

# 保存resources为.tres文件到指定文件夹
func save_resources_to_tres(resources: Array[Resource], folder_path: String) -> void:
    # 确保文件夹存在
    if not folder_path.ends_with("/"):
        folder_path += "/"

    if not DirAccess.dir_exists_absolute(folder_path):
        DirAccess.make_dir_absolute(folder_path)
        print("创建文件夹: %s" % folder_path)

    var saved_count = 0
    for resource in resources:
        # 检查resource是否为有效的Resource
        if resource == null:
            continue

        # 构造文件名，优先使用resource_name，如果没有则使用resource_path的文件名
        var base_filename = ""
        if resource.has_method("get_resource_name"):
            var res_name = resource.get_resource_name()
            if not res_name.is_empty():
                base_filename = res_name

        if base_filename.is_empty():
            # 尝试从resource_path获取文件名
            var res_path = resource.resource_path
            if not res_path.is_empty():
                base_filename = res_path.get_file().get_basename()

        # 如果还是没有名字，使用资源的类名
        if base_filename.is_empty():
            base_filename = resource.get_class()

        # 将冒号转化为双下划线
        var safe_filename = base_filename.replace(":", "__")

        # 检查是否有其他特殊字符（只允许字母、数字、下划线）
        var invalid_chars_regex = RegEx.new()
        invalid_chars_regex.compile("[^a-zA-Z0-9_]")
        var invalid_chars = invalid_chars_regex.search_all(safe_filename)

        if not invalid_chars.is_empty():
            var invalid_chars_str = ""
            for result in invalid_chars:
                invalid_chars_str += result.get_string()
            push_error("资源名称包含非法字符: %s, 非法字符: %s, 拒绝保存" % [base_filename, invalid_chars_str])
            continue

        # 确保文件名唯一（添加索引）
        var final_filename = safe_filename
        var index = 0
        while FileAccess.file_exists(folder_path + final_filename + ".tres"):
            index += 1
            final_filename = safe_filename + "_%d" % index

        var file_path = "%s%s.tres" % [folder_path, final_filename]

        # 保存为.tres文件
        var save_result = ResourceSaver.save(resource, file_path)
        if save_result == OK:
            print("保存资源到文件: %s" % file_path)
            saved_count += 1
        else:
            push_error("保存资源失败: %s, 错误代码: %d" % [file_path, save_result])

    print("成功保存 %d/%d 个资源到 %s 文件夹" % [saved_count, resources.size(), folder_path])
