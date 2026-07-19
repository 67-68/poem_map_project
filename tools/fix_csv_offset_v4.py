#!/usr/bin/env python3
"""
Comprehensive fix for _dynamic_events.csv:
1. Lines 422-2623: shift en up by 1 (standard -1 offset fix)
2. Lines 2624+ (TUT section): manual fix using careful extraction from backup
3. Lines 2835+: final UI section: fix remaining issues
"""

import csv, io, shutil, sys
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak")

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' for c in s)

def main():
    shutil.copy2(BAK_PATH, CSV_PATH)
    
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    print(f"Read {len(rows)} logical rows from backup")
    
    # Phase 1: Standard -1 shift for rows 422-2623 (before TUT section)
    SHIFT_END = 2623
    for i in range(421, min(SHIFT_END, len(rows) - 1)):
        if i + 1 < len(rows):
            rows[i][2] = rows[i + 1][2]
    print(f"Phase 1: shifted en up by 1 from L422 to L{SHIFT_END}")
    
    # Phase 2: Fix TUT section (keys starting with TRES_TUT_)
    # These have multi-line fields causing variable offset
    # We extract the correct en from the backup by finding where each zh's
    # correct en is located
    
    # Build map of all zh→en from the ENTIRE backup
    zh_to_en = {}
    for row in rows:
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            zh_to_en[zh] = en
    
    # For TUT entries, zh values are unique. Find correct en.
    tut_fixed = 0
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 2624 or line_no > 2705:
            continue
        key = row[0]
        if not key.startswith("TRES_TUT_"):
            continue
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if not zh or not has_chinese(zh):
            continue
        
        # The correct en for this zh is somewhere else in the file
        # For multi-line DESCRIPTION_1/ML entries, the zh contains the full text
        # Find the row in backup that has the same key and extract en from the
        # row AFTER the expected position
        
        # Heuristic: find any row with same zh that has a different en
        for j, r2 in enumerate(rows):
            zh2 = r2[1].strip() if len(r2) > 1 else ""
            en2 = r2[2].strip() if len(r2) > 2 else ""
            if zh2 == zh and en2 != en and not has_chinese(en2) and en2:
                # This is likely the correct en
                rows[i][2] = en2
                tut_fixed += 1
                if tut_fixed <= 10:
                    print(f"  TUT fix L{line_no}: {key} zh='{zh[:30]}' en='{en2[:50]}'")
                break
    
    print(f"Phase 2: fixed {tut_fixed} TUT entries via zh lookup")
    
    # Phase 3: Apply ground truth fix for remaining known mismatches
    # (lines 422+ only)
    gt = {
        "才华": "Talent", "城府": "Cunning", "定力": "Composure",
        "春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter",
        "钱": "Wealth", "名": "Fame", "势": "Influence",
        "健": "Health", "才": "Talent", "兴": "Inspiration",
        "望": "Reputation", "府": "Residence", "途": "Journey",
        "时": "Time", "季": "Season", "孟": "Early", "仲": "Mid",
        "京": "Capital", "隐": "Seclusion", "律法": "Law & Order",
        "泰山": "Mount Tai", "标题": "Title", "例子": "Example",
        "查看": "View", "行动": "Actions",
        "赴宴": "Attend Banquet", "确认": "Confirm",
        "条件不满足：": "Requirements not met:",
        "时间不足（剩余%d天，需要%s）": "Insufficient time (%d days remaining, need %s)",
        "产：无": "Yield: None", "险：": "Risk:", "耗：无": "Cost: None",
        "或": "or", "未知": "Unknown", "未知状态": "Unknown State",
        "需要「%d(%s)」": 'Requires "%d(%s)"',
        "暂时无法执行此行动": "Cannot perform this action right now",
        "杜甫": "Du Fu", "李白": "Li Bai", "王维": "Wang Wei",
        "高适": "Gao Shi", "郑虔": "Zheng Qian",
        "平康坊": "Pingkang Ward", "皇城": "Imperial City",
        "权贵": "Aristocrat", "中断": "Interrupt",
        "合上考评": "Overall Assessment",
        "「 既决：%s 」": "「 Resolved: %s 」",
        "卖诗": "Sell Poems", "以诗换名": "Trade verse for renown",
        "携诗拜谒": "Poem Visit", "西市": "West Market",
        "登高抒怀": "Climb High, Vent Feelings",
        "干谒权贵": "Seek Patronage from the Powerful",
        "代价是...": "The Cost Is...",
        "开始创作": "Begin Composing", "撕毁卷轴": "Tear Scroll",
        "跳过": "Skip", "开始引导": "Begin Tutorial",
        "存档1": "Save 1", "保存到此": "Save Here",
        "依此加载": "Load from Here",
        "继续游戏": "Resume", "返回主菜单": "Return to Main Menu",
        "退出观测": "Exit Observation", "系统": "System",
    }
    
    gt_fixed = 0
    for i, row in enumerate(rows):
        line_no = i + 1
        if line_no < 2 or line_no < 422:
            continue
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh in gt and has_chinese(zh) and en != gt[zh]:
            rows[i][2] = gt[zh]
            gt_fixed += 1
    
    print(f"Phase 3: fixed {gt_fixed} entries via ground truth")
    
    # Write output
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"Written: {CSV_PATH}")
    
    # Verify
    print("\n=== KEY VERIFICATION ===")
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'), (424, '隐', 'Seclusion'), (425, '京', 'Capital'),
        (427, '才华', 'Talent'), (429, '城府', 'Cunning'), (441, '冬', 'Winter'),
        (2646, '我来游历天下，增长见识', 'I travel the realm to broaden my understanding.'),
        (2647, '我来寻找作诗的灵感', 'I have come seeking inspiration for my poetry.'),
        (2652, '泰山脚下', 'At the Foot of Mount Tai'),
        (2681, '山顶被大雾罩着，什么也看不见', None),  # just check it exists
        (2798, '泰山', 'Mount Tai'),
        (2835, '赴宴', 'Attend Banquet'),
        (2837, '京', 'Capital'), (2838, '隐', 'Seclusion'),
        (2839, '律法', 'Law & Order'), (2840, '泰山', 'Mount Tai'),
        (2866, '返回主菜单', 'Return to Main Menu'),
        (2871, '退出观测', 'Exit Observation'),
    ]
    
    ok = fail = 0
    for ln, exp_zh, exp_en in checks:
        if ln > len(rows): continue
        row = rows[ln-1]
        zh = row[1].strip()[:80]
        en = row[2].strip()[:80]
        zh_ok = zh == exp_zh
        en_ok = (exp_en is None) or (en == exp_en)
        if zh_ok and en_ok:
            ok += 1
            if exp_en: print(f"  L{ln}: ✅ zh='{zh[:40]}' en='{en[:40]}'")
        else:
            fail += 1
            print(f"  L{ln}: ❌ zh='{zh[:60]}' en='{en[:60]}' (exp: zh='{exp_zh[:40]}' en='{(exp_en or '')[:40]}')")
    
    print(f"\n  {ok} OK, {fail} FAIL")

if __name__ == "__main__":
    main()
