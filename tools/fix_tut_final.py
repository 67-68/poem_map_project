#!/usr/bin/env python3
"""
Final fix for TRES_TUT_ section: the -1 shift doesn't work correctly
for entries whose en values were displaced by ~40 positions.
Build correct zh→en mapping from all file cross-references.
"""

import csv, shutil
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak")

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' for c in s)

def main():
    shutil.copy2(BAK_PATH, CSV_PATH)
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    
    # Phase 1: -1 shift for ALL rows 422-2873
    for i in range(421, len(rows) - 1):
        rows[i][2] = rows[i + 1][2]
    rows[-1][2] = ""
    print(f"Phase 1: -1 shift done")
    
    # Phase 2: Build complete zh→en map from rows 2-421 (verified correct section)
    truth = {}
    for i in range(1, 421):
        row = rows[i]
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            truth[zh] = en
    
    # Phase 3: Also collect ALL zh→en pairs from the ENTIRE file (before shift)
    # This helps us find the correct en for TUT entries
    with open(BAK_PATH, "r", encoding="utf-8") as f:
        bak_rows = list(csv.reader(f))
    
    full_map = {}
    for row in bak_rows:
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            full_map[zh] = en
    
    print(f"Phase 2: built truth dict ({len(truth)} from L2-421, {len(full_map)} full)")
    
    # Phase 4: Fix TUT entries by finding correct en in full_map
    # For each TRES_TUT_ row, if its zh is in full_map, use that en
    tut_fixed = 0
    for i, row in enumerate(rows):
        ln = i + 1
        if not row[0].startswith("TRES_TUT_"):
            continue
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh in full_map and full_map[zh] != en:
            rows[i][2] = full_map[zh]
            tut_fixed += 1
            if tut_fixed <= 20:
                print(f"  TUT fix L{ln}: {row[0]} zh='{zh[:40]}' → en='{full_map[zh][:50]}'")
    
    print(f"Phase 3: fixed {tut_fixed} TUT entries via full_map")
    
    # Phase 5: Also fix non-TUT entries in 2567-2705 range
    extra_fixed = 0
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 2567 or ln > 2720:
            continue
        if row[0].startswith("TRES_TUT_"):
            continue  # already handled
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh in full_map and full_map[zh] != en:
            rows[i][2] = full_map[zh]
            extra_fixed += 1
    
    print(f"Phase 4: fixed {extra_fixed} extra entries in L2567-2720")
    
    # Write
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"Written: {CSV_PATH}")
    
    # Show all TRES_TUT_ entries for verification
    print("\n=== ALL TRES_TUT_ ENTRIES (final) ===")
    issues = []
    for i, row in enumerate(rows):
        ln = i + 1
        if not row[0].startswith("TRES_TUT_"):
            continue
        zh = row[1].strip()[:60]
        en = row[2].strip()[:60]
        # Flag if en looks wrong (empty, Chinese, or too short for long zh)
        if not en:
            flag = "⚠️ EMPTY"
        elif has_chinese(en):
            flag = "⛔ CHINESE IN EN"
        elif len(zh) > 20 and len(en) < 5:
            flag = "⚠️ SHORT EN"
        else:
            flag = ""
        print(f"  L{ln}: {row[0]:<45} zh={zh:<60} en={en:<60} {flag}")
        if flag:
            issues.append((ln, row[0], zh, en, flag))
    
    if issues:
        print(f"\n⚠️ {len(issues)} potential issues remaining")
    else:
        print(f"\n✅ All TUT entries look clean")

if __name__ == "__main__":
    main()
