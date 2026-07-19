#!/usr/bin/env python3
"""
Complete fix: -1 shift + full TUT en dictionary.
All TRES_TUT_ en values are reconstructed from known correct translations.
"""

import csv
from pathlib import Path

CSV_PATH = Path("data/1_core_rules/translations/_dynamic_events.csv")

# Every TRES_TUT_ key → correct en mapping
TUT_EN = {
    "TRES_TUT_CHUYOU_DESCRIPTION_0": "Explore the surroundings of Mount Tai.",
    "TRES_TUT_CHUYOU_EAST_DESCRIPTION_0": "Head to Mount Tai's eastern ridge in search of a quiet valley.",
    "TRES_TUT_CHUYOU_EAST_NAME_0": "Eastern Ridge Exploration",
    "TRES_TUT_CHUYOU_FALLBACK_DESCRIPTION_0": "Continue forward.",
    "TRES_TUT_CHUYOU_FALLBACK_DESCRIPTION_1": "You wander the slopes of Mount Tai, breathing the crisp mountain air. The mountain wind blows, rustling the leaves. Occasionally, birdsong drifts in from afar.\n\nGazing into the distance, the peak remains shrouded in that thick bank of fog. When will you finally behold Mount Tai's true face?",
    "TRES_TUT_CHUYOU_FALLBACK_NAME_0": "Wandering the Mountainside",
    "TRES_TUT_CHUYOU_LOOKUP_DESCRIPTION_0": "The mist has scattered — look up toward the summit of Mount Tai.",
    "TRES_TUT_CHUYOU_LOOKUP_NAME_0": "Travel · Look Upward",
    "TRES_TUT_CHUYOU_NAME_0": "Travel",
    "TRES_TUT_CHUYOU_NORTH_DESCRIPTION_0": "Ascend the northern cliff-face and gaze upon Mount Tai's main peak.",
    "TRES_TUT_CHUYOU_NORTH_NAME_0": "Northern Crag — Beholding Mount Tai",
    "TRES_TUT_CHUYOU_SOUTH_DESCRIPTION_0": "Follow the mountain stream southward, seeking out secluded beauty.",
    "TRES_TUT_CHUYOU_SOUTH_NAME_0": "Southern Stream — Gathering Delights",
    "TRES_TUT_CHUYOU_WEST_DESCRIPTION_0": "Ascend the western ridge and behold the wondrous sea of clouds.",
    "TRES_TUT_CHUYOU_WEST_NAME_0": "Western Peak — Watching the Clouds",
    "TRES_TUT_DEFER_DONE_DESCRIPTION_0": "The mist has scattered! Look — Mount Tai!",
    "TRES_TUT_DEFER_DONE_DESCRIPTION_1": "Two ten-day periods pass in haste. One morning, you arrive at the Taoist's meditation spot and see him slowly open his eyes.\n\n\"It is done.\" The Taoist waves his whisk.\n\nYou look up — the dense fog that shrouded the peak is visibly dissipating. Sunlight breaks through the clouds, washing Mount Tai's summit in gold — majestic and solemn. For a moment your heart surges, and you feel an uncontrollable urge to shout toward the peak where the clouds have just parted.",
    "TRES_TUT_DEFER_DONE_NAME_0": "The Clouds Lift, the Mist Parts",
    "TRES_TUT_DEFER_INTERRUPT_DESCRIPTION_0": "This junior acknowledges his error.",
    "TRES_TUT_DEFER_INTERRUPT_DESCRIPTION_1": "You rashly interrupted the Taoist's ritual. The whisk in his hand halted, and the spiritual energy around him dissipated.\n\nThe Taoist turned his head, brows furrowed: \"Young man, rituals demand a single breath from start to finish. By interrupting me, I must begin again from the beginning.\"\n\nHe sighed, and spoke no further.",
    "TRES_TUT_DEFER_INTERRUPT_NAME_0": "The Taoist Is Displeased",
    "TRES_TUT_DEFER_START_DESCRIPTION_0": "Wait for the Taoist to act. If you interrupt him, he may not be pleased.",
    "TRES_TUT_DEFER_START_DESCRIPTION_1": "He sits down and begins the ritual.",
    "TRES_TUT_DEFER_START_NAME_0": "Waiting",
    "TRES_TUT_DIALOGUE_1_DESCRIPTION_0": "I am Du Fu. I journey to broaden my understanding of the world.",
    "TRES_TUT_DIALOGUE_1_DESCRIPTION_1": "The Taoist studied you for a moment and smiled: \"This humble priest has cultivated on this mountain for many years. I've learned to read people to some degree. Young friend, your steps are steady — not like the weak and frail scholars one usually sees.\"\n\nHe gave his horsetail whisk a light wave and gestured for you to sit: \"May I ask your name? What brings you to this mountain?\"",
    "TRES_TUT_DIALOGUE_1_NAME_0": "A Chance Meeting in the Mountains",
    "TRES_TUT_DIALOGUE_2_DESCRIPTION_0": "This junior will remember.",
    "TRES_TUT_DIALOGUE_2_DESCRIPTION_1": "The Taoist, hearing this, gave a slight nod: \"To possess such ambition at your age — rare indeed.\"\n\nHe pressed a hand on your shoulder and studied your complexion: \"Your frame is sturdy, your color healthy — your family has not neglected you. When abroad in the world, your body is your capital and coin is your provision. Keep both ever in mind.\"\n\nHe produced a copper coin from his sleeve and toyed with it: \"This humble priest has wandered far and wide. I know well how a single copper coin can humble even the mightiest of men. Your purse is not yet empty — travel while you are young.\"",
    "TRES_TUT_DIALOGUE_2_NAME_0": "A Youth's High Spirits",
    "TRES_TUT_DIALOGUE_3_DESCRIPTION_0": "This junior would hear more.",
    "TRES_TUT_DIALOGUE_3_DESCRIPTION_1": "The Taoist returned the coin to you, his tone turning earnest: \"Young Du, this humble priest sees that you are not one content with mediocrity. Scholars like you carry a fire within their hearts — that is ambition, that is purpose.\"\n\nHe raised a hand toward the distance: \"Look upon this world. Some chase fame and fortune. Some worry for family and country. You study the sages — to what end, then?\"\n\nHe paused: \"Literary genius, renown, fortune's favor — these three will propel you forward, yet they will trip you at critical moments. Know their measure, and you shall travel far.\"",
    "TRES_TUT_DIALOGUE_3_NAME_0": "Ambitions to the Four Corners",
    "TRES_TUT_DIALOGUE_4_DESCRIPTION_0": "Thank you for your guidance, Master.",
    "TRES_TUT_DIALOGUE_4_DESCRIPTION_1": "The Taoist gave you another long look, then spoke: \"I observe that your literary talent is passable, but your body still needs tempering. Mountaineering is not won with the brush — it is won with the legs. This frame of yours — if you do not first weather it, I fear you will not travel far.\"\n\nHe rose, dusted off his robe, and pressed a hand on your shoulder — not too light, not too heavy.\n\n\"Mm. Your foundation is solid. I have seen many scholars — after ten years buried in books, they emerge stooped and hunched. Your frame is stronger than theirs.\"\n\nHe taught you a few breathing exercises and counseled: \"One who climbs mountains — vigor is your capital. Remember this truth.\"\n\n[size=13][color=#888888]System Tip: Hover over the markings that appear on the left to view detailed effect descriptions.[/color][/size]",
    "TRES_TUT_DIALOGUE_4_NAME_0": "Body Forged Strong",
    "TRES_TUT_DIALOGUE_TIME_DESCRIPTION_0": "This junior was born in the fifteenth year of the Kaiyuan era of the Great Tang. I should be twenty-six this year.",
    "TRES_TUT_DIALOGUE_TIME_DESCRIPTION_1": "The Taoist stroked his beard and laughed: \"This humble priest has dwelt long in the mountains — the passing of months and years has grown faint to me. But tell me, young friend — do you know what year it is now?\"\n\nHe gazed toward the distant horizon, his eyes seeming to pierce the clouds: \"One who cultivates the Way counts not the seasons, but a scholar like you must keep them in mind. When to sit the examinations, when to enter the capital — these are matters of consequence.\"\n\nHe pointed beyond the mountains: \"Mark the days. Do not squander time.\"\n\n[size=13][color=#888888]System Tip: The time panel in the upper-right corner displays the current reign era and tenday. Each white orb represents one day — in this tutorial, only 2 days are available per tenday. Click the \"Skip\" button to quickly end the current tenday and advance to the next.[/color][/size]",
    "TRES_TUT_DIALOGUE_TIME_NAME_0": "Time Flies Like the Shuttle",
    "TRES_TUT_GOODBYE_DESCRIPTION_0": "Descend the mountain.",
    "TRES_TUT_GOODBYE_DESCRIPTION_1": "The day of parting arrives at last. At the foot of the mountain, you bid farewell to Taoist Master Xuanming.\n\n\"Go on.\" He waves a hand, his expression serene. \"You and I share a bond of affinity. We shall meet again, in time.\"\n\nYou bow deeply, turn, and set out on the road home. After a few steps, you cannot help but glance back — the Taoist has already turned toward the mountain, his figure slowly vanishing into the forest.\n\nThis journey to Mount Tai has profited you greatly, you think. You will return to pay a visit someday.\n\nWhat you do not realize is that this parting will stretch across twenty years.",
    "TRES_TUT_GOODBYE_NAME_0": "Descending the Mountain",
    "TRES_TUT_IDEA_HINT_DESCRIPTION_0": "A direction seems to have formed in my heart.",
    "TRES_TUT_IDEA_HINT_DESCRIPTION_1": "Standing atop Mount Tai, you look down upon the sea of clouds at your feet and the mountains and rivers stretching into the distance. This journey has yielded far more than you expected.\n\nVague thoughts about the future stir within you — still indistinct, but you can feel that your life should be more than drifting with the current.\n\nClick the blue stamp in the lower-right corner to crystallize this insight into a direction forward.",
    "TRES_TUT_IDEA_HINT_NAME_0": "A New Realization",
    "TRES_TUT_IDEA_UNLOCK_DESCRIPTION_0": "I understand now.",
    "TRES_TUT_IDEA_UNLOCK_DESCRIPTION_1": "You stand at the summit, the fierce mountain wind whipping past you, and a heroic fervor like never before surges within your chest.\n\nThe Taoist's words echo in your ears — \"What matters most in this life?\"\n\nYou had no answer then. But now, the answer rests in your heart. The world is vast — somewhere, a path awaits that is meant for you.",
    "TRES_TUT_IDEA_UNLOCK_NAME_0": "Lofty Aspirations",
    "TRES_TUT_JIAOYOU_DRINK_DESCRIPTION_0": "Share a drink with Taoist Master Xuanming.",
    "TRES_TUT_JIAOYOU_DRINK_NAME_0": "Socialize · Share a Drink",
    "TRES_TUT_JIAOYOU_TALK_DESCRIPTION_0": "Exchange a few words with the Taoist Master.",
    "TRES_TUT_JIAOYOU_TALK_NAME_0": "Socialize · Speak with the Taoist",
    "TRES_TUT_LOOKUP_MOUNTAIN_DESCRIPTION_0": "All other mountains dwarfed beneath.",
    "TRES_TUT_LOOKUP_MOUNTAIN_DESCRIPTION_1": "You scale Mount Tai's summit and gaze into the far distance.\n\nThe clouds beneath your feet churn like an ocean of waves. Distant peaks emerge and vanish in the sea of mist, like azure islands floating in a white expanse. The dome of heaven arches above, the stars arrayed across it, and for a moment you feel utterly alone between sky and earth.\n\nTen thousand leagues of deep-blue waves surge and roll — the sun and moon seem to rise from within them, the River of Stars to pour from their depths.\n\nScroll after scroll of bamboo slips unfurl before your eyes, filled with the names of those who rose and fell, who triumphed and perished.\n\nYou suddenly understand — this magnificent landscape, this is the poetry you are meant to write.",
    "TRES_TUT_LOOKUP_MOUNTAIN_NAME_0": "All Mountains Dwarfed",
    "TRES_TUT_MEET_TAOIST_DESCRIPTION_0": "I travel the realm to broaden my understanding.",
    "TRES_TUT_MEET_TAOIST_DESCRIPTION_1": "I have come seeking inspiration for my poetry.",
    "TRES_TUT_MEET_TAOIST_DESCRIPTION_2": "I... I don't know either. I just felt I had to come.",
    "TRES_TUT_MEET_TAOIST_DESCRIPTION_ML": "Mount Tai stands majestic. At its foot, birds sing among fragrant blossoms, and brooks murmur over smooth stones. You are drinking in the numinous spirit of this place when you suddenly notice a white-haired Taoist seated upon a green boulder. His bearing is transcendent, a horsetail whisk in hand, his eyes gently closed — as though he has been waiting here for you all along.\n\nHe slowly opens his eyes, studies you for a moment, then speaks: \"Young man, why have you come to Mount Tai?\"",
    "TRES_TUT_MEET_TAOIST_NAME_0": "At the Foot of Mount Tai",
    "TRES_TUT_MOVE_AWAY_DESCRIPTION_0": "Such thick fog!",
    "TRES_TUT_MOVE_AWAY_DESCRIPTION_1": "You follow the mountain path to the other side of Mount Tai. You look up, hoping to make out the summit's outline — only to find a dense fog wrapped tight around the peak, revealing nothing.\n\nThe mountain wind rises, and the fog churns like a tide. For a moment you think you glimpse the silhouette of the summit — then it is gone, as if it were never there.\n\nYou think of the Taoist — he has cultivated on this mountain for many years. Perhaps he knows the origin of this fog.",
    "TRES_TUT_MOVE_AWAY_NAME_0": "Mist Among the Mountains",
    "TRES_TUT_NO_INSPIRATION_DESCRIPTION_0": "Seems I'll need some wine to stir the muse.",
    "TRES_TUT_NO_INSPIRATION_DESCRIPTION_1": "Never mind.",
    "TRES_TUT_NO_INSPIRATION_DESCRIPTION_ML": "You face the magnificent landscape, brush in hand, determined to capture it in verse. Yet as you raise the brush, your mind goes blank.\n\nYou rack your brains for what feels like an eternity, but all you manage are a few dry, lifeless lines. Even you shake your head at them.\n\nYou recall the Taoist's words — \"Mountaineering is not won with the brush.\" Perhaps you still need something more.",
    "TRES_TUT_NO_INSPIRATION_NAME_0": "The Well of Words Runs Dry",
    "TRES_TUT_POEM_REVIEW_DESCRIPTION_0": "Ask the Master for his critique.",
    "TRES_TUT_POEM_REVIEW_DESCRIPTION_1": "After a few cups of medicinal wine, inspiration indeed flows like a spring. You dash off \"Gazing on Mount Tai\" in a single breath — every line brimming with a young man's edge and soaring ambition.\n\nThe Taoist, you realize, has been standing behind you for some time. He leans over to glance at the draft, and a flash of astonishment crosses his eyes.\n\n\"Fine! Fine indeed! 'I must ascend the utmost peak, and see all other mountains dwarfed beneath!'\" The Taoist claps his hands in praise. \"Young man, with a poetic gift like this, you will surely win great renown. A name inscribed in the annals of history is no idle dream.\"",
    "TRES_TUT_POEM_REVIEW_NAME_0": "The Taoist Critiques the Poem",
    "TRES_TUT_RESIDE_BASE_DESCRIPTION_0": "Rise and press onward.",
    "TRES_TUT_RESIDE_BASE_DESCRIPTION_1": "You find a green boulder at the foot of Mount Tai and sit. The mountain breeze brushes past, carrying the clean scent of grass and trees. Birdsong drifts from afar, deepening the mountain stillness. After a short rest, you decide to press onward.",
    "TRES_TUT_RESIDE_BASE_NAME_0": "Rest at the Mountain's Foot",
    "TRES_TUT_RESIDE_UPPER_DESCRIPTION_0": "Continue the journey.",
    "TRES_TUT_RESIDE_UPPER_DESCRIPTION_1": "The scenery at mid-mountain is wholly different from the foot. Pine winds roar in waves, and the mist gathers and scatters by turns. You lean against a tree trunk, gazing at the layered ridges receding into the distance. A bold yearning to climb higher and see farther surges within you.",
    "TRES_TUT_RESIDE_UPPER_NAME_0": "Resting Mid-Mountain",
    "TRES_TUT_RETURN_TAOIST_DESCRIPTION_0": "The summit is shrouded in dense fog — nothing can be seen.",
    "TRES_TUT_RETURN_TAOIST_DESCRIPTION_1": "You return to the green boulder where the Taoist meditates. His expression is as calm as ever, but he opens his eyes at the sound of your footsteps.\n\n\"You're back.\" His tone is even. \"Judging by your expression — what did you encounter?\"",
    "TRES_TUT_RETURN_TAOIST_NAME_0": "Reunion with the Taoist",
    "TRES_TUT_TALK_NO_RESPONSE_DESCRIPTION_0": "Let's not disturb the Taoist Master for now.",
    "TRES_TUT_TALK_NO_RESPONSE_DESCRIPTION_1": "You approach the green boulder where the Taoist meditates and call softly. \"Master Dao?\"\n\nThe Taoist sits cross-legged, eyes tightly shut, breathing long and deep. He seems to have entered a state of deep meditation. You wait a moment, but he shows no sign of response.\n\nIt seems the Master is in a critical phase of his cultivation. Better not disturb him. You decide to look around elsewhere first.",
    "TRES_TUT_TALK_NO_RESPONSE_NAME_0": "No Response",
    "TRES_TUT_TAOIST_NAME_0": "Taoist Master Xuanming",
    "TRES_TUT_TRAIT_DEMO_DESCRIPTION_0": "Thank you for your guidance, Master.",
    "TRES_TUT_TRAIT_DEMO_DESCRIPTION_1": "The Taoist pressed a hand on your shoulder — not too light, not too heavy.\n\n\"Mm. Your foundation is solid. I have seen many scholars — after ten years buried in books, they emerge stooped and hunched. Your frame is stronger than theirs.\"\n\nHe taught you a few breathing exercises and counseled: \"One who climbs mountains — vigor is your capital. Remember this truth.\"",
    "TRES_TUT_TRAIT_DEMO_NAME_0": "Robust Physique",
    "TRES_TUT_VAST_WORLD_DESCRIPTION_0": "What a vast world!",
    "TRES_TUT_VAST_WORLD_DESCRIPTION_1": "After leading you around a few mountain paths, the Taoist brings you to a spot where the view suddenly opens wide. Before you stretches a whole open valley. Distant peaks are the color of ink-wash, and a sea of clouds surges and rolls. Wind rushes through the pine forest, carrying a damp scent of grass and trees.\n\nYou stand at the cliff's edge, looking at the mountain ranges that stretch to the horizon beneath your feet, and a strange, unnameable feeling surges in your chest. The world is so vast, and you are but a speck of dust within it.\n\nThe Taoist stops beside you and speaks softly: \"This humble priest needs to meditate for a spell. Go and explore on your own. There is still much to see among these mountains.\"\n\nWith that, he finds a green stone, sits cross-legged, closes his eyes, and speaks no more.",
    "TRES_TUT_VAST_WORLD_NAME_0": "The Vast World",
    "TRES_TUT_ZHU_LIU_BASE_DESCRIPTION_0": "Rest at the foot of Mount Tai.",
    "TRES_TUT_ZHU_LIU_BASE_NAME_0": "Reside · Foot of Mount Tai",
    "TRES_TUT_ZHU_LIU_UPPER_DESCRIPTION_0": "Rest mid-mountain.",
    "TRES_TUT_ZHU_LIU_UPPER_NAME_0": "Reside · On Mount Tai",
}

# Non-TUT entries that still need fixing after -1 shift
EXTRA_FIXES = {
    "TRES_YOUXIANGFU_GATE_L0_DESCRIPTION_0": "Empty all the silver and coins from your sleeve into his outstretched palm.",
    "TRES_YOUXIANGFU_GATE_L0_DESCRIPTION_1": "Turn and walk away.",
    "TRES_YOUXIANGFU_GATE_L0_NAME_0": "The Right Chancellor's Gate Guard",
    "TRES_YOUXIANGFU_GATE_L0_REVISIT_DESCRIPTION_0": "Step into the residence.",
    "UI_AMBITION_HUD_TEXT_0": "Guide the Sovereign to Sagehood",
    "UI_AMBITION_HUD_TEXT_1": "You wish to bring order to the family, govern the state, and bring peace to all under heaven — and this requires holding office as a prerequisite.\nYou plan to try your luck in the capital, where high officials are especially numerous and there ought to be someone who appreciates your talent.",
    "UI_CONFIRMATION_DIALOG_CUSTOM_TEXT_0": "Journey to Mount Tai",
    "UI_CONFIRMATION_DIALOG_CUSTOM_TEXT_3": "Begin Tutorial",
    "UI_NOTE_PAGE_TEXT_2": "At dawn I knock on the rich man's gate; at dusk I follow fat horses' dust. Leftover wine and cold scraps — everywhere I swallow my sorrow in secret.",
    "UI_MAIN_PAGE_TEXT_0": "Capital",
    "UI_MAIN_PAGE_TEXT_1": "Seclusion",
    "UI_MAIN_PAGE_TEXT_2": "Law & Order",
    "UI_MAIN_PAGE_TEXT_3": "Mount Tai",
}

def main():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    print(f"Read {len(rows)} logical rows")

    # Step 1: -1 shift for ALL rows 422+
    for i in range(421, len(rows) - 1):
        rows[i][2] = rows[i + 1][2]
    rows[-1][2] = ""
    print("Step 1: -1 shift done")

    # Step 2: Apply TUT_EN to all TRES_TUT_ keys
    tut_fixed = 0
    for i, row in enumerate(rows):
        key = row[0]
        if key in TUT_EN:
            rows[i][2] = TUT_EN[key]
            tut_fixed += 1
    print(f"Step 2: Fixed {tut_fixed} TUT entries via dictionary")

    # Step 3: Apply EXTRA_FIXES
    extra_fixed = 0
    for i, row in enumerate(rows):
        key = row[0]
        if key in EXTRA_FIXES:
            rows[i][2] = EXTRA_FIXES[key]
            extra_fixed += 1
    print(f"Step 3: Fixed {extra_fixed} extra entries")

    # Write
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"Written: {CSV_PATH}")

    # Verify
    cn_in_en = sum(1 for r in rows if any('\u4e00' <= c <= '\u9fff' for c in (r[2] or "")))
    print(f"\nVerification: {cn_in_en} rows with Chinese in en")

    # Show all TRES_TUT_ entries
    print("\n=== ALL TRES_TUT_ (final) ===")
    for i, row in enumerate(rows):
        if row[0].startswith("TRES_TUT_"):
            zh = row[1][:30] if len(row) > 1 else ""
            en = row[2][:50] if len(row) > 2 else ""
            print(f"  L{i+1}: {row[0]:<45} zh={zh:<30} en={en}")

    # Spot checks
    print("\n=== SPOT CHECKS ===")
    targets = [
        "CODE_MAIN_ACTION_BUTTON_DC059CE490",
        "CODE_MAIN_PAGE_59CA1F817B",
        "TRES_TUT_MEET_TAOIST_DESCRIPTION_0",
        "TRES_TUT_MEET_TAOIST_NAME_0",
        "TRES_TUT_RETURN_TAOIST_NAME_0",
        "TRES_TUT_TAOIST_NAME_0",
        "UI_MAIN_PAGE_TEXT_0",
        "UI_MAIN_PAGE_TEXT_3",
    ]
    for key in targets:
        found = False
        for i, row in enumerate(rows):
            if row[0] == key:
                zh = row[1][:50]
                en = row[2][:80]
                has_cn = any('\u4e00' <= c <= '\u9fff' for c in (en or ""))
                print(f"  {'⛔' if has_cn else '✅'} L{i+1}: {key} zh={zh} en={en}")
                found = True
                break
        if not found:
            print(f"  ❓ NOT FOUND: {key}")

if __name__ == "__main__":
    main()
