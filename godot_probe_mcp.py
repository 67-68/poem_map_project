"""
godot_probe_mcp.py - Godot 活体探针 MCP 桥接服务

本服务通过 HTTP GET 请求，从运行中的 Godot 游戏实例的 RuntimeProbe 获取
实时内存状态，并向 AI 暴露只读探查工具。

网络拓扑:
  AI (Cline) → MCP (本服务, Docker) → HTTP GET → Godot RuntimeProbe (宿主机 :6066)

🛡️ 只读契约:
  - 所有工具均为只读，不修改游戏状态
  - 如果 Godot 游戏未运行，工具会返回清晰的错误信息
"""

import json
import logging
import urllib.request
import urllib.error
from mcp.server.fastmcp import FastMCP
import sys

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Godot_Probe_MCP")

# ==========================================
# 基础设施坐标
# MCP 运行在 Docker 容器内，通过 host.docker.internal 访问宿主机
# ==========================================
GODOT_PROBE_BASE = "http://host.docker.internal:6066"
REQUEST_TIMEOUT = 10  # 秒
# 人类可读输出文件路径（供终端直接 cat 查看）
HUMAN_OUTPUT_FILE = "/tmp/godot_probe_output.txt"

# 实例化 MCP 节点
mcp = FastMCP("Godot_Runtime_Probe")


def _do_probe_get(endpoint: str) -> dict:
    """
    向 Godot RuntimeProbe 发送 HTTP GET 请求的底层函数。

    参数:
        endpoint: API 路径，如 "/api/scene_tree"

    返回:
        解析后的 JSON 字典。
        如果连接失败或返回错误状态码，返回包含 "error" 字段的字典。
    """
    url = GODOT_PROBE_BASE + endpoint
    logger.info(f"Probe GET: {url}")

    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as response:
            raw = response.read().decode("utf-8")
            data = json.loads(raw)
            logger.info(f"Probe response OK: {endpoint} ({len(raw)} bytes)")
            return data

    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        logger.error(f"Probe HTTP error {e.code}: {error_body[:200]}")
        return {
            "ok": False,
            "error": f"Godot 探针返回 HTTP {e.code}",
            "detail": error_body[:500]
        }

    except urllib.error.URLError as e:
        logger.error(f"Probe connection failed: {e.reason}")
        return {
            "ok": False,
            "error": "无法连接到 Godot RuntimeProbe (端口 6066)",
            "detail": f"请确认 Godot 游戏正在运行（通过 VSCode launch.json 启动带 UI 的实例）。\n"
                      f"底层错误: {str(e.reason)}"
        }

    except TimeoutError:
        logger.error("Probe request timed out")
        return {
            "ok": False,
            "error": "请求 Godot 探针超时",
            "detail": f"Godot 在 {REQUEST_TIMEOUT} 秒内未响应。游戏可能处于繁忙状态或卡死。"
        }

    except json.JSONDecodeError as e:
        logger.error(f"Probe returned invalid JSON: {e}")
        return {
            "ok": False,
            "error": "Godot 探针返回了无效的 JSON",
            "detail": str(e)
        }

    except Exception as e:
        logger.error(f"Unexpected probe error: {e}", exc_info=True)
        return {
            "ok": False,
            "error": f"探针请求遭遇未预期异常: {str(e)}"
        }


# ═════════════════════════════════════════════════════════════════════════════
# 日志过滤引擎
# ═════════════════════════════════════════════════════════════════════════════


def _match_level(log_entry: dict, levels: list[str] | None) -> bool:
    """如果 levels 为 None 或 ["ALL"]，返回 True；否则检查 level 是否在列表中。"""
    if levels is None or "ALL" in levels:
        return True
    return log_entry.get("level", "") in levels


def _match_grep(log_entry: dict, grep: str | None) -> bool:
    """如果 grep 为 None，返回 True；否则在 message 中做大小写不敏感子串匹配。"""
    if grep is None:
        return True
    message = log_entry.get("message", "")
    return grep.lower() in message.lower()


def _parse_levels(level_str: str) -> list[str] | None:
    """
    解析 level 参数。
    - "ALL" → None (不过滤)
    - "ERROR" → ["ERROR"]
    - "ERROR,WARN" → ["ERROR", "WARN"]
    - None / "" → ["ERROR"] (默认)
    """
    if level_str is None or level_str.strip() == "":
        return ["ERROR"]
    level_str = level_str.strip().upper()
    if level_str == "ALL":
        return None  # None = 不过滤
    return [lvl.strip() for lvl in level_str.split(",")]


def _merge_context_windows(matches: list[int], context: int) -> list[tuple[int, int]]:
    """
    将匹配的 seq 列表扩展为 context 窗口，然后合并重叠/相邻窗口。

    输入:
        matches: [5, 10, 15]
        context: 5

    输出窗口（不重叠时）:
        [(0, 10), (5, 15), (10, 20)]

    合并后:
        [(0, 20)]  # 因为所有窗口有重叠

    如果有间隙:
        输入: [5, 25], context=2
        输出: [(3, 7), (23, 27)]  # 保留间隙
    """
    if not matches:
        return []

    # 生成每个匹配的窗口
    windows: list[tuple[int, int]] = []
    for seq in matches:
        start = max(0, seq - context)
        end = seq + context
        windows.append((start, end))

    # 按 start 排序
    windows.sort(key=lambda w: w[0])

    # 合并重叠或相邻（相邻 = 间隙 <= 0）
    merged: list[tuple[int, int]] = [windows[0]]
    for curr_start, curr_end in windows[1:]:
        prev_start, prev_end = merged[-1]
        if curr_start <= prev_end + 1:
            # 有重叠或相邻，合并
            merged[-1] = (prev_start, max(prev_end, curr_end))
        else:
            # 有间隙，保留为新段
            merged.append((curr_start, curr_end))

    return merged


def _filter_logs(
    logs: list[dict],
    levels: list[str] | None,
    grep: str | None,
    since: int | None,
    until: int | None,
    seq: int | None,
    context: int,
) -> dict:
    """
    核心过滤引擎。

    返回:
        {
            "matched_seq": [5, 10, ...],      # 精确匹配的 seq
            "shown_logs": [...],               # 最终输出的日志（包含 context 行）
            "matched_count": 3,                # 精确匹配数
            "shown_count": 11,                 # 总输出行数（含 context）
            "seq_range": "3-27",              # 输出覆盖的 seq 范围
            "gaps": [(13, 22)]                # 窗口间的跳跃段（用于显示 "..."）
        }
    """
    # ── 1. 找到所有"精确匹配"行 ──
    matched_indices: list[int] = []
    for i, entry in enumerate(logs):
        entry_seq = entry.get("seq")

        # seq 范围过滤
        if since is not None and entry_seq < since:
            continue
        if until is not None and entry_seq > until:
            continue

        # 如果指定了精确 seq，只匹配那一个
        if seq is not None:
            if entry_seq == seq:
                matched_indices.append(i)
                break  # 只找一个
            else:
                continue

        # level + grep 过滤
        if _match_level(entry, levels) and _match_grep(entry, grep):
            matched_indices.append(i)

    if not matched_indices:
        return {
            "matched_seq": [],
            "shown_logs": [],
            "matched_count": 0,
            "shown_count": 0,
            "seq_range": "N/A",
            "gaps": [],
        }

    # ── 2. 扩展 context 窗口并合并 ──
    matched_seq_list = [logs[i]["seq"] for i in matched_indices]
    windows = _merge_context_windows(matched_seq_list, context)

    # ── 3. 从 logs 中提取窗口内容 ──
    matched_seq_set = set(matched_seq_list)
    shown_logs: list[dict] = []
    gaps: list[tuple[int, int]] = []
    first_window = True

    for win_start, win_end in windows:
        if not first_window:
            # 在窗口之间插入间隙标记
            # 计算上一个窗口的 end 和当前窗口的 start 之间的间隙
            prev_end = windows[windows.index((win_start, win_end)) - 1][1]
            if win_start > prev_end + 1:
                gaps.append((prev_end + 1, win_start - 1))
        first_window = False

        for entry in logs:
            s = entry.get("seq")
            if win_start <= s <= win_end:
                entry_copy = dict(entry)
                entry_copy["matched"] = s in matched_seq_set
                shown_logs.append(entry_copy)

    # ── 4. 组装结果 ──
    seqs = [e["seq"] for e in shown_logs]
    if seqs:
        seq_range = f"{seqs[0]}-{seqs[-1]}"
    else:
        seq_range = "N/A"

    return {
        "matched_seq": matched_seq_list,
        "shown_logs": shown_logs,
        "matched_count": len(matched_seq_list),
        "shown_count": len(shown_logs),
        "seq_range": seq_range,
        "gaps": gaps,
    }


def _format_filter_summary(
    level_display: str,
    grep: str | None,
    context: int,
    filtered: dict,
    total_buffered: int,
    current_seq: int,
) -> str:
    """
    生成人类可读的过滤摘要。

    返回格式化的多行字符串，适合在 MCP 工具结果中显示。
    """
    lines = []
    lines.append("=" * 60)
    lines.append("  Godot 运行时日志查询结果")
    lines.append("=" * 60)
    lines.append(f"  过滤条件: level={level_display}", )
    if grep:
        lines.append(f"            grep={grep!r}")
    lines.append(f"            context=±{context} 行")
    lines.append(f"")
    lines.append(f"  📊 总计: {total_buffered} 条缓冲 | 匹配: {filtered['matched_count']} 条")
    lines.append(f"      输出: {filtered['shown_count']} 条 (含 context)")
    lines.append(f"      seq 范围: {filtered['seq_range']}")
    lines.append(f"      当前最大 seq: {current_seq}")
    if filtered["gaps"]:
        gaps_str = ", ".join(f"[{s}-{e}]" for s, e in filtered["gaps"])
        lines.append(f"      ⚡ 跳跃段: {gaps_str} (共 {len(filtered['gaps'])} 段)")
    lines.append("-" * 60)

    return "\n".join(lines)


def _format_log_lines(logs: list[dict]) -> list[str]:
    """
    将日志条目格式化为可读文本行。

    每行格式:
        > seq=042 | 14:23:45 | ERROR | PlayerState: something broke
        › seq=041 | 14:23:44 | INFO  | loading...      (context 行用 › 前缀)
    """
    lines = []
    for entry in logs:
        seq = entry.get("seq", "???")
        ts = entry.get("timestamp", "??:??:??")
        level = entry.get("level", "?????")
        msg = entry.get("message", "")
        marker = ">" if entry.get("matched", False) else "›"
        lines.append(f"  {marker} seq={seq:03d} | {ts} | {level:5s} | {msg}")
    return lines


# ═════════════════════════════════════════════════════════════════════════════
# 人类可读格式化函数（探针数据 → 终端友好输出）
# ═════════════════════════════════════════════════════════════════════════════


def _format_node(prefix: str, node: dict, is_last: bool) -> list[str]:
    """递归格式化场景树节点。"""
    name = node.get("name", "?")
    class_name = node.get("class_name", "")
    child_count = node.get("child_count", 0)
    visible = node.get("visible", True)
    children = node.get("children", [])

    visible_mark = "✓" if visible else "✗"
    if class_name:
        label = f"{name} [{class_name}] (children={child_count}, visible={visible_mark})"
    else:
        label = f"{name} (children={child_count}, visible={visible_mark})"

    lines: list[str] = []
    connector = "└── " if is_last else "├── "
    lines.append(f"{prefix}{connector}{label}")

    child_prefix = prefix + ("    " if is_last else "│   ")
    for i, child in enumerate(children):
        child_is_last = (i == len(children) - 1)
        lines.extend(_format_node(child_prefix, child, child_is_last))

    return lines


def _format_scene_tree_human(data: dict) -> str:
    """
    将场景树数据格式化为人类可读的树形结构。
    """
    if not data.get("ok", False):
        error = data.get("error", "未知错误")
        detail = data.get("detail", "")
        return (
            f"🌳 Godot 场景树\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  ❌ 错误: {error}\n"
            f"  详情: {detail}\n"
        )

    node_data = data.get("data")
    if node_data is None:
        return (
            f"🌳 Godot 场景树\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  (无数据 — Godot 可能尚未就绪)\n"
        )

    lines: list[str] = ["🌳 Godot 场景树"]
    lines.append("━" * 60)

    root_name = node_data.get("name", "root")
    root_class = node_data.get("class_name", "")
    root_children = node_data.get("children", [])
    root_child_count = node_data.get("child_count", len(root_children))

    root_label = f"📦 {root_name}"
    if root_class:
        root_label += f" [{root_class}]"
    root_label += f" (children={root_child_count})"
    lines.append(root_label)

    for i, child in enumerate(root_children):
        child_is_last = (i == len(root_children) - 1)
        lines.extend(_format_node("", child, child_is_last))

    return "\n".join(lines)


def _format_game_state_human(data: dict) -> str:
    """
    将游戏状态数据格式化为人类可读的分区块输出。
    """
    if not data.get("ok", False):
        error = data.get("error", "未知错误")
        detail = data.get("detail", "")
        return (
            f"🎮 Godot 游戏状态\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  ❌ 错误: {error}\n"
            f"  详情: {detail}\n"
        )

    d = data.get("data")
    if d is None:
        return (
            f"🎮 Godot 游戏状态\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  (无数据 — Godot 可能尚未就绪)\n"
        )

    lines: list[str] = ["🎮 Godot 游戏状态"]
    lines.append("━" * 60)

    # ── 玩家信息 ──
    player = d.get("player", {})
    lines.append("👤 玩家信息")
    name = player.get("name", "?")
    location = player.get("current_location", "?")
    lines.append(f"  姓名: {name}    位置: {location}")

    ambition = player.get("ambition")
    if ambition and ambition.get("key"):
        lines.append(f"  志向: {ambition['key']} ({ambition.get('name', '')})")
    else:
        lines.append(f"  志向: (无)")

    tags = player.get("current_action_tags", [])
    if tags:
        lines.append(f"  行动标签: [{', '.join(tags)}]")
    else:
        lines.append(f"  行动标签: (无)")

    poem_count = player.get("created_poems_count", 0)
    lines.append(f"  已创作诗篇: {poem_count} 首")
    lines.append("")

    # ── 属性数值 ──
    stats = d.get("stats", {})
    lines.append("📊 属性数值")
    if stats:
        for key in sorted(stats.keys()):
            val = stats[key]
            display_key = key.upper()
            lines.append(f"  {display_key:25s} | {val:>5d}")
    else:
        lines.append("  (无)")
    lines.append("")

    # ── Traits ──
    traits = d.get("traits", [])
    lines.append(f"🏷️ Traits ({len(traits)})")
    if traits:
        for t in traits:
            tk = t.get("key", "?")
            tn = t.get("name", "?")
            lines.append(f"  • {tk:20s} → {tn}")
    else:
        lines.append("  (无)")
    lines.append("")

    # ── Flags ──
    flags = d.get("flags", {})
    lines.append(f"🚩 Flags ({len(flags)})")
    if flags:
        for k in sorted(flags.keys()):
            v = flags[k]
            if isinstance(v, bool):
                v_str = "true" if v else "false"
            elif isinstance(v, str):
                v_str = f'"{v}"'
            else:
                v_str = str(v)
            lines.append(f"  {k:20s} = {v_str}")
    else:
        lines.append("  (无)")
    lines.append("")

    # ── Emotions ──
    emotions = d.get("emotions", {})
    lines.append(f"💭 Emotions ({len(emotions)})")
    if emotions:
        for ek in sorted(emotions.keys()):
            ev = emotions[ek]
            lines.append(f"  {ek:15s} = {ev:.2f}")
    else:
        lines.append("  (无)")
    lines.append("")

    # ── 游戏时间 ──
    game = d.get("game", {})
    lines.append("⏰ 游戏时间")
    year = game.get("year", "?")
    ratio = game.get("ratio_time", 0.0)
    mood = game.get("mood", 0.0)
    lines.append(f"  年份: {year}    时间比例: {ratio:.2f}    情绪值: {mood:.2f}")
    span = game.get("time_span", "?")
    start_y = game.get("start_year", "?")
    end_y = game.get("end_year", "?")
    lines.append(f"  时间跨度: {span} 年  ({start_y} → {end_y})")

    return "\n".join(lines)


def _format_event_system_human(data: dict) -> str:
    """
    将事件系统数据格式化为人类可读的输出。
    """
    if not data.get("ok", False):
        error = data.get("error", "未知错误")
        detail = data.get("detail", "")
        return (
            f"🎲 Godot 事件系统\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  ❌ 错误: {error}\n"
            f"  详情: {detail}\n"
        )

    d = data.get("data")
    if d is None:
        return (
            f"🎲 Godot 事件系统\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  (无数据 — Godot 可能尚未就绪)\n"
        )

    lines: list[str] = ["🎲 Godot 事件系统"]
    lines.append("━" * 60)

    # ── 保证事件 ──
    guaranteed_key = d.get("guaranteed_event_key")
    guaranteed_tag = d.get("guaranteed_main_tag")

    lines.append("🔒 保证事件")
    if guaranteed_key:
        tag_display = guaranteed_tag if guaranteed_tag else "(无)"
        lines.append(f"  事件 key: {guaranteed_key}    主标签: {tag_display}")
    else:
        lines.append("  (无保证事件)")
    lines.append("")

    # ── 签筒 ──
    pool = d.get("current_event_pool", [])
    pool_size = d.get("pool_size", len(pool))
    lines.append(f"📦 签筒 ({pool_size} 个事件)")

    if not pool:
        lines.append("  签筒为空")
    else:
        lines.append(f"  {'event_uuid':45s} │ weight │ original_weight")
        lines.append(f"  {'─' * 45}┼────────┼────────────────")
        for ev in pool:
            uuid = ev.get("event_uuid", "?")
            w = ev.get("weight", 0)
            ow = ev.get("original_weight", 0)
            lines.append(f"  {uuid:45s} │ {w:>6d} │ {ow:>15d}")

    return "\n".join(lines)


# ═════════════════════════════════════════════════════════════════════════════
# MCP Tool 定义
# ═════════════════════════════════════════════════════════════════════════════


@mcp.tool()
def get_live_scene_tree() -> str:
    """
    [场景树透视] 获取 Godot 游戏当前的实时场景树结构。

    当你需要排查 UI 面板是否已实例化、某个 Node 是否挂载在正确父节点下、
    或者验证场景树的状态是否符合预期时，调用此工具。

    返回包含 root 节点及递归子节点的 JSON，每层包含 name, class_name, child_count, visible。
    最大深度 20 层。

    前置条件: Godot 游戏必须正在运行（通过 VSCode 的 Launch Godot Project 启动）。
    """
    result = _do_probe_get("/api/scene_tree")

    human = _format_scene_tree_human(result)
    raw = json.dumps(result, ensure_ascii=False, indent=2)

    with open(HUMAN_OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(human)

    return human + "\n\n" + "=" * 60 + "\n\n" + raw


@mcp.tool()
def get_game_state() -> str:
    """
    [全局状态透视] 获取玩家状态 (PlayerState) 和游戏全局状态 (GameState) 的快照。

    当你需要确认当前玩家的属性值（文学声望、金钱、健康等）、
    所处位置、已获得的 trait、flag 数据、情绪状态、以及游戏时间进度时，调用此工具。

    返回包含以下数据的 JSON:
      - player: 名字、位置、雄心、行动标签
      - stats: 所有属性数值 (literary_fame, money, talent, health 等)
      - traits: 已获取的 trait 列表 (含 key 和 name)
      - flags: 当前所有 flag (key -> value)
      - emotions: 情绪状态字典
      - game: 年份、时间比例、情绪值等

    前置条件: Godot 游戏必须正在运行。
    """
    result = _do_probe_get("/api/game_state")

    human = _format_game_state_human(result)
    raw = json.dumps(result, ensure_ascii=False, indent=2)

    with open(HUMAN_OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(human)

    return human + "\n\n" + "=" * 60 + "\n\n" + raw


@mcp.tool()
def get_event_system() -> str:
    """
    [事件系统透视] 获取 EventManager 的实时状态。

    当你需要 Debug 事件触发问题时，调用此工具来审查：
      - 当前签筒 (current_event_pool) 中的所有事件及其权重
      - 是否有 GuaranteeNext 锁定的下一个事件
      - 签筒中的事件数量 (pool_size)

    返回包含 current_event_pool 数组和 guaranteed_event_key 的 JSON。
    每个事件条目包含 event_uuid, weight, original_weight。

    前置条件: Godot 游戏必须正在运行。
    """
    result = _do_probe_get("/api/event_system")

    human = _format_event_system_human(result)
    raw = json.dumps(result, ensure_ascii=False, indent=2)

    with open(HUMAN_OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(human)

    return human + "\n\n" + "=" * 60 + "\n\n" + raw


@mcp.tool()
def get_live_logs(
    level: str = "ERROR",
    grep: str | None = None,
    since: int | None = None,
    until: int | None = None,
    seq: int | None = None,
    context: int = 5,
    limit: int = 500,
) -> str:
    """
    [运行时日志] 获取 Godot 运行时 Logging 环形缓冲区中的日志，支持智能过滤。

    默认只返回 ERROR 级别的日志，每条错误前后带 ±5 行 context。
    可通过参数切换级别、搜索关键字、定位特定 seq、调整 context 窗口范围。

    参数:
        level:   日志级别过滤。
                 "ERROR" | "INFO" | "DEBUG" | "WARN" | "ALL" | "ERROR,WARN" (多选用逗号分隔)
                 默认 "ERROR"。
        grep:    在 message 字段中搜索子串（大小写不敏感）。
                 默认 None (不过滤)。
        since:   起始 seq 号（包含）。传给 Godot 做预过滤以减少传输量。
                 默认 None (从最早开始)。
        until:   结束 seq 号（包含）。与 since 组合实现范围截取。
                 默认 None (不限)。
        seq:     精确定位某条日志的 seq 号。指定此参数时，level/grep 过滤被忽略，
                 只返回该 seq 所在行及 context 行。
                 默认 None。
        context: 每条匹配行前后显示的行数。
                 默认 5。
        limit:   从 Godot 拉取的最大日志条数。
                 默认 500 (环形缓冲区的最大容量)。

    返回:
        包含以下部分的字符串:
        1. 人类可读的过滤摘要 (级别、匹配数、输出数、seq 范围、跳跃段)
        2. 日志列表（带 > 前缀的为匹配行，› 前缀的为 context 行）
        3. 末尾附加完整的 raw JSON 数据（供 AI 程序化解析）
    """
    # ── 1. 构建 query string ──
    qs_parts = []
    if since is not None:
        qs_parts.append(f"since={since}")
    if limit != 500:
        qs_parts.append(f"limit={limit}")
    qs = "?" + "&".join(qs_parts) if qs_parts else ""

    # ── 2. 从 Godot 拉取原始数据 ──
    endpoint = f"/api/logs{qs}"
    raw_result = _do_probe_get(endpoint)

    if not raw_result.get("ok", False):
        error_msg = raw_result.get("error", "未知错误")
        detail = raw_result.get("detail", "")
        return (
            f"❌ Godot 探针返回错误\n"
            f"错误: {error_msg}\n"
            f"详情: {detail}\n\n"
            f"完整响应:\n{json.dumps(raw_result, ensure_ascii=False, indent=2)}"
        )

    logs = raw_result.get("data", {}).get("logs", [])
    total_buffered = raw_result.get("data", {}).get("total_buffered", 0)
    current_seq = raw_result.get("data", {}).get("current_seq", 0)

    if not logs:
        level_display = level if level else "ERROR"
        return (
            f"🔍 Godot 运行时日志查询\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  过滤条件: level={level_display}\n"
            f"  since={since}, until={until}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"  缓冲区内无日志条目。Godot 可能刚启动，尚未产生日志。\n"
            f"  total_buffered={total_buffered}, current_seq={current_seq}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

    # ── 3. 解析 level 参数 ──
    levels = _parse_levels(level)
    level_display = level if level else "ERROR"

    # ── 4. 执行过滤 ──
    filtered = _filter_logs(
        logs=logs,
        levels=levels,
        grep=grep,
        since=None,   # 已在 Godot 端过滤过了
        until=None,   # 同上
        seq=seq,
        context=context,
    )

    # ── 5. 构建人类可读摘要 ──
    summary = _format_filter_summary(
        level_display=level_display,
        grep=grep,
        context=context,
        filtered=filtered,
        total_buffered=total_buffered,
        current_seq=current_seq,
    )

    # ── 6. 格式化日志行 ──
    log_lines = _format_log_lines(filtered["shown_logs"])
    log_section = "\n".join(log_lines) if log_lines else "  (无匹配日志)"

    # ── 7. 构建 raw JSON 块（供 AI 程序化解析） ──
    raw_json_data = {
        "ok": True,
        "filter_summary": {
            "level": level_display,
            "grep": grep,
            "context": context,
            "matched_count": filtered["matched_count"],
            "shown_count": filtered["shown_count"],
            "total_buffered": total_buffered,
            "current_seq": current_seq,
            "seq_range": filtered["seq_range"],
            "gaps": filtered["gaps"],
        },
        "logs": filtered["shown_logs"],
    }
    raw_json = json.dumps(raw_json_data, ensure_ascii=False, indent=2)

    # ── 8. 组装最终输出 ──
    output_parts = [
        summary,
        "",
        log_section,
        "",
        "=" * 60,
        "",
        raw_json,
    ]

    return "\n".join(output_parts)


# ==========================================
# 运行入口
# ==========================================

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Godot Runtime Probe MCP Server 启动")
    logger.info(f"探针端点: {GODOT_PROBE_BASE}")
    logger.info("可用工具:")
    logger.info("  - get_live_scene_tree()         →  GET /api/scene_tree")
    logger.info("  - get_game_state()              →  GET /api/game_state")
    logger.info("  - get_event_system()            →  GET /api/event_system")
    logger.info("  - get_live_logs(level, grep,    →  GET /api/logs?since=&limit=")
    logger.info("                 since, until,")
    logger.info("                 seq, context,")
    logger.info("                 limit)")
    logger.info("=" * 60)
    mcp.run()
