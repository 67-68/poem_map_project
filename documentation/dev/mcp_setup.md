# MCP (Model Context Protocol) 搭建记录

> 搭建日期: 2026-06-01
> 相关文件: [`godot_mcp.py`](../godot_mcp.py), [`.roo/mcp.json`](../.roo/mcp.json)

---

## 背景

本项目通过 MCP 协议为 Roo Code 提供 Godot 引擎的脚本执行能力，让 AI 可以直接在容器内调用 Godot 运行 .gd 脚本。

## 架构

```
Roo Code (AI)
    │  JSON-RPC (stdin/stdout)
    ▼
mcp CLI (FastMCP Server)  ←──  godot_mcp.py (工具定义)
    │
    ▼
godot --headless -s <script>.gd
```

MCP Server 通过 [FastMCP](https://github.com/jlowin/fastmcp) 框架实现，定义了一个工具 `run_godot_script`：

- **入参**: `script_name`（相对于项目根目录的脚本路径）、`args`（可选参数列表）
- **出参**: Godot 的 stdout/stderr 输出
- **安全机制**: 路径清洗防目录穿越，工作目录强制锁定

## 依赖

| 组件 | 安装位置 | 备注 |
|------|---------|------|
| Python 3.14+ | 系统自带 (Dockerfile) | `python3` |
| `mcp[cli]` Python 包 | `/home/vscode/mcp_venv` | 见下方坑点 |
| Godot 4.6.3 | `/usr/local/bin/godot` | 无头模式运行 |

## 新增工具: CSV 云同步自动优先本地模式

🤓☝️ `run_godot_script` 已内置 CSV 同步脚本的自动识别逻辑：

- 当 `script_name` 包含 `csv_cloud_sync_cli.gd` 时，**自动追加** `--sync --prefer-local` 参数
- 调用方无需手动传递任何额外参数，AI 和用户都可以无脑调用

### 调用示例

```
# 直接调用 CSV 同步，自动使用本地优先模式：
run_godot_script("core/csv_cloud_sync_cli.gd")

# 等价于手动传递参数：
#   godot --headless -s core/csv_cloud_sync_cli.gd -- --sync --prefer-local
```

### 手动调用（不经过 MCP 自动识别）

```bash
godot --headless -s core/csv_cloud_sync_cli.gd -- --sync
godot --headless -s core/csv_cloud_sync_cli.gd -- --sync --prefer-local
```

## 数据流架构

```
AI / 用户
    │
    ▼
run_godot_script("core/csv_cloud_sync_cli.gd")
    │ 自动追加 --sync --prefer-local
    ▼
godot --headless -s core/csv_cloud_sync_cli.gd -- --sync --prefer-local
    │
    ▼
csv_cloud_sync_cli.gd (extends SceneTree)
    │ 解析 CLI 参数
    │ 实例化 csv_cloud_loader.gd
    ▼
csv_cloud_loader.gd
    │ prefer_local_files = true
    │ start_sync_queue()
    ▼
process_next_job()
    ├─ 本地 CSV 存在? → _read_local_csv() → _process_csv_data()
    └─ 本地 CSV 不存在? → fetch_events_from_cloud() → _process_csv_data()
```

---

## 配置文件

### [`.roo/mcp.json`](../.roo/mcp.json)

```json
{
    "mcpServers": {
        "godot-tool": {
            "command": "/home/vscode/mcp_venv/bin/mcp",
            "args": [
                "run",
                "/Users/lennon/Projects/poem_map_project/godot_mcp.py"
            ],
            "disabled": false,
            "autoApprove": []
        }
    }
}
```

### [`godot_mcp.py`](../godot_mcp.py) 关键常量

```python
WORKSPACE_DIR = "/Users/lennon/Projects/poem_map_project"
```

---

## 💀 坑点记录

### 坑 1: 容器 mount 路径 ≠ Dockerfile WORKDIR

**症状**: MCP Server 启动失败，找不到脚本文件。

**根因**: 

- Dockerfile 里设了 `WORKDIR /workspace`
- 但 [`devcontainer.json`](../.devcontainer/devcontainer.json) 的 `workspaceMount` 把项目挂载到了**宿主机同路径** (`target=${localWorkspaceFolder}`)
- 结果容器内的 `/workspace/` 是**空目录**，项目实际在 `/Users/lennon/Projects/poem_map_project`

**解决**: 将 `.roo/mcp.json` 和 `godot_mcp.py` 中的所有路径改为实际工作区路径。

### 坑 2: `uv` 未正确安装

**症状**: `uv: command not found`

**根因**: Dockerfile 用 `curl ... install.sh | sh` 安装 uv，但安装脚本依赖 `$HOME/.local/bin`，可能因 RUN 层的用户上下文问题没装到 `vscode` 用户的 PATH 里。

**解决**: 放弃 uv，直接使用 venv + pip 安装 `mcp[cli]`：

```bash
python3 -m venv /home/vscode/mcp_venv
/home/vscode/mcp_venv/bin/pip install 'mcp[cli]'
```

### 坑 3: 系统 Python 受 PEP 668 保护

**症状**: `pip3 install mcp` 报错 `error: externally-managed-environment`

**根因**: Ubuntu 基镜像启用了 PEP 668，禁止直接用 pip 安装系统级包。

**解决**: 创建 venv 虚拟环境隔离。

### 坑 4: Godot 缺少系统库 `libfontconfig.so.1`

**症状**: Godot 启动时报 `libfontconfig.so.1: cannot open shared object file`

**状态**: ⏳ 未修复

**解决方向**: Dockerfile 中添加：
```dockerfile
RUN apt-get update && apt-get install -y libfontconfig1
```

### 坑 5: 非入口脚本不能直接用 `-s` 运行

**症状**: 调用 `resources_registry_creator.gd` 时报错 `doesn't inherit from SceneTree or MainLoop`

**根因**: `godot --headless -s` 只能运行继承 `SceneTree` 或 `MainLoop` 的脚本（即 Godot 入口脚本），工具类脚本需要用 `preload` / `load` 方式加载。

**解决**: 需要编写一个入口包装脚本，或者确认目标脚本是否支持 `-s` 模式。

**本项目的解决案**: 创建了 `core/csv_cloud_sync_cli.gd`，它 `extends SceneTree`，在 `_init()` 中加载并实例化 `csv_cloud_loader.gd`（`@tool extends Node`），然后调用其方法。这种「入口包装器 + 核心逻辑」的分离模式就是坑 5 的推荐解法 🤓☝️。

---

## 验证方法

MCP Server 重启后，在 Roo Code 中调用 `run_godot_script` 工具即可验证。

```json
// 调用示例
{
    "script_name": "path/to/script.gd",
    "args": ["arg1", "arg2"]
}
```

正常返回格式：
```
Godot 脚本执行成功:
<stdout 输出>
```

错误返回格式：
```
Godot 执行崩溃 (Exit Code N) 💀:
<stderr 输出>
<可能的部分 stdout>
```
