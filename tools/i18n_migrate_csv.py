#!/usr/bin/env python3
"""
i18n CSV Migration Script — Phase 3
=====================================
Scans all CSV data sources, extracts Chinese text from title/description columns,
replaces with i18n keys in-place, and generates the updated translation CSV.

Key naming (per DOCUMENTATIONS/feature_intents/i18n.md):
  Event title:        EVT_{UUID_UPPER}_TITLE
  Event description:  EVT_{UUID_UPPER}_DESC
  Option text:        EVT_{PARENT_UUID_UPPER}_OPT{N}_{FIELD}
  Trait name:         TRAIT_{TRAIT_ID_UPPER}_NAME
  Action name:        ACT_{UUID_UPPER}_NAME
  Action desc:        ACT_{UUID_UPPER}_DESC

Handles two event CSV formats:
  Format A (_random_events.csv):
    random_event,uuid,...title,description,...
    >option,opt_uuid,...title,...
    → options have their own uuid

  Format B (era CSVs like _747kuangda_denggao_events.csv):
    random_event,uuid,...title,description,...
    >option,,,,description,...   ← NO own uuid, Chinese in description
    → orphan options use parent uuid + sequential counter
"""

import csv
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSLATION_CSV = PROJECT_ROOT / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
CONSTANT_KEY_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")

translation_map: Dict[str, str] = {}
stats: Dict[str, int] = {"files": 0, "rows": 0, "keys": 0, "skipped_empty": 0,
                          "skipped_non_cjk": 0, "skipped_duplicate": 0, "skipped_already_key": 0}


def has_cjk(text: str) -> bool:
    if not text or not text.strip():
        return False
    return bool(CJK_RE.search(text))


def is_already_key(text: str) -> bool:
    return bool(CONSTANT_KEY_RE.match(text.strip()))


def make_key(prefix: str, uuid: str, suffix: str) -> str:
    clean_uuid = uuid.strip().upper().replace("-", "_").replace(" ", "_")
    clean_uuid = re.sub(r"[^A-Z0-9_]", "", clean_uuid)
    if not clean_uuid:
        clean_uuid = "UNKNOWN"
    return f"{prefix}_{clean_uuid}_{suffix}"


def register_translation(key: str, zh_text: str) -> bool:
    zh_stripped = zh_text.strip()
    if key in translation_map:
        existing = translation_map[key]
        if existing != zh_stripped:
            print(f"  ⚠️  KEY CONFLICT: {key}")
            print(f"       existing: {existing[:60]}...")
            print(f"       new:      {zh_stripped[:60]}...")
            stats["skipped_duplicate"] += 1
            return False
        stats["skipped_duplicate"] += 1
        return True
    translation_map[key] = zh_stripped
    stats["keys"] += 1
    return True


# Extra columns that may contain translatable Chinese text (beyond title/desc)
EXTRA_EVENT_COLS = ["on_enter"]  # stage-setting text before event display


def process_event_csv(filepath: Path) -> None:
    """
    Handles both Format A and Format B event CSV files.

    For option rows without their own uuid, generates a key using
    the parent event uuid + sequential per-parent counter.

    Processes: title, description, on_enter columns.
    """
    print(f"  📄 {filepath.relative_to(PROJECT_ROOT)}")

    with open(filepath, "r", encoding="utf-8", newline="") as f:
        content = f.read()

    lines = content.split("\n")
    if not lines:
        return

    reader = csv.reader([lines[0]])
    header = next(reader)
    header_lower = [h.strip().lower() for h in header]

    def find_col(name: str) -> int:
        try:
            return header_lower.index(name)
        except ValueError:
            return -1

    uuid_col = find_col("uuid")
    row_type_col = find_col("row_type")
    title_col = find_col("title")
    desc_col = find_col("description")
    name_col = find_col("name")
    onenter_col = find_col("on_enter")

    if row_type_col < 0:
        row_type_col = 0
    if uuid_col < 0:
        uuid_col = 1
    if title_col < 0 and name_col < 0:
        title_col = 4
    if desc_col < 0:
        desc_col = 5

    actual_title_col = name_col if name_col >= 0 else title_col

    # Build list of all text columns to process
    text_cols = [(actual_title_col, "TITLE")]
    if desc_col >= 0:
        text_cols.append((desc_col, "DESC"))
    if onenter_col >= 0:
        text_cols.append((onenter_col, "ONENTER"))

    modified_lines = []
    file_stats = {"rows": 0, "keys": 0}
    parent_uuid: str = ""
    opt_counter: int = 0

    for line_num, line in enumerate(lines):
        if line_num == 0:
            modified_lines.append(line)
            continue

        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            modified_lines.append(line)
            continue

        try:
            row = list(csv.reader([stripped]))[0]
        except Exception:
            modified_lines.append(line)
            continue

        # Ensure row has enough columns for all text cols
        max_needed = max(c for c, _ in text_cols) if text_cols else 0
        while len(row) <= max_needed:
            row.append("")

        row_type = row[row_type_col].strip() if row_type_col < len(row) else ""
        uuid_val = row[uuid_col].strip() if uuid_col < len(row) else ""

        is_opt = row_type.startswith(">")

        if not is_opt:
            parent_uuid = uuid_val
            opt_counter = 0

        effective_uuid = uuid_val
        if is_opt and not effective_uuid:
            if not parent_uuid:
                modified_lines.append(line)
                stats["skipped_empty"] += 1
                continue
            effective_uuid = f"{parent_uuid}_OPT{opt_counter}"
            opt_counter += 1

        if not effective_uuid:
            modified_lines.append(line)
            stats["skipped_empty"] += 1
            continue

        modified = False

        for col_idx, suffix in text_cols:
            if col_idx >= len(row):
                continue
            val = row[col_idx].strip()
            if has_cjk(val) and not is_already_key(val):
                key = make_key("EVT", effective_uuid, suffix)
                if register_translation(key, val):
                    row[col_idx] = key
                    modified = True
                    file_stats["keys"] += 1

        if modified:
            file_stats["rows"] += 1
            modified_lines.append(",".join(_csv_quote_cell(c) for c in row))
        else:
            modified_lines.append(line)

    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(modified_lines))
        if modified_lines and modified_lines[-1] != "":
            f.write("\n")

    stats["files"] += 1
    stats["rows"] += file_stats["rows"]
    print(f"    ✅ {file_stats['rows']} rows modified, {file_stats['keys']} keys generated")


# Extra trait columns that may contain Chinese
TRAIT_TEXT_COLS = ["trait_name", "narrative_murmur", "conditional_time_penalty"]


def process_traits_csv(filepath: Path) -> None:
    print(f"  📄 {filepath.relative_to(PROJECT_ROOT)}")
    with open(filepath, "r", encoding="utf-8", newline="") as f:
        content = f.read()
    lines = content.split("\n")
    reader = csv.reader([lines[0]])
    header = next(reader)
    header_lower = [h.strip().lower() for h in header]

    def _find(name: str) -> int:
        try:
            return header_lower.index(name)
        except ValueError:
            return -1

    trait_id_col = _find("trait_id")
    if trait_id_col < 0:
        trait_id_col = 0

    # Map column indices for each text column
    text_cols = []
    for col_name in TRAIT_TEXT_COLS:
        ci = _find(col_name)
        if ci >= 0:
            text_cols.append((ci, col_name.upper()))

    modified_lines = []
    file_stats = {"rows": 0, "keys": 0}
    for line_num, line in enumerate(lines):
        if line_num == 0:
            modified_lines.append(line)
            continue
        stripped = line.strip()
        if not stripped:
            modified_lines.append(line)
            continue
        try:
            row = list(csv.reader([stripped]))[0]
        except Exception:
            modified_lines.append(line)
            continue
        max_needed = max(trait_id_col, max(c for c, _ in text_cols)) if text_cols else trait_id_col
        while len(row) <= max_needed:
            row.append("")
        tid = row[trait_id_col].strip()
        if not tid:
            modified_lines.append(line)
            continue
        modified = False
        for col_idx, suffix in text_cols:
            if col_idx >= len(row):
                continue
            val = row[col_idx].strip()
            if has_cjk(val) and not is_already_key(val):
                key = make_key("TRAIT", tid, suffix)
                if register_translation(key, val):
                    row[col_idx] = key
                    modified = True
                    file_stats["keys"] += 1
        if modified:
            file_stats["rows"] += 1
        modified_lines.append(",".join(_csv_quote_cell(c) for c in row))
    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(modified_lines))
        if modified_lines and modified_lines[-1] != "":
            f.write("\n")
    stats["files"] += 1
    stats["rows"] += file_stats["rows"]
    print(f"    ✅ {file_stats['rows']} rows modified, {file_stats['keys']} keys generated")


def process_resource_converters_csv(filepath: Path) -> None:
    print(f"  📄 {filepath.relative_to(PROJECT_ROOT)}")
    with open(filepath, "r", encoding="utf-8", newline="") as f:
        content = f.read()
    lines = content.split("\n")
    reader = csv.reader([lines[0]])
    header = next(reader)
    header_lower = [h.strip().lower() for h in header]
    uuid_col = header_lower.index("uuid") if "uuid" in header_lower else 0
    name_col = header_lower.index("name") if "name" in header_lower else 1
    desc_col = header_lower.index("description") if "description" in header_lower else -1
    modified_lines = []
    file_stats = {"rows": 0, "keys": 0}
    for line_num, line in enumerate(lines):
        if line_num == 0:
            modified_lines.append(line)
            continue
        stripped = line.strip()
        if not stripped:
            modified_lines.append(line)
            continue
        try:
            row = list(csv.reader([stripped]))[0]
        except Exception:
            modified_lines.append(line)
            continue
        max_needed = max(uuid_col, name_col, desc_col) if desc_col >= 0 else max(uuid_col, name_col)
        while len(row) <= max_needed:
            row.append("")
        uid = row[uuid_col].strip()
        nv = row[name_col].strip() if name_col < len(row) else ""
        if not uid:
            modified_lines.append(line)
            continue
        mod = False
        if has_cjk(nv) and not is_already_key(nv):
            k = make_key("ACT", uid, "NAME")
            if register_translation(k, nv):
                row[name_col] = k
                mod = True
                file_stats["keys"] += 1
        if desc_col >= 0 and desc_col < len(row):
            dv = row[desc_col].strip()
            if has_cjk(dv) and not is_already_key(dv):
                k = make_key("ACT", uid, "DESC")
                if register_translation(k, dv):
                    row[desc_col] = k
                    mod = True
                    file_stats["keys"] += 1
        if mod:
            file_stats["rows"] += 1
            modified_lines.append(",".join(_csv_quote_cell(c) for c in row))
        else:
            modified_lines.append(line)
    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(modified_lines))
        if modified_lines and modified_lines[-1] != "":
            f.write("\n")
    stats["files"] += 1
    stats["rows"] += file_stats["rows"]
    print(f"    ✅ {file_stats['rows']} rows modified, {file_stats['keys']} keys generated")


def _csv_quote_cell(cell: str) -> str:
    cell_str = str(cell)
    if "," in cell_str or '"' in cell_str or "\n" in cell_str:
        return '"' + cell_str.replace('"', '""') + '"'
    return cell_str


def load_existing_translations() -> Dict[str, str]:
    existing = {}
    if TRANSLATION_CSV.exists():
        with open(TRANSLATION_CSV, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            rows = list(reader)
            if len(rows) >= 2:
                header = rows[0]
                keys_col = header.index("keys") if "keys" in header else 0
                zh_col = header.index("zh") if "zh" in header else 1
                for row in rows[1:]:
                    if len(row) > max(keys_col, zh_col):
                        k = row[keys_col].strip()
                        z = row[zh_col].strip()
                        if k and z:
                            existing[k] = z
    return existing


def write_translation_csv() -> None:
    existing = load_existing_translations()
    merged = dict(existing)
    merged.update(translation_map)
    sorted_keys = sorted(merged.keys())
    with open(TRANSLATION_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["keys", "zh", "en", "ja"])
        for key in sorted_keys:
            writer.writerow([key, merged[key], "", ""])
    print(f"\n📝 Translation CSV written: {TRANSLATION_CSV}")
    print(f"   Total keys: {len(sorted_keys)} (existing: {len(existing)}, new: {len(translation_map)})")


def find_all_data_csvs() -> List[Path]:
    data_dir = PROJECT_ROOT / "data"
    csv_files = []
    for pattern in [
        "3_actions_pool/events/**/*.csv",
        "4_eras/**/*.csv",
        "1_core_rules/disease/_disease_events.csv",
        "1_core_rules/traits/_traits.csv",
        "1_core_rules/resource_converters.csv",
    ]:
        base = data_dir / pattern.split("/")[0]
        rest = "/".join(pattern.split("/")[1:])
        if "**" in pattern:
            for f in data_dir.glob(pattern):
                csv_files.append(f)
        else:
            path = data_dir / pattern
            if path.exists():
                csv_files.append(path)
    csv_files = [f for f in csv_files if "_dynamic_events.csv" not in str(f) and "base_province" not in str(f) and "territories" not in str(f)]
    return sorted(set(csv_files))


def detect_csv_type(filepath: Path) -> str:
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            first_line = f.readline().strip()
        header = [h.strip().lower() for h in first_line.split(",")]
        if "trait_id" in header and "trait_name" in header:
            return "traits"
        if "parent_action" in header and "required_place" in header:
            return "resource_converter"
        if "row_type" in header and "uuid" in header:
            return "event"
        if "uuid" in header and ("name" in header or "title" in header):
            return "event"
        return "unknown"
    except Exception:
        return "unknown"


def main():
    print("=" * 60)
    print("🔍 i18n CSV Migration — Phase 3")
    print("=" * 60)

    csv_files = find_all_data_csvs()
    print(f"\nFound {len(csv_files)} CSV files to process\n")

    for filepath in csv_files:
        csv_type = detect_csv_type(filepath)
        try:
            if csv_type == "event":
                process_event_csv(filepath)
            elif csv_type == "traits":
                process_traits_csv(filepath)
            elif csv_type == "resource_converter":
                process_resource_converters_csv(filepath)
            else:
                print(f"  ⏭️  {filepath.relative_to(PROJECT_ROOT)} — unknown type, skipping")
        except Exception as e:
            print(f"  ❌ {filepath.relative_to(PROJECT_ROOT)} — ERROR: {e}")
            import traceback
            traceback.print_exc()

    write_translation_csv()

    print("\n" + "=" * 60)
    print("📊 Migration Summary")
    print("=" * 60)
    print(f"  Files processed:  {stats['files']}")
    print(f"  Rows modified:    {stats['rows']}")
    print(f"  Keys generated:   {stats['keys']}")
    print(f"  Duplicates:       {stats['skipped_duplicate']}")
    print(f"  Skipped (empty):  {stats['skipped_empty']}")
    print(f"  ✨ Phase 3 complete. Run Phase 4 to regenerate .tres files.")


if __name__ == "__main__":
    main()
