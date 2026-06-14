# ----------------------------------------------------------------
# CSV 云同步 - CLI 入口脚本
# ----------------------------------------------------------------
# 这个脚本是 csv_cloud_loader.gd 的 CLI 入口包装器。
# 它继承 SceneTree 以支持 godot --headless -s 调用，
# 解析命令行参数后实例化 CsvCloudLoader 并触发同步队列。
#
# 使用方式:
#   godot --headless -s core/csv_cloud_sync_cli.gd -- --sync
#   godot --headless -s core/csv_cloud_sync_cli.gd -- --sync --prefer-local
#
# MCP 调用 (godot_mcp.py):
#   run_godot_script("core/csv_cloud_sync_cli.gd", ["--sync", "--prefer-local"])
# ----------------------------------------------------------------
@tool
extends SceneTree

# 等待主循环就绪的最大迭代次数（防止死循环）
const MAX_INIT_WAIT_ITER: int = 20

# 获取重复字符分隔线（Godot 4 GDScript 不支持字符串乘法）
func _get_sep(char: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += char
	return result

func _init() -> void:
	# 🤓☝️ 使用 OS.get_cmdline_user_args() 获取 -- 分隔符之后的用户参数
	# OS.get_cmdline_args() 只返回 Godot 引擎的参数，不包含用户参数
	var args = OS.get_cmdline_user_args()
	
	var should_sync = "--sync" in args
	var prefer_local = "--prefer-local" in args
	
	if not should_sync:
		# 如果没有 --sync 参数，直接退出（可能是误调用）
		Logging.info("WARNING: csv_cloud_sync_cli.gd 被调用但没有 --sync 参数，直接退出")
		Logging.info("用法: godot --headless -s core/csv_cloud_sync_cli.gd -- --sync [--prefer-local]")
		quit(0)
		return
	
	var sep = _get_sep("=", 60)
	Logging.info("\n" + sep)
	Logging.info("  CSV 云同步 CLI 入口")
	Logging.info("  prefer_local: %s" % prefer_local)
	Logging.info(sep + "\n")
	
	# 等待 Engine.get_main_loop() 就绪（参考 gut_cmdln.gd 的模式）
	var iter := 0
	while Engine.get_main_loop() == null and iter < MAX_INIT_WAIT_ITER:
		await create_timer(0.01).timeout
		iter += 1
	
	if Engine.get_main_loop() == null:
		Logging.err("主循环未就绪，无法启动同步")
		quit(1)
		return
	
	# 加载并实例化 CSV 云同步加载器
	var loader_script = load("res://core/csv_cloud_loader.gd")
	if loader_script == null:
		Logging.err("无法加载 csv_cloud_loader.gd")
		quit(1)
		return
	
	var loader = loader_script.new()
	loader.prefer_local_files = prefer_local
	
	# 添加到场景树使其能正常初始化
	get_root().add_child(loader)
	
	# 启动同步队列
	loader.start_sync_queue()
	
	# 等待一帧让同步队列开始执行
	await create_timer(0.1).timeout
	
	# 保持脚本运行直到同步完成
	# 每一轮同步大约需要 1-2 秒，给一个足够的缓冲
	await create_timer(30.0).timeout
	
	Logging.info("\n" + sep)
	Logging.info("  CLI 同步入口执行完毕")
	Logging.info(sep + "\n")
	
	quit(0)
