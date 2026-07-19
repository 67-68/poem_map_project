#!/usr/bin/env python3
"""
Fix _dynamic_events.csv: en column is shifted down by 1 row from line 422 to EOF.
For each row i (422 ≤ i ≤ N-1): en[i] should be the value currently at en[i+1].
The last row's en becomes empty.
"""

import csv
import shutil
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BACKUP_PATH = CSV_PATH.with_suffix(".csv.bak")

SHIFT_START = 422  # 1-based line number where en offset begins

def main():
    # Read all rows
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    
    print(f"Read {len(rows)} rows from {CSV_PATH}")
    header = rows[0]
    data_rows = rows[1:]
    
    assert header == ['keys', 'zh', 'en', 'ja'], f"Unexpected header: {header}"
    assert len(data_rows[-1]) == 4, f"Last row has {len(data_rows[-1])} cols: {data_rows[-1]}"
    
    # Backup
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"Backup saved to {BACKUP_PATH}")
    
    # SHIFT_START is 1-based. Row index in data_rows is SHIFT_START - 2
    start_idx = SHIFT_START - 2  # 0-based index into data_rows
    
    print(f"Shift starts at CSV line {SHIFT_START} (data_rows index {start_idx})")
    
    # Show preview of what will change
    print("\n=== PREVIEW (first 10 affected rows) ===")
    for i in range(start_idx, min(start_idx + 10, len(data_rows))):
        old_en = data_rows[i][2]
        new_en = data_rows[i + 1][2] if i + 1 < len(data_rows) else ""
        zh = data_rows[i][1]
        keys = data_rows[i][0]
        print(f"  Line {i+2}: keys={keys[:55]}")
        print(f"    zh: {zh[:80]}")
        print(f"    OLD en: {old_en[:80]}")
        print(f"    NEW en: {new_en[:80]}")
        print()
    
    # Apply fix: shift en column up by 1
    for i in range(start_idx, len(data_rows)):
        if i + 1 < len(data_rows):
            data_rows[i][2] = data_rows[i + 1][2]
        else:
            # Last row: use its own ja value (which is typically empty) or keep whatever
            data_rows[i][2] = ""
    
    print(f"Fixed {len(data_rows) - start_idx} rows")
    
    # Write fixed CSV
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(data_rows)
    
    print(f"Written fixed CSV to {CSV_PATH}")
    
    # Verify a few known pairs
    print("\n=== VERIFICATION (known pairs after fix) ===")
    known_pairs = {
        "才华": "Talent", "城府": "Cunning", "定力": "Composure",
        "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
        "钱": "Wealth", "名": "Fame", "势": "Influence",
        "健": "Health", "才": "Talent", "兴": "Inspiration",
        "望": "Reputation", "府": "Residence", "途": "Journey",
        "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
    }
    ok = 0
    fail = 0
    for i, row in enumerate(data_rows):
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh in known_pairs:
            expected = known_pairs[zh]
            if en == expected:
                ok += 1
            else:
                fail += 1
                print(f"  ❌ Line {i+2}: zh='{zh}' en='{en}' (expected '{expected}')")
    
    print(f"  Verified: {ok} correct, {fail} wrong")
    
    # Verify specific known-broken lines
    print("\n=== SPECIFIC FIX VERIFICATION ===")
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'),
        (424, '隐', 'Seclusion'),
        (425, '京', 'Capital'),
        (426, '狂笑不止，踽踽独行', 'Laughing uncontrollably, wandering alone'),
    ]
    for line_no, expected_zh, expected_en in checks:
        row = data_rows[line_no - 2]
        actual_zh = row[1]
        actual_en = row[2]
        zh_ok = actual_zh == expected_zh
        en_ok = actual_en == expected_en
        status = "✅" if (zh_ok and en_ok) else "❌"
        print(f"  {status} Line {line_no}: zh='{actual_zh[:60]}' en='{actual_en[:60]}'")

if __name__ == "__main__":
    main()
