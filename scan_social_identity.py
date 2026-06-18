#!/usr/bin/env python3
"""模糊扫描社交身份实体，构建社交身份库 v2
策略：
1. CSV只扫 description/title/results 字段（跳过 requirements/interruptions/template/provider）
2. Config JSON 跳过 ai_persona/prompt_features/fact_features（那是给AI写手的指令，不是游戏世界内容）
3. 用正则复合模式匹配，避免n-gram碎片化
4. 严格的黑名单排除噪声
"""

import csv
import json
import re
import os
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path("/Users/lennon/Projects/poem_map_project")

# ============================================================
# 黑名单：明确不是社交身份的词
# ============================================================
HARD_BLACKLIST = {
    # 代词/虚词
    '有人', '的人', '那人', '个人', '没人', '某人', '此人', '彼人', '他人',
    '这个人', '那个人', '两个人', '一个人', '好几个人',
    '主人',  # 太泛 → 但要小心，"主人"有时是身份称呼
    # 游戏术语/非身份
    '玩家', '玩家野心', '叙述者', '叙事作家', '叙事作', '事作家', '作家',
    '钻营者', '逢迎者',  # 这些是 faction 描述词，暂时保留供人工审查
    # 写作指令碎片（来自 config 的 ai_persona/prompt_features）
    '上帝', '止上帝', '禁止上帝', '禁止上帝视角', '用相同', '使用相同', '使用相',
    '用相', '复使', '重复使', '复使用相', '复使用相同', '中重复使',
    '禁止使', '感官', '感官通道', '官通道', '通道', '续两次使',
    '描述手', '描手', '白描手', '用白描手', '词和感官', '使用相同的',
    '不是敌人', '不是敌人是', '的句式', '句式动词', '动词和感官',
    # n-gram 碎片
    '层文人', '居长', '困居长', '岁困居长', '岁困', '十三岁困',
    '四十三岁', '十岁', '十三', '四十三',
    # 常见动词/动作
    '拱手', '点头', '摇头', '伸手', '抬手', '转身', '迈步',
    '一道', '一时', '一次', '一阵', '一会',
    '都尉', '高参军',  # 高参军是姓+官名，不是独立身份词
    # n-gram 碎片 - 正则错误匹配
    '他将', '你将', '李大夫', '李十二郎', '十二郎',
    '那些狂客', '座中宾客', '书上右丞', '说王右丞',
    '右丞',  # 太泛，除非是独立官职词
    '生圈', '人圈', '的笔触', '笔触',
    # 人称代词含身份字
    '亲自',  # 不是身份
    '兄弟',  # 太泛，指亲属关系
    # 正则碎片 - 带量词的客
    '其他客', '旁边清客', '那位客',
}

# 但下面这些虽然在config writing instructions中出现，在游戏文本中也有意义
# 需要特殊处理
CONDITIONAL_KEEP = {
    '作家': False,  # config里是"叙事作家"，CSV里不太可能出现
    '上帝': False,
    '感官': False,
    '通道': False,
    '叙述者': False,
    '重复': False,
    '使用': False,
}

# ============================================================
# 身份特征字库（这些字高频出现在官职/身份词中）
# ============================================================
OFFICIAL_CHARS = {'官', '吏', '令', '尉', '史', '丞', '监', '使', '守', '将', '帅',
                  '相', '卿', '侯', '伯', '王', '帝', '君', '长', '司', '曹',
                  '郎', '员', '侍', '从', '卫', '士', '宰', '尚', '书'}

ROLE_CHARS = {'客', '人', '夫', '匠', '师', '徒', '生', '者', '子'}

SOCIAL_CHARS = {'贵', '豪', '绅', '贾', '商', '贩', '主', '佣', '仆',
                '奴', '婢', '妾', '乞', '丐', '盗', '贼', '匪', '寇',
                '侠', '儒', '僧', '道', '尼', '巫', '医', '卜', '妓',
                '优', '伶', '屠', '渔', '樵', '牧', '农', '工'}

ALL_IDENTITY_CHARS = OFFICIAL_CHARS | ROLE_CHARS | SOCIAL_CHARS


# ============================================================
# 正则复合模式：匹配已知的复合身份结构
# ============================================================
COMPOUND_PATTERNS = [
    # 精确常见身份
    (r'(?:权贵|官僚|门子|清客|掮客|学士|县尉|纨绔|草包|录事|参军|侍从|管家|幕僚|师爷|衙役|捕快|差役|走卒)',
     'exact_known'),
    # 社会阶层
    (r'(?:清流|浊流|寒门|世家|豪门|贵族|平民|百姓|庶民|白丁|布衣)',
     'social_class'),
    # 文人类
    (r'(?:书生|文人|雅士|名流|显贵|新贵|文士|诗客|词客|才子|墨客)',
     'literati'),
    # 商业
    (r'(?:商贾|贩夫|贩卒|屠狗|卖浆|引车|挑夫|脚夫|货郎|摊主|掌柜|老板|东家|店主|伙计|学徒)',
     'merchant'),
    # 官职（X+官/吏/令/尉/史/丞/监/使）
    (r'[\u4e00-\u9fff]{1,3}(?:令|尉|史|丞|监|使|守|将|帅|相|卿|侯)', 'official_suffix'),
    # 学术
    (r'(?:博士|助教|学士|直学|学正|学录|教授|山长)',
     'academic'),
    # 中央官职
    (r'(?:宰相|尚书|侍郎|郎中|员外|舍人|供奉|拾遗|补阙)',
     'central_official'),
    # 地方官职
    (r'(?:节度|观察|防御|团练|经略|巡抚|总督|提督|总兵|刺史|太守|县令|县丞|主簿)',
     'local_official'),
    # 僚属
    (r'(?:参军|别驾|长史|司马|判官|掌书记|孔目|押司|都头|节级)',
     'staff_official'),
    # 身份结尾词 (X+客, X+夫, X+匠, X+师)
    (r'[\u4e00-\u9fff]{1,3}(?:客|夫|匠|师)', 'role_suffix'),
    # 下层流动人口
    (r'(?:乞丐|流民|难民|灾民|饥民|役夫|民夫|苦力|长工|短工|佃户|客户)',
     'lower_class'),
    # 艺伎/青楼
    (r'(?:歌妓|舞妓|乐妓|艺妓|娼妓|名妓|伶人|优伶|乐工|舞女)',
     'entertainer'),
    # 宗教
    (r'(?:僧侣|道士|尼姑|和尚|禅师|法师|真人|天师|方丈|道长|仙姑)',
     'religious'),
    # 宫廷
    (r'(?:宦官|太监|内侍|宫人|宫女|黄门|中官)',
     'palace'),
    # 侠客/武士
    (r'(?:侠客|剑客|刀客|刺客|死士|义士|壮士|游侠|侠士)',
     'warrior'),
    # 科举/士人
    (r'(?:举人|进士|秀才|贡生|监生|生员|童生|秀才|举子|门生)',
     'exam_rank'),
    # 家族
    (r'(?:族长|家长|家主|门主|帮主|盟主|坊主|堂主)',
     'leader'),
    # 底层
    (r'(?:乞丐|叫花|要饭|穷酸|酸儒|腐儒|老儒|穷措|措大)',
     'bottom'),
    # 仆人
    (r'(?:侍从|跟班|随从|亲随|家丁|家奴|仆役|婢女|丫鬟|仆从)',
     'servant'),
    # 先生类（有具体角色的）
    (r'(?:道士|术士|方士|相士|卜者|相士|铁口|算命)',
     'diviner'),
    # 官职（常见的唐代官职结尾）
    (r'[\u4e00-\u9fff]{2,3}(?:郎|丞|簿|史|录事|参军|县尉|主簿)', 'tang_official'),
    # 僚属（幕府）
    (r'(?:幕僚|幕友|幕客|清客|门客|食客|宾客|座上客)', 'retainer'),
    # 浊流相关角色
    (r'(?:浊流|阉党|权宦|奸佞|佞臣|权臣|弄臣|幸臣)', 'zhuoliu'),
    # 清流相关角色
    (r'(?:清流|诤臣|直臣|忠臣|谏官|清议|清望)', 'qingliu'),
]

# 额外的身份词（在这些模式下也提取2-3字身份词）
EXTRA_PATTERNS = [
    # 将军类
    (r'(?:牙将|裨将|偏将|副将|大将|上将|猛将|骁将|虎将|悍将)', 'general'),
    # 先生（特定语境）
    (r'(?:教书|算命|风水|看相|说书|医|画)', 'occupation_prefix'),
]

# ============================================================
# 从文本中提取所有匹配的身份词
# ============================================================
def extract_identities(text):
    """从文本中提取身份词，返回 {身份词: count}"""
    found = defaultdict(int)
    for pattern, _ptype in COMPOUND_PATTERNS:
        for match in re.finditer(pattern, text):
            word = match.group()
            if word not in HARD_BLACKLIST:
                found[word] += 1

    # 额外扫描「X+先生」「X+大人」模式（仅在游戏文本中，不在config中）
    for match in re.finditer(r'(?:先生|大人|老爷|公子|娘子)', text):
        word = match.group()
        found[word] += 1

    return found


def extract_with_context(text, source_file, source_type='csv'):
    """提取身份词并附带上下文片段"""
    results = defaultdict(lambda: {'count': 0, 'files': set(), 'examples': []})

    for pattern, ptype in COMPOUND_PATTERNS:
        for match in re.finditer(pattern, text):
            word = match.group()
            if word in HARD_BLACKLIST:
                continue
            results[word]['count'] += 1
            results[word]['files'].add(source_file)
            if len(results[word]['examples']) < 3:
                start = max(0, match.start() - 10)
                end = min(len(text), match.end() + 10)
                snippet = text[start:end].replace('\n', ' ').strip()
                results[word]['examples'].append(
                    f"[{source_file}:{ptype}] ...{snippet}..."
                )

    # 先生/大人/老爷
    for match in re.finditer(r'(?:先生|大人|老爷)', text):
        word = match.group()
        results[word]['count'] += 1
        results[word]['files'].add(source_file)
        if len(results[word]['examples']) < 3:
            start = max(0, match.start() - 10)
            end = min(len(text), match.end() + 10)
            snippet = text[start:end].replace('\n', ' ').strip()
            results[word]['examples'].append(
                f"[{source_file}:honorific] ...{snippet}..."
            )

    return results


# ============================================================
# CSV 扫描：只读 description, title, results, context
# ============================================================
def scan_csv_files(csv_dir):
    csv_dir = Path(csv_dir)
    results = defaultdict(lambda: {'count': 0, 'files': set(), 'examples': []})

    for csv_file in sorted(csv_dir.glob('*.csv')):
        if csv_file.name.startswith('.') or '.translation' in csv_file.name or '.import' in str(csv_file):
            continue

        file_stem = csv_file.stem
        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row_num, row in enumerate(reader, start=2):
                    # 只提取游戏文本字段
                    game_text = ' '.join([
                        row.get('description', '') or '',
                        row.get('title', '') or '',
                        row.get('results', '') or '',
                        row.get('context', '') or '',
                    ])

                    extracted = extract_with_context(game_text, file_stem, 'csv')
                    for word, data in extracted.items():
                        results[word]['count'] += data['count']
                        results[word]['files'] |= data['files']
                        for ex in data['examples']:
                            if len(results[word]['examples']) < 3 and ex not in results[word]['examples']:
                                results[word]['examples'].append(ex)
        except Exception as e:
            print(f"  警告: 读取 {csv_file} 失败: {e}")

    return results


# ============================================================
# Config JSON 扫描：只读 background_context, name
# (跳过 ai_persona/prompt_features/fact_features/emotion_pairs)
# ============================================================
def scan_config_json(json_dir):
    json_dir = Path(json_dir)
    results = defaultdict(lambda: {'count': 0, 'files': set(), 'examples': []})

    for json_file in sorted(json_dir.glob('event_base_config_*.json')):
        if '_sandbox' in json_file.name or json_file.name.startswith('.'):
            continue

        file_stem = json_file.stem
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            if isinstance(data, dict):
                text = ' '.join([
                    data.get('background_context', '') or '',
                    data.get('name', '') or '',
                ])
                extracted = extract_with_context(text, file_stem, 'config')
                for word, data2 in extracted.items():
                    results[word]['count'] += data2['count']
                    results[word]['files'] |= data2['files']
                    for ex in data2['examples']:
                        if len(results[word]['examples']) < 3 and ex not in results[word]['examples']:
                            results[word]['examples'].append(ex)
        except Exception as e:
            print(f"  警告: 读取 {json_file} 失败: {e}")

    return results


# ============================================================
# Sandbox JSON 扫描
# ============================================================
def scan_sandbox_json(json_dir):
    json_dir = Path(json_dir)
    results = defaultdict(lambda: {'count': 0, 'files': set(), 'examples': []})

    for json_file in sorted(json_dir.glob('event_base_config_*_sandbox.json')):
        if json_file.name.startswith('.'):
            continue

        file_stem = json_file.stem
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # sandbox JSON: { "NPC_NAME": { "emotion_key": ["desc1", "desc2", ...] } }
            texts = []
            if isinstance(data, dict):
                for npc_name, emotions in data.items():
                    if isinstance(emotions, dict):
                        for emotion_key, descriptions in emotions.items():
                            if isinstance(descriptions, list):
                                for desc in descriptions:
                                    if isinstance(desc, str):
                                        texts.append(desc)
                            elif isinstance(descriptions, str):
                                texts.append(descriptions)

            all_text = ' '.join(texts)
            extracted = extract_with_context(all_text, file_stem, 'sandbox')
            for word, data2 in extracted.items():
                results[word]['count'] += data2['count']
                results[word]['files'] |= data2['files']
                for ex in data2['examples']:
                    if len(results[word]['examples']) < 3 and ex not in results[word]['examples']:
                        results[word]['examples'].append(ex)
        except Exception as e:
            print(f"  警告: 读取 {json_file} 失败: {e}")

    return results


# ============================================================
# 报告生成
# ============================================================
def generate_report(csv_results, config_results, sandbox_results, output_path):
    # 合并
    all_results = defaultdict(lambda: {'count': 0, 'files': set(), 'examples': []})
    for source in [csv_results, config_results, sandbox_results]:
        for word, data in source.items():
            all_results[word]['count'] += data['count']
            all_results[word]['files'] |= data['files']
            for ex in data['examples']:
                existing = all_results[word]['examples']
                if len(existing) < 5 and ex not in existing:
                    existing.append(ex)

    # 原始白名单
    original_whitelist = {
        '清流主人', '集贤院学士', '县尉', '掮客',
        '紫袍胖子权贵', '清客', '门子', '浊流官僚'
    }

    # 过滤：出现>=2次 或 涉及>=2文件
    filtered = {}
    for word, data in all_results.items():
        if data['count'] >= 2 or len(data['files']) >= 2:
            filtered[word] = data

    sorted_items = sorted(filtered.items(), key=lambda x: (-x[1]['count'], -len(x[1]['files'])))

    def count_csv(fs):
        return sum(1 for f in fs if '_events' in f)

    def count_config(fs):
        return sum(1 for f in fs if 'event_base_config' in f and '_sandbox' not in f)

    def count_sandbox(fs):
        return sum(1 for f in fs if '_sandbox' in f)

    # --- 写入 ---
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("# 社交身份库 (基于事件内容模糊扫描 v2)\n\n")
        f.write("扫描范围: data/4_eras/747_kuangda/*.csv (仅description/title/results/context), ")
        f.write("tools/event_base_config_*.json (仅background_context/name), ")
        f.write("tools/event_base_config_*_sandbox.json (仅description/title)\n\n")
        f.write("**注意**: 排除了 `ai_persona` / `prompt_features` / `fact_features` 等AI写作指令字段。\n\n")

        # === 频率总表 ===
        f.write("## 身份词出现频率总表\n\n")
        f.write("| 身份词 | 出现总次数 | CSV | Config | Sandbox | 来源示例 |\n")
        f.write("|--------|-----------|------|--------|---------|----------|\n")

        for word, data in sorted_items:
            csv_n = count_csv(data['files'])
            conf_n = count_config(data['files'])
            sb_n = count_sandbox(data['files'])
            ex = data['examples'][0][:60] if data['examples'] else '-'
            f.write(f"| {word} | {data['count']} | {csv_n} | {conf_n} | {sb_n} | {ex} |\n")

        # === 按文件分布 ===
        f.write("\n## 按文件分布\n\n")
        all_files = set()
        for _w, data in sorted_items:
            all_files |= data['files']

        for file_name in sorted(all_files):
            f.write(f"### {file_name}\n\n")
            file_items = [(w, d['count']) for w, d in sorted_items if file_name in d['files']]
            for word, count in sorted(file_items, key=lambda x: -x[1])[:20]:
                exs = [e for e in all_results[word]['examples'] if file_name in e]
                ex_str = exs[0][:80] if exs else ''
                f.write(f"- **{word}**: {count} 次")
                if ex_str:
                    f.write(f" — {ex_str}")
                f.write("\n")
            f.write("\n")

        # === 高频但未被收录 ===
        f.write("\n## 高频但未被收录的身份\n\n")
        f.write(f"**原始白名单** ({len(original_whitelist)} 项): {', '.join(sorted(original_whitelist))}\n\n")
        f.write("| 身份词 | 出现总次数 | 涉及文件数 | 涉及文件 |\n")
        f.write("|--------|-----------|-----------|----------|\n")

        new_identities = [(w, d) for w, d in sorted_items if w not in original_whitelist]
        for word, data in new_identities:
            flist = ', '.join(sorted(data['files'])[:5])
            f.write(f"| {word} | {data['count']} | {len(data['files'])} | {flist} |\n")

        # === 建议补充 ===
        f.write("\n## 建议补充的身份\n\n")

        high = [(w, d) for w, d in new_identities if d['count'] >= 5 or len(d['files']) >= 3]
        high_words = {w for w, _ in high}
        mid = [(w, d) for w, d in new_identities
               if w not in high_words and (3 <= d['count'] < 5 or len(d['files']) >= 2) and (d['count'] >= 2)]
        mid_words = {w for w, _ in mid} | high_words
        low = [(w, d) for w, d in new_identities
               if w not in mid_words and d['count'] <= 2 and len(d['files']) <= 1]

        if high:
            f.write("### 🔴 高优先级（强烈建议收录）\n\n")
            f.write("| 身份词 | 次数 | 文件数 | 理由 |\n")
            f.write("|--------|------|--------|------|\n")
            for word, data in high:
                f.write(f"| {word} | {data['count']} | {len(data['files'])} | "
                        f"跨{len(data['files'])}个文件，共{data['count']}次出现 |\n")
            f.write("\n")

        if mid:
            f.write("### 🟡 中优先级（可考虑）\n\n")
            f.write("| 身份词 | 次数 | 文件数 | 理由 |\n")
            f.write("|--------|------|--------|------|\n")
            for word, data in mid:
                f.write(f"| {word} | {data['count']} | {len(data['files'])} | "
                        f"跨{len(data['files'])}个文件，共{data['count']}次出现 |\n")
            f.write("\n")

        if low:
            f.write("### 🟢 低优先级（可选）\n\n")
            f.write("| 身份词 | 次数 | 文件数 |\n")
            f.write("|--------|------|--------|\n")
            for word, data in low[:30]:
                f.write(f"| {word} | {data['count']} | {len(data['files'])} |\n")
            f.write("\n")

        # === 统计摘要 ===
        f.write("\n## 统计摘要\n\n")
        f.write(f"- 扫描到的候选身份词总数: {len(all_results)}\n")
        f.write(f"- 过滤后（出现>=2次或涉及>=2文件）: {len(filtered)}\n")
        f.write(f"- 在原始白名单中的: {sum(1 for w in filtered if w in original_whitelist)}\n")
        f.write(f"- 新发现（不在白名单中）: {len(new_identities)}\n")
        f.write(f"- 🔴 高优先级建议: {len(high)}\n")
        f.write(f"- 🟡 中优先级建议: {len(mid)}\n")
        f.write(f"- 🟢 低优先级候选: {len(low)}\n")

    print(f"\n=== 报告已生成: {output_path} ===")
    print(f"  候选身份词总数: {len(all_results)}")
    print(f"  过滤后: {len(filtered)}")
    print(f"  新发现身份: {len(new_identities)}")
    print(f"  🔴 高优先级: {len(high)}")
    print(f"  🟡 中优先级: {len(mid)}")
    print(f"  🟢 低优先级: {len(low)}")

    if high:
        names = [w for w, _ in high[:20]]
        print(f"  高优先级: {', '.join(names)}")


def main():
    # 1. CSV
    print("=== 扫描 CSV 文件（仅 game text 字段）===")
    csv_dir = PROJECT_ROOT / "data" / "4_eras" / "747_kuangda"
    csv_results = scan_csv_files(csv_dir)
    print(f"  CSV 完成: {len(csv_results)} 个候选身份词")

    # 2. Config JSON
    print("\n=== 扫描 Config JSON（仅 background_context + name）===")
    json_dir = PROJECT_ROOT / "tools"
    config_results = scan_config_json(json_dir)
    print(f"  Config JSON 完成: {len(config_results)} 个候选身份词")

    # 3. Sandbox JSON
    print("\n=== 扫描 Sandbox JSON ===")
    sandbox_results = scan_sandbox_json(json_dir)
    print(f"  Sandbox JSON 完成: {len(sandbox_results)} 个候选身份词")

    # 4. 生成报告
    output_path = PROJECT_ROOT / "plans" / "social_identity_library.md"
    generate_report(csv_results, config_results, sandbox_results, output_path)


if __name__ == '__main__':
    main()
