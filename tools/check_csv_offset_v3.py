#!/usr/bin/env python3
"""
Comprehensive offset detection and fix for _dynamic_events.csv.
Detects: en column offset by 1 starting from a specific line.
Outputs detailed analysis and optionally generates fixed CSV.
"""

import csv
import sys
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
OUT_PATH = CSV_PATH.parent / "_dynamic_events_fixed.csv"

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in s)

def load_csv():
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            rows.append((i + 1, row))
    return rows

def find_shift_start(rows):
    """Find the exact line where en offset by -1 begins."""
    
    # Pairs where zh and en should match closely (short property names)
    known_pairs = {
        "才华": "Talent", "城府": "Cunning", "定力": "Composure",
        "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
        "钱": "Wealth", "名": "Fame", "势": "Influence",
        "健": "Health", "才": "Talent", "兴": "Inspiration",
        "望": "Reputation", "府": "Residence", "途": "Journey",
        "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
    }
    
    # For each row, check: does en[row] match zh[row]'s known translation,
    # or does en[row] match zh[row-1]'s known translation?
    
    results = []
    for idx, (line_no, row) in enumerate(rows):
        if line_no < 2:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        # Get previous row's zh
        prev_zh = ""
        if idx > 1:
            prev_row = rows[idx - 1]
            prev_zh = prev_row[1][1].strip() if len(prev_row[1]) > 1 and prev_row[1][1] else ""
        
        if zh in known_pairs:
            expected = known_pairs[zh]
            if en == expected:
                results.append((line_no, "ALIGNED", zh, en, ""))
            elif prev_zh in known_pairs and en == known_pairs[prev_zh]:
                results.append((line_no, "OFFSET-1", zh, en, f"(en is for '{prev_zh}'='{expected}')"))
            else:
                results.append((line_no, "MISMATCH", zh, en, f"(expected '{expected}')"))
    
    return results

def verify_offset_consistency(rows, shift_start):
    """For every row from shift_start to end, verify en[row] = translation of zh[row-1]."""
    
    # Use the known pairs as ground truth
    known_pairs = {
        "才华": "Talent", "城府": "Cunning", "定力": "Composure",
        "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
        "钱": "Wealth", "名": "Fame", "势": "Influence",
        "健": "Health", "才": "Talent", "兴": "Inspiration",
        "望": "Reputation", "府": "Residence", "途": "Journey",
        "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
    }
    
    aligned_count = 0
    offset_count = 0
    mismatch_count = 0
    first_mismatch = None
    
    for idx, (line_no, row) in enumerate(rows):
        if line_no < shift_start or line_no < 2:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        prev_zh = ""
        if idx > 0:
            prev_row = rows[idx - 1]
            prev_zh = prev_row[1][1].strip() if len(prev_row[1]) > 1 and prev_row[1][1] else ""
        
        if zh in known_pairs:
            expected_self = known_pairs[zh]
            expected_prev = known_pairs.get(prev_zh, "")
            
            if en == expected_self:
                aligned_count += 1
            elif expected_prev and en == expected_prev:
                offset_count += 1
            else:
                mismatch_count += 1
                if first_mismatch is None:
                    first_mismatch = (line_no, zh, en, expected_self)
    
    return aligned_count, offset_count, mismatch_count, first_mismatch

def find_shift_end(rows):
    """Check if the offset ever realigns (i.e., a region where en is correct again)."""
    known_pairs = {
        "才华": "Talent", "城府": "Cunning", "定力": "Composure",
        "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
        "钱": "Wealth", "名": "Fame", "势": "Influence",
        "健": "Health", "才": "Talent", "兴": "Inspiration",
        "望": "Reputation", "府": "Residence", "途": "Journey",
        "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
    }
    
    state = None  # None=before shift, 'shifted'=in shift, 'aligned'=after realignment
    transitions = []
    
    for idx, (line_no, row) in enumerate(rows):
        if line_no < 2 or line_no < 400:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        prev_zh = ""
        if idx > 0:
            prev_row = rows[idx - 1]
            prev_zh = prev_row[1][1].strip() if len(prev_row[1]) > 1 and prev_row[1][1] else ""
        
        if zh not in known_pairs:
            continue
        
        expected_self = known_pairs[zh]
        expected_prev = known_pairs.get(prev_zh, "")
        
        current = 'aligned' if en == expected_self else ('shifted' if (expected_prev and en == expected_prev) else 'unknown')
        
        if state != current:
            transitions.append((line_no, state, current, zh, en))
            state = current
    
    return transitions

def main():
    rows = load_csv()
    print(f"Loaded {len(rows)} rows (including header)")
    
    # Step 1: Find shift start
    print("\n" + "=" * 80)
    print("STEP 1: FIND SHIFT START (checking known pairs)")
    print("=" * 80)
    results = find_shift_start(rows)
    
    aligned_before = []
    shifted_after = []
    for line_no, status, zh, en, note in results:
        if status == "ALIGNED" and line_no < 430:
            aligned_before.append((line_no, zh, en))
        if status == "OFFSET-1" and line_no < 450:
            shifted_after.append((line_no, zh, en, note))
    
    for ln, zh, en in aligned_before:
        print(f"  Line {ln}: ✅ ALIGNED: zh='{zh}' ↔ en='{en}'")
    
    shift_start = None
    for ln, zh, en, note in shifted_after:
        if shift_start is None:
            shift_start = ln
        print(f"  Line {ln}: 🔴 OFFSET-1: zh='{zh}' en='{en}' {note}")
    
    if shift_start:
        # The actual shift in en column starts at shift_start
        # But the "cause" might be one row earlier
        print(f"\n  → Shift detected starting at line {shift_start}")
        print(f"  → This means en on line {shift_start} belongs to zh on line {shift_start - 1}")
    else:
        print("No shift detected in known pairs range (400-450)")
    
    # Step 2: Verify offset consistency after shift_start
    if shift_start:
        print("\n" + "=" * 80)
        print(f"STEP 2: VERIFY OFFSET CONSISTENCY (lines {shift_start}-{len(rows)})")
        print("=" * 80)
        aligned, offset, mismatch, first_mm = verify_offset_consistency(rows, shift_start)
        total = aligned + offset + mismatch
        print(f"  Aligned with own zh: {aligned} ({aligned/total*100:.1f}%)")
        print(f"  Offset by -1 (en matches prev zh): {offset} ({offset/total*100:.1f}%)")
        print(f"  Neither: {mismatch} ({mismatch/total*100:.1f}%)")
        if first_mm:
            print(f"  First mismatch: Line {first_mm[0]}, zh='{first_mm[1]}', en='{first_mm[2]}' (expected '{first_mm[3]}')")
    
    # Step 3: Find if shift ever ends
    print("\n" + "=" * 80)
    print("STEP 3: STATE TRANSITIONS (does shift ever realign?)")
    print("=" * 80)
    transitions = find_shift_end(rows)
    for line_no, old_state, new_state, zh, en in transitions[:20]:
        print(f"  Line {line_no}: {old_state} → {new_state}  zh='{zh}' en='{en}'")
    
    # Step 4: Check for "normal" rows within shifted region (30 random samples)
    if shift_start:
        print("\n" + "=" * 80)
        print(f"STEP 4: RANDOM SAMPLING WITHIN SHIFTED REGION (lines {shift_start}-{len(rows)})")
        print("=" * 80)
        import random
        random.seed(42)
        shifted_rows = [(i, rows[i]) for i in range(shift_start - 1, len(rows))]
        sample = random.sample(shifted_rows, min(30, len(shifted_rows)))
        
        offset_samples = 0
        aligned_samples = 0
        for idx, (line_no, row) in sorted(sample, key=lambda x: x[0]):
            zh = row[1].strip() if len(row) > 1 and row[1] else ""
            en = row[2].strip() if len(row) > 2 and row[2] else ""
            
            prev_zh = ""
            if idx > 0:
                prev_row = rows[idx - 1]
                prev_zh = prev_row[1][1].strip() if len(prev_row[1]) > 1 and prev_row[1][1] else ""
            
            # Heuristic: if zh is long (>15) and en is short (<10 non-Chinese), likely offset
            zh_is_long = len(zh) > 15
            en_is_short_name = len(en) < 12 and not has_chinese(en)
            en_is_long = len(en) > 20
            
            likely_offset = (zh_is_long and en_is_short_name) or (len(zh) < 6 and en_is_long)
            
            if likely_offset:
                offset_samples += 1
                flag = "🔴 OFFSET"
            else:
                # Check more carefully
                zh_has_chinese = has_chinese(zh)
                en_has_chinese = has_chinese(en)
                if not en_has_chinese and zh_has_chinese and len(zh) > 10 and len(en) < 8:
                    offset_samples += 1
                    flag = "🔴 OFFSET"
                elif zh_has_chinese and len(zh) < 10 and len(en) > 20:
                    offset_samples += 1
                    flag = "🔴 OFFSET"
                else:
                    aligned_samples += 1
                    flag = "🟢 MAYBE OK"
            
            print(f"\n  Line {line_no}: {flag}")
            print(f"    keys: {row[0][:70]}")
            print(f"    zh   ({len(zh)}c): {zh[:100]}")
            print(f"    en   ({len(en)}c): {en[:100]}")
            if prev_zh:
                print(f"    prev_zh: {prev_zh[:80]}")
        
        print(f"\n  Summary: {offset_samples} offset, {aligned_samples} possibly aligned out of {len(sample)} samples")
    
    # Step 5: Print conclusion
    print("\n" + "=" * 80)
    print("CONCLUSION")
    print("=" * 80)
    
    if shift_start and offset > 0 and aligned == 0:
        print(f"""
The en column is CONSISTENTLY OFFSET BY 1 ROW from line {shift_start} to the end of file.
Each row's en field is the translation of the PREVIOUS row's zh field.

To fix: Take all rows from line {shift_start} to line {len(rows)}, and shift each en value UP by one row.
(i.e., move en[line_{shift_start}] to en[line_{shift_start}]'s proper position)

Equivalently: Starting at line {shift_start}, set en[row] = "the en value currently on row+1",
and set the last row's en to empty (or copy from original).

The CSV has {len(rows) - 1} data rows. The shift affects lines {shift_start} through {len(rows)} ({len(rows) - shift_start + 1} rows).
""")
    elif aligned > 0:
        print(f"\nMixed results: {aligned} aligned, {offset} offset. The offset is not uniform.")
        print("Need more detailed analysis.")
    else:
        print("Could not determine shift pattern definitively.")

if __name__ == "__main__":
    main()
