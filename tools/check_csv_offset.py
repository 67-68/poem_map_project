#!/usr/bin/env python
"""Check _dynamic_events.csv for column offset issues around line 420+"""

import csv
import random
import sys
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

def analyze_csv():
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            rows.append((i + 1, row))  # 1-based line numbers

    header = rows[0]
    print(f"=== HEADER (line 1): {header[1]}")
    print(f"    Columns: {header[1]}")
    print(f"    Expected: keys, zh, en, ja")
    print()

    # Analyze each row for column count
    problem_lines = []
    col_counts = {}
    for line_no, row in rows[1:]:  # skip header
        n_cols = len(row)
        col_counts[n_cols] = col_counts.get(n_cols, 0) + 1
        if n_cols != 4:
            problem_lines.append((line_no, n_cols, row))

    print(f"=== COLUMN COUNT DISTRIBUTION ===")
    for n, count in sorted(col_counts.items()):
        print(f"  {n} columns: {count} rows ({count/(len(rows)-1)*100:.1f}%)")

    if problem_lines:
        print(f"\n=== ROWS WITH ≠4 COLUMNS ({len(problem_lines)} total, showing first 20) ===")
        for line_no, n_cols, row in problem_lines[:20]:
            print(f"  Line {line_no} ({n_cols} cols): {row[:min(5, len(row))]}")
        if len(problem_lines) > 20:
            print(f"  ... and {len(problem_lines) - 20} more")

    print(f"\n=== HEURISTIC: DETECT SHIFTED ROWS ===")
    # Strategy: Look at the keys column. Normal keys follow patterns like:
    #   CODE_XXXX_XXXXXXXX
    #   EVT_XXXX_XXXX
    #   TRES_XXXX
    #   TRAIT_XXXX
    #   PROPERTY_NAME_XXXX
    #   FEIHUALING_XXXX
    #   LIANJU_XXXX
    #
    # If a row is shifted, the zh content might be in the keys column,
    # and subsequent columns are also shifted.
    
    # Heuristic 1: Check if 'keys' column starts with expected prefixes
    valid_key_prefixes = [
        'ACT_', 'CHAR_NAME_', 'CODE_', 'EVT_', 'PROPERTY_NAME_',
        'TRAIT_', 'TRES_', 'FEIHUALING_', 'LIANJU_',
    ]
    
    shifted_regions = []
    current_region_start = None
    current_region_type = None  # 'normal' or 'shifted'
    
    for line_no, row in rows[1:]:
        if len(row) < 1:
            continue
        keys_val = row[0].strip() if row[0] else ""
        
        is_likely_normal = False
        for prefix in valid_key_prefixes:
            if keys_val.startswith(prefix):
                is_likely_normal = True
                break
        
        # Also check: if keys column contains Chinese characters, it's likely shifted
        has_chinese = any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in keys_val)
        
        status = 'shifted' if has_chinese and not is_likely_normal else 'normal'
        if not is_likely_normal and not has_chinese and keys_val == '':
            status = 'empty_key'
        
        if current_region_type is None:
            current_region_start = line_no
            current_region_type = status
        elif status != current_region_type:
            shifted_regions.append((current_region_start, line_no - 1, current_region_type))
            current_region_start = line_no
            current_region_type = status
    
    if current_region_start is not None:
        shifted_regions.append((current_region_start, len(rows), current_region_type))
    
    print(f"\n=== REGIONS BY KEY COLUMN STATUS ===")
    for start, end, rtype in shifted_regions:
        marker = "⚠️ SHIFTED" if rtype == 'shifted' else ("⚪ EMPTY KEY" if rtype == 'empty_key' else "✅ NORMAL")
        print(f"  Lines {start:5d} - {end:5d}  [{marker}]  ({end - start + 1} rows)")

    # Now do the 30 random samples
    print(f"\n=== RANDOM SAMPLE (30 rows across file) ===")
    random.seed(42)
    data_rows = rows[1:]  # exclude header
    sample_indices = sorted(random.sample(range(len(data_rows)), min(30, len(data_rows))))
    
    for idx in sample_indices:
        line_no, row = data_rows[idx]
        keys_val = row[0].strip() if len(row) > 0 and row[0] else "(empty)"
        zh_val = row[1].strip() if len(row) > 1 and row[1] else "(empty)"
        en_val = row[2].strip() if len(row) > 2 and row[2] else "(empty)"
        ja_val = row[3].strip() if len(row) > 3 and row[3] else "(empty)"
        
        # Determine if likely shifted
        has_chinese_keys = any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in keys_val)
        has_chinese_en = any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in en_val)
        
        if has_chinese_keys:
            flag = "🔴 SHIFTED (zh in keys col)"
        elif has_chinese_en:
            flag = "🟡 MAYBE SHIFTED (zh in en col)"
        else:
            # Check if any prefix matches
            is_valid = any(keys_val.startswith(p) for p in valid_key_prefixes)
            flag = "✅ NORMAL" if is_valid else "❓ UNKNOWN KEY PATTERN"
        
        print(f"\n  Line {line_no}: {flag}")
        print(f"    keys: {keys_val[:80]}")
        print(f"    zh:   {zh_val[:80]}")
        print(f"    en:   {en_val[:80]}")
        print(f"    ja:   {ja_val[:80]}")

    # Look at the transition point more closely
    print(f"\n=== TRANSITION ZOOM: Lines 415-435 ===")
    for line_no, row in rows:
        if 415 <= line_no <= 435:
            print(f"\n  Line {line_no}:")
            for ci, col_name in enumerate(['keys', 'zh', 'en', 'ja']):
                val = row[ci] if ci < len(row) else "(MISSING)"
                print(f"    {col_name}: {val[:120]}")

if __name__ == "__main__":
    analyze_csv()
