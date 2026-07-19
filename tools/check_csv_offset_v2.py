#!/usr/bin/env python3
"""Detect column misalignment: is en[row] actually the translation of zh[row-1]?"""

import csv
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in s)

def analyze():
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            rows.append((i + 1, row))  # 1-based

    # Check: for each row starting at row N, does en[row_N] make more sense
    # as translation of zh[row_{N-1}] rather than zh[row_N]?
    
    # Heuristic: compare string lengths and Chinese presence
    # If zh is short (a name) and en is also short, it's likely correct
    # If zh is short but en is long (description), something may be wrong
    
    print("=== CHECKING EN↔ZH PAIR COHERENCE AROUND LINE 420 ===")
    print("Looking for rows where zh is short (< 8 chars) but en is long (> 30 chars)")
    print("This suggests the short zh name is paired with some other row's description.\n")
    
    suspicious_lines = []
    for line_no, row in rows:
        if line_no < 400 or line_no > 500:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh and en:
            zh_short = len(zh) <= 8
            en_long = len(en) >= 30
            has_zh_in_en = has_chinese(en)
            if zh_short and en_long:
                suspicious_lines.append((line_no, row))
                print(f"  ⚠️ Line {line_no}: keys={row[0]}")
                print(f"     zh (SHORT, {len(zh)}c): {zh}")
                print(f"     en (LONG,  {len(en)}c): {en[:100]}")
                if line_no > 1:
                    prev = rows[line_no - 2]  # rows is 0-indexed
                    prev_zh = prev[1][1].strip() if len(prev[1]) > 1 and prev[1][1] else ""
                    prev_en = prev[1][2].strip() if len(prev[1]) > 2 and prev[1][2] else ""
                    print(f"     PREV ROW {line_no-1}: zh={prev_zh[:60]}")
                    print(f"     PREV ROW {line_no-1}: en={prev_en[:60]}")
    
    if not suspicious_lines:
        print("  (No suspicious short-zh/long-en pairs found in 400-500)")
    
    # More robust check: For each row where zh and en both exist,
    # check if en makes more sense for the previous row's zh
    print("\n\n=== PHASE 2: FULL AUTO-DETECTION OF OFFSET REGIONS ===")
    print("Algorithm: Check if en[row] + zh[row-1] form a better pair than en[row] + zh[row]")
    print("Heuristic: When zh[row] is short name, en[row] should also be short name.")
    print("When zh[row] is long description, en[row] should also be long.")
    
    offset_regions = []
    in_offset = False
    offset_start = None
    
    for idx, (line_no, row) in enumerate(rows[1:], start=0):  # skip header
        if line_no < 2:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        if not zh or not en:
            continue
        
        zh_len = len(zh)
        en_len = len(en)
        
        # Get previous row's zh
        prev_idx = idx - 1
        prev_zh = ""
        if prev_idx >= 0:
            prev_row = rows[prev_idx + 1]  # +1 because rows[0] is header
            prev_zh = prev_row[1][1].strip() if len(prev_row[1]) > 1 and prev_row[1][1] else ""
        
        # Detect: zh is long description but en is short name
        # This strongly suggests en belongs to a different row
        zh_is_long = zh_len > 15
        en_is_short = en_len < 10 and not has_chinese(en)
        zh_is_short = zh_len < 8
        en_is_long = en_len > 20
        
        is_misaligned = False
        if zh_is_long and en_is_short:
            is_misaligned = True
        elif zh_is_short and en_is_long:
            is_misaligned = True
        
        if is_misaligned and not in_offset:
            in_offset = True
            offset_start = line_no
        elif not is_misaligned and in_offset:
            offset_regions.append((offset_start, line_no - 1))
            in_offset = False
    
    if in_offset:
        offset_regions.append((offset_start, len(rows)))
    
    if offset_regions:
        print(f"\nFound {len(offset_regions)} potentially misaligned region(s):")
        for start, end in offset_regions:
            print(f"  Lines {start} - {end}  ({end - start + 1} rows)")
    else:
        print("\nNo misaligned regions detected by length heuristic.")

    # Phase 3: Direct comparison - for the suspicious area, show side-by-side
    print("\n\n=== PHASE 3: TARGETED SIDE-BY-SIDE (Lines 415-450) ===")
    print(f"{'Line':>5} | {'keys':<55} | {'zh':<40} | {'en':<40}")
    print("-" * 150)
    for line_no, row in rows:
        if 415 <= line_no <= 450:
            keys = row[0][:53] if len(row) > 0 else ""
            zh = row[1][:38] if len(row) > 1 and row[1] else ""
            en = row[2][:38] if len(row) > 2 and row[2] else ""
            ja = row[3][:20] if len(row) > 3 and row[3] else ""
            marker = ""
            if line_no == 422:
                marker = " ← START OF SHIFT?"
            print(f"{line_no:5d} | {keys:<55} | {zh:<40} | {en:<40} {marker}")

    # Phase 4: Find if the shift ends somewhere
    print("\n\n=== PHASE 4: HUNT FOR END OF SHIFT (Lines 420-600) ===")
    print("Looking for positions where alignment seems to restore...")
    
    # Check pairs where zh is a CODE_ or EVT_ pattern with short name + en is short
    # and they actually match (e.g., "才华" ↔ "Talent")
    known_pairs = {
        "才华": "Talent",
        "城府": "Cunning", 
        "定力": "Composure",
        "春": "Spring",
        "夏": "Summer",
        "秋": "Autumn",
        "冬": "Winter",
        "钱": "Wealth",
        "名": "Fame",
        "势": "Influence",
        "健": "Health",
        "才": "Talent",
        "兴": "Inspiration",
        "望": "Reputation",
        "府": "Residence",
        "途": "Journey",
        "时": "Time",
        "季": "Season",
        "孟": "Early",
        "仲": "Mid",
    }
    
    for line_no, row in rows:
        if line_no < 420 or line_no > 600:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh in known_pairs and en in known_pairs.values():
            expected_en = known_pairs[zh]
            actual_en = en
            match = "✅" if actual_en == expected_en else "❌ MISMATCH"
            print(f"  Line {line_no}: zh='{zh}' en='{en}' (expected en='{expected_en}') {match}")

if __name__ == "__main__":
    analyze()
