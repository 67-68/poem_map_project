#!/usr/bin/env python3
"""
Clean fix: shift en up by 1 from line 422 to the end of the file.
Then apply ground truth for known discrepancies.
"""

import csv, shutil
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak")

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' for c in s)

def main():
    # Restore from original backup
    shutil.copy2(BAK_PATH, CSV_PATH)
    
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    print(f"Logical rows: {len(rows)}")
    
    # Phase 1: Shift en up by 1 from line 422 to line 2872 (all data rows)
    for i in range(421, len(rows) - 1):
        if i + 1 < len(rows):
            rows[i][2] = rows[i + 1][2]
    # Last row: set en to empty (was last, now nothing to shift into it)
    rows[-1][2] = ""
    print("Phase 1: Shifted en up by 1 from L422 to L2873")
    
    # Phase 2: Ground truth corrections
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
        "携诗拜谒": "Poem Visit",
        "西市": "West Market", "清流": "Pure Stream",
        "登高抒怀": "Climb High, Vent Feelings",
        "干谒权贵": "Seek Patronage from the Powerful",
        "代价是...": "The Cost Is...",
        "开始创作": "Begin Composing", "撕毁卷轴": "Tear Scroll",
        "跳过": "Skip", "开始引导": "Begin Tutorial",
        "存档1": "Save 1", "保存到此": "Save Here",
        "依此加载": "Load from Here",
        "继续游戏": "Resume", "返回主菜单": "Return to Main Menu",
        "退出观测": "Exit Observation", "系统": "System",
        "上旬": "Early Month",
        "曾状态": "Status", "决议": "Decrees",
        "交游 · 赴宴": "Socialize · Banquet",
    }
    
    gt_fixed = 0
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 2:
            continue
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh in gt and has_chinese(zh) and en != gt[zh]:
            rows[i][2] = gt[zh]
            gt_fixed += 1
    
    print(f"Phase 2: Ground truth fix for {gt_fixed} entries")
    
    # Write
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"Written: {CSV_PATH}")
    
    # Verify
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'), (424, '隐', 'Seclusion'), (425, '京', 'Capital'),
        (427, '才华', 'Talent'), (429, '城府', 'Cunning'), (441, '冬', 'Winter'),
        (2646, '我来游历天下，增长见识', 'I travel the realm to broaden my understanding.'),
        (2647, '我来寻找作诗的灵感', 'I have come seeking inspiration for my poetry.'),
        (2652, '泰山脚下', 'At the Foot of Mount Tai'),
        (2689, '玄明道人', 'Taoist Master Xuanming'),
        (2701, '天地苍茫', 'The Vast World'),
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
        if zh == exp_zh and en == exp_en:
            ok += 1
            print(f"  L{ln}: ✅ {exp_zh[:30]} → {exp_en[:30]}")
        else:
            fail += 1
            print(f"  L{ln}: ❌ zh='{zh[:60]}' en='{en[:60]}'")
    
    print(f"\n  Result: {ok}/{ok+fail} passed")
    
    if fail > 0:
        print("\n  FAILED CHECKS - manual inspection needed")

if __name__ == "__main__":
    main()
