"""
Plugin 包 — 事件 Prompt 插件

在此包中放置 EventPromptPlugin 子类。
每个插件文件应调用 register_plugin() 在 import 时自动注册。

包 __init__.py 会自动发现并 import 所有插件模块，
确保 PLUGIN_REGISTRY 在 generate_orthogonal_events.py 启动前已填充。
"""

import importlib
import pkgutil
import sys

# ── 自动发现并导入所有插件模块 ──
# 遍历 tools.plugins 包下的所有 .py 文件（排除 __init__），
# import 它们以触发 register_plugin() 调用。
_package_name = __name__
for _importer, _module_name, _is_pkg in pkgutil.iter_modules(__path__):
    if _is_pkg or _module_name == "__init__":
        continue
    _full_path = f"{_package_name}.{_module_name}"
    if _full_path not in sys.modules:
        importlib.import_module(_full_path)
