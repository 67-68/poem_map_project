#!/usr/bin/env python3
"""
替换项目中所有裸 print/printerr/push_warning/push_error 为 Logging.xxx()

映射规则：
  print(...)       → Logging.info(...)
  printerr(...)    → Logging.err(...)
  push_warning(...) → Logging.warn(...)
  push_error(...)  → Logging.err(...)

排除规则：
  - addons/gut/  (第三方测试框架)
  - parser/safe_logger.gd  (用户明确要求保留)
  - core/logger.gd  (自身定义)
  - 已包含 Logging.xxx() 的行不处理

@tool 和 standalone 脚本自动添加 const Logging = preload("res://core/logger.gd")
"""

import os
import re
import sys

PROJECT_ROOT = "/Users/lennon/Projects/poem_map_project"
EXCLUDE_DIRS = {"addons/gut/"}
EXCLUDE_FILES = {
    "parser/safe_logger.gd",
    "core/logger.gd",
}

# 需要添加 preload 的文件（@tool 或 standalone 脚本）
# 通过检查文件第一行是否包含 @tool 或 extends Node/RefCounted 且不在场景树中
TOOL_FILES_NEEDING_PRELOAD = {
    # @tool 脚本
    "core/util.gd",
    "core/data_scanner.gd",
    "core/data_loader.gd",
    "core/icon_loader.gd",
    "core/csv_cloud_sync_cli.gd",
    "core/csv_cloud_loader.gd",
    "core/event_data_linter.gd",
    "core/prop_parser.gd",
    "core/base_repository.gd",
    "core/utils/resource_asset_exporter.gd",
    "resources_registry_creator.gd",
    "tools/debug_float_text.gd",
    "debuggers/event_chain_linter.gd",
    "debuggers/event_action_tag_linter.gd",
    "addons/data_syncer.gd",
    "core/linter_rules/business_linter_rule.gd",
    "core/linter_rules/schema_linter_rule.gd",
    "core/linter_rules/linker_linter_rule.gd",
    "core/linter_rules/base_linter_rule.gd",
}


def get_project_files():
    """获取所有需要处理的 .gd 文件"""
    result = []
    for root, dirs, files in os.walk(PROJECT_ROOT):
        # 跳过排除目录
        rel_root = os.path.relpath(root, PROJECT_ROOT)
        if any(rel_root.startswith(ex) or rel_root == ex.strip("/") for ex in EXCLUDE_DIRS):
            continue
        # 跳过 .godot
        if ".godot" in rel_root:
            continue

        for f in files:
            if not f.endswith(".gd"):
                continue
            filepath = os.path.join(root, f)
            rel_path = os.path.relpath(filepath, PROJECT_ROOT)

            if rel_path in EXCLUDE_FILES:
                continue

            result.append((rel_path, filepath))

    return result


def needs_preload(rel_path: str, content: str) -> bool:
    """检查文件是否需要添加 Logging preload"""
    if rel_path in TOOL_FILES_NEEDING_PRELOAD:
        return True

    # 检查第一行是否是 @tool
    first_line = content.split("\n")[0].strip() if content else ""
    if first_line == "@tool":
        return True

    # 检查是否是 RefCounted（无法使用 autoload）
    if "extends RefCounted" in content.split("\n")[0] if content else "":
        return True

    return False


def has_logging_preload(content: str) -> bool:
    """检查文件是否已有 Logging preload"""
    return 'const Logging = preload("res://core/logger.gd")' in content


def add_logging_preload(content: str) -> str:
    """添加 Logging preload 到文件"""
    lines = content.split("\n")
    # 找到第一个非空行之后的合适位置插入
    insert_pos = 0
    for i, line in enumerate(lines):
        # 跳过 shebang、@tool、extends、class_name、# 注释等
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("@") or stripped.startswith("extends") or stripped.startswith("class_name") or stripped == "":
            insert_pos = i + 1
        else:
            break

    preload_line = 'const Logging = preload("res://core/logger.gd")'
    
    # 检查是否已经在附近有了其他 preload
    for i in range(max(0, insert_pos - 3), min(len(lines), insert_pos + 5)):
        if "preload" in lines[i]:
            insert_pos = i + 1

    lines.insert(insert_pos, preload_line)
    return "\n".join(lines)


# 正则：匹配行首缩进后的 print(...)/printerr(...)/push_warning(...)/push_error(...)
# 不匹配已包含 Logging. 的行
def make_replacement(content: str) -> tuple[str, int]:
    """
    执行替换，返回 (新内容, 替换数量)
    """
    replacements = {
        "print": "Logging.info",
        "printerr": "Logging.err",
        "push_warning": "Logging.warn",
        "push_error": "Logging.err",
    }

    lines = content.split("\n")
    new_lines = []
    total_count = 0

    for line in lines:
        stripped = line.strip()
        new_line = line

        # 跳过注释行
        if stripped.startswith("#"):
            new_lines.append(line)
            continue

        for old_func, new_func in replacements.items():
            # 只在行首或前导空白后匹配函数名
            # 模式: 行首空白 + func_name(
            pattern = re.compile(r'^(\s*)' + re.escape(old_func) + r'\(')
            m = pattern.match(stripped)

            if m:
                # 检查是否已经包含 Logging. 前缀
                if "Logging." + old_func in stripped:
                    continue

                # 替换
                indent = line[:len(line) - len(line.lstrip())]
                rest = stripped[len(m.group(0)):]  # 括号后面的内容
                new_line = indent + new_func + "(" + rest
                total_count += 1
                break

        new_lines.append(new_line)

    return "\n".join(new_lines), total_count


def main():
    files = get_project_files()
    total_replaced = 0
    total_preload_added = 0
    processed_files = []
    skipped_files = []

    for rel_path, abs_path in files:
        with open(abs_path, "r", encoding="utf-8") as f:
            original = f.read()

        content = original

        # 1. 检查是否需要添加 preload
        needs = needs_preload(rel_path, content)
        has_pre = has_logging_preload(content)

        if needs and not has_pre:
            # 检查文件中是否真的有 print/printerr/push_warning/push_error 调用
            has_bare_call = False
            for func_name in ["print", "printerr", "push_warning", "push_error"]:
                pattern = re.compile(r'^\s*' + re.escape(func_name) + r'\(', re.MULTILINE)
                if pattern.search(content) and "Logging." + func_name not in content.split("\n")[0]:
                    has_bare_call = True
                    break

            if has_bare_call:
                content = add_logging_preload(content)
                total_preload_added += 1

        # 2. 替换 print/printerr/push_warning/push_error
        content, count = make_replacement(content)

        if count > 0 or content != original:
            with open(abs_path, "w", encoding="utf-8") as f:
                f.write(content)
            total_replaced += count
            processed_files.append(f"{rel_path} ({count} 处替换)")
        else:
            skipped_files.append(rel_path)

    print(f"=== 替换完成 ===")
    print(f"处理文件数: {len(processed_files)}")
    print(f"总替换数: {total_replaced}")
    print(f"新增 preload: {total_preload_added}")
    print()
    if processed_files:
        print("已处理文件:")
        for pf in processed_files:
            print(f"  ✅ {pf}")
    if skipped_files and len(skipped_files) < 50:
        print(f"\n无变更文件 ({len(skipped_files)}):")
        for sf in skipped_files:
            print(f"  - {sf}")


if __name__ == "__main__":
    main()
