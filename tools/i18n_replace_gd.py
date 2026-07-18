#!/usr/bin/env python3
"""
i18n Phase 8: Replace Chinese string literals in .gd files with tr("KEY")
=======================================================================
Scans all .gd files for "Chinese text" in double quotes,
looks up the translation table (reverse: zh_text → key),
and replaces with tr("KEY").

Skips:
  - Comments (#)
  - Logging.* lines (debug logs stay Chinese)
  - Paths (res://, uid://)
  - Empty strings
  - Already tr()-wrapped strings
"""

import csv
import re
from pathlib import Path
from collections import OrderedDict

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSLATION_CSV = PROJECT_ROOT / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

CJK = re.compile(r"[\u4e00-\u9fff]")
EXCLUDE = {".git", ".godot", ".venv", "addons", "__pycache__", "node_modules", "tests"}

# Build reverse lookup: zh_text → key
zh_to_key: dict = {}
stats = {"files": 0, "replaced": 0, "skipped_logging": 0, "skipped_comment": 0,
         "skipped_path": 0, "not_found": 0}


def load_translations():
    if not TRANSLATION_CSV.exists():
        print("❌ Translation CSV not found")
        return
    with open(TRANSLATION_CSV, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)
    if len(rows) < 2:
        return
    kc = rows[0].index("keys")
    zc = rows[0].index("zh")
    for r in rows[1:]:
        if len(r) > max(kc, zc):
            k = r[kc].strip()
            z = r[zc].strip()
            if k and z:
                # Store with \n normalized for multi-line matching
                zh_to_key[z.replace("\n", "\\n")] = k
    print(f"Loaded {len(zh_to_key)} zh→key mappings")


def replace_in_file(filepath: Path) -> int:
    """Replace Chinese strings with tr('KEY') calls. Returns number of replacements."""
    try:
        raw = filepath.read_text("utf-8", errors="ignore")
    except Exception:
        return 0

    lines = raw.split("\n")
    replaced = 0
    new_lines = []

    for line in lines:
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("#"):
            new_lines.append(line)
            stats["skipped_comment"] += 1 if CJK.search(stripped) else 0
            continue

        # Skip Logging.* lines (debug logs keep Chinese)
        if "Logging." in line:
            new_lines.append(line)
            stats["skipped_logging"] += 1 if CJK.search(line) else 0
            continue

        # Skip if no Chinese at all
        if not CJK.search(line):
            new_lines.append(line)
            continue

        # Find all double-quoted strings on this line
        modified = False
        result = ""

        # Use regex to find quoted strings, handling escaped quotes
        # Pattern: "anything" but not part of tr("...")
        idx = 0
        while idx < len(line):
            # Find next quote
            q_start = line.find('"', idx)
            if q_start == -1:
                result += line[idx:]
                break

            # Copy text before quote
            result += line[idx:q_start]

            # Check if preceded by tr( or path keywords
            prefix = line[max(0, q_start - 20):q_start]
            is_tr = "tr(" in prefix and prefix.rstrip().endswith("tr(")
            is_path = any(kw in prefix for kw in ["res://", "uid://", "path=", "path ="])

            # Find matching close quote (handle \\" escapes)
            q_end = q_start + 1
            while q_end < len(line):
                if line[q_end] == '"' and line[q_end - 1] != '\\':
                    break
                q_end += 1
            else:
                # Unclosed quote — leave as-is
                result += line[q_start:]
                break

            quoted = line[q_start + 1:q_end]

            if not CJK.search(quoted) or quoted.startswith("res://") or quoted.startswith("uid://") or is_tr or is_path:
                result += line[q_start:q_end + 1]
            else:
                # Look up in translation table
                key = zh_to_key.get(quoted.replace("\n", "\\n"))
                if not key:
                    # Try with literal \n
                    key = zh_to_key.get(quoted)
                if key:
                    result += f'tr("{key}")'
                    replaced += 1
                    modified = True
                else:
                    # Not in table — leave as-is
                    result += f'"{quoted}"'
                    stats["not_found"] += 1
                    if stats["not_found"] <= 10:
                        print(f'  ⚠️  Not in table: {filepath.name}:"{quoted[:60]}"')

            idx = q_end + 1

        if modified:
            new_lines.append(result)
        else:
            new_lines.append(line)

    if replaced > 0:
        with open(filepath, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(new_lines))
            if new_lines and new_lines[-1] != "":
                f.write("\n")
        stats["files"] += 1
        stats["replaced"] += replaced

    return replaced


def main():
    load_translations()
    if not zh_to_key:
        print("No translations loaded, aborting")
        return

    print(f"\n🔍 Scanning .gd files...")
    total = 0
    for f in sorted(PROJECT_ROOT.rglob("*.gd")):
        if any(p in EXCLUDE for p in f.parts):
            continue
        r = replace_in_file(f)
        if r > 0:
            print(f"  ✅ {f.relative_to(PROJECT_ROOT)}: {r} replacements")
        total += r

    print(f"\n{'='*60}")
    print(f"📊 Phase 8 Summary")
    print(f"{'='*60}")
    print(f"  Files modified:   {stats['files']}")
    print(f"  Strings replaced: {stats['replaced']}")
    print(f"  Skipped Logging:  {stats['skipped_logging']}")
    print(f"  Skipped comments: {stats['skipped_comment']}")
    print(f"  Skipped paths:    {stats['skipped_path']}")
    print(f"  Not in table:     {stats['not_found']}")
    print(f"\n✅ Done.")


if __name__ == "__main__":
    main()
