#!/usr/bin/env python3
"""
i18n Phase 6 - Full extract: .tres/.tscn/.gd → translation CSV
================================================================
Scans ALL remaining Chinese text, generates namespaced keys,
replaces .tres/.tscn in-place, extracts .gd strings to table only.
"""

import csv
import hashlib
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSLATION_CSV = PROJECT_ROOT / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"

CJK = re.compile(r"[\u4e00-\u9fff]")
CONST_KEY = re.compile(r"^[A-Z][A-Z0-9_]*$")
EXCLUDE = {".git", ".godot", ".venv", "addons", "__pycache__", "node_modules", "tests"}

# .tres translatable fields
TEXT_FIELDS = {
    "name", "description", "transition_text", "info", "failed_hint",
    "disabled_reason", "perception_text", "death_hint", "interrupt_text",
    "crazy_option_text", "narrative_murmur", "display_char",
    "trait_name", "hint_text", "deadline_warning", "gain_text", "loss_text",
    "hover_narrative", "lock_narrative", "success_hint",
    "description_explanation", "note_narrative", "note_explanation",
    "example", "idea_demonstrations",  # Array[String]
}

# These .tres fields contain Chinese but are data IDs, NOT translatable
ID_FIELDS = {"uuid", "primary_ethnicity", "color", "trait_id", "flag_id",
             "script", "icon", "texture", "resource_path", "uid",
             "metadata/_custom_type_script", "button_group",
             "stage_id", "texts", "interrupt_provider", "providers", "generator_name"}

existing: dict = {}
new_keys: dict = {}
stats = {"t": 0, "s": 0, "g": 0, "k": 0, "d": 0}


def slug(t: str) -> str:
    t = t.replace("-", "_").replace(".", "_").replace(" ", "_").replace("/", "_")
    t = re.sub(r"[^A-Za-z0-9_]", "", t.upper())
    return re.sub(r"_+", "_", t)[:80]


def load():
    if not TRANSLATION_CSV.exists():
        return
    with open(TRANSLATION_CSV, "r", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    if len(rows) < 2:
        return
    hdr = rows[0]
    kc = hdr.index("keys") if "keys" in hdr else 0
    zc = hdr.index("zh") if "zh" in hdr else 1
    for r in rows[1:]:
        if len(r) > max(kc, zc) and r[kc].strip() and r[zc].strip():
            existing[r[kc].strip()] = r[zc].strip()


def add(key: str, zh: str) -> bool:
    zh = zh.strip()
    if not zh or not CJK.search(zh):
        return False
    if key in existing or key in new_keys:
        stats["d"] += 1
        return False
    new_keys[key] = zh
    stats["k"] += 1
    return True


def cjk(s: str) -> bool:
    return bool(CJK.search(s))


def is_key(s: str) -> bool:
    return bool(CONST_KEY.match(s.strip()))


# ══════════════════════════════════════════════════════════
# .tres
# ══════════════════════════════════════════════════════════

FIELD_RX = re.compile(r'^(\w+)\s*=\s*"(.*)"$')
ARRAY_RX = re.compile(r'^(\w+)\s*=\s*Array\[String\]\(\[(.+)\]\)$')
ARRAY_ELEM_RX = re.compile(r'"([^"]*)"')


def scan_tres():
    print("🔍 .tres ...")
    cnt = 0
    for f in sorted(PROJECT_ROOT.rglob("*.tres")):
        if any(p in EXCLUDE for p in f.parts):
            continue
        try:
            raw = f.read_text("utf-8", errors="ignore")
        except:
            continue
        modified = False
        lines = raw.split("\n")
        out = []
        ctr: dict = {}

        for line in lines:
            # Skip comments
            s = line.strip()
            if s.startswith(";") or s.startswith("#"):
                out.append(line)
                continue

            # --- Array[String] ---
            am = ARRAY_RX.match(line)
            if am:
                fn = am.group(1).strip()
                body = am.group(2)
                if fn in TEXT_FIELDS:
                    elems = ARRAY_ELEM_RX.findall(body)
                    new_elems = []
                    changed = False
                    for e in elems:
                        if cjk(e) and not is_key(e):
                            k = f"TRES_{slug(f.stem)}_{slug(fn)}_{ctr.get(fn,0)}"
                            ctr[fn] = ctr.get(fn, 0) + 1
                            if add(k, e):
                                new_elems.append(f'"{k}"')
                                changed = True
                            else:
                                new_elems.append(f'"{e}"')
                        else:
                            new_elems.append(f'"{e}"')
                    if changed:
                        out.append(f'{fn} = Array[String]([{", ".join(new_elems)}])')
                        modified = True
                        cnt += 1
                        stats["t"] += len(new_elems)
                        continue
                out.append(line)
                continue

            # --- Simple field = "value" ---
            m = FIELD_RX.match(line)
            if not m:
                out.append(line)
                continue

            fn = m.group(1).strip()
            val = m.group(2)

            if fn in ID_FIELDS or not cjk(val) or is_key(val) or fn not in TEXT_FIELDS:
                out.append(line)
                continue

            k = f"TRES_{slug(f.stem)}_{slug(fn)}_{ctr.get(fn,0)}"
            ctr[fn] = ctr.get(fn, 0) + 1
            if add(k, val):
                out.append(f'{fn} = "{k}"')
                modified = True
                cnt += 1
                stats["t"] += 1
            else:
                out.append(line)

        if modified:
            with open(f, "w", encoding="utf-8", newline="") as fo:
                fo.write("\n".join(out))
                if out and out[-1] != "":
                    fo.write("\n")

    print(f"  ✅ {cnt} entries, {stats['t']} key registrations")


# ══════════════════════════════════════════════════════════
# .tscn — full project (not just data/)
# ══════════════════════════════════════════════════════════

TSCN_TX = re.compile(r'text\s*=\s*"([^"]*)"')


def scan_tscn():
    print("🔍 .tscn ...")
    cnt = 0
    for f in sorted(PROJECT_ROOT.rglob("*.tscn")):
        if any(p in EXCLUDE for p in f.parts):
            continue
        try:
            raw = f.read_text("utf-8", errors="ignore")
        except:
            continue
        modified = False
        idx = 0
        for m in TSCN_TX.finditer(raw):
            val = m.group(1)
            if not cjk(val) or is_key(val):
                continue
            k = f"UI_{slug(f.stem)}_TEXT_{idx}"
            idx += 1
            if add(k, val):
                raw = raw.replace(f'text = "{val}"', f'text = "{k}"', 1)
                modified = True
                cnt += 1
                stats["s"] += 1
        if modified:
            with open(f, "w", encoding="utf-8", newline="") as fo:
                fo.write(raw)
    print(f"  ✅ {cnt} entries")


# ══════════════════════════════════════════════════════════
# .gd — extract only (no in-place replacement)
# ══════════════════════════════════════════════════════════

STR_RX = re.compile(r'"([^"]*)"')


def scan_gd():
    print("🔍 .gd (extract only) ...")
    cnt = 0
    for f in sorted(PROJECT_ROOT.rglob("*.gd")):
        if any(p in EXCLUDE for p in f.parts):
            continue
        try:
            raw = f.read_text("utf-8", errors="ignore")
        except:
            continue
        for line in raw.split("\n"):
            s = line.strip()
            if s.startswith("#") or "Logging." in line or not cjk(line):
                continue
            for m in STR_RX.finditer(line):
                val = m.group(1)
                if not cjk(val) or is_key(val):
                    continue
                if val.startswith("res://") or val.startswith("uid://"):
                    continue
                h = hashlib.sha256(val.encode()).hexdigest()[:10].upper()
                k = f"CODE_{slug(f.stem)}_{h}"
                if add(k, val):
                    cnt += 1
                    stats["g"] += 1
    print(f"  ✅ {cnt} strings")


# ══════════════════════════════════════════════════════════
def write():
    merged = dict(existing)
    merged.update(new_keys)
    sk = sorted(merged)
    with open(TRANSLATION_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys", "zh", "en", "ja"])
        for k in sk:
            w.writerow([k, merged[k], "", ""])
    print(f"\n📝 {TRANSLATION_CSV}")
    print(f"   {len(sk)} total ({len(existing)} existing + {len(new_keys)} new)")


def main():
    load()
    print(f"Loaded {len(existing)} keys\n")
    scan_tres()
    print()
    scan_tscn()
    print()
    scan_gd()
    print()
    write()
    print(f"\n{'='*60}\n📊 .tres={stats['t']}  .tscn={stats['s']}  .gd={stats['g']}  keys={stats['k']}  dupes={stats['d']}\n✅ Done.")


if __name__ == "__main__":
    main()
