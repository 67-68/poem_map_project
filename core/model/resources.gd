class_name ResourceRegistry extends Resource

# 🚨 废弃 (DEPRECATED) — 2026-06-13
# Registry 系统已全局切除，不再使用。
# 保留此类仅作引用兼容（防止已序列化的 .tres 文件反序列化失败）。
# 新代码不应再实例化此类。

# 你的指针仓库，全关在这里面
@export var resources: Dictionary = {}

# 还可以顺便塞点全局配置
@export var registry_version: String = "1.0.0"