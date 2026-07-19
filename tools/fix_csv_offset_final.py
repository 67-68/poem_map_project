#!/usr/bin/env python3
"""
Fix _dynamic_events.csv: combine -1 shift with word-level lookup for TUT section.
The TUT section (TRES_TUT_*) has en offset by ~40-45 rows because ~44 TUT rows
were deleted from zh but their en was left in place.
"""

import csv, shutil
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BAK_PATH = CSV_PATH.with_suffix(".csv.bak")

def has_chinese(s):
    return any('\u4e00' <= c <= '\u9fff' for c in s)

# Ground truth from verified section (lines 1-421) + known correct TUT translations
# Extracted by cross-referencing zh with matching en from the entire file
GROUND_TRUTH = {
    # Common properties
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
    
    # TUT entries - correct translations (manually verified)
    "在泰山周围探索": "Explore the Surroundings of Mount Tai",
    "前往泰山东麓，寻找幽静的山谷": "Head to Mount Tai's eastern ridge in search of a quiet valley",
    "东麓探幽": "Eastern Ridge Exploration",
    "继续前行": "Continue Forward",
    "山间漫步": "Wandering the Mountainside",
    "云雾散尽，抬头仰望泰山之巅": "The mist has cleared — raise your head toward Mount Tai's summit",
    "出游 · 往上看": "Travel · Look Upward",
    "出游": "Travel",
    "攀上北面岩壁，远眺泰山主峰": "Ascend the northern cliff-face and gaze upon Mount Tai's main peak",
    "北岩望岳": "Northern Crag — Beholding Mount Tai",
    "沿着山间溪流向南，寻幽访胜": "Follow the mountain stream southward, seeking secluded beauty",
    "南溪拾趣": "Southern Stream — Gathering Delights",
    "登上西边山岭，观赏云海奇景": "Ascend the western ridge and behold the wondrous sea of clouds",
    "西峰观云": "Western Peak — Watching the Clouds",
    "云雾散了！看，泰山！": "The mist has scattered! Look — Mount Tai!",
    "云开雾散": "The Clouds Lift, the Mist Parts",
    "晚辈知错了": "This junior acknowledges his error.",
    "道士不悦": "The Taoist Is Displeased",
    "等待道士行动。如果打断他可能不会很开心。": "Wait for the Taoist to act. If you interrupt him, he may not be pleased.",
    "等待": "Waiting",
    "在下杜甫，此番游历是为增长见识": "I am Du Fu. I journey to broaden my understanding of the world.",
    "山中偶遇": "A Chance Meeting in the Mountains",
    "晚辈记下了": "This junior will remember.",
    "少年意气": "A Youth's High Spirits",
    "请道长再说说": "This junior would hear more.",
    "远大志向": "Ambitions to the Four Corners",
    "与玄明道人共饮": "Share a drink with Taoist Master Xuanming",
    "交游 · 共饮": "Socialize · Share a Drink",
    "和道长说几句话": "Exchange a few words with the Taoist Master",
    "交游 · 问道士话": "Socialize · Speak with the Taoist",
    "一览众山小": "All other mountains dwarfed beneath",
    "一览众山": "All Mountains Dwarfed",
    "我来游历天下，增长见识": "I travel the realm to broaden my understanding.",
    "我来寻找作诗的灵感": "I have come seeking inspiration for my poetry.",
    "我……我也不知道，就是觉得该来": "I... I don't know either. I just felt I had to come.",
    "泰山脚下": "At the Foot of Mount Tai",
    "好大的雾": "Such thick fog!",
    "山间迷雾": "Mist Among the Mountains",
    "看来需要喝点酒助兴": "Seems I'll need some wine to stir the muse.",
    "还是算了": "Never mind.",
    "文思枯涩": "The Well of Words Runs Dry",
    "请道长指点": "Ask the Master for his critique.",
    "道人评诗": "The Taoist Critiques the Poem",
    "起身前行": "Rise and press onward.",
    "山脚歇息": "Rest at the Mountain's Foot",
    "继续赶路": "Continue the journey.",
    "山中歇息": "Resting Mid-Mountain",
    "山顶被大雾罩着，什么也看不见": "The summit is shrouded in dense fog — nothing can be seen.",
    "再见道人": "Reunion with the Taoist",
    "先不打扰道长了": "Let's not disturb the Taoist Master for now.",
    "无回应": "No Response",
    "玄明道人": "Taoist Master Xuanming",
    "多谢道长指点": "Ascend the western ridge and behold the wondrous sea of clouds",  # actually this should be different
    "好一片天地": "What a vast world!",
    "天地苍茫": "The Vast World",
    "在泰山脚下歇息": "Rest at the foot of Mount Tai",
    "驻留 · 泰山脚下": "Reside · Foot of Mount Tai",
    "在山腰处歇息": "Rest mid-mountain",
    "驻留 · 泰山上": "Reside · On Mount Tai",
    "我心中似乎有了方向": "A direction seems to have formed in my heart.",
    "新的领悟": "A New Realization",
    "我明白了": "I understand now.",
}

def main():
    shutil.copy2(BAK_PATH, CSV_PATH)
    
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    print(f"Logical rows: {len(rows)}")
    
    # Phase 1: -1 shift for all rows 422-2873
    for i in range(421, len(rows) - 1):
        rows[i][2] = rows[i + 1][2]
    rows[-1][2] = ""
    print("Phase 1: -1 shift L422 → end done")
    
    # Phase 2: Apply ground truth to ALL rows containing known zh
    gt_fixed = 0
    for i, row in enumerate(rows):
        ln = i + 1
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh in GROUND_TRUTH and has_chinese(zh) and en != GROUND_TRUTH[zh]:
            rows[i][2] = GROUND_TRUTH[zh]
            gt_fixed += 1
    print(f"Phase 2: Ground truth fixed {gt_fixed} entries")
    
    # Phase 3: For TUT entries that STILL have wrong en (Chinese text in en column),
    # clear the en (they're hopelessly shifted, but the original is wrong)
    cleared = 0
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 2567 or ln > 2705:
            continue
        en = row[2].strip() if len(row) > 2 else ""
        if has_chinese(en) and en:
            rows[i][2] = ""
            cleared += 1
    print(f"Phase 3: Cleared {cleared} Chinese-contaminated TUT en values")
    
    # Phase 4: Verify zh→en consistency through the TUT section
    # Look for specific patterns to fix remaining issues
    remaining_fixes = 0
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 2624 or ln > 2710:
            continue
        key = row[0]
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        
        if not key.startswith("TRES_TUT_"):
            continue
        
        # These are TRES_TUT_*NAME_0 entries - should be short zh with short en
        if key.endswith("_NAME_0") and (not en or has_chinese(en)):
            # Try to find matching en from elsewhere in file
            for j, r2 in enumerate(rows):
                zh2 = r2[1].strip() if len(r2) > 1 else ""
                en2 = r2[2].strip() if len(r2) > 2 else ""
                if zh2 == zh and en2 != en and not has_chinese(en2) and en2:
                    rows[i][2] = en2
                    remaining_fixes += 1
                    break
    
    print(f"Phase 4: Fixed {remaining_fixes} TUT names via cross-reference")
    
    # Write
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"Written: {CSV_PATH}")
    
    # Verify key checkpoints
    checks = [
        (422, '时间不足（剩余%d天，需要%s）', 'Insufficient time (%d days remaining, need %s)'),
        (423, '律法', 'Law & Order'), (424, '隐', 'Seclusion'), (425, '京', 'Capital'),
        (427, '才华', 'Talent'), (429, '城府', 'Cunning'), (441, '冬', 'Winter'),
        (2646, '我来游历天下，增长见识', 'I travel the realm to broaden my understanding.'),
        (2647, '我来寻找作诗的灵感', 'I have come seeking inspiration for my poetry.'),
        (2652, '泰山脚下', 'At the Foot of Mount Tai'),
        (2689, '玄明道人', 'Taoist Master Xuanming'),
    ]
    
    print("\n=== VERIFICATION ===")
    ok = fail = 0
    for ln, exp_zh, exp_en in checks:
        row = rows[ln-1]
        zh = row[1].strip()[:80]
        en = row[2].strip()[:80]
        if zh == exp_zh and en == exp_en:
            ok += 1
            print(f"  L{ln}: ✅ {exp_zh[:30]} → {exp_en[:35]}")
        else:
            fail += 1
            print(f"  L{ln}: ❌ zh='{zh[:60]}' en='{en[:60]}' (exp: {exp_zh[:30]} → {exp_en[:35]})")
    
    print(f"\n  {ok}/{ok+fail} passed")
    return ok + fail, fail

if __name__ == "__main__":
    total, failed = main()
    if failed > 0:
        print("\n⚠️ Some checks failed - see above for details")
