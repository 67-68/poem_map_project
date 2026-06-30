#!/usr/bin/env python3
"""
build_data_index.py — 扫描 data/ 目录，生成 _file_index.json
供 DataScanner 在 HTML5 导出中 DirAccess 不可用时作为降级清单。

输出格式:
{
  "files": ["1_core_rules/properties/ruler_stat.tres", ...],
  "generated_at": "2025-01-01T00:00:00",
  "total": 562
}
"""
import json
import os
from datetime import datetime, timezone

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
OUTPUT_PATH = os.path.join(DATA_DIR, "_file_index.json")

EXCLUDE_PREFIXES = (".", "_file_index")


def main():
    files = []
    for root, dirs, filenames in os.walk(DATA_DIR):
        # 计算相对路径
        rel_root = os.path.relpath(root, DATA_DIR)
        if rel_root == ".":
            rel_root = ""

        for fname in sorted(filenames):
            # 跳过输出文件自身和其他隐藏文件
            if fname.startswith(".") or fname in EXCLUDE_PREFIXES:
                continue

            ext = os.path.splitext(fname)[1].lower()

            # .tres 全部收录
            if ext == ".tres":
                pass
            # .csv：跳过 _ 前缀的（DSL 源文件，已有预生成 .tres）
            elif ext == ".csv":
                if fname.startswith("_"):
                    continue
            # .json：仅收录 eb_ 前缀的 EventBase 配置文件
            elif ext == ".json":
                if not fname.startswith("eb_"):
                    continue
            else:
                continue

            rel_path = os.path.join(rel_root, fname) if rel_root else fname
            files.append(rel_path)

    payload = {
        "files": files,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total": len(files),
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"[build_data_index] 扫描完成: {len(files)} 个文件 → {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
