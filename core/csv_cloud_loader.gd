@tool
extends Node

@export_group("Continuous Integration Pipeline")
@export var sync_all_data: bool = false:
    set(val):
        sync_all_data = false
        if val == true:
            notify_property_list_changed()
            start_sync_queue() # 🚨 启动队列机制！

## 🗂️ 本地优先模式
## 启用后，优先读取本地已存在的 CSV 文件，跳过云端拉取。
## 仅当本地文件不存在时，自动降级到云端拉取。
## 适合离线开发或频繁调试场景，省流量防限速 💀
@export var prefer_local_files: bool = false

@export_group("Godot Cache Management")
## 💀 删掉 .godot 导入缓存文件夹，强制 Godot 全量重新导入所有资源
## Godot 4 的导入缓存机制会导致修改代码后不生效（因为缓存的字节码没更新）
## 点击后执行: rm -rf res://.godot/
## ⚠️ 执行后需要重启 Godot 编辑器才能生效
@export var clear_godot_cache: bool = false:
    set(val):
        clear_godot_cache = false
        if val == true:
            notify_property_list_changed()
            _clear_godot_import_cache()

# 🤓☝️ 核心契约 1：资产同步清单 (The Manifest)
# 把 URL 和它对应的本地保存路径死死绑定在一起！这就是你说的"携带信息"！
#
# ⚠️ 排序警告 ⚠️
# 解析顺序至关重要！trait 和 flag 必须排在 random_event 之前，因为：
#   - random_event 的 template 字段可能引用 urn:trait:xxx / urn:flag:xxx
#   - 如果 trait/flag 尚未加载到 Database，URN 解析会失败，template 回退为空事件
#   - 届时错误将难以追踪 💀
# 如果你觉得"我换个顺序也没事吧"然后乱改 → 时序bug自求多福。
const DATA_MANIFEST: Array[Dictionary] = [
    {
        "name": "trait_data",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=309055591&single=true&output=csv",
        "save_path": "res://data/tres_traits/traits.csv",
        "data_type": "trait"
    },
    {
        "name": "flags_data",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=2126665400&single=true&output=csv",
        "save_path": "res://data/flags/flags.csv",
        "data_type": "flag"
    },
    {
        "name": "state_transistors",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=1696402287&single=true&output=csv",
        "save_path": "res://data/tres_state_transistors/state_transistor.csv",
        "data_type": "state_transistor"
    },
    {
        "name": "随机事件池",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=0&single=true&output=csv",
        "save_path": "res://data/random_events/random_events.csv",
        "data_type": "random_event"
    }
]

# 任务指针：当前正在下载第几个文件？
var _current_job_index: int = -1

# 简化的重试逻辑 - 最多重试3次原始URL
const MAX_RETRIES = 3

func _ready():
    # CLI 模式检测：当通过 godot --headless -s <entry.gd> --sync --prefer-local 启动时
    # 🚨 注意：如果 csv_cloud_loader 是通过 CLI 入口脚本 (csv_cloud_sync_cli.gd) 实例化的，
    #          这里不做任何操作，由入口脚本负责启动同步。
    #          此处的 CLI 检测是兜底方案，当脚本被单独 -s 运行时生效。
    var args = OS.get_cmdline_args()
    var should_sync = "--sync" in args
    var prefer_local = "--prefer-local" in args
    
    if should_sync:
        print("===== CLI 模式启动 csv_cloud_loader =====")
        print("prefer_local_files: %s" % prefer_local)
        prefer_local_files = prefer_local
        start_sync_queue()

# 🚨 启动队列机制
func start_sync_queue() -> void:
    if DATA_MANIFEST.is_empty():
        push_error("DATA_MANIFEST 为空，没有配置任何数据源！💀")
        return
    
    var source_mode = "本地优先" if prefer_local_files else "云端"
    print("===== 开始数据同步队列 (%s 模式) =====" % source_mode)
    print("共需同步 %d 个数据源" % DATA_MANIFEST.size())
    
    _current_job_index = 0
    process_next_job()

# 刷新所有 registry 文件（每次保存 .tres 后调用）
# 虽然全量扫描所有文件夹是 O(n) 重复劳动，但 CSV 同步本身就是低频操作，
# 性能过剩到可以忽略不计 🤓☝️。主要是为了保证下一个表的 template URN
# 能通过 registry 找到当前表刚保存的 .tres 文件。
# 如果哪天你觉得同步太慢，99.99% 是网络问题，不是这里的问题 💀
func _regenerate_registries(silent: bool = false) -> void:
    if not silent:
        print("\n===== 刷新resources registry文件 =====")
    var registry_creator_script = load("res://resources_registry_creator.gd")
    if not registry_creator_script:
        push_error("无法加载resources_registry_creator.gd，跳过registry刷新 💀")
        return
    
    var registry_creator = registry_creator_script.new()
    registry_creator.overwrite_existing = true
    registry_creator.skip_files_without_uuid = true
    registry_creator.verbose = not silent  # 🚨 静默模式下关闭registry创建器的详细输出
    registry_creator.create_all_registries()
    if not silent:
        print("===== Resources registry刷新完成 =====\n")

# 处理下一个任务
func process_next_job() -> void:
    if _current_job_index >= DATA_MANIFEST.size():
        print("===== 所有数据源同步完成！🤓☝️ =====")
        _current_job_index = -1
        
        # 🚨 同步完成后，再刷新一次registry（冗余但无害）
        _regenerate_registries()
        
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
    
    # 🚨 本地优先模式：检查本地CSV文件是否存在
    if prefer_local_files:
        var local_content = _read_local_csv(job_save_path)
        if local_content != "":
            print("✅ 本地CSV文件存在，跳过云端下载: %s" % job_save_path)
            _process_csv_data(local_content, job_save_path, job_data_type)
            _current_job_index += 1
            process_next_job()
            return
        else:
            print("⚠️ 本地CSV文件不存在（路径: %s），降级到云端拉取..." % job_save_path)
    
    # 默认/降级：从云端拉取
    retry_count = 0
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

# 简单的CSV行解析，处理引号、逗号和括号深度
# 括号内的逗号不被视为分隔符（支持 DSL 函数调用）
# 🚨 同时匹配 ASCII 和全角括号（纯文本中全角括号是正常的，但也需要跟踪深度）
func parse_csv_line(line: String) -> Array[String]:
    var result: Array[String] = []
    var current = ""
    var in_quotes = false
    var paren_depth = 0

    for i in range(line.length()):
        var ch = line[i]
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ',' and not in_quotes and paren_depth == 0:
            result.append(current)
            current = ""
        else:
            current += ch
            if not in_quotes:
                if ch == '(' or ch == '\uff08':
                    paren_depth += 1
                elif ch == ')' or ch == '\uff09':
                    paren_depth -= 1

    result.append(current)
    return result

# 📖 读取本地 CSV 文件内容
# 优先使用 res:// 路径，如果文件不存在返回空字符串
# 调用方根据返回值是否为空判断是否需要降级到云端
func _read_local_csv(save_path: String) -> String:
    if not FileAccess.file_exists(save_path):
        print("本地CSV文件不存在: %s" % save_path)
        return ""
    
    var file = FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        push_error("无法打开本地CSV文件: %s 💀" % save_path)
        return ""
    
    var content = file.get_as_text()
    file.close()
    print("成功读取本地CSV文件: %s (%d 字节)" % [save_path, content.length()])
    return content

# 🧩 共享解析链路：解析原始 CSV 内容、创建 Resource、注入数据库、保存 .tres
# 这是「获取层」和「持久化层」之间的共享方法，无论数据来自云端还是本地都走这里
func _process_csv_data(raw_csv_string: String, save_path: String, data_type: String) -> void:
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
    
    # 使用 DSL 解析器解析数据（根据 data_type 选择不同的解析逻辑）
    var resources = DSLParser.parse_csv_data(csv_data, data_type)

    # 将解析成功的资源注入到数据库（根据类型）
    for resource in resources:
        if resource is RandomEvent:
            print("事件注入成功: %s" % resource.uuid)
        elif resource is Flag:
            print("标志位注入成功: %s" % resource.uuid)
        elif resource is Trait:
            print("特性注入成功: %s" % resource.uuid)
        else:
            print("资源注入成功: %s" % resource.resource_path)

    print("数据注入完成！共注入 %d 个资源 🤓☝️" % resources.size())

    # 调试：检查资源有效性
    if resources.is_empty():
        print("Warning: DSLParser 返回空资源数组，跳过保存")
        return

    # 调试：检查转换后的资源数组
    print("资源数组转换完成，大小: %d" % resources.size())
    for i in range(min(resources.size(), 3)):  # 只打印前3个
        var res = resources[i]
        print("资源[%d]: 类名=%s, resource_path=%s" % [i, res.get_class(), res.resource_path])

    # 从CSV路径推断.tres保存路径（同目录下）
    var tres_save_path = save_path.get_base_dir() + "/"
    save_resources_to_tres(resources, tres_save_path)

    # 🚨 立即静默刷新registry，确保下一个表的 template URN 能找到本表刚保存的 .tres
    # 只有最后一次全量同步完成后才输出日志，中间刷新静默执行
    _regenerate_registries(true)

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
    
    # 重置重试计数器
    retry_count = 0
    
    # 保存原始CSV文件到指定路径，下次本地优先模式可以直接使用
    if not save_path.is_empty():
        save_raw_csv(raw_csv_string, save_path)
    
    # 🧩 共享解析链路：解析、创建资源、保存 .tres
    _process_csv_data(raw_csv_string, save_path, data_type)
    
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

# 💀 清空 .godot 导入缓存文件夹（带三重安全保险 + 废纸篓回收）
# Godot 4 会把编译后的脚本字节码缓存到 .godot/ 下，
# 如果你在外面（VS Code）改了脚本，Godot 可能还拿着旧的字节码不撒手。
# 删了这个文件夹，重启 Godot 后它会老老实实地全量重新导入 🤓☝️
#
# 🛡️ 安全校验（防止删错祖宗文件夹）：
#   1. 路径必须以 .godot 结尾
#   2. 父目录必须是项目根目录（res:// 全局化后的路径）
#   3. 目标必须真实存在于文件系统
#   全部通过才执行，任何一个不满足直接拒绝 💀
#
# ♻️ 使用 OS.move_to_trash() 代替 rm -rf：
#   - 不直接删除，而是移到系统废纸篓，可恢复
#   - 不执行 shell 命令，没有命令注入风险
#   - macOS/Linux/Windows 全平台兼容
func _clear_godot_import_cache() -> void:
    var project_root = ProjectSettings.globalize_path("res://")
    var godot_dir_path = project_root.path_join(".godot")
    
    print("\n===== 💀 准备清除 Godot 导入缓存 =====")
    print("项目根目录: %s" % project_root)
    print("目标路径:   %s" % godot_dir_path)
    
    # 🛡️ 保险 1：校验路径是否以 .godot 结尾
    if not godot_dir_path.ends_with(".godot"):
        push_error("❌ 安全校验失败：目标路径不以 .godot 结尾！路径=%s" % godot_dir_path)
        push_error("   拒绝执行，这可能是个错误的目标路径 💀")
        return
    
    # 🛡️ 保险 2：校验父目录是否为项目根目录
    var parent_dir = godot_dir_path.get_base_dir()
    if parent_dir != project_root.trim_suffix("/"):
        push_error("❌ 安全校验失败：父目录不是项目根目录！")
        push_error("   期望父目录: %s" % project_root)
        push_error("   实际父目录: %s" % parent_dir)
        push_error("   拒绝执行，路径异常 💀")
        return
    
    # 🛡️ 保险 3：校验目标是否存在
    if not DirAccess.dir_exists_absolute(godot_dir_path):
        print("⚠️ .godot 文件夹不存在，无需清理")
        return
    
    # 🔥 三重保险全部通过，用 OS.move_to_trash() 安全删除
    print("🛡️ 安全校验全部通过，开始移动至废纸篓...")
    print("目标: %s" % godot_dir_path)
    print("♻️ 使用 OS.move_to_trash() — 文件将被移到系统废纸篓，可随时恢复")
    
    var success = OS.move_to_trash(godot_dir_path)
    
    if success:
        print("✅ .godot 导入缓存已成功移入废纸篓！")
        print("⚠️ 重要：请重启 Godot 编辑器让导入机制重新生效")
        print("   Godot 会在启动时重新生成 .godot/ 目录并全量导入所有资源")
        print("💡 如需恢复，请前往系统废纸篓找回 .godot 文件夹")
    else:
        push_error("❌ 移动至废纸篓失败！可能原因：")
        push_error("   - 权限不足（尝试用 rm -rf 手动删除）")
        push_error("   - 文件系统错误")
