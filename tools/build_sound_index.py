#!/usr/bin/env python3
"""
build_sound_index.py — 扫描 assets/sounds/ 目录，生成 _file_index.json
供 AudioManager 在 HTML5 导出中 DirAccess 不可用时作为降级清单。

输出格式（与 data/_file_index.json 同一范式）:
{
  "files": ["755_backhome/baby_final.wav", "bell_impact/impactBell_heavy_000.ogg", ...],
  "generated_at": "...",
  "total": 39
}
"""
import json
import os
from datetime import datetime, timezone

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS_DIR = os.path.join(PROJECT_ROOT, "assets", "sounds")
OUTPUT_PATH = os.path.join(SOUNDS_DIR, "_file_index.json")

AUDIO_EXTS = {".ogg", ".wav", ".mp3"}


def main():
    files = []
    for root, dirs, filenames in os.walk(SOUNDS_DIR):
        rel_root = os.path.relpath(root, SOUNDS_DIR)
        if rel_root == ".":
            rel_root = ""

        for fname in sorted(filenames):
            if fname.startswith(".") or fname.startswith("_"):
                continue
            ext = os.path.splitext(fname)[1].lower()
            if ext not in AUDIO_EXTS:
                continue
            rel_path = os.path.join(rel_root, fname) if rel_root else fname
            files.append(rel_path)

    payload = {
        "files": files,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total": len(files),
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"[build_sound_index] 扫描完成: {len(files)} 个文件 → {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
