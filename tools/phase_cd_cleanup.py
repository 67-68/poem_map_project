#!/usr/bin/env python3
"""
Phase C+D: Multi-action event library cleaning script.

Phase C: Clean 6 KEEP libraries — modify JSON config + filter CSV
Phase D: Delete 12 SPLIT library JSON configs (6 config + 6 sandbox)
"""

import json
import csv
import os
import io
import re

BASE = "/Users/a67_68/projects/dufu_simulator"

# ============================================================
# Phase C: KEEP libraries
# ============================================================

KEEP_CONFIGS = [
    {
        "name": "kuangke_qingliu",
        "json": "tools/event_base_config_kuangke_qingliu.json",
        "csv": "data/4_eras/747_kuangda/_kuangke_qingliu_events.csv",
        "action": "jiaoyou",
        # Dimension values whose stored_to action doesn't match dominant action
        "delete_actions": ["fangshi", "denggao"],
    },
    {
        "name": "qingliu_passive_benefits",
        "json": "tools/event_base_config_qingliu_passive_benefits.json",
        "csv": "data/4_eras/747_kuangda/_qingliu_passive_benefits_events.csv",
        "action": "fangshi",
        "delete_actions": ["jiaoyou", "baiye"],
    },
    {
        "name": "qingliu_zuanying",
        "json": "tools/event_base_config_qingliu_zuanying.json",
        "csv": "data/4_eras/747_kuangda/_qingliu_zuanying_events.csv",
        "action": "jiaoyou",
        "delete_actions": ["fangshi"],
    },
    {
        "name": "qingliu_jiaolv",
        "json": "tools/event_base_config_qingliu_jiaolv.json",
        "csv": "data/4_eras/747_kuangda/_qingliu_jiaolv_events.csv",
        "action": "fangshi",
        "delete_actions": ["jiaoyou", "duzhuo"],
    },
    {
        "name": "zhuoliu_zuanying",
        "json": "tools/event_base_config_zhuoliu_zuanying.json",
        "csv": "data/4_eras/747_kuangda/_zhuoliu_zuanying_events.csv",
        "action": "jiaoyou",
        "delete_actions": ["fangshi", "baiye"],
    },
    {
        "name": "zize",
        "json": "tools/event_base_config_zize.json",
        "csv": "data/4_eras/747_kuangda/_zize_events.csv",
        "action": "fangshi",
        "delete_actions": ["duzhuo", "jiaoyou"],
    },
]


# ============================================================
# Helper: action name from store_to value
# ============================================================

def action_from_store_to(store_to: str) -> str:
    """Extract action name from '747_kuangda.jiaoyou' -> 'jiaoyou'"""
    return store_to.rsplit(".", 1)[-1] if "." in store_to else store_to


# ============================================================
# Phase C — JSON processing
# ============================================================

def process_keep_json(config: dict) -> dict:
    """Process a single KEEP library JSON:
    1. Set root-level archetype_id
    2. Find dimension values with stored_to not matching dominant action, delete them
    3. For remaining values, remove store_to and archetype_id fields
    4. Check for scene gateway dimensions (action:scene_* or action:main:XXX tags)
    """
    json_path = os.path.join(BASE, config["json"])
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    dominant_action = config["action"]
    delete_actions = config["delete_actions"]
    deleted_count = 0

    # Step 1: Set root archetype_id
    data["archetype_id"] = dominant_action
    print(f"  Root archetype_id set to: {dominant_action}")

    # Process dimensions
    if "dimensions" in data:
        dims_to_remove = []
        for dim_idx, dim in enumerate(data["dimensions"]):
            # Check if this is a scene gateway dimension
            is_scene_gateway = False
            for v in dim.get("values", []):
                tags = v.get("tags", [])
                for tag in tags:
                    if tag.startswith("action:scene_"):
                        is_scene_gateway = True
                        break
                if is_scene_gateway:
                    break

            if is_scene_gateway:
                print(f"  Scene gateway dimension detected: '{dim['id']}', will delete entire dimension")
                dims_to_remove.append(dim_idx)
                continue

            # Process values in this dimension
            values_to_keep = []
            for v in dim.get("values", []):
                store_to = v.get("stored_to")
                if store_to:
                    act = action_from_store_to(store_to)
                    if act in delete_actions:
                        print(f"  DELETE value '{v['id']}' (store_to={store_to})")
                        deleted_count += 1
                        continue

                # Keep this value: remove store_to and archetype_id
                v.pop("stored_to", None)
                v.pop("archetype_id", None)
                values_to_keep.append(v)

            dim["values"] = values_to_keep

        # Remove scene gateway dimensions (in reverse order to maintain indices)
        for idx in reversed(dims_to_remove):
            dim_name = data["dimensions"][idx]["id"]
            data["dimensions"].pop(idx)
            print(f"  REMOVED entire dimension: '{dim_name}'")

    print(f"  Total deleted dimension values: {deleted_count}")

    # Write back
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return data


# ============================================================
# Phase C — CSV processing
# ============================================================

def process_keep_csv(config: dict):
    """Process a single KEEP library CSV:
    1. Filter out event rows whose store_to doesn't match dominant action (and their option rows)
    2. From remaining event rows' context, delete 'store_to=<value>' (keep archetype=<value>)
    """
    csv_path = os.path.join(BASE, config["csv"])
    dominant_action = config["action"]

    # Read all lines
    with open(csv_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if not lines:
        print(f"  WARNING: Empty CSV: {config['csv']}")
        return

    header = lines[0]
    data_lines = lines[1:]

    # Parse into rows
    # CSV format: row_type,uuid,context,requirements,title,description,on_enter,results,interruptions,template,provider
    # We need to handle potential commas in context/description fields

    reader = csv.DictReader(io.StringIO("".join(lines)))
    fieldnames = reader.fieldnames

    rows = list(reader)

    # First pass: identify which event UUIDs to keep
    # An event row has row_type == "random_event"
    # An option row has row_type starting with ">option"
    # Options are linked to events by following after the event row (no explicit UUID link in CSV format)
    # Actually, looking at the CSV, options don't have a parent UUID field.
    # They are implicitly linked by position (option rows follow their parent event row).

    # Strategy: Parse sequentially. Track event row's store_to action.
    # If event's store_to doesn't match, skip the event AND any following option rows.
    # Option rows start with ">option"

    parsed_rows = []
    for row in rows:
        parsed_rows.append(row)

    # Filter: group by event-options
    # An event row has row_type == "random_event"
    # Following rows with row_type starting with ">" are its options
    filtered_rows = []
    skip_current_event = False
    kept_count = 0
    removed_event_count = 0
    removed_option_count = 0

    for row in parsed_rows:
        row_type = row.get("row_type", "").strip()

        if row_type == "random_event":
            # This is an event row - check its store_to
            context = row.get("context", "")
            store_to_match = re.search(r'store_to=([^\|]+)', context)
            if store_to_match:
                store_to_val = store_to_match.group(1).strip()
                action = action_from_store_to(store_to_val)
                if action != dominant_action:
                    skip_current_event = True
                    removed_event_count += 1
                    continue
                else:
                    skip_current_event = False
                    # Remove store_to from context (keep archetype)
                    context = re.sub(r'\|\s*store_to=[^\|]*', '', context)
                    context = re.sub(r'^store_to=[^\|]*\|', '', context)
                    context = re.sub(r'^store_to=[^\|]*$', '', context)
                    row["context"] = context
                    filtered_rows.append(row)
                    kept_count += 1
            else:
                # No store_to in context - keep it
                skip_current_event = False
                filtered_rows.append(row)
                kept_count += 1

        elif row_type.startswith(">"):
            # Option row
            if skip_current_event:
                removed_option_count += 1
                continue
            else:
                filtered_rows.append(row)

        else:
            # Unknown type, keep it
            skip_current_event = False
            filtered_rows.append(row)

    print(f"  Kept events: {kept_count}, Removed events: {removed_event_count}, Removed options: {removed_option_count}")

    # Write back — clean rows to only include known fieldnames
    cleaned_rows = []
    for row in filtered_rows:
        cleaned = {k: v for k, v in row.items() if k in fieldnames}
        cleaned_rows.append(cleaned)

    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(cleaned_rows)


# ============================================================
# Phase D: Delete SPLIT library JSON files
# ============================================================

SPLIT_FILES = [
    "tools/event_base_config_duotai_humiliation.json",
    "tools/event_base_config_duotai_humiliation_sandbox.json",
    "tools/event_base_config_kuangke_zhuoliu.json",
    "tools/event_base_config_kuangke_zhuoliu_sandbox.json",
    "tools/event_base_config_qingliu_fengying.json",
    "tools/event_base_config_qingliu_fengying_sandbox.json",
    "tools/event_base_config_qingliu_daoxin_posui.json",
    "tools/event_base_config_qingliu_daoxin_posui_sandbox.json",
    "tools/event_base_config_zhuoliu_fengying.json",
    "tools/event_base_config_zhuoliu_fengying_sandbox.json",
    "tools/event_base_config_zhuoliu_lieqi.json",
    "tools/event_base_config_zhuoliu_lieqi_sandbox.json",
]


def delete_split_files():
    """Delete 12 SPLIT library JSON files (6 config + 6 sandbox)"""
    deleted = 0
    not_found = 0
    for rel_path in SPLIT_FILES:
        full_path = os.path.join(BASE, rel_path)
        if os.path.exists(full_path):
            os.remove(full_path)
            print(f"  DELETED: {rel_path}")
            deleted += 1
        else:
            print(f"  NOT FOUND (skipped): {rel_path}")
            not_found += 1
    print(f"  Deleted: {deleted}, Not found (skipped): {not_found}")
    return deleted, not_found


# ============================================================
# Main
# ============================================================

def main():
    print("=" * 70)
    print("PHASE C: KEEP Library Cleaning (6 libraries)")
    print("=" * 70)

    for config in KEEP_CONFIGS:
        print(f"\n--- Processing: {config['name']} (dominant action: {config['action']}) ---")
        print(f"  JSON: {config['json']}")
        print(f"  CSV:  {config['csv']}")

        # JSON processing
        print("\n  [JSON]")
        process_keep_json(config)

        # CSV processing
        print("\n  [CSV]")
        process_keep_csv(config)

        print(f"  Done: {config['name']}")

    print("\n" + "=" * 70)
    print("PHASE D: Delete SPLIT Library JSON Configs (12 files)")
    print("=" * 70)
    delete_split_files()

    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print("Phase C: 6 KEEP libraries cleaned (JSON + CSV)")
    print("Phase D: 12 SPLIT library files deleted")
    print("\nNext step: Run Godot sync to verify no broken references")


if __name__ == "__main__":
    main()
