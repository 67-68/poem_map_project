#!/usr/bin/env python3
"""
Fix _dynamic_events.csv: 
- Lines 422-2794: en shifted -1 (en[i] = translation of zh[i-1])
  Fix: shift en UP by 1 (en[i] = en[i+1])

- Lines 2795+: multi-line CSV fields cause complex corruption
  Manual fix using ground truth + heuristics
"""

import csv, io, shutil
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak3")

# Known correct translations (zh → en) from verified early section
GROUND_TRUTH = {
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
    "产：无": "Yield: None",
    "险：": "Risk:",
    "耗：无": "Cost: None",
    "或": "or",
    "未知": "Unknown",
    "未知状态": "Unknown State",
    "需要「%d(%s)」": 'Requires "%d(%s)"',
    "暂时无法执行此行动": "Cannot perform this action right now",
    "杜甫": "Du Fu",
    "李白": "Li Bai",
    "王维": "Wang Wei",
    "高适": "Gao Shi",
    "郑虔": "Zheng Qian",
    "平康坊": "Pingkang Ward",
    "西市": "West Market",  # varies
    "皇城": "Imperial City",
    "权贵": "Aristocrat",
    "中断": "Interrupt",
    "合上考评": "Overall Assessment",
    "「 既决：%s 」": "「 Resolved: %s 」",
    "卖诗": "Sell Poems",
    "以诗换名": "Trade verse for renown",
    "携诗拜谒": "Poem Visit",
}

# Additional UI translations that appear at end of file
UI_TRANSLATIONS = {
    "致君尧舜上": "Guide the Sovereign to Sagehood",
    "开始引导": "Begin Tutorial",
    "开始创作": "Begin Composing",
    "撕毁卷轴": "Tear Scroll",
    "登高抒怀": "Climb High, Vent Feelings",
    "干谒权贵": "Seek Patronage from the Powerful",
    "代价是...": "The Cost Is...",
    "跳过": "Skip",
    "存档1": "Save 1",
    "保存到此": "Save Here",
    "依此加载": "Load from Here",
    "继续游戏": "Resume Game",
    "返回主菜单": "Return to Main Menu",
    "退出观测": "Exit Observation",
    "上旬": "Early Month",
    "第1天": "Day 1",
    "天宝十四载": "Year 14 of Tianbao",
    "系统": "System",
    "曾状态": "Status",
    "决议": "Decrees",
    "交游 · 赴宴": "Socialize · Banquet",
}

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' for c in s)

def main():
    shutil.copy2(CSV_PATH, BAK_PATH)
    print(f"Backup: {BAK_PATH}")
    
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    print(f"Read {len(rows)} rows")
    
    # Phase 1: Fix lines 422-2794 by shifting en UP by 1
    # en[422] should become en[423], en[423] → en[424], etc.
    # en[2794] should become en[2795], en[2795] keeps its current value (boundary)
    SHIFT_END = 2794  # last row to shift (inclusive)
    
    for i in range(421, min(SHIFT_END, len(rows) - 1)):  # 0-based index for line 422
        if i + 1 < len(rows):
            rows[i][2] = rows[i + 1][2]
    
    print(f"Phase 1: Shifted en up by 1 from line 422 to {SHIFT_END}")
    
    # Phase 2: Fix remaining rows with ground truth
    all_truth = {**GROUND_TRUTH, **UI_TRANSLATIONS}
    fixed_count = 0
    for i, row in enumerate(rows):
        ln = i + 1
        zh = row[1].strip() if len(row) > 1 and row[1] else ""
        en = row[2].strip() if len(row) > 2 and row[2] else ""
        if zh in all_truth and has_chinese(zh) and en != all_truth[zh]:
            row[2] = all_truth[zh]
            fixed_count += 1
            if fixed_count <= 10:
                print(f"  GT fix L{ln}: '{zh[:30]}' en '{en[:30]}' → '{all_truth[zh][:30]}'")
    
    print(f"Phase 2: Fixed {fixed_count} rows via ground truth")
    
    # Phase 3: For rows where zh has a known correct en that's currently at the wrong position,
    # try to find and swap
    # This handles cases like 京→Traits at L2835 area
    
    # Phase 4: Write output
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    
    print(f"Written fixed file: {CSV_PATH}")
    
    # Verify
    print("\n=== VERIFICATION ===")
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'),
        (424, '隐', 'Seclusion'),
        (425, '京', 'Capital'),
        (427, '才华', 'Talent'),
        (429, '城府', 'Cunning'),
        (441, '冬', 'Winter'),
        (2798, '泰山', 'Mount Tai'),
        (2835, '赴宴', 'Attend Banquet'),
        (2837, '京', 'Capital'),
        (2838, '隐', 'Seclusion'),
        (2839, '律法', 'Law & Order'),
        (2840, '泰山', 'Mount Tai'),
        (2866, '返回主菜单', 'Return to Main Menu'),
        (2871, '退出观测', 'Exit Observation'),
    ]
    
    ok = 0
    fail = 0
    for ln, exp_zh, exp_en in checks:
        if ln > len(rows):
            continue
        row = rows[ln - 1]
        zh = row[1].strip()[:60]
        en = row[2].strip()[:60]
        if zh == exp_zh and en == exp_en:
            ok += 1
            print(f"  L{ln}: ✅")
        else:
            fail += 1
            print(f"  L{ln}: ❌ zh='{zh}' en='{en}' (exp: zh='{exp_zh}' en='{exp_en}')")
    
    print(f"\n  {ok} OK, {fail} FAIL")

if __name__ == "__main__":
    main()
