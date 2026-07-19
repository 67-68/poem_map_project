#!/usr/bin/env python3
"""
Fix _dynamic_events.csv with precise row-by-row analysis.
The en column has a -1 shift starting at line 422.
But there may be additional corruption in the UI section (lines 2795+).

Strategy:
1. For each zh, find its CORRECT en by looking it up in ground truth
   (built from lines 1-421 which are verified correct)
2. Apply the fix conditionally
"""

import csv, sys
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak2")

has_chinese = lambda s: any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in s)

def build_truth(rows):
    """Build zh→en mapping from verified-correct lines 1-421."""
    truth = {}
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 2:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            truth[zh] = en
    return truth

def main():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    
    print(f"Read {len(rows)} rows")
    
    # Backup
    import shutil
    shutil.copy2(CSV_PATH, BAK_PATH)
    print(f"Backup: {BAK_PATH}")
    
    # Build truth from first 421 lines (verified correct section)
    truth = build_truth(rows[:421])
    print(f"Built truth dictionary: {len(truth)} entries")
    
    # Analyze and fix rows 422+
    fixed = 0
    could_not_fix = 0
    unchanged = 0
    fix_report = []
    
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 422:
            continue
        if len(row) < 3:
            continue
        
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        if not zh or not has_chinese(zh):
            continue
        
        if zh in truth:
            correct_en = truth[zh]
            if en != correct_en:
                row[2] = correct_en
                fixed += 1
                fix_report.append((line_no, row[0][:50], zh[:40], en[:40], correct_en[:40]))
        else:
            # zh not in truth - try the -1 shift heuristic
            if i > 0:
                prev_row = rows[i - 1]
                prev_zh = prev_row[1].strip() if len(prev_row[1]) > 1 else ""
                prev_en = prev_row[2].strip() if len(prev_row[2]) > 2 else ""
                
                # Check if prev_zh has a known correct en
                if prev_zh in truth:
                    correct_for_prev = truth[prev_zh]
                    if en == correct_for_prev:
                        # This row's en is actually prev row's translation. Try -1 shift.
                        # The correct en for this row might be in the next row
                        if i + 1 < len(rows):
                            next_en = rows[i + 1][2].strip() if len(rows[i + 1]) > 2 else ""
                            if not has_chinese(next_en) and next_en:
                                row[2] = next_en
                                fixed += 1
                                fix_report.append((line_no, row[0][:50], zh[:40], en[:40], next_en[:40]))
                            else:
                                # Last resort: look up zh in the FULL file for any alt en
                                alt_en = None
                                for j, r2 in enumerate(rows):
                                    if j != i and r2[1].strip() == zh and not has_chinese(r2[2].strip()) and r2[2].strip() != en:
                                        alt_en = r2[2].strip()
                                        break
                                if alt_en:
                                    row[2] = alt_en
                                    fixed += 1
                                    fix_report.append((line_no, row[0][:50], zh[:40], en[:40], alt_en[:40]))
                                else:
                                    could_not_fix += 1
                        else:
                            could_not_fix += 1
                    else:
                        unchanged += 1
                else:
                    could_not_fix += 1
    
    print(f"\nFix summary:")
    print(f"  Fixed: {fixed} rows")
    print(f"  Could not fix: {could_not_fix} rows")
    print(f"  Unchanged (already correct): {unchanged} rows")
    
    if fix_report:
        print(f"\n=== FIX REPORT (first 20) ===")
        for line_no, key, zh, old_en, new_en in fix_report[:20]:
            print(f"  L{line_no}: {key}")
            print(f"    zh: {zh}")
            print(f"    OLD en: {old_en}")
            print(f"    NEW en: {new_en}")
    
    # Write fixed file
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"\nWritten fixed file: {CSV_PATH}")
    
    # Verify specific problematic lines
    print("\n=== VERIFICATION ===")
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'),
        (424, '隐', 'Seclusion'),
        (425, '京', 'Capital'),
        (426, '狂笑不止，踽踽独行', 'Laughing uncontrollably, wandering alone'),
        (2835, '赴宴', 'Attend Banquet'),
        (2837, '京', 'Capital'),
        (2838, '隐', 'Seclusion'),
        (2839, '律法', 'Law & Order'),
        (2840, '泰山', 'Mount Tai'),
    ]
    for line_no, expected_zh, expected_en in checks:
        if line_no > len(rows):
            continue
        row = rows[line_no - 1]
        zh = row[1].strip()
        en = row[2].strip()
        zh_ok = "✅" if zh == expected_zh else "❌"
        en_ok = "✅" if en == expected_en else "❌"
        print(f"  L{line_no}: zh {zh_ok} en {en_ok} | zh='{zh[:50]}' en='{en[:50]}'")

if __name__ == "__main__":
    main()
