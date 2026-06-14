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

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Godot_Probe_MCP")

# ==========================================
# 基础设施坐标
# MCP 运行在 Docker 容器内，通过 host.docker.internal 访问宿主机
# ==========================================
GODOT_PROBE_BASE = "http://host.docker.internal:6066"
REQUEST_TIMEOUT = 10  # 秒

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
            "error": f"无法连接到 Godot RuntimeProbe (端口 6066)",
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


# ==========================================
# MCP Tool 定义
# ==========================================

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
    return json.dumps(result, ensure_ascii=False, indent=2)


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
    return json.dumps(result, ensure_ascii=False, indent=2)


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
    return json.dumps(result, ensure_ascii=False, indent=2)



@mcp.tool()
def get_live_logs() -> str:
    """
    [运行时日志] 获取 Godot 运行时 Logging 环形缓冲区中的日志。
    
    当你需要查看最近发生了什么、排查 Bug 或追踪执行流程时，调用此工具。
    返回包含日志条目数组 (logs) 的 JSON，每个条目包含:
      - seq: 自增序列号
      - timestamp: 时间戳
      - level: 日志级别 (DEBUG/INFO/WARN/ERROR)
      - message: 日志消息
    
    同时返回:
      - total_buffered: 总缓冲条目数（可能超过返回数量）
      - current_seq: 当前最大序列号（用于后续增量拉取）
    
    前置条件: Godot 游戏必须正在运行。
    """
    result = _do_probe_get("/api/logs")
    return json.dumps(result, ensure_ascii=False, indent=2)

# ==========================================
# 运行入口
# ==========================================

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Godot Runtime Probe MCP Server 启动")
    logger.info(f"探针端点: {GODOT_PROBE_BASE}")
    logger.info("可用工具:")
    logger.info("  - get_live_scene_tree()  →  GET /api/scene_tree")
    logger.info("  - get_game_state()       →  GET /api/game_state")
    logger.info("  - get_event_system()     →  GET /api/event_system")
    logger.info("  - get_live_logs()        →  GET /api/logs")
    logger.info("=" * 60)
    mcp.run()
