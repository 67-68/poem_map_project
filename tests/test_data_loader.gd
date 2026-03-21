# ----------------------------------------------------------------
# 大唐地理系统 - DataLoader 核心逻辑无菌测试舱
# ----------------------------------------------------------------
# 架构师留言：
# 如果这些测试挂了，说明你的底层数据管道漏水了。
# 绝不允许带着 failing tests 提交代码！😡
# ----------------------------------------------------------------
extends GutTest

# --- [测试用数据模型模拟] ---
# 别污染真实的业务类，我们用 Mock 来测试反射拦截
class MockEntity extends Resource:
	@export var id: String
	@export var name: String
	@export var uv_position: Vector2
	@export var properties: Dictionary = {}
	
	# 模拟你的 GameEntity 构造函数，吃进字典并赋值
	func _init(data: Dictionary = {}):
		for key in data.keys():
			if key in self:
				self.set(key, data[key])
			elif key == "properties":
				self.properties = data[key]

# --- [沙盒生命周期管理] ---
const TEST_DIR = "user://test_sandbox/"
const TEST_JSON = "user://test_sandbox/test_poet.json"
const TEST_CSV = "user://test_sandbox/test_map.csv"

func before_all():
	# 建立无菌室
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_absolute(TEST_DIR)

func after_all():
	# 焚烧无菌室，不留一丝痕迹 💀
	if FileAccess.file_exists(TEST_JSON): DirAccess.remove_absolute(TEST_JSON)
	if FileAccess.file_exists(TEST_CSV): DirAccess.remove_absolute(TEST_CSV)
	DirAccess.remove_absolute(TEST_DIR)

# --- [核心测试用例：JSON 篇] ---

func test_json_loads_and_intercepts_ghost_fields():
	# 1. 制造带毒的数据 (故意写错 name -> peot_name)
	var dirty_json = [
		{"id": "001", "name": "李白", "valid_prop": "酒仙"},
		{"id": "002", "peot_name": "杜甫", "ghost_field": "💀"} 
	]
	var file = FileAccess.open(TEST_JSON, FileAccess.WRITE)
	file.store_string(JSON.stringify(dirty_json))
	file.close()
	
	# 2. 跑毒
	var results = DataLoader.load_json_model(MockEntity, TEST_JSON)
	
	# 3. 验尸
	assert_eq(results.size(), 2, "应该成功加载两条数据")
	assert_eq(results[0].name, "李白", "李白的数据应该完好无损")
	assert_eq(results[1].name, "", "杜甫的 name 字段被写错了，这里应该是默认空值")
	# 注意：GUT 没法直接 assert 控制台的 warning，但你运行时绝对会看到黄字满天飞 🤣

# --- [核心测试用例：CSV 篇] ---

func test_csv_coordinate_aggregation_and_routing():
	# 1. 制造复杂 CSV（包含：空行、正常字段、扩展属性 prop/、幽灵字段、坐标 uv_x/uv_y）
	var csv_content = """id,name,uv_x,uv_y,prop/mood,what_is_this
001,长安,100.5,200.5,繁华,幽灵数据1
# 这一行是注释，应该被踢掉
002,洛阳,300.0,400.0,衰败,幽灵数据2
"""
	var file = FileAccess.open(TEST_CSV, FileAccess.WRITE)
	file.store_string(csv_content)
	file.close()
	
	# 2. 跑毒
	breakpoint
	var results = DataLoader.load_csv_model(MockEntity, TEST_CSV)
	
	# 3. 验尸
	assert_eq(results.size(), 2, "注释行必须被干掉，只能有两条有效数据")
	
	var changan = results[0]
	assert_eq(changan.id, "001", "基础路由：ID解析失败")
	assert_eq(changan.name, "长安", "基础路由：Name解析失败")
	
	# 测试极其重要的坐标聚合逻辑 🤓☝️
	assert_eq(changan.uv_position, Vector2(100.5, 200.5), "坐标聚合失败！如果这里挂了，Shader 会把州府画到虚空里去 😨")
	
	# 测试 prop/ 扩展属性路由
	assert_true(changan.properties.has("mood"), "扩展属性路由失败：prop/mood 没有被正确剥离前缀塞进 properties")
	assert_eq(changan.properties["mood"], "繁华", "扩展属性值不匹配")
	
	# 测试幽灵字段的宽容度（兜底策略）
	assert_true(changan.properties.has("what_is_this"), "宽容度测试失败：幽灵字段必须作为兜底塞进 properties 里，防止强类型崩溃")
