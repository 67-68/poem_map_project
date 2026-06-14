#!/usr/bin/env python3
"""
修复 Logging.xxx("msg", var1, var2) 多参数调用。
转为：Logging.xxx("msg " + str(var1) + " " + str(var2))

使用字符串连接（str() 包裹）来保持通用性，兼容 GDScript 任意类型参数。
"""

import re
import os

PROJECT_ROOT = "/Users/lennon/Projects/poem_map_project"
LOGGING_FUNCS = ["Logging.info", "Logging.err", "Logging.warn", "Logging.debug", "Logging.error"]


def extract_top_level_args(s: str) -> list[str]:
    """按顶级逗号分割参数列表，正确处理括号/引号嵌套"""
    args = []
    depth = 0
    in_string = False
    string_char = None
    current = ""

    for c in s:
        if c in ('"', "'") and not in_string:
            in_string = True
            string_char = c
            current += c
        elif c == string_char and in_string:
            in_string = False
            string_char = None
            current += c
        elif c in ('(', '[') and not in_string:
            depth += 1
            current += c
        elif c in (')', ']') and not in_string:
            depth -= 1
            current += c
        elif c == ',' and depth == 0 and not in_string:
            args.append(current.strip())
            current = ""
        else:
            current += c

    if current.strip():
        args.append(current.strip())

    return args


def wrap_arg(arg: str) -> str:
    """将参数包装为 str(arg) 形式。如果已经是字符串字面量则去掉引号"""
    arg = arg.strip()
    # 如果是字符串字面量 "xxx"，提取内容
    if (arg.startswith('"') and arg.endswith('"')) or (arg.startswith("'") and arg.endswith("'")):
        return arg[1:-1]  # 去掉引号，直接嵌入
    # 如果是数字、布尔值、null，直接返回 str(...)
    return "${" + arg + "}"


def fix_line(line: str) -> str | None:
    """修复一行中的多参数 Logging 调用，返回修复后的行或 None"""
    original = line
    for func in LOGGING_FUNCS:
        # 查找 func("...", ...) 模式
        idx = line.find(func + "(")
        if idx == -1:
            continue

        # 找到匹配的括号
        start = idx + len(func) + 1  # '(' 之后
        depth = 1
        end = start
        while end < len(line) and depth > 0:
            if line[end] == '(':
                depth += 1
            elif line[end] == ')':
                depth -= 1
            end += 1
        end -= 1  # 回退到 ')'

        if depth != 0:
            continue

        # 提取括号内的内容
        inner = line[start:end]

        # 分割参数
        args = extract_top_level_args(inner)

        if len(args) <= 1:
            continue  # 单参数，没问题

        first_arg = args[0].strip()

        # 确认第一个是字符串字面量
        if not ((first_arg.startswith('"') and first_arg.endswith('"')) or
                (first_arg.startswith("'") and first_arg.endswith("'"))):
            continue  # 第一个不是字符串，跳过

        # 构建新的调用：func("first", arg2, arg3) → func("first " + str(arg2) + " " + str(arg3))
        first_str = first_arg[1:-1]  # 去掉引号
        remaining = args[1:]

        # 构建连接表达式
        parts = []
        remaining_parts = []

        for i, arg in enumerate(remaining):
            arg = arg.strip()
            # 如果是字符串字面量，直接嵌入
            if (arg.startswith('"') and arg.endswith('"')) or (arg.startswith("'") and arg.endswith("'")):
                remaining_parts.append(arg[1:-1])
            else:
                remaining_parts.append("${" + arg + "}")

        # 重新组合：把 adjacent string literals 合并
        merged = []
        for rp in remaining_parts:
            if rp.startswith("${"):
                merged.append(rp)
            else:
                # 字符串字面量
                if merged and not merged[-1].startswith("${"):
                    merged[-1] = merged[-1] + rp
                else:
                    merged.append(rp)

        # 构建最终字符串
        result_str = first_str
        for m in merged:
            if m.startswith("${"):
                result_str += " %s"
            else:
                result_str += m

        # 构建参数数组
        format_args = []
        for m in merged:
            if m.startswith("${"):
                format_args.append(m[2:-1])  # 去掉 ${}

        if format_args:
            new_inner = '"%s" %% [%s]' % (result_str, ", ".join(format_args))
        else:
            new_inner = '"%s"' % result_str

        before = line[:idx]
        after = line[end + 1:]
        line = before + func + "(" + new_inner + ")" + after

        if line != original:
            return line

    return None


def process_file(filepath: str) -> int:
    """处理单个文件，返回修复数量"""
    with open(filepath, "r") as f:
        lines = f.readlines()

    fixed_count = 0
    new_lines = []
    for i, line in enumerate(lines):
        stripped = line.rstrip("\n").rstrip("\r")
        fixed = fix_line(stripped)
        if fixed is not None and fixed != stripped:
            print(f"  [{os.path.relpath(filepath, PROJECT_ROOT)}:{i+1}]")
            print(f"    - {stripped}")
            print(f"    + {fixed}")
            new_lines.append(fixed + "\n")
            fixed_count += 1
        else:
            new_lines.append(line)

    if fixed_count > 0:
        with open(filepath, "w") as f:
            f.writelines(new_lines)

    return fixed_count


def main():
    total_fixed = 0
    fixed_files = []

    for root, dirs, files in os.walk(PROJECT_ROOT):
        rel_root = os.path.relpath(root, PROJECT_ROOT)
        if "addons/gut" in rel_root:
            continue
        if ".godot" in rel_root:
            continue

        for f in files:
            if not f.endswith(".gd"):
                continue

            filepath = os.path.join(root, f)
            count = process_file(filepath)
            if count > 0:
                total_fixed += count
                fixed_files.append(os.path.relpath(filepath, PROJECT_ROOT))

    print(f"\n=== 修复完成 ===")
    print(f"修复文件数: {len(fixed_files)}")
    print(f"总修复数: {total_fixed}")


if __name__ == "__main__":
    main()
