#!/usr/bin/env python3
"""
正交事件生成管线 — 向后兼容入口点。

此文件是重构后的兼容性 shim，实际逻辑已迁移至 tools/event_generator/ 模块包。
直接运行此文件或 python3 -m tools.event_generator.main 效果相同。

用法:
  export DEEPSEEK_API_KEY="sk-xxx"
  .venv/bin/python tools/generate_orthogonal_events.py --config <json_or_py>
  .venv/bin/python tools/generate_orthogonal_events.py --dry-run
  .venv/bin/python tools/generate_orthogonal_events.py --trial
  
使用示例
  .venv/bin/python tools/generate_orthogonal_events.py --config tools/event_base_config_duotai_humiliation.json --trial
"""

import sys
from pathlib import Path

# ── 自动将项目根目录加入 sys.path ──
_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

# 委托至新模块入口
from tools.event_generator.main import main  # noqa: E402

if __name__ == "__main__":
    main()
