# ----------------------------------------------------------------
# EventBaseLoader 无菌测试舱
# ----------------------------------------------------------------
# 架构师留言：
# EventBaseLoader 是纯静态方法类（RefCounted），不依赖场景树。
# 测试分两层：
#   1. _extract_uuid 纯单元测试 —— 不碰文件系统，全内存 Mock
#   2. scan 集成测试 —— 运行时在 user:// 动态建临时 .tres fixtures
#
# ⚠️ 关键约定：每个 scan 测试使用 before_each 建立独立 fixtures，
#   避免 push_error 交叉污染（如冲突目录触发的错误不会泄漏到其他测试）。
# ----------------------------------------------------------------
extends GutTest

# ════════════════════════════════════════════════════════════════
# Mock 资源（仅用于 _extract_uuid 纯内存单元测试）
# ════════════════════════════════════════════════════════════════

class MockEvent extends Resource:
	@export var uuid: String = ""
	@export var id: String = ""

# ════════════════════════════════════════════════════════════════
# 常量
# ════════════════════════════════════════════════════════════════

const FIXTURE_DIR := "user://test_event_base"
const TEST_EVENT_RES := preload("res://tests/fixtures/test_event_resource.gd")

# ════════════════════════════════════════════════════════════════
# 生命周期 — 每个测试前重建干净的 fixture 根目录
# ════════════════════════════════════════════════════════════════

func before_each() -> void:
	# 先递归删除旧目录
	_remove_fixture_dir("")
	# 重建空的根目录
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)


func after_each() -> void:
	_remove_fixture_dir("")


# ════════════════════════════════════════════════════════════════
# 辅助方法
# ════════════════════════════════════════════════════════════════

static func _make_fixture_dir(relative: String) -> void:
	var target = FIXTURE_DIR + "/" + relative
	DirAccess.make_dir_recursive_absolute(target)


static func _make_fixture(relative: String, p_uuid: String) -> void:
	"""用 TestEventResource 创建 .tres/.tscn fixture（确保 uuid 可被反序列化）
	
	.tscn 文件手动写文本（用 [gd_resource 头而非 [gd_scene），
	使 load() 返回 Resource 而非 PackedScene，验证 .tscn 后缀也能被扫描加载。
	"""
	var path = FIXTURE_DIR + "/" + relative
	if relative.ends_with(".tscn"):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if not file:
			push_error("无法写入 fixture: " + path)
			return
		file.store_line("[gd_resource type=\"Resource\" load_steps=2 format=3]")
		file.store_line("")
		file.store_line("[ext_resource type=\"Script\" path=\"res://tests/fixtures/test_event_resource.gd\" id=\"1\"]")
		file.store_line("")
		file.store_line("[resource]")
		file.store_line("script = ExtResource(\"1\")")
		file.store_line("uuid = \"" + p_uuid + "\"")
		file.close()
	else:
		var res = TEST_EVENT_RES.new()
		res.uuid = p_uuid
		ResourceSaver.save(res, path)


static func _make_fixture_empty(relative: String) -> void:
	"""创建既没有 uuid 也没有 id 的普通 Resource"""
	var path = FIXTURE_DIR + "/" + relative
	var res = Resource.new()
	ResourceSaver.save(res, path)


static func _remove_fixture_dir(relative: String) -> void:
	var target = FIXTURE_DIR + "/" + relative
	var dir = DirAccess.open(target)
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f not in [".", ".."]:
				var full = target.path_join(f)
				if dir.current_is_dir():
					_remove_recursive(full)
				else:
					dir.remove(f)
			f = dir.get_next()
		dir.list_dir_end()


static func _remove_recursive(path: String) -> void:
	var d = DirAccess.open(path)
	if not d:
		return
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		if f not in [".", ".."]:
			var full = path.path_join(f)
			if d.current_is_dir():
				_remove_recursive(full)
			else:
				d.remove(f)
		f = d.get_next()
	d.list_dir_end()
	var parent = path.get_base_dir()
	var parent_dir = DirAccess.open(parent)
	if parent_dir:
		parent_dir.remove(path.get_file())


# ════════════════════════════════════════════════════════════════
# 第一部分：_extract_uuid 纯单元测试
# ════════════════════════════════════════════════════════════════

func test_extract_uuid_with_uuid_field() -> void:
	var res = MockEvent.new()
	res.uuid = "evt_001"
	res.id = "evt_id"
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "evt_001", "uuid 字段有效时应返回 uuid")


func test_extract_uuid_with_id_field() -> void:
	var res = MockEvent.new()
	res.id = "evt_002"
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "evt_002", "仅有 id 字段时应返回 id")


func test_extract_uuid_uuid_over_id() -> void:
	"""uuid 和 id 同时存在时，uuid 优先"""
	var res = MockEvent.new()
	res.uuid = "uuid_priority"
	res.id = "id_fallback"
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "uuid_priority", "uuid 应优先于 id")


func test_extract_uuid_neither() -> void:
	"""既无 uuid 也无 id 属性 → 返回空字符串"""
	var res = Resource.new()
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "", "无 uuid/id 时应返回空串")


func test_extract_uuid_empty_uuid_valid_id() -> void:
	"""uuid 为空字符串、id 有效时应返回 id"""
	var res = MockEvent.new()
	res.uuid = ""
	res.id = "fallback_id"
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "fallback_id", "uuid 空串时降级到 id")


func test_extract_uuid_empty_id_valid_uuid() -> void:
	"""id 为空、uuid 有效时应返回 uuid"""
	var res = MockEvent.new()
	res.uuid = "valid_uuid"
	res.id = ""
	var got = EventBaseLoader._extract_uuid(res)
	assert_eq(got, "valid_uuid", "id 空串时仍返回 uuid")


# ════════════════════════════════════════════════════════════════
# 第二部分：scan 集成测试
# ════════════════════════════════════════════════════════════════
# 每个测试在 before_each 清理后构建自己的 fixture 集，保证隔离。
# 冲突测试（duplicate, base_internal）会故意触发 push_error，
# 这些 push_error 仅在该测试内出现，不影响其他测试。
# ════════════════════════════════════════════════════════════════

func test_scan_empty_directory() -> void:
	"""空目录应返回零结果"""
	# before_each 已经保证 FIXTURE_DIR 是空目录
	var result = EventBaseLoader.scan(FIXTURE_DIR)
	assert_eq(result.pool.size(), 0, "空目录 pool 应为 0")
	assert_eq(result.bases.size(), 0, "空目录 bases 应为 0")
	assert_eq(result.duplicates.size(), 0, "空目录 duplicates 应为 0")
	assert_eq(result.scanned_file_count, 0, "空目录扫描计数应为 0")


func test_scan_root_level_file() -> void:
	"""根级 .tres 文件：pool 应有条目，bases 应为空（无顶层 base）"""
	_make_fixture("root.tres", "root_evt")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	assert_true(result.pool.has("root_evt"), "pool 应包含根级 uuid")

	# 根级文件的 top_level_base 为 ""，所以 bases 不应该包含该资源
	var any_base_contains_root := false
	for base_name in result.bases:
		if result.bases[base_name].has("root_evt"):
			any_base_contains_root = true
			break
	assert_false(any_base_contains_root, "根级文件不应出现在任何 base 分表中")


func test_scan_subdirectory_file() -> void:
	"""一级子目录文件：pool 含 'base.uuid'，bases 含对应条目"""
	_make_fixture_dir("actions")
	_make_fixture("actions/fight.tres", "fight_01")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	var full_id = "actions.fight_01"
	assert_true(result.pool.has(full_id), "pool 应包含 'actions.fight_01'")

	assert_true(result.bases.has("actions"), "bases 应包含 'actions' 分表")
	assert_true(result.bases["actions"].has("fight_01"), "actions 分表应包含 fight_01")


func test_scan_nested_subdirectory() -> void:
	"""二级嵌套：pool 含完整命名空间路径，bases 保留顶层 base"""
	_make_fixture_dir("actions")
	_make_fixture_dir("actions/explore")
	_make_fixture("actions/explore/cave.tres", "cave_01")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	var full_id = "actions.explore.cave_01"
	assert_true(result.pool.has(full_id), "pool 应包含 'actions.explore.cave_01'")
	assert_true(result.bases["actions"].has("cave_01"), "bases['actions'] 应包含 deep 资源")
	assert_eq(result.bases["actions"]["cave_01"], result.pool[full_id],
		"bases 和 pool 中同一资源的引用应一致")


func test_scan_tscn_file_as_resource() -> void:
	""".tscn 后缀文件应像 .tres 一样被加载（只要 load() 能识别）"""
	_make_fixture_dir("story")
	_make_fixture("story/prologue.tscn", "prologue_02")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	var full_id = "story.prologue_02"
	assert_true(result.pool.has(full_id),
		".tscn 文件应被加载并加入 pool")
	assert_true(result.bases["story"].has("prologue_02"),
		".tscn 文件应出现在 bases 分表中")


func test_scan_skip_no_uuid() -> void:
	"""无 uuid 的资源应被跳过，不影响 pool/bases"""
	_make_fixture_dir("actions")
	_make_fixture("actions/fight.tres", "fight_01")
	_make_fixture_empty("actions/no_uuid.tres")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	# 只有 fight_01 应存在
	assert_true(result.pool.has("actions.fight_01"), "有 uuid 的资源应被加载")
	assert_eq(result.pool.size(), 1, "无 uuid 的资源不应计入 pool")
	# scanned_file_count 应统计所有文件（包括被跳过的）
	assert_eq(result.scanned_file_count, 2, "应扫描到 2 个文件（含被跳过的）")


func test_scan_duplicate_detection() -> void:
	"""全局 ID 冲突 → duplicates 非空，第二个文件被拒绝"""
	_make_fixture_dir("duplicates")
	_make_fixture("duplicates/first.tres", "dup_evt")
	_make_fixture("duplicates/second.tres", "dup_evt")

	var result = EventBaseLoader.scan(FIXTURE_DIR + "/duplicates")

	# 预期的 push_error（第二个文件触发 ID 冲突）
	assert_push_error(1, "ID 冲突")

	assert_gt(result.duplicates.size(), 0,
		"存在冲突时应检测到 duplicates")
	assert_true(result.duplicates.has("dup_evt"),
		"duplicates 列表应包含冲突 ID 'dup_evt'")

	# 第一个文件仍存在于 pool 中
	assert_true(result.pool.has("dup_evt"),
		"首个冲突文件仍应在 pool 中")

	# pool 中只有一条 "dup_evt"（未被第二条覆盖）
	assert_eq(result.pool["dup_evt"].get("uuid"),
		"dup_evt", "pool 中的 uuid 应与第一个文件一致")


func test_scan_base_internal_conflict() -> void:
	"""同一 base 内 uuid 冲突（不同 full_id）应触发 push_error 但不阻断加载"""
	# 当扫描根目录时，base_conflict/ 下的 area_a/ 和 area_b/ 共享 top_level_base = "base_conflict"
	# 因此能够触发 base 内 uuid 冲突检测
	_make_fixture_dir("base_conflict/area_a")
	_make_fixture_dir("base_conflict/area_b")
	_make_fixture("base_conflict/area_a/a.tres", "base_same_uuid")
	_make_fixture("base_conflict/area_b/b.tres", "base_same_uuid")

	# 扫描 FIXTURE_DIR 根目录，使 area_a/area_b 的 top_level_base = "base_conflict"
	var result = EventBaseLoader.scan(FIXTURE_DIR)

	# 两个文件 full_id 不同（base_conflict.area_a.base_same_uuid vs base_conflict.area_b.base_same_uuid），
	# 不会触发全局冲突；但同属 base "base_conflict"，uuid 都是 "base_same_uuid"，
	# 会触发 base 内冲突检测（line 115-117）
	assert_push_error(1, "uuid 冲突")

	assert_true(result.bases.has("base_conflict"),
		"存在冲突的 base 分表仍应存在")
	assert_true(result.bases["base_conflict"].has("base_same_uuid"),
		"base 冲突资源仍应出现在 bases 分表中")
	assert_true(result.pool.has("base_conflict.area_a.base_same_uuid"),
		"pool 应有 base_conflict.area_a 的记录")
	assert_true(result.pool.has("base_conflict.area_b.base_same_uuid"),
		"pool 应有 base_conflict.area_b 的记录")
	assert_eq(result.scanned_file_count, 2, "应扫描到 2 个文件")


func test_scan_custom_delimiter() -> void:
	"""自定义分隔符应改变 full_id 的命名空间拼接方式"""
	_make_fixture_dir("actions")
	_make_fixture("actions/village.tres", "village_01")

	var result = EventBaseLoader.scan(FIXTURE_DIR, "/")

	var full_id_with_slash = "actions/village_01"
	assert_true(result.pool.has(full_id_with_slash),
		"使用 '/' 分隔符时 full_id 应为 'actions/village_01'")


func test_scan_file_count_mixed() -> void:
	"""scanned_file_count 应等于所有 .tres + .tscn 文件的总数（含被跳过的）"""
	_make_fixture("root.tres", "root_evt")
	_make_fixture_dir("actions")
	_make_fixture("actions/fight.tres", "fight_01")
	_make_fixture("actions/village.tres", "village_01")
	_make_fixture_dir("story")
	_make_fixture("story/prologue.tres", "prologue_01")
	_make_fixture("story/prologue.tscn", "prologue_02")
	_make_fixture_empty("actions/no_uuid.tres")

	var result = EventBaseLoader.scan(FIXTURE_DIR)
	assert_eq(result.scanned_file_count, 6,
		"应扫描到 6 个资源文件（含 .tscn 和无 uuid 的）")


func test_scan_bases_cover_pool() -> void:
	"""bases 中所有资源的 uuid 总数 + 根级资源数应等于 pool 大小"""
	_make_fixture("root.tres", "root_evt")
	_make_fixture_dir("actions")
	_make_fixture("actions/fight.tres", "fight_01")
	_make_fixture_dir("story")
	_make_fixture("story/prologue.tres", "prologue_01")

	var result = EventBaseLoader.scan(FIXTURE_DIR)

	# 根级资源总数
	var root_count := 0
	if result.pool.has("root_evt"):
		root_count = 1

	var bases_total := 0
	for base_name in result.bases:
		bases_total += result.bases[base_name].size()

	assert_eq(bases_total + root_count, result.pool.size(),
		"bases 资源总数 + 根级资源数应等于 pool 大小")


func test_scan_pool_has_all_expected_keys() -> void:
	"""验证所有预期的 full_id 是否存在（集成烟雾测试）"""
	_make_fixture("root.tres", "root_evt")
	_make_fixture_dir("actions")
	_make_fixture("actions/fight.tres", "fight_01")
	_make_fixture("actions/village.tres", "village_01")
	_make_fixture_dir("actions/explore")
	_make_fixture("actions/explore/cave.tres", "cave_01")
	_make_fixture_dir("story")
	_make_fixture("story/prologue.tres", "prologue_01")
	_make_fixture("story/prologue.tscn", "prologue_02")

	var result = EventBaseLoader.scan(FIXTURE_DIR)

	var expected_keys := [
		"root_evt",                                   # 根级文件
		"actions.fight_01",                            # 一级子目录
		"actions.village_01",
		"actions.explore.cave_01",                     # 二级嵌套
		"story.prologue_01",                           # 一级子目录
		"story.prologue_02",                           # .tscn 文件
	]
	for key in expected_keys:
		assert_true(result.pool.has(key),
			"pool 应包含 '%s'" % [key])
