# ====================================================================
# 总控制中心：只管方向，绝不手写底层脏活！
# ====================================================================
@tool
extends Node

@export_group("Continuous Integration Pipeline")
@export var sync_all_data: bool = false:
	set(val):
		sync_all_data = false 
		if val == true:
			notify_property_list_changed()
			_start_decoupled_pipeline()

const DATA_MANIFEST: Array[Dictionary] = [
	{
		"name": "test_随机事件池",
		"url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vRaiGJGCA7xT0b1Ch_GB_i7lMzBHD77JwzEThqqzXrLn7cIvUPc5dsfwM4LINfR7PmEYv3x34fou_Ji/pub?output=csv",
		"save_path": "res://data/random_events/random_events.csv",
		"data_type": "random_event"
	},
	{
		"name": "flags_data",
		"url": "https://docs.google.com/spreadsheets/d/e/2PACX-1vT2EfTq6BZ59bQ7lIRBd2q-hoJb1RAJHc2vOwlp5wJ03R7fG23SuvoWOKRcbSsPuPwbp_rs7m1Tk081/pub?output=csv",
		"save_path": "res://data/flags/flags.csv",
		"data_type": "flags"
	}
]

var _current_job_idx: int = -1
const MAX_RETRIES = 3
var _retry_count: int = 0


func _start_decoupled_pipeline() -> void:
	if DATA_MANIFEST.is_empty():
		push_error("[CI] 清单为空，你想同步寂寞吗？😡")
		return
		
	print("\n🚀 ===== 启动解耦版大唐 CI 数据管线 =====")
	_current_job_idx = 0
	_retry_count = 0
	_execute_current_job()


func _execute_current_job() -> void:
	if _current_job_idx >= DATA_MANIFEST.size():
		_run_downstream_validation_phases()
		return
		
	var job = DATA_MANIFEST[_current_job_idx]
	var job_name = job.get("name", "Unknown")
	var job_url = job.get("url", "")
	var job_save_path = job.get("save_path", "")
	var job_data_type = job.get("data_type", "random_event")
	
	if job_url.is_empty():
		push_error("[PIPELINE] 任务 %s 的 URL 为空，跳过 💀" % job_name)
		_advance_pipeline()
		return
	
	print("[PIPELINE] 正在处理核心资产 [%d/%d]: %s (数据类型: %s)" % [_current_job_idx + 1, DATA_MANIFEST.size(), job_name, job_data_type])
	
	# 🤓☝️ 保留同步 curl 实现（务实选择：避免异步复杂性）
	var output = []
	var exit_code = OS.execute("curl", ["-s", "-L", job_url], output)
	
	if exit_code != 0:
		push_error("[FETCH ERROR] 网络请求失败，错误代码: %d, 大唐的信使死在路上了 💀" % exit_code)
		_handle_fetch_failure(job)
		return
	
	var raw_csv_string: String = output[0] if output.size() > 0 else ""
	
	if raw_csv_string.is_empty():
		push_error("[FETCH ERROR] 网络请求返回空数据 😭")
		_handle_fetch_failure(job)
		return
	
	print("[PIPELINE] 成功获取数据，大小: %d 字节" % raw_csv_string.length())
	_retry_count = 0
	
	# 处理获取到的数据
	_process_job_data(raw_csv_string, job)


func _handle_fetch_failure(job: Dictionary) -> void:
	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		print("[PIPELINE] Warning: 第 %d 次重试..." % _retry_count)
		_execute_current_job()
	else:
		print("[PIPELINE] Error: 重试次数耗尽，跳过当前任务 😭")
		_advance_pipeline()


func _process_job_data(raw_csv_string: String, job: Dictionary) -> void:
	# 🤓☝️ 优雅重构 2：职责分离，把脏文本丢给刚刚抽离出来的纯清洗芯片
	var csv_data = CryptoCSVParser.parse_string_to_matrix(raw_csv_string)
	if csv_data.is_empty():
		push_error("[CSV ERROR] 表头或数据格式断裂，拒绝污染下游存储！")
		_advance_pipeline()
		return
	
	# 备份原始 CSV
	_save_raw_csv(raw_csv_string, job.save_path)
	
	# 🤓☝️ 优雅重构 3：调用 DSL 翻译官与资源序列化器
	var resources = DSLParser.parse_csv_data(csv_data, job.data_type)
	
	if resources.is_empty():
		print("[PIPELINE] Warning: DSLParser 返回空资源数组，跳过保存")
		_advance_pipeline()
		return
	
	print("[PIPELINE] 资源数组转换完成，大小: %d" % resources.size())
	for i in range(min(resources.size(), 3)):
		var res = resources[i]
		print("[PIPELINE] 资源[%d]: 类名=%s, resource_path=%s" % [i, res.get_class(), res.resource_path])
	
	# 调试：检查资源类型
	for resource in resources:
		if resource is RandomEvent:
			print("[PIPELINE] 云端事件注入成功: %s" % resource.uuid)
		elif resource is Flag:
			print("[PIPELINE] 云端标志位注入成功: %s" % resource.uuid)
		else:
			print("[PIPELINE] 云端资源注入成功: %s" % resource.resource_path)
	
	# 🤓☝️ 优雅重构 4：调用资源导出芯片
	var tres_dir = job.save_path.get_base_dir() + "/"
	ResourceAssetExporter.export_to_tres_folder(resources, tres_dir)
	
	print("[PIPELINE] 云端数据注入成功！系统活过来了 🤓☝️")
	_advance_pipeline()


func _save_raw_csv(csv_content: String, save_path: String) -> void:
	if save_path.is_empty():
		return
	
	var dir_path = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
		print("[PIPELINE] 创建目录: %s" % dir_path)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(csv_content)
		file.close()
		print("[PIPELINE] 原始CSV文件已保存到: %s" % save_path)
	else:
		push_error("[PIPELINE] 无法保存CSV文件到: %s 💀" % save_path)


func _advance_pipeline() -> void:
	_current_job_idx += 1
	_retry_count = 0
	_execute_current_job()


# 🤓☝️ 优雅重构 5：集中式下游阶段调度，告别面条式的串联嵌套
func _run_downstream_validation_phases() -> void:
	print("\n📦 ===== 资产下载完毕，开始下游固化与御史台会审 =====")
	_current_job_idx = -1
	
	# 1. 刷新 Registry 注册表
	_try_execute_sub_tool("res://resources_registry_creator.gd", "create_all_registries")
	
	# 2. 强行拉起事件 Linter 会审
	_try_execute_sub_tool("res://core/event_data_linter.gd", "execute_linter")
	
	print("🏁 ===== 大唐 CI 流水线全线走通！杜甫活过来了 🤓☝️ =====\n")


# 辅助防御性工具方法：安全的动态调用
func _try_execute_sub_tool(script_path: String, method_name: String) -> void:
	var script = load(script_path)
	if not script:
		push_error("[DEPS ERROR] 找不到组件: %s 💀" % script_path)
		return
	
	var instance = script.new()
	if instance.has_method(method_name):
		print("[PIPELINE] 执行工具: %s::%s()" % [script_path, method_name])
		instance.call(method_name)
	else:
		push_error("[DEPS ERROR] 组件缺少方法: %s::%s() 💀" % [script_path, method_name])
