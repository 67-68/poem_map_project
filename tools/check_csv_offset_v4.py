#!/usr/bin/env python3
"""
Full file offset analysis: check if the offset is uniform across the entire file
or if there are multiple offset regions.
"""

import csv
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in s)

def analyze():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    
    header = rows[0]
    print(f"Header: {header}, {len(rows)} rows total\n")
    
    # Define ground-truth pairs (zh ↔ correct en)
    # These are KNOWN CORRECT translations
    gt_pairs = {
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
        "京": "Capital",
        "隐": "Seclusion",
        "律法": "Law & Order",
        "泰山": "Mount Tai",
        "标题": "Title",
        "例子": "Example",
        "查看": "View",
        "行动": "Actions",
        "赴宴": "Attend Banquet",
        "确认": "Confirm",
    }
    
    # For every row, check if it appears in ANY position that could be:
    # - Correct: en matches gt_pairs[zh]
    # - Offset by -1: en matches gt_pairs[prev_zh]  
    # - Offset by +1: en matches gt_pairs[next_zh]
    # - Offset by N: en matches gt_pairs[zh_N_rows_away]
    
    print("=== ANALYZING ALL gt_pair MATCHES ===")
    print(f"{'Line':>5} | {'keys':<55} | {'zh':<35} | {'en':<40} | {'STATUS'}")
    print("-" * 155)
    
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 2:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        if zh not in gt_pairs:
            continue
        
        expected = gt_pairs[zh]
        if en == expected:
            status = "✅ CORRECT"
            print(f"{line_no:5d} | {row[0]:<55} | {zh:<35} | {en:<40} | {status}")
        else:
            # Find where the correct en ACTUALLY is
            found_at = None
            for j, row2 in enumerate(rows):
                if row2[2].strip() == expected:
                    found_at = j + 1
                    break
            if found_at:
                offset = found_at - line_no
                status = f"❌ OFFSET={offset:+d} (correct en at line {found_at})"
            else:
                status = f"❌ MISSING (correct en '{expected}' not found anywhere)"
            print(f"{line_no:5d} | {row[0]:<55} | {zh:<35} | {en:<40} | {status}")

    # Now check the end of file specifically
    print("\n\n=== ZOOM: Lines 2825-2874 (UI section) ===")
    print(f"{'Line':>5} | {'keys':<55} | {'zh':<40} | {'en':<40} | {'OFFSET STATUS'}")
    print("-" * 160)
    
    gt_map = {}  # map zh → correct en
    for k, v in gt_pairs.items():
        gt_map[k] = v
    
    for i, row in enumerate(rows):
        line_no = i + 1
        if not (2825 <= line_no <= 2874):
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        
        if zh in gt_map:
            expected = gt_map[zh]
            if en == expected:
                status = "✅"
            else:
                # Find where correct en is
                found = None
                for j, r2 in enumerate(rows):
                    if r2[2].strip() == expected:
                        found = j + 1
                        break
                status = f"❌ correct='{expected}' at L{found} (offset={found - line_no:+d})" if found else f"❌ missing '{expected}'"
        else:
            status = "(not in gt_pairs)"
        
        print(f"{line_no:5d} | {row[0]:<55} | {zh:<40} | {en:<40} | {status}")

    # Find consecutive offset patterns at end of file
    print("\n\n=== SEARCH FOR CONSECUTIVE ALIGNED BLOCKS (lines 400-2873) ===")
    # Use more comprehensive known pairs
    
    # Extended known pairs from the full file
    extended_pairs = {}
    # Collect from lines 1-419 which are known to be correct
    for i, row in enumerate(rows):
        line_no = i + 1
        if not (2 <= line_no <= 419):
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            extended_pairs[zh] = en
    
    # Now check how many rows after 422 have en matching extended_pairs[zh]
    aligned = 0
    misaligned = 0
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 422 or line_no > 2873:
            continue
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if not zh or not en:
            continue
        if has_chinese(zh) and not has_chinese(en):
            if en == extended_pairs.get(zh, ""):
                aligned += 1
                if aligned <= 5:
                    print(f"  Line {line_no}: ✅ ALIGNED: zh='{zh[:40]}' en='{en[:40]}'")
            else:
                misaligned += 1
                if misaligned <= 30:
                    # Show what the correct en should be and where it is
                    correct_en = extended_pairs.get(zh, "UNKNOWN")
                    found_at = "N/A"
                    for j, r2 in enumerate(rows):
                        if r2[2].strip() == correct_en:
                            found_at = str(j + 1)
                            break
                    print(f"  Line {line_no}: ❌ MISALIGNED: zh='{zh[:40]}' en='{en[:40]}' | correct='{correct_en[:40]}' at L{found_at}")
    
    print(f"\n  Summary: {aligned} aligned, {misaligned} misaligned (lines 422-2873)")

if __name__ == "__main__":
    analyze()
