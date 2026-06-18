#!/usr/bin/env python3
"""扫描 747_kuangda 下所有 CSV 事件描述，分析每个身份的 leverage 潜力。"""

import csv
import os
import re
import json
from collections import defaultdict

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_DIR = os.path.join(BASE_DIR, "data", "4_eras", "747_kuangda")
OUTPUT = os.path.join(BASE_DIR, "plans", "leverage_scan_report.md")

# ============================================================
# 身份/NPC 关键词映射（从 canonical_social_identities.md）
# ============================================================
IDENTITY_KEYWORDS = {
    "TARGET_IDENTITY_QINGLIU_OWNER": {
        "name": "清流主人",
        "category": "清流上层",
        "patterns": [r"清流主人"],
    },
    "TARGET_IDENTITY_QINGLIU_OFFICIAL": {
        "name": "清流官",
        "category": "清流官僚",
        # 参军/侍郎/员外 出现在清流上下文中
        "patterns": [r"清流[^\n]{0,10}(?:参军|侍郎|员外)", r"(?:参军|侍郎|员外)[^\n]{0,10}清流"],
        # 也有单独匹配，上下文通过附近关键词辅助判断
        "context_required": True,
    },
    "TARGET_IDENTITY_ZHUOLIU_OFFICIAL": {
        "name": "浊流官",
        "category": "浊流官僚",
        "patterns": [r"浊流[^\n]{0,10}(?:参军|侍郎|员外)", r"(?:参军|侍郎|员外)[^\n]{0,10}浊流"],
        "context_required": True,
    },
    "TARGET_IDENTITY_QUANGUI": {
        "name": "权贵",
        "category": "浊流上层",
        "patterns": [r"权贵", r"紫袍"],
    },
    "TARGET_IDENTITY_QINGKE": {
        "name": "清客",
        "category": "清流门客",
        "patterns": [r"清客"],
    },
    "TARGET_IDENTITY_MENZI": {
        "name": "门子",
        "category": "底层吏员",
        "patterns": [r"门子"],
    },
    "TARGET_IDENTITY_COUNTY_SHERIFF": {
        "name": "县尉",
        "category": "地方吏员",
        "patterns": [r"县尉"],
    },
    "TARGET_IDENTITY_VENDOR": {
        "name": "商贩",
        "category": "市井商贩",
        "patterns": [r"掌柜", r"摊主", r"主簿"],
    },
    "TARGET_IDENTITY_POOR": {
        "name": "穷人",
        "category": "底层流浪",
        "patterns": [r"乞丐", r"流民"],
    },
}

NPC_KEYWORDS = {
    "TARGET_NPC_LIBAI": {"name": "李白", "patterns": [r"李白", r"太白"]},
    "TARGET_NPC_DUFU": {"name": "杜甫", "patterns": [r"杜甫", r"子美"]},
    "TARGET_NPC_WANGWEI": {"name": "王维", "patterns": [r"王维", r"摩诘"]},
    "TARGET_NPC_GAOSHI": {"name": "高适", "patterns": [r"高适", r"达夫"]},
    "TARGET_NPC_ZHENGQIAN": {"name": "郑虔", "patterns": [r"郑虔"]},
    "TARGET_NPC_LILINFU": {"name": "李灵甫", "patterns": [r"李灵甫"]},
}


def find_all_csv_files(base_dir):
    """递归查找所有 CSV 文件。"""
    csv_files = []
    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".csv"):
                csv_files.append(os.path.join(root, f))
    csv_files.sort()
    return csv_files


def extract_description_column(headers):
    """找到 description 列的索引。"""
    for i, h in enumerate(headers):
        if h.strip().lower() == "description":
            return i
    return None


def read_csv_events(filepath):
    """读取 CSV 文件，返回事件列表 [{uuid, title, description, file}]。"""
    events = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            headers = next(reader, None)
            if not headers:
                return events
            
            desc_idx = extract_description_column(headers)
            # 找到 uuid 和 title 列
            uuid_idx = None
            title_idx = None
            for i, h in enumerate(headers):
                h_clean = h.strip().lower()
                if h_clean == "uuid":
                    uuid_idx = i
                elif h_clean == "title":
                    title_idx = i
            
            if desc_idx is None:
                print(f"  [WARN] No description column in {filepath}")
                return events
            
            for row in reader:
                if len(row) <= desc_idx:
                    continue
                # 跳过非 random_event 行
                if row[0].strip() != "random_event":
                    continue
                
                uuid_val = row[uuid_idx].strip() if uuid_idx is not None and len(row) > uuid_idx else ""
                title_val = row[title_idx].strip() if title_idx is not None and len(row) > title_idx else ""
                desc_val = row[desc_idx].strip()
                
                if desc_val:
                    events.append({
                        "uuid": uuid_val,
                        "title": title_val,
                        "description": desc_val,
                        "file": os.path.basename(filepath),
                    })
    except Exception as e:
        print(f"  [ERROR] reading {filepath}: {e}")
    
    return events


def match_identity(description, file_basename):
    """在描述文本中匹配身份关键词，返回匹配列表。
    每个匹配: (tag, keyword_matched, context_note)
    """
    matches = []
    for tag, info in IDENTITY_KEYWORDS.items():
        for pat in info["patterns"]:
            m = re.search(pat, description)
            if m:
                # 对于 context_required 的身份，检查文件上下文
                if info.get("context_required"):
                    # 通过文件名判断是清流还是浊流上下文
                    if "qingliu" in tag.lower() and "qingliu" in file_basename.lower():
                        matches.append((tag, m.group(), f"文件上下文确认为清流: {file_basename}"))
                    elif "zhuoliu" in tag.lower() and "zhuoliu" in file_basename.lower():
                        matches.append((tag, m.group(), f"文件上下文确认为浊流: {file_basename}"))
                    # 如果文件名不匹配，跳过（无法确定归属）
                else:
                    matches.append((tag, m.group(), info["name"]))
                break  # 每个 pattern 只匹配一次
    return matches


def match_npcs(description):
    """在描述文本中匹配 NPC 关键词。"""
    matches = []
    for tag, info in NPC_KEYWORDS.items():
        for pat in info["patterns"]:
            m = re.search(pat, description)
            if m:
                matches.append((tag, m.group(), info["name"]))
                break
    return matches


def classify_leverage(description, identity_tag, identity_name):
    """分类把柄类型。
    
    返回: (leverage_type, summary, suggested_leverage_text)
    
    leverage_type:
      - 🔴 LEVERAGE: 把柄素材 - 对方做了见不得人的事
      - 🟡 WEAKNESS: 弱点情报 - 对方的软肋
      - 🟢 SOCIAL: 社交情报 - 社交关系/立场
      - ⚪ NONE: 无价值 - 仅路过/背景板
    """
    desc = description
    
    # ========== 🔴 把柄素材 (Leverage) ==========
    # 受贿、贪腐
    if re.search(r"(受贿|贪[赃墨污腐]|收[买了]通|贿赂|赂[遗送]|中饱|克扣|盘剥|搜刮|敛财)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}涉嫌受贿/贪腐", f"add_leverage({identity_tag}, 1)  # 受贿证据")
    
    # 欺压百姓、滥用职权
    if re.search(r"(欺[压凌负]|仗势|横行|鱼肉百姓|作威作福|一手遮天|以权谋私)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}欺压百姓/滥用职权", f"add_leverage({identity_tag}, 1)  # 欺压/滥权")
    
    # 偷情、私通、丑闻
    if re.search(r"(偷情|私通|苟合|奸[情淫]|妾室|外室|私生子|丑闻|帷薄)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}涉及私情/丑闻", f"add_leverage({identity_tag}, 1)  # 私情丑闻")
    
    # 阳奉阴违、两面三刀
    if re.search(r"(阳奉阴违|两面三刀|口是心非|当面.*背后|明[面里].*暗[地里]|笑里藏刀)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}阳奉阴违/两面派", f"add_leverage({identity_tag}, 1)  # 两面派")
    
    # 告密、出卖
    if re.search(r"(告密|出卖|通风报信|告发|密报|出卖朋友|背[叛弃])", desc):
        return ("🔴 LEVERAGE", f"{identity_name}出卖他人/告密", f"add_leverage({identity_tag}, 1)  # 告密/出卖")
    
    # 造假、欺诈
    if re.search(r"(作[假伪弊]|[伪虛虚]造|欺[诈骗哄]|冒[充名顶]|偷梁换柱)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}造假/欺诈", f"add_leverage({identity_tag}, 1)  # 造假/欺诈")
    
    # 结党营私
    if re.search(r"(结党|营私|[勾拉]结|朋党|私相授受|暗通[款曲]|里应外合)", desc):
        return ("🔴 LEVERAGE", f"{identity_name}结党营私", f"add_leverage({identity_tag}, 1)  # 结党营私")
    
    # ========== 🟡 弱点情报 (Weakness) ==========
    # 缺钱、穷困
    if re.search(r"([缺欠短]钱|[缺欠短]银|[手囊]中羞涩|穷[困苦酸]|债[台主]|催[债账]|典当|变卖)", desc):
        return ("🟡 WEAKNESS", f"{identity_name}经济窘迫", f"add_leverage({identity_tag}, 1)  # 经济弱点")
    
    # 怕某人/某事
    if re.search(r"(惧[怕内]|畏[惧缩]|胆[怯战]|[惶恐]恐|谈[之而].*色变|忌惮|不敢[得罪招惹])", desc):
        return ("🟡 WEAKNESS", f"{identity_name}有畏惧对象", f"add_leverage({identity_tag}, 1)  # 恐惧弱点")
    
    # 有把柄在别人手里
    if re.search(r"(把柄|拿[捏住]|要[挟胁]|[被受]人.*[控掌制握]|短处|痛处|软肋)", desc):
        return ("🟡 WEAKNESS", f"{identity_name}有把柄在他人手中", f"add_leverage({identity_tag}, 1)  # 把柄弱点")
    
    # 沉迷、嗜好
    if re.search(r"([贪沉]杯|嗜酒|好赌|[贪沉]迷|瘾|不能自[拔已]|酒[色气].*过度)", desc):
        return ("🟡 WEAKNESS", f"{identity_name}有不良嗜好", f"add_leverage({identity_tag}, 1)  # 嗜好弱点")
    
    # 身体不好、有病
    if re.search(r"(病[重危入膏肓]|咳[血嗽]|[吐咯]血|伤病|旧疾|身体.*[差垮不行]|憔悴|日渐消瘦)", desc):
        return ("🟡 WEAKNESS", f"{identity_name}身体抱恙", f"add_leverage({identity_tag}, 1)  # 健康弱点")
    
    # 失宠、被贬
    if re.search(r"(失宠|被贬|降[职官级]|[遭被受]人排挤|失势|靠山倒)", desc):
        return ("🟡 WEAKNESS", f"{identity_name}失势/被贬", f"add_leverage({identity_tag}, 1)  # 失势弱点")
    
    # ========== 🟢 社交情报 (Social Intel) ==========
    # 与某人交往密切
    if re.search(r"([与和跟同].*(?:交[往好游谊]|[走來来][往往]|[親亲]近|密[切交]|[結结]交|私交|莫逆|知[己交]))", desc):
        return ("🟢 SOCIAL", f"{identity_name}有密切社交关系", f"可选: add_leverage({identity_tag}, 1)  # 社交情报")
    
    # 立场/站队
    if re.search(r"(站[队在]|[靠依]向|投[靠奔]|依附|归[附顺]|[傾倾]向|拥护|[支撐撑]持)", desc):
        return ("🟢 SOCIAL", f"{identity_name}显露政治立场/站队", f"可选: add_leverage({identity_tag}, 1)  # 站队情报")
    
    # 秘密谈话/密谋
    if re.search(r"(密[谋谈议]|[偷偷窃窃]|私[下底里]|耳语|附耳|低语|屏退|秘密)", desc):
        return ("🟢 SOCIAL", f"{identity_name}参与密谈", f"可选: add_leverage({identity_tag}, 1)  # 密谈情报")
    
    # 交易/利益交换
    if re.search(r"(交易|交换|买[通卖]|[買买]通|利诱|条件交换|人情.*[交换换往来])", desc):
        return ("🟢 SOCIAL", f"{identity_name}参与利益交换", f"可选: add_leverage({identity_tag}, 1)  # 利益交换情报")
    
    # ========== ⚪ 无价值 ==========
    return ("⚪ NONE", f"{identity_name}仅作为背景/路过角色", "")


def main():
    csv_files = find_all_csv_files(CSV_DIR)
    print(f"找到 {len(csv_files)} 个 CSV 文件")
    
    # 收集所有事件
    all_events = []
    for fp in csv_files:
        events = read_csv_events(fp)
        print(f"  {os.path.basename(fp)}: {len(events)} 个 random_event")
        all_events.extend(events)
    
    print(f"\n总计 {len(all_events)} 个 random_event")
    
    # 按身份/NPC 分组匹配
    identity_results = defaultdict(list)
    npc_results = defaultdict(list)
    
    total_matched = 0
    
    for evt in all_events:
        desc = evt["description"]
        file_basename = evt["file"]
        
        # 匹配身份
        id_matches = match_identity(desc, file_basename)
        for tag, keyword, ctx_note in id_matches:
            lev_type, summary, sug = classify_leverage(desc, tag, IDENTITY_KEYWORDS[tag]["name"])
            identity_results[tag].append({
                "event_uuid": evt["uuid"],
                "event_title": evt["title"],
                "file": file_basename,
                "keyword_matched": keyword,
                "summary": summary,
                "leverage_type": lev_type,
                "suggested_action": sug,
                "description_excerpt": desc[:120] + ("..." if len(desc) > 120 else ""),
            })
            total_matched += 1
        
        # 匹配 NPC
        npc_matches = match_npcs(desc)
        for tag, keyword, name in npc_matches:
            lev_type, summary, sug = classify_leverage(desc, tag, name)
            npc_results[tag].append({
                "event_uuid": evt["uuid"],
                "event_title": evt["title"],
                "file": file_basename,
                "keyword_matched": keyword,
                "summary": summary,
                "leverage_type": lev_type,
                "suggested_action": sug,
                "description_excerpt": desc[:120] + ("..." if len(desc) > 120 else ""),
            })
            total_matched += 1
    
    # ========== 生成报告 ==========
    lines = []
    lines.append("# 把柄/重要信息扫描报告")
    lines.append("")
    lines.append(f"> **扫描范围**: `data/4_eras/747_kuangda/` 下 {len(csv_files)} 个 CSV 文件")
    lines.append(f"> **事件总数**: {len(all_events)} 个 random_event")
    lines.append(f"> **匹配总数**: {total_matched} 条身份/NPC 提及")
    lines.append(f"> **生成时间**: {os.popen('date -u +\"%Y-%m-%dT%H:%M:%SZ\"').read().strip()}")
    lines.append("")
    
    # 统计
    all_matches = []
    for tag, items in identity_results.items():
        all_matches.extend([(tag, item) for item in items])
    for tag, items in npc_results.items():
        all_matches.extend([(tag, item) for item in items])
    
    lever_count = sum(1 for _, item in all_matches if item["leverage_type"] == "🔴 LEVERAGE")
    weak_count = sum(1 for _, item in all_matches if item["leverage_type"] == "🟡 WEAKNESS")
    social_count = sum(1 for _, item in all_matches if item["leverage_type"] == "🟢 SOCIAL")
    none_count = sum(1 for _, item in all_matches if item["leverage_type"] == "⚪ NONE")
    
    lines.append("## 扫描统计摘要")
    lines.append("")
    lines.append(f"| 类别 | 数量 |")
    lines.append(f"|------|------|")
    lines.append(f"| 🔴 把柄素材 (Leverage) | {lever_count} |")
    lines.append(f"| 🟡 弱点情报 (Weakness) | {weak_count} |")
    lines.append(f"| 🟢 社交情报 (Social Intel) | {social_count} |")
    lines.append(f"| ⚪ 无价值 (None) | {none_count} |")
    lines.append(f"| **总计** | **{lever_count + weak_count + social_count + none_count}** |")
    lines.append("")
    
    # 按身份输出
    lines.append("---")
    lines.append("")
    lines.append("## 一、身份维度 (Identity Results)")
    lines.append("")
    
    identity_order = [
        "TARGET_IDENTITY_QINGLIU_OWNER",
        "TARGET_IDENTITY_QINGLIU_OFFICIAL",
        "TARGET_IDENTITY_ZHUOLIU_OFFICIAL",
        "TARGET_IDENTITY_QUANGUI",
        "TARGET_IDENTITY_QINGKE",
        "TARGET_IDENTITY_MENZI",
        "TARGET_IDENTITY_COUNTY_SHERIFF",
        "TARGET_IDENTITY_VENDOR",
        "TARGET_IDENTITY_POOR",
    ]
    
    for tag in identity_order:
        info = IDENTITY_KEYWORDS[tag]
        items = identity_results.get(tag, [])
        lines.append(f"### {tag} ({info['name']})")
        lines.append("")
        lines.append(f"**分类**: {info['category']} | **匹配数**: {len(items)}")
        lines.append("")
        
        if not items:
            lines.append("> ⚠️ 当前事件库中**未提及**此身份。需要新写事件来引入。")
            lines.append("")
            continue
        
        for item in items:
            lines.append(f"#### 事件: `{item['event_uuid']}`")
            lines.append(f"- **标题**: {item['event_title']}")
            lines.append(f"- **文件**: {item['file']}")
            lines.append(f"- **描述摘要**: \"{item['description_excerpt']}\"")
            lines.append(f"- **关键词匹配**: `{item['keyword_matched']}`")
            lines.append(f"- **把柄类型**: {item['leverage_type']} — {item['summary']}")
            if item['suggested_action']:
                lines.append(f"- **建议操作**: `{item['suggested_action']}`")
            lines.append("")
    
    # NPC 部分
    lines.append("---")
    lines.append("")
    lines.append("## 二、NPC 维度 (NPC Results)")
    lines.append("")
    
    npc_order = [
        "TARGET_NPC_LIBAI",
        "TARGET_NPC_DUFU",
        "TARGET_NPC_WANGWEI",
        "TARGET_NPC_GAOSHI",
        "TARGET_NPC_ZHENGQIAN",
        "TARGET_NPC_LILINFU",
    ]
    
    for tag in npc_order:
        info = NPC_KEYWORDS[tag]
        items = npc_results.get(tag, [])
        lines.append(f"### {tag} ({info['name']})")
        lines.append("")
        lines.append(f"**匹配数**: {len(items)}")
        lines.append("")
        
        if not items:
            lines.append("> ⚠️ 当前事件库中**未提及**此 NPC。需要新写事件来引入。")
            lines.append("")
            continue
        
        for item in items:
            lines.append(f"#### 事件: `{item['event_uuid']}`")
            lines.append(f"- **标题**: {item['event_title']}")
            lines.append(f"- **文件**: {item['file']}")
            lines.append(f"- **描述摘要**: \"{item['description_excerpt']}\"")
            lines.append(f"- **关键词匹配**: `{item['keyword_matched']}`")
            lines.append(f"- **把柄类型**: {item['leverage_type']} — {item['summary']}")
            if item['suggested_action']:
                lines.append(f"- **建议操作**: `{item['suggested_action']}`")
            lines.append("")
    
    # 建议部分
    lines.append("---")
    lines.append("")
    lines.append("## 三、集成建议")
    lines.append("")
    lines.append("### 对每个身份的 leverage 添加建议")
    lines.append("")
    lines.append("| 身份 Tag | 身份名 | 匹配事件数 | 🔴 | 🟡 | 🟢 | ⚪ | 建议 |")
    lines.append("|---------|--------|-----------|----|----|----|----|------|")
    
    for tag in identity_order:
        info = IDENTITY_KEYWORDS[tag]
        items = identity_results.get(tag, [])
        l = sum(1 for i in items if i["leverage_type"] == "🔴 LEVERAGE")
        w = sum(1 for i in items if i["leverage_type"] == "🟡 WEAKNESS")
        s = sum(1 for i in items if i["leverage_type"] == "🟢 SOCIAL")
        n = sum(1 for i in items if i["leverage_type"] == "⚪ NONE")
        
        if not items:
            suggestion = "需新写事件引入此身份"
        elif l > 0:
            suggestion = f"有 {l} 个把柄素材可用，可直接添加 leverage"
        elif w > 0:
            suggestion = f"有 {w} 个弱点情报，可转化为 leverage"
        elif s > 0:
            suggestion = f"有 {s} 个社交情报，需补充具体劣迹事件"
        else:
            suggestion = "当前事件仅有背景出现，需增强冲突"
        
        lines.append(f"| {tag} | {info['name']} | {len(items)} | {l} | {w} | {s} | {n} | {suggestion} |")
    
    lines.append("")
    
    for tag in npc_order:
        info = NPC_KEYWORDS[tag]
        items = npc_results.get(tag, [])
        l = sum(1 for i in items if i["leverage_type"] == "🔴 LEVERAGE")
        w = sum(1 for i in items if i["leverage_type"] == "🟡 WEAKNESS")
        s = sum(1 for i in items if i["leverage_type"] == "🟢 SOCIAL")
        n = sum(1 for i in items if i["leverage_type"] == "⚪ NONE")
        
        if not items:
            suggestion = "需新写事件引入此 NPC"
        elif l > 0:
            suggestion = f"有 {l} 个把柄素材可用，可直接添加 leverage"
        elif w > 0:
            suggestion = f"有 {w} 个弱点情报，可转化为 leverage"
        elif s > 0:
            suggestion = f"有 {s} 个社交情报，需补充具体劣迹事件"
        else:
            suggestion = "当前事件仅有背景出现，需增强冲突"
        
        lines.append(f"| {tag} | {info['name']} | {len(items)} | {l} | {w} | {s} | {n} | {suggestion} |")
    
    lines.append("")
    
    # 写入文件
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines) + "\n")
    
    print(f"\n报告已生成: {OUTPUT}")
    print(f"身份匹配: {sum(len(v) for v in identity_results.values())} 条")
    print(f"NPC 匹配: {sum(len(v) for v in npc_results.values())} 条")
    print(f"🔴 LEVERAGE: {lever_count}")
    print(f"🟡 WEAKNESS: {weak_count}")
    print(f"🟢 SOCIAL: {social_count}")
    print(f"⚪ NONE: {none_count}")


if __name__ == "__main__":
    main()
