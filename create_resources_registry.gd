@tool
extends EditorScript

# 脚本：为每个数据类型创建单独的resources registry
# 使用core/model/resources.gd作为资源模板，UUID作为key
# 这个脚本现在作为EditorScript的入口，调用独立的registry创建逻辑

const REGISTRY_CREATOR_PATH = "res://resources_registry_creator.gd"

# 配置选项
var overwrite_existing = true  # 是否覆盖已存在的registry文件
var skip_files_without_uuid = true  # 是否跳过没有uuid或id字段的文件

func _run():
	# 加载独立的registry创建逻辑
	var registry_creator_script = load(REGISTRY_CREATOR_PATH)
	if not registry_creator_script:
		print("错误：无法加载resources_registry_creator.gd")
		return
	
	# 创建实例并配置
	var registry_creator = registry_creator_script.new()
	registry_creator.overwrite_existing = overwrite_existing
	registry_creator.skip_files_without_uuid = skip_files_without_uuid
	
	# 执行registry创建
	registry_creator.create_all_registries()
