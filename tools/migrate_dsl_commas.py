#!/usr/bin/env python3
"""
DSL 逗号迁移工具 — 将 CSV 数据中所有的 DSL 逗号替换为分层符号。

映射方案:
  Layer 0 (顶级表达式分隔):  , → |
  Layer 1 (函数参数分隔):    , → ;
  Layer 2 (数组/标签分隔):   , → /

用法:
  python3 tools/migrate_dsl_commas.py
"""

import csv
import os
from pathlib import Path


def convert_dsl_commas(text: str) -> str:
    """将文本中的 DSL 逗号按嵌套层级转换为对应符号。"""
    result = []
    paren_depth = 0
    bracket_depth = 0
    in_quote = False

    for ch in text:
        if ch == '"':
            in_quote = not in_quote
            result.append(ch)
        elif ch == '(' and not in_quote:
            paren_depth += 1
            result.append(ch)
        elif ch == ')' and not in_quote:
            paren_depth -= 1
            result.append(ch)
        elif ch == '[' and not in_quote:
            bracket_depth += 1
            result.append(ch)
        elif ch == ']' and not in_quote:
            bracket_depth -= 1
            result.append(ch)
        elif ch == ',' and not in_quote:
            if bracket_depth > 0:
                result.append('/')  # Layer 2: 数组元素
            elif paren_depth > 0:
                result.append(';')  # Layer 1: 函数参数
            else:
                result.append('|')  # Layer 0: 顶层表达式
        else:
            result.append(ch)

    return ''.join(result)


def migrate_csv(filepath: str) -> None:
    """迁移单个 CSV 文件中的所有 DSL 逗号。"""
    filepath = Path(filepath)
    if not filepath.exists():
        print(f"⚠ 文件不存在: {filepath}")
        return

    # 读取原始数据
    rows = []
    with open(filepath, 'r', newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            rows.append(row)

    if not rows:
        print(f"⚠ 空文件: {filepath}")
        return

    # 转换每个单元格
    converted_count = 0
    new_rows = []
    for row in rows:
        new_row = []
        for cell in row:
            new_cell = convert_dsl_commas(cell)
            if new_cell != cell:
                converted_count += 1
            new_row.append(new_cell)
        new_rows.append(new_row)

    # 写回
    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(new_rows)

    print(f"✓ {filepath}: 转换了 {converted_count} 个单元格")


def main():
    project_root = Path(__file__).parent.parent

    # 需要迁移的 CSV 文件
    csv_files = [
        project_root / "data" / "random_events" / "random_events.csv",
        project_root / "data" / "tres_state_transistors" / "state_transistor.csv",
    ]

    for csv_file in csv_files:
        migrate_csv(csv_file)

    print("\n迁移完成。")


if __name__ == "__main__":
    main()
