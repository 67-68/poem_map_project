from mcp.server.fastmcp import FastMCP
import subprocess
import logging
import os

# 配置基础日志，别连自己怎么死的都不知道 😭
logging.basicConfig(level=logging.INFO)

# 🤓☝️ 实例化 MCP 节点
mcp = FastMCP("GodotToolController")

# 定义一个绝对安全的工作目录边界 (防止目录穿越攻击)
WORKSPACE_DIR = "/Users/lennon/Projects/poem_map_project"

# CSV 云同步 CLI 入口脚本名（用于自动识别并追加 prefer-local 参数）
CSV_SYNC_SCRIPT_NAME = "csv_cloud_sync_cli.gd"

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
    # 这样调用方无需手动传递这些参数，AI 和用户都可以无脑调用
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
        
    logging.info(f"Triggering Godot: {' '.join(cmd)}")

    # 3. 阻塞式执行与错误捕获
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            cwd=WORKSPACE_DIR # 强制工作目录
        )
        return f"Godot 脚本执行成功:\n{result.stdout}"
    except subprocess.CalledProcessError as e:
        return f"Godot 执行崩溃 (Exit Code {e.returncode}) 💀:\n{e.stderr}\n{e.stdout}"


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
        
    logging.info(f"Triggering Godot Scene: {' '.join(cmd)}")

    # 3. 阻塞式执行与错误捕获
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            cwd=WORKSPACE_DIR
        )
        return f"Godot 场景执行成功:\n{result.stdout}"
    except subprocess.CalledProcessError as e:
        return f"Godot 场景执行崩溃 (Exit Code {e.returncode}) 💀:\n{e.stderr}\n{e.stdout}"