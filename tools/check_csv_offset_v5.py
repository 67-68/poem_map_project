#!/usr/bin/env python3
"""
Find the exact transition point(s) where en offset direction changes.
Check: does en[row] match zh[row-1] or zh[row+1]?
"""

import csv
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

has_chinese = lambda s: any('\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf' for c in s)

# Ground truth pairs (from lines 1-421 which are verified correct)
gt_pairs = {
    "才华": "Talent", "城府": "Cunning", "定力": "Composure",
    "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
    "钱": "Wealth", "名": "Fame", "势": "Influence",
    "健": "Health", "才": "Talent", "兴": "Inspiration",
    "望": "Reputation", "府": "Residence", "途": "Journey",
    "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
    "京": "Capital", "隐": "Seclusion", "律法": "Law & Order",
    "泰山": "Mount Tai", "标题": "Title",
    "狂笑不止，踽踽独行": "Laughing uncontrollably, wandering alone",
    "条件不满足：": "Requirements not met:",
    "时间不足（剩余%d天，需要%s）": "Insufficient time (%d days remaining, need %s)",
    "赴宴": "Attend Banquet",
}

def analyze():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    print(f"Total rows: {len(rows)}\n")
    
    # For every zh in gt_pairs, find which line has that zh, and where its correct en is
    print("=== TRACKING gt_pair TRANSLATIONS ===")
    print(f"{'zh':<30} | {'zh_line':>7} | {'correct_en':<45} | {'en_at_zh_line':<45} | {'en_at_zh+1':<45} | {'en_at_zh-1':<45}")
    print("-" * 220)
    
    for zh, correct_en in sorted(gt_pairs.items(), key=lambda x: x[1]):
        zh_line = None
        en_line = None
        for i, row in enumerate(rows):
            line_no = i + 1
            if row[1].strip() == zh:
                zh_line = line_no
            if row[2].strip() == correct_en:
                en_line = line_no
        
        if zh_line is None or en_line is None:
            continue
        
        en_at_zh = rows[zh_line - 1][2].strip()
        en_at_prev = rows[zh_line - 2][2].strip() if zh_line > 1 else ""
        en_at_next = rows[zh_line][2].strip() if zh_line < len(rows) - 1 else ""
        
        offset = en_line - zh_line
        status = ""
        if en_at_zh == correct_en:
            status = "✅ ALIGNED"
        elif en_at_prev == correct_en:
            status = "🔴 SHIFTED DOWN (en at zh-1)"
        elif en_at_next == correct_en:
            status = "🔵 SHIFTED UP (en at zh+1)"
        else:
            status = f"❓ OFFSET={offset:+d}"
        
        print(f"{zh:<30} | {zh_line:>7d} | {correct_en:<45} | {en_at_zh:<45} | {en_at_next:<45} | {en_at_prev:<45} | {status}")
    
    # Now check every row for the direction of shift
    print("\n\n=== OFFSET DIRECTION PER ROW (using gt_pairs only) ===")
    print(f"{'Line':>6} | {'zh':<35} | {'en':<45} | {'DIRECTION'}")
    print("-" * 130)
    
    for i, row in enumerate(rows):
        line_no = i + 1
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh not in gt_pairs:
            continue
        correct = gt_pairs[zh]
        
        if en == correct:
            direction = "OK"
        else:
            # Check prev row
            prev_zh = rows[i - 1][1].strip() if i > 0 else ""
            if prev_zh in gt_pairs and en == gt_pairs[prev_zh]:
                direction = "DOWN (en=prev_zh_translation)"
            else:
                next_zh = rows[i + 1][1].strip() if i + 1 < len(rows) else ""
                if next_zh in gt_pairs and en == gt_pairs[next_zh]:
                    direction = "UP (en=next_zh_translation)"
                else:
                    direction = f"UNKNOWN (correct={correct})"
        
        if line_no >= 420 or direction != "OK":
            print(f"{line_no:>6d} | {zh:<35} | {en:<45} | {direction}")
    
    # EXTENDED ANALYSIS: For EVERY row from 420-450 and 2825-2874, check offset
    print("\n\n=== FULL TRACKING: Where is each corrected en? (lines 420-460) ===")
    for li in range(420, 461):
        row = rows[li - 1]
        keys = row[0]
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        
        # Find where this zh's correct en is
        if not zh or not has_chinese(zh) or not en:
            continue
        
        found_alt = None
        for j, r2 in enumerate(rows):
            en2 = r2[2].strip() if len(r2) > 2 else ""
            zh2 = r2[1].strip() if len(r2) > 1 else ""
            if zh2 == zh and en2 != en and not has_chinese(en2):
                found_alt = (j + 1, en2)
                break
        
        if found_alt:
            offset = found_alt[0] - li
            print(f"  L{li}: zh='{zh[:50]}' en='{en[:50]}' | alt_en='{found_alt[1][:50]}' at L{found_alt[0]} (offset={offset:+d})")
    
    print("\n\n=== FULL TRACKING: Lines 2825-2873 ===")
    for li in range(2825, 2874):
        if li > len(rows):
            break
        row = rows[li - 1]
        keys = row[0]
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        
        if not zh or not en:
            continue
        
        # Find any row with same zh and different en
        found_alt = None
        for j, r2 in enumerate(rows):
            en2 = r2[2].strip() if len(r2) > 2 else ""
            zh2 = r2[1].strip() if len(r2) > 1 else ""
            if zh2 == zh and en2 != en and not has_chinese(en2):
                found_alt = (j + 1, en2)
                break
        
        if found_alt:
            offset = found_alt[0] - li
            print(f"  L{li}: zh='{zh[:60]}' en='{en[:60]}' | alt at L{found_alt[0]} (offset={offset:+d}): '{found_alt[1][:60]}'")
        else:
            # Might be unique - check if it makes sense
            print(f"  L{li}: zh='{zh[:60]}' en='{en[:60]}' | (unique, no alt found)")

    # Final: check the transition around the area where the early offset pattern should flip
    print("\n\n=== HUNTING FOR THE TRANSITION POINT ===")
    # At lines 422-4xx, en[row] = correct for zh[row-1] (DOWN)
    # At lines 283x, en[row] = correct for zh[row+1] (UP)
    # There must be a point where a row was deleted/inserted causing this reversal
    
    # Check: for the original correct file, what would be the proper en at each row?
    # The correct en for zh[row] should match the en that was originally at that row
    
    # Actually, let's find pairs that appear TWICE in the file
    print("\nChecking for duplicated zh values and their en shifts...")
    zh_seen = {}
    for i, row in enumerate(rows):
        line_no = i + 1
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            if zh in zh_seen:
                prev_line, prev_en = zh_seen[zh]
                if prev_en != en:
                    print(f"  DUPLICATE zh='{zh[:40]}': L{prev_line} en='{prev_en[:40]}' vs L{line_no} en='{en[:40]}'")
                    zh_seen[zh] = (line_no, en)  # update
            else:
                zh_seen[zh] = (line_no, en)

if __name__ == "__main__":
    analyze()
