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

# 🤓☝️ run_safe_shell_command 安全白名单
# 只有这些命令可以被执行，从根本上杜绝 shell 注入
ALLOWED_COMMANDS = {
    # 版本控制
    "git",
    # 文件浏览与搜索 (禁止删除/写入危险操作)
    "cat", "ls", "head", "tail", "wc", "find", "grep",
    "sort", "uniq", "echo", "printf",
    # Python 生态
    "python3", "pip3",
    # Godot 引擎
    "godot",
    # MCP CLI
    "mcp",
}

# 参数黑名单模式：如果参数中包含这些 token，直接拒绝执行
BLOCKED_ARG_TOKENS = {
    ";", "|", "`", "$(",
}

@mcp.tool()
def run_godot_script(script_name: str, args: list[str] = None) -> str:
    """
    [严密契约] 运行指定的 Godot Tool 脚本。
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
        # 不要强行吞咽错误，把 Godot 吐出来的完整报错拍在 AI 脸上 😨
        return f"Godot 执行崩溃 (Exit Code {e.returncode}) 💀:\n{e.stderr}\n{e.stdout}"


@mcp.tool()
def run_safe_shell_command(
    command: str,
    args: list[str] = None,
    timeout: int = 30
) -> str:
    """
    [严密契约] 在项目工作目录下安全执行白名单命令。

    自动锁定工作目录为 WORKSPACE_DIR，AI 无需手动 cd。
    命令与参数分离，从根本上杜绝 shell 注入。
    执行过程中不使用 shell=True，子进程无法访问 shell 元字符。

    :param command: 命令名，必须在 ALLOWED_COMMANDS 白名单中
    :param args: 参数列表，每个参数独立传入
    :param timeout: 超时秒数（默认 30s，最大 120s）
    """
    if args is None:
        args = []

    # 1. 白名单校验 🤓☝️
    if command not in ALLOWED_COMMANDS:
        allowed_list = ", ".join(sorted(ALLOWED_COMMANDS))
        return (
            f"安全拦截 💀: '{command}' 不在白名单中。\n"
            f"允许的命令: {allowed_list}"
        )

    # 2. 参数安全检查 — 禁止 shell 元字符渗透
    for i, arg in enumerate(args):
        for blocked in BLOCKED_ARG_TOKENS:
            if blocked in arg:
                return (
                    f"安全拦截 💀: 参数 #{i} 包含禁止的 shell 元字符 '{blocked}'。\n"
                    f"  禁止的参数: {arg}"
                )

    # 3. 组装命令 (不使用 shell=True，零注入风险)
    cmd = [command]
    cmd.extend(args)

    # 4. 超时上限硬限制
    timeout = min(timeout, 120)

    logging.info(f"Executing safe command: {' '.join(cmd)} (cwd={WORKSPACE_DIR}, timeout={timeout}s)")

    # 5. 执行
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,  # 不抛异常，让调用方自行判断 exit code
            cwd=WORKSPACE_DIR,
            timeout=timeout
        )

        # 组装输出
        output_parts = []
        if result.stdout:
            output_parts.append(result.stdout.rstrip())
        if result.stderr:
            output_parts.append(f"[STDERR]\n{result.stderr.rstrip()}")
        if result.returncode != 0:
            output_parts.append(f"[Exit Code: {result.returncode}]")

        return "\n".join(output_parts) if output_parts else "(无输出)"

    except subprocess.TimeoutExpired:
        return f"执行超时 ({timeout}s) 💀，命令可能仍在后台运行。"
    except FileNotFoundError:
        return f"命令未找到: {command} 💀，请检查是否已安装。"
    except PermissionError:
        return f"权限不足 💀: 无法执行 {command}"
