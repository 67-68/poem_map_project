# ----------------------------------------------------------------
# 测试用 Resource 类型 — 供 EventBaseLoader 集成测试生成 .tres fixtures
# ----------------------------------------------------------------
# 必须使用 class_name 全局注册，否则 ResourceSaver.save / load
# 无法正确序列化/反序列化 uuid/id 字段。
# ----------------------------------------------------------------
extends Resource
class_name TestEventResource
@export var uuid: String = ""
@export var id: String = ""
