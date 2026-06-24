#!/usr/bin/env python3
"""
inject_preloads.py — 扫描所有 autoload 文件，为引用的非 autoload class_name 自动插入 preload。

HTML5 导出中，只有显式 autoload 的 class_name 才对其他编译单元可见。
对于 autoload A 引用但未作为 autoload 的 class_name B，需在 A 顶部插入:
    const _B = preload("res://path/to/b.gd")

用法:
  python tools/inject_preloads.py          # 干跑，只显示将要插入的内容
  python tools/inject_preloads.py --apply  # 实际修改文件
"""

import sys
import re
import os
from pathlib import Path
from collections import defaultdict

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROJECT_FILE = PROJECT_ROOT / "project.godot"


def parse_autoloads(content: str) -> list[tuple[str, str]]:
    """解析 project.godot 的 [autoload] 段，返回 [(name, path), ...]"""
    in_autoload = False
    result = []
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_autoload = stripped[1:-1].strip().lower() == "autoload"
            continue
        if in_autoload and "=" in stripped:
            # Name="*res://path"
            name, _, path = stripped.partition("=")
            name = name.strip()
            path = path.strip().strip('"').lstrip("*").removeprefix("res://")
            result.append((name, path))
    return result


def build_class_name_map() -> dict[str, str]:
    """扫描所有 .gd 文件，构建 class_name → 相对路径 的映射"""
    mapping = {}
    for gd_file in PROJECT_ROOT.rglob("*.gd"):
        if ".godot" in str(gd_file) or "__pycache__" in str(gd_file):
            continue
        try:
            text = gd_file.read_text(encoding="utf-8")
        except Exception:
            continue
        m = re.search(r'^class_name\s+(\w+)', text, re.MULTILINE)
        if m:
            rel_path = str(gd_file.relative_to(PROJECT_ROOT))
            mapping[m.group(1)] = rel_path
    return mapping


def find_class_refs(file_content: str, class_map: dict, autoload_names: set, own_class: str | None) -> set[str]:
    """在文件内容中查找所有引用的 class_name（非 autoload、非自身的）"""
    # 提取所有看起来像 class_name 的标识符
    words = set(re.findall(r'\b([A-Z][a-zA-Z0-9_]*)\b', file_content))

    # 过滤：必须是已知的 class_name
    known = set(class_map.keys())
    refs = words & known

    # 排除 autoload 和自身
    refs -= autoload_names
    if own_class:
        refs.discard(own_class)

    # 排除基础类型
    refs -= {"Node", "Control", "Resource", "RefCounted", "Object",
             "CanvasLayer", "PanelContainer", "VBoxContainer", "HBoxContainer",
             "Button", "ScrollContainer", "Node2D", "GDScript", "MapMarker",
             "True", "False", "None", "String", "Array", "Dictionary", "int",
             "float", "bool", "Vector2", "Vector3", "Color", "PackedScene",
             "Texture", "Texture2D", "Font", "StyleBox", "Material"}

    return refs


def extract_class_name(file_content: str) -> str | None:
    """提取文件自身的 class_name"""
    m = re.search(r'^class_name\s+(\w+)', file_content, re.MULTILINE)
    return m.group(1) if m else None


def already_has_preload(file_content: str, class_name: str) -> bool:
    """检查文件中是否已有对 class_name 的 preload"""
    pattern = rf'preload\s*\(\s*["\'].*?{re.escape(class_name)}.*?["\']'
    return bool(re.search(pattern, file_content, re.IGNORECASE))
    # Also check by file path
    # This is simpler - just check if there's already a preload for this file


def generate_preload_lines(refs: set[str], class_map: dict) -> list[str]:
    """为引用的 class_name 生成 preload 行"""
    lines = []
    for cn in sorted(refs):
        file_path = class_map.get(cn)
        if file_path:
            lines.append(f'const _{cn} = preload("res://{file_path}")')
    return lines


def insert_preloads(file_path: str, new_lines: list[str], dry_run: bool = True) -> bool:
    """在文件顶部插入 preload 行（extends 行之后）"""
    full_path = PROJECT_ROOT / file_path
    if not full_path.exists():
        print(f"  ⚠️  文件不存在: {file_path}")
        return False

    content = full_path.read_text(encoding="utf-8")
    lines = content.splitlines(keepends=True)

    # 找到 extends 行（通常是第 1 行，可能在 @tool 之后）
    insert_pos = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("extends "):
            insert_pos = i + 1
            break

    if insert_pos == -1:
        # 没有 extends？在 @tool 后或文件首插入
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped == "@tool":
                insert_pos = i + 1
                break
        if insert_pos == -1:
            insert_pos = 0

    # 检查是否已经有相同的 preload
    existing_preloads = set()
    for line in lines:
        m = re.search(r'const\s+_(\w+)\s*=\s*preload', line)
        if m:
            existing_preloads.add(m.group(1))

    lines_to_insert = []
    for nl in new_lines:
        m = re.search(r'const\s+_(\w+)', nl)
        if m and m.group(1) not in existing_preloads:
            lines_to_insert.append(nl + "\n")

    if not lines_to_insert:
        return False

    if dry_run:
        print(f"\n📄 {file_path} (insert at line {insert_pos + 1}):")
        for l in lines_to_insert:
            print(f"   + {l.rstrip()}")
        return True

    # 实际修改
    for i, nl in enumerate(lines_to_insert):
        lines.insert(insert_pos + i, nl)

    full_path.write_text("".join(lines), encoding="utf-8")
    print(f"  ✓ {file_path}: 插入 {len(lines_to_insert)} 条 preload")
    return True


def main():
    dry_run = "--apply" not in sys.argv

    print("🔍 扫描 autoload 配置...")
    project_content = PROJECT_FILE.read_text(encoding="utf-8")
    autoloads = parse_autoloads(project_content)
    autoload_names = {name for name, _ in autoloads}
    autoload_paths = {path for _, path in autoloads}

    print(f"   autoload 数量: {len(autoloads)}")
    for name, path in autoloads:
        print(f"     {name} → {path}")

    print("\n🔍 构建 class_name 映射...")
    class_map = build_class_name_map()
    print(f"   找到 {len(class_map)} 个 class_name")

    print(f"\n🔍 分析每个 autoload 文件...")
    total_insertions = 0
    modified_files = 0

    for name, path in autoloads:
        full_path = PROJECT_ROOT / path
        if not full_path.exists():
            print(f"  ⚠️  autoload 文件不存在: {path}")
            continue

        content = full_path.read_text(encoding="utf-8")
        own_class = extract_class_name(content)
        refs = find_class_refs(content, class_map, autoload_names, own_class)

        if not refs:
            continue

        # 过滤已存在的 preload（按 class_name）
        filtered_refs = {r for r in refs if not already_has_preload(content, r)}
        if not filtered_refs:
            continue

        preload_lines = generate_preload_lines(filtered_refs, class_map)
        if insert_preloads(path, preload_lines, dry_run=dry_run):
            total_insertions += len(preload_lines)
            modified_files += 1

    if dry_run:
        print(f"\n📊 干跑完成: 将修改 {modified_files} 个文件, 共 {total_insertions} 条 preload")
        print("   添加 --apply 参数实际执行修改")
    else:
        print(f"\n✅ 完成: 修改了 {modified_files} 个文件, 共插入 {total_insertions} 条 preload")


if __name__ == "__main__":
    main()
