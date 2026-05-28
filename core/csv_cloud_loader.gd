@tool
extends Node

@export_group("Continuous Integration Pipeline")
@export var sync_all_data: bool = false:
    set(val):
        sync_all_data = false 
        if val == true:
            notify_property_list_changed()
            start_sync_queue() # 🚨 启动队列机制！

# 🤓☝️ 核心契约 1：资产同步清单 (The Manifest)
# 把 URL 和它对应的本地保存路径死死绑定在一起！这就是你说的"携带信息"！
const DATA_MANIFEST: Array[Dictionary] = [
    {
        "name": "随机事件池",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=0&single=true&output=csv",
        "save_path": "res://data/random_events/random_events.csv",
        "data_type": "random_event"
},
    {
        "name": "flags_data",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=2126665400&single=true&output=csv",
        "save_path": "res://data/flags/flags.csv",
        "data_type": "flag"
    },
    {
        "name": "trait_data",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=309055591&single=true&output=csv",
        "save_path": "res://data/tres_traits/traits.csv",
        "data_type": "trait"
    }
]

# 任务指针：当前正在下载第几个文件？
var _current_job_index: int = -1

# 简化的重试逻辑 - 最多重试3次原始URL
const MAX_RETRIES = 3

func _ready():
    # 自动启动同步队列（可选，根据需要开启）
    # start_sync_queue()
    pass

# 🚨 启动队列机制
func start_sync_queue() -> void:
    if DATA_MANIFEST.is_empty():
        push_error("DATA_MANIFEST 为空，没有配置任何数据源！💀")
        return
    
    print("===== 开始云端数据同步队列 =====")
    print("共需同步 %d 个数据源" % DATA_MANIFEST.size())
    
    _current_job_index = 0
    process_next_job()

# 处理下一个任务
func process_next_job() -> void:
    if _current_job_index >= DATA_MANIFEST.size():
        print("===== 所有数据源同步完成！🤓☝️ =====")
        _current_job_index = -1
        
        # 🚨 同步完成后，自动创建resources registry文件
        print("\n===== 开始创建resources registry文件 =====")
        var registry_creator_script = load("res://resources_registry_creator.gd")
        if not registry_creator_script:
            push_error("无法加载resources_registry_creator.gd，跳过registry创建 💀")
            return
        
        var registry_creator = registry_creator_script.new()
        registry_creator.overwrite_existing = true  # 总是覆盖，确保registry是最新的
        registry_creator.skip_files_without_uuid = true
        registry_creator.create_all_registries()
        print("===== Resources registry创建完成 =====\n")
        
        # 🚨 Registry创建完成后，执行事件数据Linter
        print("\n===== 开始执行事件数据Linter =====")
        var linter = EventDataLinter.new()
        linter.execute_linter()
        print("===== 事件数据Linter执行完成 =====\n")
        
        return
    
    var current_job = DATA_MANIFEST[_current_job_index]
    var job_name = current_job.get("name", "Unknown")
    var job_url = current_job.get("url", "")
    var job_save_path = current_job.get("save_path", "")
    var job_data_type = current_job.get("data_type", "random_event")

    if job_url.is_empty():
        push_error("任务 %s 的 URL 为空，跳过 💀" % job_name)
        _current_job_index += 1
        process_next_job()
        return

    print("\n===== 开始处理任务 [%d/%d]: %s (数据类型: %s) =====" % [_current_job_index + 1, DATA_MANIFEST.size(), job_name, job_data_type])
    fetch_events_from_cloud(job_url, job_save_path, job_data_type)

var retry_count = 0

# 保存原始CSV文件到指定路径
func save_raw_csv(csv_content: String, save_path: String) -> void:
    # 确保目录存在
    var dir_path = save_path.get_base_dir()
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_absolute(dir_path)
        print("创建目录: %s" % dir_path)
    
    # 保存CSV文件
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_string(csv_content)
        file.close()
        print("原始CSV文件已保存到: %s" % save_path)
    else:
        push_error("无法保存CSV文件到: %s 💀" % save_path)
        push_error('是不是文件路径写错了?')

# 验证资源是否可以保存
func is_resource_savable(resource: Resource) -> bool:

    if resource == null:
        return false
    
    # 检查是否是有效的 Resource 类型
    if not resource is Resource:
        return false
    
    return true

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

func fetch_events_from_cloud(url: String, save_path: String = "res://tests/", data_type: String = "random_event") -> void:
    print("开始请求云端数据: %s (尝试 %d/%d)" % [url, retry_count + 1, MAX_RETRIES + 1])
    
    # 使用 curl 进行同步网络请求，避免 @tool 脚本中的异步问题 💀
    var output = []
    var exit_code = OS.execute("curl", ["-s", "-L", url], output)
    
    if exit_code != 0:
        push_error("网络请求发起失败！错误代码: %d, 大唐的信使死在路上了 💀" % exit_code)
        if retry_count < MAX_RETRIES:
            retry_count += 1
            print("Warning: 第 %d 次重试原始URL..." % retry_count)
            fetch_events_from_cloud(url, save_path, data_type)
        else:
            # 重试次数耗尽，跳过当前任务继续下一个
            print("Error: 重试次数耗尽，跳过当前任务 😭")
            _current_job_index += 1
            process_next_job()
        return
    
    var raw_csv_string: String = output[0] if output.size() > 0 else ""
    
    if raw_csv_string.is_empty():
        push_error("网络请求返回空数据")
        if retry_count < MAX_RETRIES:
            retry_count += 1
            print("Warning: 第 %d 次重试原始URL..." % retry_count)
            fetch_events_from_cloud(url, save_path, data_type)
        else:
            # 重试次数耗尽，跳过当前任务继续下一个
            print("Error: 重试次数耗尽，跳过当前任务 😭")
            _current_job_index += 1
            process_next_job()
        return
    
    print("成功获取数据，大小: %d 字节" % raw_csv_string.length())
    print("\n===== 原始CSV文件内容 =====")
    print(raw_csv_string)
    print("===== CSV文件内容结束 =====\n")
    
    # 重置重试计数器
    retry_count = 0
    
    # 保存原始CSV文件到指定路径
    if not save_path.is_empty():
        save_raw_csv(raw_csv_string, save_path)
    
    # 将包含几百行文本的 raw_csv_string 交给你之前写好的微语法解析器
    var csv_lines = raw_csv_string.split("\n")
    if csv_lines.size() < 2:
        push_error("CSV 数据不足，至少需要表头和一行数据")
        # 数据格式错误，跳过当前任务继续下一个
        _current_job_index += 1
        process_next_job()
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
    
    # 使用 DSL 解析器解析数据（根据 data_type 选择不同的解析逻辑）
    var resources = DSLParser.parse_csv_data(csv_data, data_type)

    # 将解析成功的资源注入到数据库（根据类型）
    for resource in resources:
        if resource is RandomEvent:
            print("云端事件注入成功: %s" % resource.uuid)
        elif resource is Flag:
            print("云端标志位注入成功: %s" % resource.uuid)
        elif resource is Trait:
            print("云端特性注入成功: %s" % resource.uuid)
        else:
            print("云端资源注入成功: %s" % resource.resource_path)

    print("云端数据注入完成！共注入 %d 个资源 🤓☝️" % resources.size())

    # 调试：检查资源有效性
    if resources.is_empty():
        print("Warning: DSLParser 返回空资源数组，跳过保存")
        _current_job_index += 1
        process_next_job()
        return

    # 调试：检查转换后的资源数组
    print("资源数组转换完成，大小: %d" % resources.size())
    for i in range(min(resources.size(), 3)):  # 只打印前3个
        var res = resources[i]
        print("资源[%d]: 类名=%s, resource_path=%s" % [i, res.get_class(), res.resource_path])

    # 从CSV路径推断.tres保存路径（同目录下）
    var tres_save_path = save_path.get_base_dir() + "/"
    save_resources_to_tres(resources, tres_save_path)

    print("云端数据注入成功！系统活过来了 🤓☝️")

    # 🚨 当前任务完成，推进到下一个任务
    _current_job_index += 1
    process_next_job()

# 保存resources为.tres文件到指定文件夹
func save_resources_to_tres(resources: Array[Resource], folder_path: String) -> void:
    # 确保文件夹存在
    if not folder_path.ends_with("/"):
        folder_path += "/"

    if not DirAccess.dir_exists_absolute(folder_path):
        DirAccess.make_dir_absolute(folder_path)
        print("创建文件夹: %s" % folder_path)

    var saved_count = 0
    var skipped_count = 0
    
    for resource in resources:
        # 检查resource是否为有效的Resource
        if resource == null:
            print("Warning: 跳过 null 资源")
            skipped_count += 1
            continue
        
        # 验证资源是否可以保存
        if not is_resource_savable(resource):
            print("Warning: 跳过无效资源 (类名: %s)" % resource.get_class())
            skipped_count += 1
            continue

        # 构造文件名，优先使用uuid，其次使用resource_name，最后使用resource_path的文件名
        var base_filename = ""
        
        # 🎯 优先尝试获取 uuid 属性
        if resource.has_method("get") and resource.get("uuid") != null:
            var uuid = resource.get("uuid")
            if uuid is String and not uuid.is_empty():
                base_filename = uuid
                print("使用 uuid 作为文件名: %s" % base_filename)
        
        # 如果没有 uuid，尝试获取 resource_name
        if base_filename.is_empty() and resource.has_method("get_resource_name"):
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
            # 如果类名是通用的 Resource，跳过这个资源
            if base_filename == "Resource":
                print("Warning: 资源没有有效名称，跳过保存 (类名: %s)" % base_filename)
                skipped_count += 1
                continue

        # 统一转换：冒号转化为单下划线，连字符也转化为下划线（为了兼容文件系统）
        var safe_filename = base_filename.replace(":", "_").replace("-", "_")

        # 检查是否有其他特殊字符（只允许字母、数字、下划线）
        var invalid_chars_regex = RegEx.new()
        invalid_chars_regex.compile("[^a-zA-Z0-9_]")
        var invalid_chars = invalid_chars_regex.search_all(safe_filename)

        if not invalid_chars.is_empty():
            var invalid_chars_str = ""
            for result in invalid_chars:
                invalid_chars_str += result.get_string()
            push_error("资源名称包含非法字符: %s, 非法字符: %s, 拒绝保存" % [base_filename, invalid_chars_str])
            skipped_count += 1
            continue

        # 直接使用转换后的文件名，不添加索引，直接覆盖已存在的文件
        var final_filename = safe_filename

        var file_path = "%s%s.tres" % [folder_path, final_filename]

        # 保存为.tres文件
        var save_result = ResourceSaver.save(resource, file_path)
        if save_result == OK:
            print("保存资源到文件: %s" % file_path)
            saved_count += 1
        else:
            push_error("保存资源失败: %s, 错误代码: %d" % [file_path, save_result])
            skipped_count += 1

    print("成功保存 %d/%d 个资源到 %s 文件夹 (跳过 %d 个)" % [saved_count, resources.size(), folder_path, skipped_count])
