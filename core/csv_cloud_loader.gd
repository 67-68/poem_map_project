extends Node

# 🤓☝️ 必须在场景树里实际挂载这个原生节点！
@onready var http_request: HTTPRequest = $HTTPRequest 

# 填入你刚刚发布的纯 CSV 直链
const SHEET_CSV_URL: String = "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?output=csv"

# 简化的重试逻辑 - 最多重试3次原始URL
const MAX_RETRIES = 3

func _ready():
    # 配置HTTPRequest以更好地处理重定向
    http_request.use_threads = true
    http_request.timeout = 30.0  # 30秒超时
    fetch_events_from_cloud()

var retry_count = 0

func fetch_events_from_cloud(url: String = SHEET_CSV_URL) -> void:
    # 异步底层 API 调用，绝对不阻塞主线程渲染！
    Logging.info("开始请求云端数据: %s (尝试 %d/%d)" % [url, retry_count + 1, MAX_RETRIES + 1])
    var err: int = http_request.request(url)
    if err != OK:
        Logging.err("网络请求发起失败！错误代码: %d, 大唐的信使死在路上了 💀" % err)
        return
    Logging.info("网络请求已发起，等待响应...")

# 必须连接 http_request 节点的 request_completed 信号到此函数
func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    Logging.info("收到HTTP响应，结果代码: %d, 状态码: %d" % [_result, response_code])
    
    # 特殊处理307重定向 - 这是正常的，Godot不会自动跟随重定向
    if response_code == 307:
        Logging.warn("检测到307重定向，这是Google Sheets的正常行为")
        # 从响应头中获取Location
        var redirect_url = ""
        for header in _headers:
            if header.to_lower().begins_with("location:"):
                redirect_url = header.substr(9).strip_edges()
                Logging.info("重定向到: %s" % redirect_url)
                break
        
        if not redirect_url.is_empty():
            if retry_count < MAX_RETRIES:
                retry_count += 1
                Logging.info("跟随重定向 (尝试 %d/%d)..." % [retry_count + 1, MAX_RETRIES + 1])
                fetch_events_from_cloud(redirect_url)
                return
            else:
                Logging.err("重定向次数过多，放弃请求")
        else:
            Logging.err("无法从响应头中找到Location信息")
        return
    
    # 检查结果代码
    if _result != HTTPRequest.RESULT_SUCCESS:
        Logging.err("请求失败，结果代码: %d (0=成功, 1=连接错误, 2=无响应, 3=超时, 4=SSL错误)" % _result)
        match _result:
            HTTPRequest.RESULT_CANT_CONNECT:
                Logging.err("无法连接到服务器 - 检查网络连接")
            HTTPRequest.RESULT_CANT_RESOLVE:
                Logging.err("无法解析域名 - 检查URL或DNS")
            HTTPRequest.RESULT_CONNECTION_ERROR:
                Logging.err("连接错误 - 服务器可能拒绝连接")
            HTTPRequest.RESULT_TIMEOUT:
                Logging.err("请求超时 - 网络太慢或服务器无响应")
            4: # RESULT_SSL_HANDSHAKE_ERROR in Godot 4.x
                Logging.err("SSL握手错误 - HTTPS证书问题")
        return
    
    if response_code != 200:
        Logging.err("云端太府寺拒绝访问，HTTP 状态码: %d 😨" % response_code)
        
        # 重试逻辑 - 简化为只重试原始URL
        if retry_count < MAX_RETRIES:
            retry_count += 1
            Logging.warn("第 %d 次重试原始URL..." % retry_count)
            fetch_events_from_cloud(SHEET_CSV_URL)
        else:
            Logging.err("已达到最大重试次数，放弃请求")
        return
        
    Logging.info("成功获取数据，大小: %d 字节" % body.size())
    
    # 重置重试计数器
    retry_count = 0
        
    # 核心 API：将下载的原始字节流直接反序列化为人类可读的 UTF-8 字符串
    var raw_csv_string: String = body.get_string_from_utf8()
    
    # 将包含几百行文本的 raw_csv_string 交给你之前写好的微语法解析器
    var csv_lines = raw_csv_string.split("\n")
    if csv_lines.size() < 2:
        Logging.err("CSV 数据不足，至少需要表头和一行数据")
        return
    
    # 解析表头
    var csv_headers = csv_lines[0].strip_edges().split(",")
    
    # 解析每一行数据
    var csv_data: Array[Dictionary] = []
    for i in range(1, csv_lines.size()):
        var line = csv_lines[i].strip_edges()
        if line.is_empty():
            continue
            
        var values = line.split(",")
        var row_data = {}
        
        for j in range(csv_headers.size()):
            if j < values.size():
                var key = csv_headers[j].strip_edges()
                var value = values[j].strip_edges()
                row_data[key] = value
        
        if not row_data.is_empty():
            csv_data.append(row_data)
    
    # 使用 DSL 解析器解析事件数据
    var events = DSLParser.parse_csv_data(csv_data)
    
    # 将解析成功的事件注入到 Global.random_events 中
    for event in events:
        Global.random_events[event.uuid] = event
        Logging.info("云端事件注入成功: %s" % event.uuid)
    
    Logging.info("云端数据注入完成！共注入 %d 个事件 🤓☝️" % events.size())
    
    print("云端数据注入成功！系统活过来了 🤓☝️")
