#!/usr/bin/env python3
"""
toggle_export_fix.py — 切换 Logging 和 ENUMS 的 autoload 状态

HTML5 导出要求 Logging 和 ENUMS 作为 autoload 才能注册 class_name。
日常编辑器开发中保留 autoload 也无影响（--script 模式不加载 autoload）。
脚本中的静态方法在任何场景下都可正常调用。

用法:
  python tools/toggle_export_fix.py add      # 添加 Logging + ENUMS 到 [autoload]
  python tools/toggle_export_fix.py remove   # 从 [autoload] 移除 Logging + ENUMS
  python tools/toggle_export_fix.py status   # 查看当前状态
"""

import sys
from pathlib import Path

PROJECT_FILE = Path(__file__).resolve().parent.parent / "project.godot"

AUTOLOAD_ENTRIES = [
    'Logging="*res://core/logging.gd"',
    'ENUMS="*res://model/enumerates.gd"',
]


def read_project() -> str:
    return PROJECT_FILE.read_text(encoding="utf-8")


def write_project(content: str) -> None:
    PROJECT_FILE.write_text(content, encoding="utf-8")


def get_autoload_status(content: str) -> dict:
    """返回 { 'Logging': True/False, 'ENUMS': True/False }"""
    in_autoload = False
    result = {"Logging": False, "ENUMS": False}
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1].strip().lower()
            in_autoload = section == "autoload"
            continue
        if in_autoload:
            if stripped.startswith("Logging="):
                result["Logging"] = True
            elif stripped.startswith("ENUMS="):
                result["ENUMS"] = True
    return result


def add_entries(content: str) -> str:
    """在 [autoload] 下 GameConfig 行后插入 Logging + ENUMS。"""
    lines = content.splitlines(keepends=True)
    result = []
    in_autoload = False
    inserted = set()

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_autoload = stripped[1:-1].strip().lower() == "autoload"
            result.append(line)
            continue

        result.append(line)

        if in_autoload and stripped.startswith("GameConfig=") and "Logging" not in inserted:
            indent = line[:len(line) - len(line.lstrip())] if line.strip() else "\t"
            for entry in AUTOLOAD_ENTRIES:
                result.append(f"{indent}{entry}\n")
            inserted.add("Logging")

    return "".join(result)


def remove_entries(content: str) -> str:
    """从 [autoload] 中移除 Logging + ENUMS 行。"""
    lines = content.splitlines(keepends=True)
    result = []
    in_autoload = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_autoload = stripped[1:-1].strip().lower() == "autoload"
            result.append(line)
            continue
        if in_autoload and (stripped.startswith("Logging=") or stripped.startswith("ENUMS=")):
            continue
        result.append(line)

    return "".join(result)


def cmd_add():
    content = read_project()
    status = get_autoload_status(content)
    if status["Logging"] and status["ENUMS"]:
        print("✓ Logging + ENUMS 已经是 autoload，无需操作。")
        return

    # 先移除已有再添加（避免重复）
    content = remove_entries(content)
    content = add_entries(content)
    write_project(content)
    print("✓ Logging + ENUMS 已加入 project.godot [autoload]。")


def cmd_remove():
    content = read_project()
    status = get_autoload_status(content)
    if not status["Logging"] and not status["ENUMS"]:
        print("✓ Logging + ENUMS 不在 [autoload] 中，无需操作。")
        return
    new_content = remove_entries(content)
    write_project(new_content)
    print("✓ Logging + ENUMS 已从 project.godot [autoload] 移除。")


def cmd_status():
    content = read_project()
    status = get_autoload_status(content)
    if status["Logging"]:
        print("📗 Logging: autoload ✓")
    else:
        print("📕 Logging: 不是 autoload")
    if status["ENUMS"]:
        print("📗 ENUMS:   autoload ✓")
    else:
        print("📕 ENUMS:   不是 autoload")


def main():
    if len(sys.argv) < 2:
        print("用法: python tools/toggle_export_fix.py <add|remove|status>")
        sys.exit(1)

    cmd = sys.argv[1].strip().lower()
    if cmd == "add":
        cmd_add()
    elif cmd == "remove":
        cmd_remove()
    elif cmd == "status":
        cmd_status()
    else:
        print(f"未知命令: {cmd}")
        print("用法: python tools/toggle_export_fix.py <add|remove|status>")
        sys.exit(1)


if __name__ == "__main__":
    main()
