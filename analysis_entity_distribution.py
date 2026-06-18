#!/usr/bin/env python3
"""分析15个社交实体在事件库中的分布情况"""

import json
import csv
import os
import re
import glob
from collections import defaultdict

# ─── 实体定义 ───────────────────────────────────────────
ENTITIES = {
    # 具名 NPC
    "NPC_GAOSHI":    {"id": "GAOSHI",    "name": "高适",   "type": "npc"},
    "NPC_WANGWEI":   {"id": "WANGWEI",   "name": "王维",   "type": "npc"},
    "NPC_ZHENGQIAN": {"id": "ZHENGQIAN", "name": "郑虔",   "type": "npc"},
    "NPC_LIBAI":     {"id": "LIBAI",     "name": "李白",   "type": "npc"},
    "NPC_LILINFU":   {"id": "LILINFU",   "name": "李灵甫", "type": "npc"},
    # 势力
    "FACTION_QINGLIU": {"id": "QINGLIU", "name": "清流", "type": "faction"},
    "FACTION_ZHUOLIU": {"id": "ZHUOLIU", "name": "浊流", "type": "faction"},
    # 身份
    "IDENTITY_QINGLIU_OWNER":     {"id": "qingliu_owner",     "name": "清流主人",     "type": "identity"},
    "IDENTITY_JIXIAN_ACADEMIC":   {"id": "jixian_academic",   "name": "集贤院学士",   "type": "identity"},
    "IDENTITY_COUNTY_SHERIFF":    {"id": "county_sheriff",    "name": "县尉",         "type": "identity"},
    "IDENTITY_BROKER":            {"id": "broker",            "name": "掮客",         "type": "identity"},
    "IDENTITY_PURPLE_ROBE_NOBLE": {"id": "purple_robe_noble", "name": "紫袍胖子权贵", "type": "identity"},
    "IDENTITY_QINGKE":            {"id": "qingke",            "name": "清客",         "type": "identity"},
    "IDENTITY_MENZI":             {"id": "menzi",             "name": "门子",         "type": "identity"},
    "IDENTITY_ZHUOLIU_OFFICIAL":  {"id": "zhuoliu_official",  "name": "浊流官僚",     "type": "identity"},
}

# ─── 从 tag 字典提取现有 TARGET tag ─────────────────────
def extract_target_tags_from_dictionary():
    """从 tag_dictioinary.md 提取已有的 TARGET_NPC_* 和 TARGET_FACTION_*"""
    tag_file = "DOCUMENTATIONS/events/tag_dictioinary.md"
    result = {}
    with open(tag_file, 'r') as f:
        content = f.read()
    # 找所有 TARGET_NPC_ 和 TARGET_FACTION_ 行
    for line in content.split('\n'):
        line = line.strip()
        # 格式: `TARGET_NPC_LIBAI`
        for prefix in ['TARGET_NPC_', 'TARGET_FACTION_']:
            match = re.search(rf'`({prefix}\w+)`', line)
            if match:
                tag = match.group(1)
                result[tag] = True
    return result

# ─── 实体 key -> 搜索词列表 ──────────────────────────────
def get_entity_search_terms():
    """为每个实体生成搜索用的词列表"""
    terms = {}
    for ent_key, ent in ENTITIES.items():
        t = []
        t.append(ent['id'])          # LIBAI, GAOSHI, etc
        t.append(ent['name'])        # 李白, 高适, etc
        # 对于身份实体，还需要拆词搜索
        if ent['type'] == 'identity':
            # 比如 "清流主人" -> ["清流主人", "清流", "主人"]
            # "集贤院学士" -> ["集贤院学士", "集贤院", "学士"]
            # "紫袍胖子权贵" -> whole name only
            pass
        terms[ent_key] = t
    return terms

# ─── 1. Tag 字典现有 tag ────────────────────────────────
def analyze_tag_dictionary():
    existing = extract_target_tags_from_dictionary()
    rows = []
    for ent_key in ENTITIES:
        ent = ENTITIES[ent_key]
        prefix = f"TARGET_{ent['type'].upper()}_"
        expected_tag = f"{prefix}{ent['id']}"
        has_tag = expected_tag in existing
        rows.append({
            'entity_key': ent_key,
            'name': ent['name'],
            'type': ent['type'],
            'expected_tag': expected_tag,
            'has_target_tag': has_tag,
        })
    return rows

# ─── 2. Config JSON 分析 ────────────────────────────────
def analyze_config_jsons():
    config_files = sorted(glob.glob("tools/event_base_config_*.json"))
    # 排除 sandbox
    config_files = [f for f in config_files if '_sandbox' not in os.path.basename(f)]

    results = []  # [{config, entities_found: {ent_key: [where_found]}, missing: []}]

    for cf in config_files:
        basename = os.path.basename(cf)
        with open(cf, 'r') as f:
            try:
                data = json.load(f)
            except:
                results.append({'config': basename, 'entities_found': {}, 'missing': [], 'error': 'json parse error'})
                continue

        entities_found = defaultdict(list)  # ent_key -> [location]

        # 检查 background_context
        bg = data.get('background_context', '')
        # 检查 ai_persona
        ai = data.get('ai_persona', '')

        # 检查 dimensions
        dims = data.get('dimensions', [])
        for dim in dims:
            for val in dim.get('values', []):
                val_id = val.get('id', '')
                tags = val.get('tags', [])
                tags_str = ' '.join(tags)

                # 检查 value id 是否包含实体 ID
                for ent_key, ent in ENTITIES.items():
                    if ent['id'].lower() in val_id.lower():
                        entities_found[ent_key].append(f"dim:{dim['id']}/val.id={val_id}")
                    if ent['name'] in val_id:
                        entities_found[ent_key].append(f"dim:{dim['id']}/val.id={val_id}")

                # 检查 tags 是否包含实体tag
                for ent_key, ent in ENTITIES.items():
                    prefix = f"TARGET_{ent['type'].upper()}_"
                    expected_tag = f"{prefix}{ent['id']}"
                    for tag in tags:
                        if expected_tag in tag:
                            entities_found[ent_key].append(f"dim:{dim['id']}/tags.contains={expected_tag}")

        # 检查 universal_tags
        utags = ' '.join(data.get('universal_tags', []))
        for ent_key, ent in ENTITIES.items():
            if ent['name'] in utags:
                entities_found[ent_key].append("universal_tags")
            if ent['id'].lower() in utags.lower():
                entities_found[ent_key].append("universal_tags")

        # 检查 background_context 中的实体名字
        for ent_key, ent in ENTITIES.items():
            if ent['name'] in bg:
                entities_found[ent_key].append("background_context")

        # 检查 ai_persona 中的实体名字
        for ent_key, ent in ENTITIES.items():
            if ent['name'] in ai:
                entities_found[ent_key].append("ai_persona")

        # 确定缺失
        found_set = set(entities_found.keys())
        all_set = set(ENTITIES.keys())
        missing = sorted(all_set - found_set, key=lambda k: (ENTITIES[k]['type'], ENTITIES[k]['name']))

        results.append({
            'config': basename,
            'entities_found': dict(entities_found),
            'missing': missing,
        })

    return results

# ─── 3. CSV 分析 ───────────────────────────────────────
def analyze_csvs():
    csv_files = sorted(glob.glob("data/4_eras/747_kuangda/*.csv"))

    results = []

    for cf in csv_files:
        basename = os.path.basename(cf)
        entity_count = defaultdict(int)  # ent_key -> count
        total_events = 0

        with open(cf, 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                total_events += 1
                # 检查 context 列 (包含 trigger_tags=...)
                context = row.get('context', '')
                # 检查 description 列
                desc = row.get('description', '')
                # 检查 title
                title = row.get('title', '')
                # 检查 on_enter
                on_enter = row.get('on_enter', '')
                # 检查 results
                results_col = row.get('results', '')

                combined = f"{context} {desc} {title} {on_enter} {results_col}"

                for ent_key, ent in ENTITIES.items():
                    if ent['name'] in combined:
                        entity_count[ent_key] += 1

        results.append({
            'csv': basename,
            'total_events': total_events,
            'entities_found': dict(entity_count),
        })

    return results

# ─── 4. Sandbox JSON 分析 ───────────────────────────────
def analyze_sandboxes():
    sandbox_files = sorted(glob.glob("tools/event_base_config_*_sandbox.json"))

    results = []

    for sf in sandbox_files:
        basename = os.path.basename(sf)
        with open(sf, 'r') as f:
            try:
                data = json.load(f)
            except:
                results.append({'sandbox': basename, 'entities_found': [], 'error': 'json parse error'})
                continue

        entities_found = []

        # sandbox JSON 结构: {key: [strings...]}
        if isinstance(data, dict):
            all_text = json.dumps(data, ensure_ascii=False)
            for ent_key, ent in ENTITIES.items():
                if ent['name'] in all_text:
                    entities_found.append(ent_key)

        results.append({
            'sandbox': basename,
            'entities_found': entities_found,
        })

    return results

# ─── 生成报告 ───────────────────────────────────────────
def generate_report(tag_rows, config_results, csv_results, sandbox_results):
    lines = []

    lines.append("# 15个社交实体事件分布报告\n")
    lines.append(f"> 生成时间: 2026-06-17\n")
    lines.append("---\n")

    # ── 1. Tag 字典现状 ──
    lines.append("## 1. Tag 字典现状\n")
    lines.append("| 实体 | 类型 | 预期 TARGET tag | 是否有 TARGET tag |")
    lines.append("|------|------|----------------|-------------------|")

    npc_rows = [r for r in tag_rows if r['type'] == 'npc']
    faction_rows = [r for r in tag_rows if r['type'] == 'faction']
    identity_rows = [r for r in tag_rows if r['type'] == 'identity']

    for r in npc_rows:
        status = "✅" if r['has_target_tag'] else "❌ 缺失"
        lines.append(f"| {r['name']} | NPC | `{r['expected_tag']}` | {status} |")

    for r in faction_rows:
        status = "✅" if r['has_target_tag'] else "❌ 缺失"
        lines.append(f"| {r['name']} | 势力 | `{r['expected_tag']}` | {status} |")

    lines.append("")
    lines.append("> **身份类实体**: 身份类不使用 TARGET tag（身份不是对象，而是角色属性），因此不在此表中。\n")

    # ── 2. Config JSON 分布 ──
    lines.append("## 2. Config JSON 分布\n")
    lines.append("### 2.1 按 Config 详细分布\n")

    for cr in config_results:
        cfg = cr['config']
        short = cfg.replace('event_base_config_', '').replace('.json', '')
        found = cr['entities_found']
        missing = cr['missing']

        lines.append(f"#### {short}\n")

        if found:
            lines.append("| 实体 | 出现位置 |")
            lines.append("|------|---------|")
            for ent_key in sorted(found.keys(), key=lambda k: (ENTITIES[k]['type'], ENTITIES[k]['name'])):
                locations = '; '.join(found[ent_key])
                lines.append(f"| {ENTITIES[ent_key]['name']} ({ent_key}) | {locations} |")
            lines.append("")

        if missing:
            lines.append(f"**缺失实体 ({len(missing)}):** ")
            miss_names = [f"{ENTITIES[k]['name']}" for k in missing]
            lines.append(', '.join(miss_names))
            lines.append("\n")
        else:
            lines.append("*所有15个实体均有提及*\n")

    # ── 2.2 汇总矩阵 ──
    lines.append("### 2.2 Config × 实体 覆盖矩阵\n")

    # 构建矩阵
    config_names = [cr['config'].replace('event_base_config_', '').replace('.json', '') for cr in config_results]
    lines.append("| Config \\ 实体 | " + " | ".join([ENTITIES[e]['name'][:3] for e in ENTITIES.keys()]) + " |")
    lines.append("|" + "---|" * (len(ENTITIES) + 1))

    for i, cr in enumerate(config_results):
        row_cells = [config_names[i]]
        found_set = set(cr['entities_found'].keys())
        for ent_key in ENTITIES.keys():
            if ent_key in found_set:
                row_cells.append("✓")
            else:
                row_cells.append("—")
        lines.append("| " + " | ".join(row_cells) + " |")
    lines.append("")

    # ── 3. CSV 事件分布 ──
    lines.append("## 3. CSV 事件分布\n")

    for cr in csv_results:
        csv_name = cr['csv'].replace('_events.csv', '').lstrip('_')
        total = cr['total_events']
        found = cr['entities_found']

        lines.append(f"### {csv_name} (共 {total} 事件)\n")

        if found:
            lines.append("| 实体 | 出现次数 | 覆盖率 |")
            lines.append("|------|---------|--------|")
            for ent_key in sorted(found.keys(), key=lambda k: (-found[k], ENTITIES[k]['name'])):
                rate = f"{found[ent_key] / total * 100:.1f}%"
                lines.append(f"| {ENTITIES[ent_key]['name']} ({ent_key}) | {found[ent_key]} | {rate} |")
        else:
            lines.append("*无实体提及*\n")
        lines.append("")

    # ── 4. Sandbox 提及情况 ──
    lines.append("## 4. Sandbox 提及情况\n")
    lines.append("| Sandbox 文件 | 提及的实体 |")
    lines.append("|-------------|-----------|")
    for sr in sandbox_results:
        sname = sr['sandbox'].replace('event_base_config_', '').replace('.json', '')
        if sr['entities_found']:
            entities_names = [f"{ENTITIES[e]['name']}" for e in sr['entities_found']]
            lines.append(f"| {sname} | {', '.join(entities_names)} |")
        else:
            lines.append(f"| {sname} | *(无)* |")
    lines.append("")

    # ── 5. 总结与建议 ──
    lines.append("## 5. 总结与建议\n")

    # 5.1 充分覆盖
    lines.append("### 5.1 充分覆盖的实体\n")
    # 在所有 config 中都有提及的实体
    all_covered = set(ENTITIES.keys())
    for cr in config_results:
        all_covered &= set(cr['entities_found'].keys())
    if all_covered:
        lines.append("以下实体在**所有 Config** 中均有提及：\n")
        for ent_key in sorted(all_covered, key=lambda k: (ENTITIES[k]['type'], ENTITIES[k]['name'])):
            lines.append(f"- **{ENTITIES[ent_key]['name']}** ({ent_key})")
    else:
        lines.append("*没有任何一个实体在所有 Config 中都有提及。*\n")
    lines.append("")

    # 5.2 需要添加 tag 的实体
    lines.append("### 5.2 需要添加 TARGET tag 的实体\n")
    need_tag = [r for r in tag_rows if not r['has_target_tag'] and r['type'] in ('npc', 'faction')]
    if need_tag:
        lines.append("| 实体 | 预期 tag |")
        lines.append("|------|---------|")
        for r in need_tag:
            lines.append(f"| {r['name']} | `{r['expected_tag']}` |")
    else:
        lines.append("*所有 NPC/势力实体都已有 TARGET tag。*\n")
    lines.append("")

    # 5.3 身份类实体分析
    lines.append("### 5.3 身份类实体分析\n")
    lines.append("身份类实体（identity）不使用 TARGET tag，而应通过 `virtual_dimension_ids` 或 `AI_PERSONA`/`BACKGROUND_CONTEXT` 注入。\n")
    identity_keys = [k for k in ENTITIES if ENTITIES[k]['type'] == 'identity']

    lines.append("| 身份实体 | 在 Config 中出现次数 | 在 CSV 中出现总次数 | 建议 |")
    lines.append("|---------|---------------------|-------------------|------|")
    for ik in identity_keys:
        config_count = sum(1 for cr in config_results if ik in cr['entities_found'])
        csv_total = sum(cr['entities_found'].get(ik, 0) for cr in csv_results)
        suggestion = ""
        if config_count == 0:
            suggestion = "⚠️ 未在任何 Config 中出现，建议添加"
        elif csv_total > 0:
            suggestion = "已在 CSV 中有实际出现"
        else:
            suggestion = "仅出现在 Config 文本中"
        lines.append(f"| {ENTITIES[ik]['name']} ({ik}) | {config_count}/{len(config_results)} | {csv_total} | {suggestion} |")
    lines.append("")

    # 5.4 建议优先处理的 config
    lines.append("### 5.4 建议优先处理的 Config\n")

    # 统计每个 config 缺失的 NPC + Faction + identity（需要关注的）
    target_types = ('npc', 'faction', 'identity')
    target_keys = [k for k in ENTITIES if ENTITIES[k]['type'] in target_types]

    lines.append("| Config | 缺失实体数 | 缺失列表 | 建议操作 |")
    lines.append("|--------|-----------|---------|---------|")
    for cr in config_results:
        missing = cr['missing']
        target_missing = [k for k in missing if ENTITIES[k]['type'] in target_types]
        if target_missing:
            names = [ENTITIES[k]['name'] for k in target_missing[:5]]
            more = f" +{len(target_missing)-5} more" if len(target_missing) > 5 else ""
            action = "补充 dimensions 或 universal_tags"
            lines.append(f"| {cr['config']} | {len(target_missing)} | {', '.join(names)}{more} | {action} |")
        else:
            lines.append(f"| {cr['config']} | 0 | — | 无需修改 |")
    lines.append("")

    lines.append("---\n")
    lines.append("*报告由 `analysis_entity_distribution.py` 自动生成*\n")

    return '\n'.join(lines)


# ─── Main ────────────────────────────────────────────────
if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)) or '.')

    print("=== 开始分析 ===")
    print("1/4 分析 Tag 字典...")
    tag_rows = analyze_tag_dictionary()

    print("2/4 分析 Config JSON...")
    config_results = analyze_config_jsons()

    print("3/4 分析 CSV 文件...")
    csv_results = analyze_csvs()

    print("4/4 分析 Sandbox JSON...")
    sandbox_results = analyze_sandboxes()

    print("生成报告...")
    report = generate_report(tag_rows, config_results, csv_results, sandbox_results)

    output_path = "plans/entity_distribution_report.md"
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"报告已保存到 {output_path}")
    print(f"报告长度: {len(report)} 字符")
