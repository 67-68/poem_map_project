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

@export_group("Generated Events Import Pipeline")
## 📥 导入正交生成管线产出的 CSV 事件数据
##
## 点击后，扫描 res://data/generated_events/ 目录下的 *_events.csv 文件，
## 使用 DSLParser 解析并保存为 .tres 资源。
##
## 这是 Phase B（Python 生成脚本） → Phase C（Godot 加载端）的桥接按钮。
## 完整的管线是：
##   Python 生成 → data/generated_events/*_events.csv
##   → csv_cloud_loader 读取并解析 → DSLParser 创建 RandomEvent Resource
##   → save_resources_to_tres 保存为 .tres
## 全程零代码改动，点一下就行 🤓☝️
@export var import_generated_events: bool = false:
    set(val):
        import_generated_events = false
        if val == true:
            notify_property_list_changed()
            _import_generated_events_from_csv()

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
        "save_path": "res://data/1_core_rules/traits/_traits.csv",
        "data_type": "trait"
    },
    {
        "name": "flags_data",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=2126665400&single=true&output=csv",
        "save_path": "res://data/1_core_rules/flags/_flags.csv",
    "data_type": "flag"
    },
    {
        "name": "state_transistors",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=1696402287&single=true&output=csv",
        "save_path": "res://data/1_core_rules/state_transistors/_state_transistor.csv",
        "data_type": "state_transistor"
    },
    {
        "name": "随机事件池",
        "url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?gid=0&single=true&output=csv",
        "save_path": "res://data/3_actions_pool/events/_random_events.csv",
        "data_type": "random_event"
    },
    # ════════════════════════════════════════════════════════════════
    # 🏠 本地生成事件（Phase B Python 管线产物）
    # is_generated = true 时，系统跳过云端拉取，直接从本地 CSV 读取。
    # .tres 输出目录需要手动指定（通过 tres_output_dir 字段）。
    # ════════════════════════════════════════════════════════════════
    {
        "name": "拜谒蜜月期生成事件（本地生成）",
        "save_path": "data/4_eras/745_ambition/baiye/honey_moon/_bai_ye_honeymoon_events.csv",
        "data_type": "random_event",
        "is_generated": true,
    },
    {
        "name": "拜谒真实面目",
        "save_path": "res://data/4_eras/745_ambition/baiye/real_appearance/_bai_ye_real_appearance_events.csv",
        "data_type": "random_event",
        "is_generated": true,
    },
    {
        "name": "野心生活事件",
        "save_path": "res://data/4_eras/745_ambition/_scene_imagery_library_events.csv",
        "data_type": "random_event",
        "is_generated": true,
    },
]

# 🗺️ store_to 路径映射表
# 当 CSV 的 context 列指定了 store_to=<key> 时，根据此表将 .tres 文件路由到对应目录。
# 如果 key 不在映射表中，直接使用 key 作为 res:// 相对路径（如 store_to=data/mydir → res://data/mydir）
# 🗺️ store_to 路径映射表（v2：era-action 复合键）
# 格式：<era_id>.<action_name> → res://data/<era_dir>/<action_dir>/
# 例如 "745_ambition.fengzhao" → res://data/4_eras/745_ambition/fengzhao/
# 🚨 旧版纯 action 键（fengzhao/denggao 等）已迁移为 era-action 复合键。
#     保留 baiye 条目（旧格式，用于拜谒事件，后续也会迁移）。
const STORE_TO_PATH_MAP: Dictionary = {
    # ── 745_ambition 时代 ──
    "745_ambition.fengzhao": "res://data/4_eras/745_ambition/fengzhao",
    "745_ambition.denggao": "res://data/4_eras/745_ambition/denggao",
    "745_ambition.duzhuo": "res://data/4_eras/745_ambition/duzhuo",
    "745_ambition.jiaoyou": "res://data/4_eras/745_ambition/jiaoyou",
    "745_ambition.fangshi": "res://data/4_eras/745_ambition/fangshi",
    # ── 旧格式（待迁移） ──
    "baiye": "res://data/tres_random_event_bai_ye",
}

# 任务指针：当前正在下载第几个文件？
var _current_job_index: int = -1

# 简化的重试逻辑 - 最多重试3次原始URL
const MAX_RETRIES = 3

func _ready():
    # CLI 模式检测：当通过 godot --headless -s <entry.gd> --sync --prefer-local 启动时
    # 🚨 注意：如果 csv_cloud_loader 是通过 CLI 入口脚本 (csv_cloud_sync_cli.gd) 实例化的，
    #          这里不做任何操作，由入口脚本负责启动同步。
    #          此处的 CLI 检测是兜底方案，当脚本被单独 -s 运行时生效。
    # 🤓☝️ 使用 OS.get_cmdline_user_args() 获取 -- 分隔符之后的用户参数
    var args = OS.get_cmdline_user_args()
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


# 处理下一个任务
func process_next_job() -> void:
    if _current_job_index >= DATA_MANIFEST.size():
        print("===== 所有数据源同步完成！🤓☝️ =====")
        _current_job_index = -1
        
        
        # 🚨 数据同步完成后，执行事件数据Linter
        print("\n===== 开始执行事件数据Linter =====")
        var linter = EventDataLinter.new()
        linter.execute_linter()
        print("===== 事件数据Linter执行完成 =====\n")
        
        return
    
    var current_job = DATA_MANIFEST[_current_job_index]
    var job_name = current_job.get("name", "Unknown")
    var job_save_path = current_job.get("save_path", "")
    var job_data_type = current_job.get("data_type", "random_event")
    var job_is_generated = current_job.get("is_generated", false)
    var job_tres_output_dir = current_job.get("tres_output_dir", "")

    # ── 分支 A: 本地生成文件（Phase B 管线产物） ──
    if job_is_generated:
        print("\n===== 开始处理任务 [%d/%d]: %s (本地生成数据) =====" % [_current_job_index + 1, DATA_MANIFEST.size(), job_name])
        var local_content = _read_local_csv(job_save_path)
        if local_content == "":
            push_error("生成事件 CSV 文件不存在: %s 💀" % job_save_path)
            print("请先运行 Python 生成脚本: poetry run python tools/generate_orthogonal_events.py")
        else:
            _process_csv_data(local_content, job_save_path, job_data_type, job_tres_output_dir)
        _current_job_index += 1
        process_next_job()
        return

    var job_url = current_job.get("url", "")
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
func _process_csv_data(raw_csv_string: String, save_path: String, data_type: String, tres_output_dir: String = "") -> void:
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

    # 从CSV路径推断.tres保存路径
    # 如果指定了 tres_output_dir，使用指定的路径；否则使用CSV所在目录
    var tres_save_path = tres_output_dir if not tres_output_dir.is_empty() else save_path.get_base_dir() + "/"
    save_resources_to_tres(resources, tres_save_path)


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
# 🆕 支持逐资源 store_to 路由：如果 resource 是 RandomEvent 且 custom_context_params 中有 store_to，
#   则根据 store_to key 查 STORE_TO_PATH_MAP 确定实际保存路径；未命中则直接作为 res:// 路径使用。
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

        # 🆕 逐资源 store_to 路由检测
        # 如果资源是 RandomEvent 且 custom_context_params 中有 store_to，根据映射表或直接路径路由
        var actual_folder_path = folder_path
        if resource is RandomEvent:
            var custom_params = resource.custom_context_params
            if custom_params.has("store_to"):
                var store_key: String = custom_params["store_to"]
                if STORE_TO_PATH_MAP.has(store_key):
                    actual_folder_path = STORE_TO_PATH_MAP[store_key]
                    print("🆕 store_to 命中映射表: key=%s → path=%s" % [store_key, actual_folder_path])
                else:
                    # 未命中映射表，直接使用 key 作为 res:// 相对路径
                    actual_folder_path = "res://" + store_key.trim_prefix("/")
                    print("🆕 store_to 未命中映射表，直接使用 raw key: key=%s → path=%s" % [store_key, actual_folder_path])
                if not actual_folder_path.ends_with("/"):
                    actual_folder_path += "/"
                # 确保目标文件夹存在
                if not DirAccess.dir_exists_absolute(actual_folder_path):
                    DirAccess.make_dir_absolute(actual_folder_path)
                    print("创建 store_to 文件夹: %s" % actual_folder_path)

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

        var file_path = "%s%s.tres" % [actual_folder_path, final_filename]

        # 保存为.tres文件
        var save_result = ResourceSaver.save(resource, file_path)
        if save_result == OK:
            print("保存资源到文件: %s" % file_path)
            saved_count += 1
        else:
            push_error("保存资源失败: %s, 错误代码: %d" % [file_path, save_result])
            skipped_count += 1

    print("成功保存 %d/%d 个资源  (跳过 %d 个)" % [saved_count, resources.size(), skipped_count])

# 📥 导入正交生成管线产出的 CSV 事件数据
# 这是 Phase B（Python 生成）→ Phase C（Godot 加载）的桥接函数。
#
# 流程：
#   1. 扫描 data/generated_events/ 目录下最新的 *_events.csv
#   2. 读取 CSV 内容
#   3. 通过 _process_csv_data() 走完整管线：DSLParser → .tres
#
# 这个函数不需要任何配置，点一下按钮就行 🤓☝️
func _import_generated_events_from_csv() -> void:
    print("\n===== 📥 开始导入生成事件 CSV =====")
    
    # ── 1. 收集 DATA_MANIFEST 中所有 is_generated 条目 ──
    var generated_entries: Array[Dictionary] = []
    for entry in DATA_MANIFEST:
        if entry.get("is_generated", false):
            generated_entries.append(entry)
    
    if generated_entries.is_empty():
        print("⚠️  DATA_MANIFEST 中没有 is_generated 条目")
        print("   请先在 DATA_MANIFEST 中添加生成事件配置")
        print("   然后运行 Python 生成脚本: poetry run python tools/generate_orthogonal_events.py")
        return
    
    print("✅ 找到 %d 个生成事件条目，开始全量解析..." % generated_entries.size())
    
    var GENERATED_DIR = "res://data/generated_events/"
    
    # ├ 兜底：扫描目录中是否有 manifest 未收录的 CSV（防遗漏）
    var orphan_csvs: Array[String] = []
    if DirAccess.dir_exists_absolute(GENERATED_DIR):
        var dir = DirAccess.open(GENERATED_DIR)
        if dir:
            dir.list_dir_begin()
            var file_name = dir.get_next()
            while file_name != "":
                if file_name.ends_with("_events.csv") and not file_name.begins_with("."):
                    # 检查这个 CSV 是否已被 manifest 收录
                    var full_path = GENERATED_DIR + file_name
                    var is_covered = false
                    for entry in generated_entries:
                        if entry.get("save_path", "") == full_path:
                            is_covered = true
                            break
                    if not is_covered:
                        orphan_csvs.append(full_path)
                file_name = dir.get_next()
            dir.list_dir_end()
    if not orphan_csvs.is_empty():
        print("⚠️  发现 %d 个未收录到 DATA_MANIFEST 的 CSV 文件:" % orphan_csvs.size())
        for oc in orphan_csvs:
            print("   - %s" % oc)
        print("   建议将其加入 DATA_MANIFEST（is_generated=true）")
    
    # ── 2. 全量遍历 generated_entries，逐个解析 ──
    var success_count = 0
    for entry in generated_entries:
        var name = entry.get("name", "Unknown")
        var csv_path = entry.get("save_path", "")
        var data_type = entry.get("data_type", "random_event")
        var tres_output_dir = entry.get("tres_output_dir", "")
        
        if csv_path.is_empty():
            print("⚠️  条目 '%s' 的 save_path 为空，跳过" % name)
            continue
        
        print("\n--- 处理: %s ---" % name)
        print("   CSV: %s" % csv_path)
        if not tres_output_dir.is_empty():
            print("   .tres 输出: %s (手动指定)" % tres_output_dir)
        else:
            print("   .tres 输出: %s (自动推导自 CSV 路径)" % csv_path.get_base_dir() + "/")
        
        # ── 3. 读取 CSV 内容 ──
        if not FileAccess.file_exists(csv_path):
            print("⚠️  CSV 文件不存在: %s" % csv_path)
            print("   请先运行 Python 生成脚本生成此文件")
            continue
        
        var file = FileAccess.open(csv_path, FileAccess.READ)
        if file == null:
            push_error("无法打开文件: %s 💀" % csv_path)
            continue
        
        var csv_content = file.get_as_text()
        file.close()
        
        if csv_content.is_empty():
            push_error("CSV 文件为空，跳过: %s 💀" % csv_path)
            continue
        
        print("✅ 成功读取 CSV (%d 字节)" % csv_content.length())
        
        # ── 4. 走完整管线：DSLParser → .tres ──
        # 🧩 _process_csv_data 内部会：
        #   - 解析 CSV headers + rows → Array[Dictionary]
        #   - 调用 DSLParser.parse_csv_data(csv_data, data_type)
        #   - 遍历资源注入数据库
        #   - save_resources_to_tres(resources, csv所在目录 或 tres_output_dir)
        _process_csv_data(csv_content, csv_path, data_type, tres_output_dir)
        success_count += 1
    
    
    print("\n✅ 生成事件导入完成！")
    print("   成功处理: %d/%d 个条目" % [success_count, generated_entries.size()])
    if not orphan_csvs.is_empty():
        print("   ⚠️  目录中还有 %d 个未收录的 CSV（见上方列表）" % orphan_csvs.size())
    print("   .tres 输出目录: 由各条目的 tres_output_dir 字段指定（详见上方处理日志）")
    print("===== 📥 导入完成 =====\n")


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
