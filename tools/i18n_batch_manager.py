#!/usr/bin/env python3
"""i18n Batch Manager — 翻译批次提取与回写工具

用法:
  # 1. 从主 CSV 提取 15 个批次文件到 plans/i18n_batches/
  python3 tools/i18n_batch_manager.py extract

  # 2. 将某批次的翻译结果写回主 CSV
  python3 tools/i18n_batch_manager.py apply B01

  # 3. 查看进度
  python3 tools/i18n_batch_manager.py status
"""

import csv
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
MASTER_CSV = PROJECT_ROOT / "data" / "1_core_rules" / "translations" / "_dynamic_events.csv"
BATCH_DIR = PROJECT_ROOT / "plans" / "i18n_batches"

# ── 15 批次行范围定义 ──────────────────────────────────────────
BATCH_RANGES = [
    ("B01", 2, 121, "系统UI",
     "行动名/描述、角色名、地点标签、行动提示格式化、行动管理消息"),
    ("B02", 122, 241, "系统内部",
     "引荐/把柄运算符、BBcode格式化、Buff运算符、业务规则检查、链执行器、奉先事件"),
    ("B03", 242, 421, "数据层+UI组件",
     "CSV加载器、数据库、数据扫描、决策卷轴、情绪、枚举、事件按钮/UI、示例、阵营、聚焦对话、游戏数据面板、存档、测试诗事件、Glitch预处理器、理念、物品选择器、玩家面板、把柄添加"),
    ("B04", 422, 561, "游戏逻辑",
     "联句计分、检查器、主行动按钮、修饰符、月末结算、叙事覆盖、笔记管理、NPC行动/需求、选项按钮、人物状态、选择器、人选、玩家状态、诗词创作器"),
    ("B05", 562, 701, "诗词+属性+社交",
     "诗词评分/奖励/槽、属性状态/运算符/需求、中断、随机选择、范围需求、远程行动、右侧面板、随机意象、运行时探针、Schema检查、结算纸带、人物状态、驻留地点、粉碎效果、简单运算符、社交行动/关系页"),
    ("B06", 702, 871, "时间+特效+教程",
     "风格策略、子行动按钮、生存管理、时间呼吸/控制/运算符/服务（年号季节）、墓碑屏幕、特质展示/提示/运算符/需求、教程控制器、社交节点、URN、视觉测试"),
    ("B07", 1596, 1797, "核心属性系统",
     "FEIHUALING/LIANJU结果、PROPERTY_NAME属性名、TRAIT特质名、TRES时代/抱负/属性描述与6级渐变文本"),
    ("B08", 1798, 1997, "回落叙事①",
     "拜谒回落、长安漫步叙事、登高回落、疾病名称描述、独酌叙事、坊市回落、科举结束、抱负开始、回乡叙事"),
    ("B09", 1998, 2108, "回落叙事②+理念",
     "坊市回落(续)、奉先村叙事、奉召回落、科举叙事、归家、健康渐变、宴席回落、理念描述、灵感渐变"),
    ("B10", 2177, 2259, "NPC交互+渐变",
     "暗巷回落、联句叙事、李白品酒、右相承诺、势渐变、金钱渐变、濒死焚稿"),
    ("B11", 2260, 2343, "笔记+诗词+渐变",
     "教程笔记、NPC文档、出城、宴席唱和、同乡、诗词模板、诗人名、声望渐变、仕途渐变、狂态示例"),
    ("B12", 2558, 2687, "教程对话①",
     "渔阳鼙鼓结局、时间渐变、吐蕃、教程出游（山间/望山/四方探索）、延迟完成、对话（偶遇/意气/志向/体魄/岁月）、共饮、揭示、告别"),
    ("B13", 2688, 2795, "教程②+叙事",
     "教程理念提示/解锁、交游、望山、遇道士、迷雾、无灵感、评诗、驻留、回道人、道人名、天地苍茫、升官、右相府门叙事、郑虔交换、浊流钻营碎片"),
    ("B14", 2758, 2840, "叙事碎片+UI①",
     "浊流钻营(续)、自责叙事（冻尸/当玉/家书/故友/酒保/书生）、UI行动按钮/抱负/竹简/确认/存档/理念/物品/玩家面板/主行动/叙事覆盖/笔记"),
    ("B15", 2841, 2874, "UI②",
     "UI NPC行动/覆盖行动/选择器/诗词创作/诗词需求/诗词槽/属性标签/右侧面板/小按钮/小属性/社交页/系统菜单/时间控制/墓碑/特质展示/养疴"),
]

GLOBAL_RULES = """# ─── 全局翻译铁律 ──────────────────────────────────────────────
# 1. 保留所有标记原样: {param} {@keyword} [br] [glitch level=N]...[/glitch]
#    [color=#xxx]...[/color] [font_size=N][b]...[/b][/font_size] [i]...[/i]
#    [center]...[/center] [shake rate=N level=N]...[/shake] \\n
# 2. 保留 %d %s %.1f %% 等 C 风格格式说明符
# 3. 保留 emoji 和特殊字符: ⏱ ⏳ 📍 ⚠ ━━━ • 等
# 4. 风格: 自然流畅英文，非文言英译。唐代氛围但不堆砌生僻词
# 5. 只输出第3列(en)的翻译，每行一个翻译字符串，按输入顺序，空行输出空
# 6. 输出格式: 一个纯文本文件，每行一个英文翻译
# ────────────────────────────────────────────────────────────────
"""


def read_master_csv() -> list[dict]:
    rows = []
    with open(MASTER_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "keys": row.get("keys", "").strip(),
                "zh": row.get("zh", "").strip(),
                "en": row.get("en", "").strip(),
                "ja": row.get("ja", "").strip(),
            })
    return rows


def write_master_csv(rows: list[dict]):
    with open(MASTER_CSV, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["keys", "zh", "en", "ja"])
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def extract_batches():
    os.makedirs(BATCH_DIR, exist_ok=True)
    all_rows = read_master_csv()
    total_lines = len(all_rows)

    for batch_id, start, end, domain, description in BATCH_RANGES:
        start_idx = start - 2
        end_idx = end - 2

        if start_idx < 0 or end_idx >= total_lines:
            print(f"  ⚠ {batch_id}: 行范围 {start}-{end} 超出文件范围，跳过")
            continue

        batch_rows = all_rows[start_idx : end_idx + 1]
        need_translation = [r for r in batch_rows if r["zh"] and not r["en"]]
        skip_count = len(batch_rows) - len(need_translation)

        # _en.txt — 子Agent 在此填写翻译
        en_file = BATCH_DIR / f"{batch_id}_en.txt"
        with open(en_file, "w", encoding="utf-8") as f:
            f.write(f"# Batch {batch_id}: {domain} — {description}\n")
            f.write(f"# 行范围: {start}-{end}  待翻译: {len(need_translation)}行  已有: {skip_count}行\n")
            f.write(GLOBAL_RULES)
            f.write(f"# 域: {domain}\n")
            f.write("# 格式: 每行一条英文翻译。已翻译的行保留原 en 值不动，待翻译的行填空行。\n")
            f.write("# ────────────────────────────────────────────────────────────────\n\n")
            for row in batch_rows:
                f.write(f"# [{row['keys']}] {row['zh']}\n")
                if row["en"]:
                    f.write(f"{row['en']}\n")
                else:
                    f.write("\n")

        print(f"  ✅ {batch_id}: 行{start}-{end} → {en_file.name} ({len(need_translation)}行待译)")

    print(f"\n✅ 全部 {len(BATCH_RANGES)} 批次已提取到 {BATCH_DIR}/")
    print(f"   子Agent翻译 *_en.txt 后，运行:")
    print(f"   python3 tools/i18n_batch_manager.py apply B01  (以此类推)")


def apply_batch(batch_id: str):
    en_file = BATCH_DIR / f"{batch_id}_en.txt"
    if not en_file.exists():
        print(f"❌ 找不到 {en_file}")
        sys.exit(1)

    batch_info = None
    for b in BATCH_RANGES:
        if b[0] == batch_id:
            batch_info = b
            break
    if not batch_info:
        print(f"❌ 未知批次: {batch_id}")
        sys.exit(1)

    # 读取 _en.txt — 按 key 解析翻译（每行格式: # [KEY] zh_text \n en_text）
    key_to_en: dict[str, str] = {}
    current_key = None
    with open(en_file, "r", encoding="utf-8") as f:
        for line in f:
            stripped = line.rstrip("\n").rstrip("\r")
            if stripped.startswith("# [") and "] " in stripped:
                # e.g. "# [CODE_EXAMPLE_USAGE_2117252AA8] 拂袖而去"
                bracket_end = stripped.index("] ")
                current_key = stripped[3:bracket_end]  # skip "# ["
            elif current_key and not stripped.startswith("#"):
                # Translation line (non-comment, non-blank) — only store if not already set
                if stripped and current_key not in key_to_en:
                    key_to_en[current_key] = stripped
                current_key = None
            elif stripped == "":
                # Blank line — consume current_key without storing
                current_key = None

    # 写回主 CSV — 按 key 匹配
    all_rows = read_master_csv()
    applied = 0
    for row in all_rows:
        key = row["keys"]
        if key in key_to_en and row["zh"] and not row["en"]:
            new_en = key_to_en[key].strip()
            if new_en:
                row["en"] = new_en
                applied += 1

    write_master_csv(all_rows)
    print(f"✅ {batch_id}: 已写入 {applied} 条 EN 翻译（按 key 匹配） → {MASTER_CSV}")


def status_batches():
    all_rows = read_master_csv()
    print("批次翻译进度:\n")
    total_need = 0
    total_done = 0
    for batch_id, start, end, domain, _ in BATCH_RANGES:
        start_idx = start - 2
        end_idx = min(end - 1, len(all_rows) - 1)
        batch_rows = all_rows[start_idx : end_idx + 1]
        need = sum(1 for r in batch_rows if r["zh"])
        done = sum(1 for r in batch_rows if r["zh"] and r["en"])
        total_need += need
        total_done += done
        pct = f"{done}/{need}"
        width = 20
        filled = int(width * done / need) if need else 0
        bar = "▓" * filled + "░" * (width - filled)
        pct_str = f"{100*done//need}%" if need else "100%"
        print(f"  {batch_id}  {bar}  {pct} ({pct_str})  {domain}")
    pct_all = f"{100*total_done//total_need}%" if total_need else "100%"
    print(f"\n  总计: {total_done}/{total_need} ({pct_all})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        print("可用命令: extract | apply <BATCH_ID> | status")
        sys.exit(0)

    cmd = sys.argv[1].lower()

    if cmd == "extract":
        extract_batches()
    elif cmd == "apply":
        if len(sys.argv) < 3:
            print("用法: python3 tools/i18n_batch_manager.py apply <BATCH_ID>")
            sys.exit(1)
        apply_batch(sys.argv[2].upper())
    elif cmd == "status":
        status_batches()
    else:
        print(f"未知命令: {cmd}")
        print("可用命令: extract | apply <BATCH_ID> | status")
        sys.exit(1)
