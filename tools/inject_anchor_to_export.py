#!/usr/bin/env python3
"""将 _export_dependency_anchor.tscn 注入 export_presets.cfg 的 export_files 首位。

必须在 Godot 编辑器完全关闭后运行，否则修改会被编辑器覆盖。
"""

import re
import sys

PRESETS_PATH = "export_presets.cfg"
ANCHOR_PATH = "res://core/_export_dependency_anchor.tscn"


def inject():
    with open(PRESETS_PATH, "r") as f:
        content = f.read()

    # 匹配 export_files=PackedStringArray(...) 行
    pattern = r'(export_files=PackedStringArray\()'
    replacement = f'\\1"{ANCHOR_PATH}", '

    new_content = re.sub(pattern, replacement, content)

    if new_content == content:
        print("❌ 未找到 export_files=PackedStringArray( 行，或锚点已存在")
        sys.exit(1)

    with open(PRESETS_PATH, "w") as f:
        f.write(new_content)

    print(f"✅ 已将 {ANCHOR_PATH} 注入 export_files 首位")
    print("⚠️  现在可以重新打开 Godot 编辑器并导出")


def verify():
    with open(PRESETS_PATH, "r") as f:
        content = f.read()
    if ANCHOR_PATH in content:
        print(f"✅ 锚点场景 {ANCHOR_PATH} 存在于 export_presets.cfg")
    else:
        print(f"❌ 锚点场景 {ANCHOR_PATH} 不存在于 export_presets.cfg")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "verify":
        verify()
    else:
        inject()
