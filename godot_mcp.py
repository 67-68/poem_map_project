from mcp.server.fastmcp import FastMCP
import subprocess
import signal
import logging
import os

# 配置基础日志，别连自己怎么死的都不知道 😭
logging.basicConfig(level=logging.INFO)

# 🤓☝️ 实例化 MCP 节点
mcp = FastMCP("GodotToolController")

# 定义一个绝对安全的工作目录边界 (防止目录穿越攻击)
WORKSPACE_DIR = "/Users/a67_68/projects/dufu_simulator"

# CSV 云同步 CLI 入口脚本名（用于自动识别并追加 prefer-local 参数）
CSV_SYNC_SCRIPT_NAME = "csv_cloud_sync_cli.gd"

# 子进程超时（秒），防止 Godot 崩溃后挂死导致 MCP 工具永久阻塞
# 必须低于 MCP 协议层 60s 超时，否则子进程来不及 kill 就裸超时
SUBPROCESS_TIMEOUT = 15


def _run_godot_subprocess(cmd: list[str], label: str) -> str:
    """
    统一进程管理：用 Popen 启动 Godot 子进程，wait(timeout) 等待，
    无论成功/失败/超时都在 finally 中 SIGTERM → SIGKILL 确保不留僵尸。
    """
    proc = None
    try:
        logging.info(f"Triggering {label}: {' '.join(cmd)}")
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=WORKSPACE_DIR,
        )
        stdout, stderr = proc.communicate(timeout=SUBPROCESS_TIMEOUT)
        if proc.returncode != 0:
            return (
                f"Godot {label} 执行崩溃 (Exit Code {proc.returncode}) 💀:\n"
                f"{stderr}\n{stdout}"
            )
        return f"Godot {label} 执行成功:\n{stdout}"
    except subprocess.TimeoutExpired:
        # 超时时先 SIGTERM 优雅退出，再强制 SIGKILL
        _kill_proc(proc, label)
        return (
            f"Godot {label} 执行超时 ({SUBPROCESS_TIMEOUT}s) 💀:\n"
            f"子进程已被强制终止，防止残留僵尸进程。"
        )
    except Exception as e:
        _kill_proc(proc, label)
        return f"Godot {label} 执行遭遇未预期异常 💀: {str(e)}"


def _kill_proc(proc, label: str):
    """优雅终止 → 强制杀死，确保不留僵尸。"""
    if proc is None:
        return
    try:
        proc.terminate()
        proc.wait(timeout=5)
        logging.info(f"子进程({label}) SIGTERM 优雅终止成功")
    except Exception:
        try:
            proc.kill()
            proc.wait(timeout=2)
            logging.warning(f"子进程({label}) SIGTERM 失败，已 SIGKILL 强制杀死")
        except Exception:
            logging.error(f"子进程({label}) 杀死失败，可能已自行退出")


@mcp.tool()
def run_godot_script(script_name: str, args: list[str] = None) -> str:
    """
    [严密契约] 运行指定的 Godot Tool 脚本（--script 模式，不加载 autoload）。
    仅适用于不依赖 autoload/class_name 的纯脚本。
    :param script_name: 必须是相对于项目根目录的脚本路径，例如 "addons/my_tool/build.gd"
    :param args: 传递给脚本的可选参数列表
    """
    if args is None:
        args = []
        
    # 1. 物理防御：路径清洗与限制 😡
    target_path = os.path.abspath(os.path.join(WORKSPACE_DIR, script_name))
    if not target_path.startswith(WORKSPACE_DIR):
        return "安全拦截 💀：禁止访问工作区外部的脚本！"
        
    if not os.path.exists(target_path):
        return f"执行失败：找不到脚本文件 {target_path}"

    # 🤓☝️ 自动识别 CSV 云同步脚本，追加 --sync --prefer-local 参数
    if CSV_SYNC_SCRIPT_NAME in script_name:
        if "--sync" not in args:
            args.append("--sync")
        if "--prefer-local" not in args:
            args.append("--prefer-local")
        logging.info(f"自动识别 CSV 同步脚本，已追加 --sync --prefer-local 参数")

    # 2. 组装安全的执行命令 (强制 Headless)
    # Godot 4 传参规范: godot --headless -s <script> -- <args>
    cmd = ["godot", "--headless", "-s", target_path]
    if args:
        cmd.append("--")
        cmd.extend(args)

    return _run_godot_subprocess(cmd, "脚本")


@mcp.tool()
def run_godot_scene(scene_name: str, args: list[str] = None) -> str:
    """
    [场景模式] 运行指定的 Godot 场景（加载 autoload 和 class_name）。
    适用于需要访问 Logging、PlayerState 等 autoload 的 @tool 脚本。
    :param scene_name: 必须是相对于项目根目录的场景路径，例如 "parser/event_chain_builder.tscn"
    :param args: 传递给场景的命令行参数列表（通过 OS.get_cmdline_args() 获取）
    """
    if args is None:
        args = []
        
    # 1. 物理防御：路径清洗与限制 😡
    target_path = os.path.abspath(os.path.join(WORKSPACE_DIR, scene_name))
    if not target_path.startswith(WORKSPACE_DIR):
        return "安全拦截 💀：禁止访问工作区外部的场景！"
        
    if not os.path.exists(target_path):
        return f"执行失败：找不到场景文件 {target_path}"

    # 2. 组装安全的执行命令 (强制 Headless，场景模式加载 autoload)
    cmd = ["godot", "--headless", target_path]
    if args:
        cmd.append("--")
        cmd.extend(args)

    return _run_godot_subprocess(cmd, "场景")