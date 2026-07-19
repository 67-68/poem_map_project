#!/usr/bin/env python3
"""
Sample 30 rows from lines 422+ in _dynamic_events.csv.
Classify each: is en correct for this zh, or is en the translation of prev zh (-1 shift)?
Then find boundary between shifted and normal regions.
"""

import csv, random
from pathlib import Path

CSV_PATH = Path(__file__).parent.parent / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

def has_chinese(s): return any('\u4e00' <= c <= '\u9fff' for c in s)

def analyze():
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    
    # Build truth from lines 2-421 (verified correct)
    truth = {}
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 1 or ln > 421:
            break
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        if zh and en and has_chinese(zh) and not has_chinese(en):
            truth[zh] = en
    
    # Also build reverse: en → zh (for checking which zh an en belongs to)
    en_to_zh = {v: k for k, v in truth.items()}
    
    print(f"Truth entries: {len(truth)}\n")
    
    # Classify EVERY row from 422 to end
    results = []
    for i, row in enumerate(rows):
        ln = i + 1
        if ln < 422:
            continue
        zh = row[1].strip() if len(row) > 1 else ""
        en = row[2].strip() if len(row) > 2 else ""
        
        prev_zh = rows[i-1][1].strip() if i > 0 and len(rows[i-1]) > 1 else ""
        
        if not zh or not has_chinese(zh):
            continue
        if not en or has_chinese(en):
            results.append((ln, row[0][:50], "NO_EN", zh, en))
            continue
        
        # Check: is en correct for this zh?
        if zh in truth and en == truth[zh]:
            results.append((ln, row[0][:50], "CORRECT", zh, en))
        # Check: is en the translation of PREVIOUS zh?
        elif prev_zh in truth and en == truth[prev_zh]:
            results.append((ln, row[0][:50], "SHIFTED-1", zh, en))
        # Check: which zh does en belong to?
        elif en in en_to_zh:
            target_zh = en_to_zh[en]
            # Find where target_zh is
            target_ln = None
            for j, r2 in enumerate(rows):
                if r2[1].strip() == target_zh:
                    target_ln = j + 1
                    break
            offset = target_ln - ln if target_ln else "?"
            results.append((ln, row[0][:50], f"BELONGS_TO_L{target_ln}({target_zh[:30]})", zh, en))
        else:
            results.append((ln, row[0][:50], "UNKNOWN", zh, en))
    
    print(f"=== CLASSIFICATION OF ALL ROWS 422+ ===")
    counts = {}
    status_list = []
    for ln, key, status, zh, en in results:
        counts[status] = counts.get(status, 0) + 1
        status_list.append(status)
    
    for s, c in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {s}: {c}")
    
    # Find runs of SHIFTED-1
    print(f"\n=== RUNS OF SHIFTED-1 / CORRECT ===")
    runs = []
    current_run = None
    run_start = None
    for ln, key, status, zh, en in results:
        simplified = "SHIFTED" if status == "SHIFTED-1" else ("CORRECT" if status == "CORRECT" else "OTHER")
        if current_run is None or current_run != simplified:
            if current_run is not None:
                runs.append((run_start, ln - 1, current_run))
            current_run = simplified
            run_start = ln
    
    if current_run is not None:
        runs.append((run_start, results[-1][0], current_run))
    
    for start, end, status in runs:
        length = end - start + 1
        if length < 5:
            continue
        print(f"  L{start}-L{end} [{status}] ({length} rows)")
    
    # NOW: 30 random samples from 422+
    print(f"\n=== 30 RANDOM SAMPLES (lines 422+) ===")
    random.seed(42)
    sample = random.sample(results, min(30, len(results)))
    sample.sort(key=lambda x: x[0])
    
    shifted_count = 0
    correct_count = 0
    other_count = 0
    
    for ln, key, status, zh, en in sample:
        if status == "SHIFTED-1":
            shifted_count += 1
        elif status == "CORRECT":
            correct_count += 1
        else:
            other_count += 1
    
    print(f"\n  SHIFTED-1: {shifted_count}")
    print(f"  CORRECT: {correct_count}")
    print(f"  OTHER: {other_count}")
    print()
    
    for ln, key, status, zh, en in sample:
        flag = "🔴SHIFTED" if status == "SHIFTED-1" else ("🟢CORRECT" if status == "CORRECT" else f"⚪{status}")
        print(f"  L{ln}: {flag}")
        print(f"    zh: {zh[:80]}")
        print(f"    en: {en[:80]}")
    
    # Find the boundary between shifted and correct regions
    print(f"\n=== TRANSITION POINTS ===")
    prev_status = None
    for ln, key, status, zh, en in results:
        simplified = "S" if status == "SHIFTED-1" else ("C" if status == "CORRECT" else "O")
        if simplified in ("S", "C") and prev_status not in (None, simplified):
            print(f"  L{ln}: {prev_status} → {simplified}  zh='{zh[:40]}' en='{en[:40]}'")
        if simplified in ("S", "C"):
            prev_status = simplified

if __name__ == "__main__":
    analyze()
