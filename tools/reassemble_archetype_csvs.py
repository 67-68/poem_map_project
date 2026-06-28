#!/usr/bin/env python3
"""
Phase 4: CSV Re-assembly — 清洗所有 CSV

1. event 行: 从 store_to 提取 archetype 注入 context 列
2. option 行: 清洗 results 列（删除 prop_*，保留 emo_*/imagery_*）
3. 处理无 JSON 配置的 3 个 CSV
"""
import csv
import re
import os
import io

BASE_DATA_DIR = "/Users/a67_68/projects/dufu_simulator/data"

# ── 需要处理的 CSV 文件（所有 17 个） ──
CSV_FILES = [
    # 747_kuangda 时代
    "4_eras/747_kuangda/_duotai_humiliation_events.csv",
    "4_eras/747_kuangda/_kuangke_qingliu_events.csv",
    "4_eras/747_kuangda/_kuangke_zhuoliu_events.csv",
    "4_eras/747_kuangda/_qingliu_daoxin_posui_events.csv",
    "4_eras/747_kuangda/_qingliu_fengying_events.csv",
    "4_eras/747_kuangda/_qingliu_jiaolv_events.csv",
    "4_eras/747_kuangda/_qingliu_passive_benefits_events.csv",
    "4_eras/747_kuangda/_qingliu_zuanying_events.csv",
    "4_eras/747_kuangda/_zhuoliu_fengying_events.csv",
    "4_eras/747_kuangda/_zhuoliu_lieqi_events.csv",
    "4_eras/747_kuangda/_zhuoliu_zuanying_events.csv",
    "4_eras/747_kuangda/_zize_events.csv",
    "4_eras/747_kuangda/_drunken_oblivion_events.csv",
    "4_eras/747_kuangda/_political_purge_events.csv",
    "4_eras/747_kuangda/denggao/_747kuangda_denggao_events.csv",
    # 745_ambition 时代
    "4_eras/745_ambition/_scene_imagery_library_events.csv",
    "4_eras/745_ambition/baiye/honey_moon/_bai_ye_honeymoon_events.csv",
    "4_eras/745_ambition/baiye/real_appearance/_bai_ye_real_appearance_events.csv",
    # 755_backhome
    "4_eras/755_backhome/_ganlu_journey_events.csv",
    # 3_actions_pool
    "3_actions_pool/events/_random_events.csv",
]

# ── 已知单行动库的 archetype 映射（用于无 store_to 的 CSV，从 config 级 archetype_id 推断） ──
FILE_ARCHETYPE_MAP = {
    "4_eras/745_ambition/baiye/honey_moon/_bai_ye_honeymoon_events.csv": "baiye",
    "4_eras/745_ambition/baiye/real_appearance/_bai_ye_real_appearance_events.csv": "baiye",
    "4_eras/747_kuangda/denggao/_747kuangda_denggao_events.csv": "denggao",
    "4_eras/745_ambition/_scene_imagery_library_events.csv": "baiye",
}


def extract_store_to(context_str: str) -> str:
    """从 context 列提取 store_to 值。"""
    m = re.search(r'store_to=([^|]+)', context_str)
    if m:
        return m.group(1).strip()
    return ""


def extract_archetype_from_context(context_str: str) -> str:
    """检查是否已有 archetype。"""
    m = re.search(r'archetype=([^|]+)', context_str)
    if m:
        return m.group(1).strip()
    return ""


def extract_archetype_from_store_to(store_to: str) -> str:
    """从 store_to 提取 archetype_id。"""
    if "." in store_to:
        return store_to.split(".")[-1]
    return store_to


def inject_archetype(context_str: str, archetype: str) -> str:
    """向 context 列注入 archetype（如果不存在）。"""
    if extract_archetype_from_context(context_str):
        return context_str  # 已有，跳过
    if archetype:
        return context_str + f"|archetype={archetype}"
    return context_str


def clean_operator_dsl(dsl: str) -> str:
    """清洗 operator DSL：删除 prop_* 操作符，保留 emo_*/imagery_*。"""
    if not dsl or dsl.strip() == "":
        return dsl
    parts = re.split(r'\s*\|\s*', dsl.strip())
    cleaned = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # 检查是否为 prop_* 操作
        if part.startswith("prop_"):
            continue
        cleaned.append(part)
    return " | ".join(cleaned)


def process_csv(filepath: str) -> bool:
    """处理单个 CSV 文件。返回是否做了修改。"""
    if not os.path.exists(filepath):
        print(f"  ❌ 文件不存在: {filepath}")
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    if not lines:
        return False

    # 解析 header
    header = lines[0].strip()
    cols = [c.strip() for c in csv.reader([header]).__next__()]
    
    # 找到关键列的索引
    try:
        context_idx = cols.index("context")
        # 将 header 转为小写匹配
        cols_lower = [c.lower() for c in cols]
    except ValueError:
        print(f"  ❌ {filepath}: 找不到 'context' 列")
        return False

    try:
        row_type_idx = cols.index("row_type")
    except ValueError:
        print(f"  ❌ {filepath}: 找不到 'row_type' 列")
        return False

    # 找到 results 列的索引（option 行使用）
    # CSV 可能使用不同命名，查找有代表性的列名
    results_col = -1
    for col_name in ["results", "result", "on_enter"]:
        try:
            results_col = cols.index(col_name)
            break
        except ValueError:
            continue

    changed = False
    new_lines = [header]

    for line in lines[1:]:
        if not line.strip():
            new_lines.append(line)
            continue

        # 用 csv 解析行
        reader = csv.reader([line])
        try:
            row = next(reader)
        except StopIteration:
            new_lines.append(line)
            continue

        if len(row) <= max(context_idx, row_type_idx):
            new_lines.append(line)
            continue

        row_type = row[row_type_idx].strip().lower()

        if "event" in row_type or row_type == "random_event":
            # ── Event 行：注入 archetype ──
            context_val = row[context_idx]
            store_to = extract_store_to(context_val)
            
            archetype = ""
            if store_to:
                archetype = extract_archetype_from_store_to(store_to)
            else:
                # fallback: 从 FILE_ARCHETYPE_MAP 按相对路径查找
                rel = os.path.relpath(filepath, BASE_DATA_DIR)
                archetype = FILE_ARCHETYPE_MAP.get(rel, "")
            
            if archetype:
                new_context = inject_archetype(context_val, archetype)
                if new_context != context_val:
                    row[context_idx] = new_context
                    changed = True
                    print(f"  📌 {os.path.basename(filepath)}: → archetype={archetype}")

        elif row_type.startswith(">option") or row_type == "option":
            # ── Option 行：清洗 results ──
            if results_col >= 0 and results_col < len(row):
                results_val = row[results_col]
                if results_val:
                    cleaned = clean_operator_dsl(results_val)
                    if cleaned != results_val:
                        row[results_col] = cleaned
                        changed = True

        new_lines.append(",".join(row))

    if changed:
        new_content = "\n".join(new_lines)
        # 确保文件以换行结尾
        if not new_content.endswith("\n"):
            new_content += "\n"
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"  ✅ {os.path.relpath(filepath, BASE_DATA_DIR)}: 已更新")
    else:
        print(f"  ⏭️  {os.path.relpath(filepath, BASE_DATA_DIR)}: 无变更")

    return changed


def main():
    print("=" * 60)
    print("Phase 4: CSV Re-assembly — 清洗所有事件库 CSV")
    print("=" * 60)
    print()

    total_changed = 0
    for rel_path in CSV_FILES:
        filepath = os.path.join(BASE_DATA_DIR, rel_path)
        if process_csv(filepath):
            total_changed += 1

    print()
    print("=" * 60)
    print(f"处理完成！{total_changed} 个文件有变更")
    print("=" * 60)


if __name__ == "__main__":
    main()
