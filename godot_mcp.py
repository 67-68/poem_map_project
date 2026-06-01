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

# ... 其他 FastMCP 启动样板代码不用写，FastMCP 支持直接用 CLI 启动 ...