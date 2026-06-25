#!/usr/bin/env python3
"""Phase 2: Replace deprecated attributes in operator_dsl/result fields of 16 event config JSONs."""

import json
import re
import sys

FILES = [
    "tools/event_base_config_zhuoliu_lieqi.json",
    "tools/event_base_config_zhuoliu_zuanying.json",
    "tools/event_base_config_qingliu_zuanying.json",
    "tools/event_base_config_kuangke_zhuoliu.json",
    "tools/event_base_config_qingliu_fengying.json",
    "tools/event_base_config_zhuoliu_fengying.json",
    "tools/event_base_config_duotai_humiliation.json",
    "tools/event_base_config_zize.json",
    "tools/event_base_config_qingliu_daoxin_posui.json",
    "tools/event_base_747kuangda_denggao.json",
    "tools/event_base_config_qingliu_jiaolv.json",
    "tools/event_base_config_qingliu_passive_benefits.json",
    "tools/event_base_config_bai_ye_real_appearance.json",
    "tools/event_base_config_ganlu_journey.json",
    "tools/event_base_config_kuangke_qingliu.json",
    "tools/bai_ye_honeymoon_config.json",
]


def replace_in_string(s):
    """Apply all replacements to a single DSL string value. Returns (new_str, change_descriptions)."""
    if not isinstance(s, str) or not s.strip():
        return s, []

    original = s
    changes = []

    # ── Step 1: Name substitutions ──

    # fatigue / FATIGUE → health
    s, n = re.subn(
        r'prop_(add|sub)\(name=(f|F)(a|A)(t|T)(i|I)(g|G)(u|U)(e|E);\s*val=(-?\d+)\)',
        r'prop_\1(name=health; val=\9)', s)
    if n:
        changes.append(f"fatigue/FATIGUE→health: {n}")

    # burnout / BURNOUT → health
    s, n = re.subn(
        r'prop_(add|sub)\(name=(b|B)(u|U)(r|R)(n|N)(o|O)(u|U)(t|T);\s*val=(-?\d+)\)',
        r'prop_\1(name=health; val=\9)', s)
    if n:
        changes.append(f"burnout/BURNOUT→health: {n}")

    # career_progress → progress
    s, n = re.subn(
        r'prop_(add|sub)\(name=career_progress;\s*val=(-?\d+)\)',
        r'prop_\1(name=progress; val=\2)', s)
    if n:
        changes.append(f"career_progress→progress: {n}")

    # official_prestige → progress
    s, n = re.subn(
        r'prop_(add|sub)\(name=official_prestige;\s*val=(-?\d+)\)',
        r'prop_\1(name=progress; val=\2)', s)
    if n:
        changes.append(f"official_prestige→progress: {n}")

    # sick prop_add → prop_sub(name=health)  (sick = negative health)
    s, n = re.subn(
        r'prop_add\(name=(s|S)(i|I)(c|C)(k|K);\s*val=(-?\d+)\)',
        r'prop_sub(name=health; val=\5)', s)
    if n:
        changes.append(f"sick→prop_sub(health): {n}")

    # flag_int_append(name=kuangda) → prop_add(name=progress)
    s, n = re.subn(
        r'flag_int_append\(name=kuangda;\s*val=(-?\d+)\)',
        r'prop_add(name=progress; val=\1)', s)
    if n:
        changes.append(f"flag_int_append(kuangda)→prop_add(progress): {n}")

    # flag_int_sub(name=kuangda) → prop_sub(name=progress)
    s, n = re.subn(
        r'flag_int_sub\(name=kuangda;\s*val=(-?\d+)\)',
        r'prop_sub(name=progress; val=\1)', s)
    if n:
        changes.append(f"flag_int_sub(kuangda)→prop_sub(progress): {n}")

    # ── Step 2: Remove inspiration / INSPIRATION / drunk / DRUNK operators ──
    # Pattern: optional leading |, whitespace, prop_add/sub(name=inspiration/INSPIRATION/drunk/DRUNK; val=N)
    insp_drunk_re = r'\s*\|\s*prop_(add|sub)\(name=(inspiration|INSPIRATION|drunk|DRUNK);\s*val=\d+\)'
    s, n = re.subn(insp_drunk_re, '', s)
    if n:
        changes.append(f"removed inspiration/drunk (mid): {n}")

    # Also handle standalone at beginning (no leading |)
    insp_drunk_start_re = r'^\s*prop_(add|sub)\(name=(inspiration|INSPIRATION|drunk|DRUNK);\s*val=\d+\)\s*'
    s, n = re.subn(insp_drunk_start_re, '', s)
    if n:
        changes.append(f"removed inspiration/drunk (lead): {n}")

    # ── Step 3: Cleanup ──
    # Collapse consecutive pipes
    while '||' in s or '| |' in s:
        s = re.sub(r'\|\s*\|', '|', s)

    # Trim leading/trailing pipe and whitespace
    s = s.strip()
    s = re.sub(r'^\|\s*', '', s)
    s = re.sub(r'\s*\|$', '', s)

    if s != original:
        return s, changes
    return s, changes


def walk_and_replace(obj, path=''):
    """Recursively walk JSON, replace in operator_dsl, result, and option_results values."""
    if isinstance(obj, dict):
        for key, value in list(obj.items()):
            new_path = f'{path}.{key}' if path else key
            if key in ('operator_dsl', 'result'):
                if isinstance(value, str):
                    new_val, changes = replace_in_string(value)
                    if changes:
                        obj[key] = new_val
                        print(f"  {new_path}: {', '.join(changes)}")
            elif key == 'option_results':
                if isinstance(value, dict):
                    for opt_key, opt_val in list(value.items()):
                        if isinstance(opt_val, str):
                            new_val, changes = replace_in_string(opt_val)
                            if changes:
                                value[opt_key] = new_val
                                print(f"  {new_path}.{opt_key}: {', '.join(changes)}")
            else:
                walk_and_replace(value, new_path)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            walk_and_replace(item, f'{path}[{i}]')


def main():
    total_changes = 0
    for filepath in FILES:
        file_changes = 0
        print(f'\n=== {filepath} ===')
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"  ERROR loading: {e}")
            continue

        # Collect changes (walk_and_replace prints them)
        # Redirect stdout to capture change count
        import io
        old_stdout = sys.stdout
        sys.stdout = capture = io.StringIO()
        try:
            walk_and_replace(data)
        finally:
            sys.stdout = old_stdout

        output = capture.getvalue()
        if output.strip():
            print(output.rstrip())
            file_changes = len([l for l in output.split('\n') if l.strip()])

        if file_changes == 0:
            print("  (no changes)")
            continue

        total_changes += file_changes

        # Write back with consistent formatting
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')

        # Verify JSON validity
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                json.load(f)
            print(f"  JSON valid ✓")
        except json.JSONDecodeError as e:
            print(f"  JSON INVALID after write: {e}")

    print(f'\n===== SUMMARY =====')
    print(f'Total files with changes: {sum(1 for fp in FILES if _has_changes(fp))}')
    print(f'Total change entries: {total_changes}')


def _has_changes(fp):
    """Quick check if file had any target patterns (post-hoc)."""
    try:
        with open(fp, 'r', encoding='utf-8') as f:
            content = f.read()
        # Check for any remaining deprecated patterns
        patterns = [
            r'prop_(add|sub)\(name=(fatigue|FATIGUE|burnout|BURNOUT)',
            r'prop_(add|sub)\(name=career_progress',
            r'prop_(add|sub)\(name=official_prestige',
            r'prop_add\(name=(sick|SICK)',
            r'flag_int_(append|sub)\(name=kuangda',
            r'prop_(add|sub)\(name=(inspiration|INSPIRATION|drunk|DRUNK)',
        ]
        for pat in patterns:
            if re.search(pat, content):
                return True
        return False
    except Exception:
        return False


if __name__ == '__main__':
    main()
