import json
import requests
import logging
from mcp.server.fastmcp import FastMCP

# 🤓☝️ 配置基础日志，别连自己怎么死的都不知道
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Godot_RAG_Bridge")

# 1. 实例化 MCP 节点
mcp = FastMCP("Godot_RAG_Bridge")

# ==========================================
# 基础设施坐标
# 容器内通过 host.docker.internal 访问宿主机服务
# ==========================================
OLLAMA_URL = "http://host.docker.internal:11434/api/embeddings"
QDRANT_BASE = "http://host.docker.internal:6333"
COLLECTION_NAME = "ws-48af07278f848afa"  # 从 Qdrant 文档中确认的 collection 名称
QDRANT_SEARCH_URL = f"{QDRANT_BASE}/collections/{COLLECTION_NAME}/points/search"

# Payload 字段名 (与索引脚本保持一致)
FIELD_FILEPATH = "filePath"
FIELD_CODE_CHUNK = "codeChunk"

# 向量维度校验 (当前 collection 为 768 维)
EXPECTED_VECTOR_DIM = 768


@mcp.tool()
def semantic_code_search(query: str, top_k: int = 3) -> str:
    """
    [语义搜索] 通过自然语言搜索项目代码库和文档。
    
    当你需要查找不熟悉的游戏机制、寻找 Bug 相关的上下文代码、或了解项目中的某个概念时，调用此工具。
    
    :param query: 自然语言查询，例如 "事件流动机制是怎么实现的？" 或 "飞花令的判定逻辑"
    :param top_k: 返回结果数量 (1-10)，默认 3，防止撑爆上下文
    :return: 格式化的代码片段列表
    """
    try:
        # ==========================================
        # 步骤 A: 参数校验
        # ==========================================
        if not query or not query.strip():
            return "错误: 查询字符串不能为空。"
        
        if top_k < 1:
            top_k = 1
        elif top_k > 10:
            top_k = 10

        # ==========================================
        # 步骤 B: 文本 -> 向量 (呼叫 Ollama)
        # ==========================================
        logger.info(f"Ollama embedding: query='{query[:50]}...'")
        ollama_payload = {
            "model": "nomic-embed-text",
            "prompt": query
        }
        ollama_res = requests.post(OLLAMA_URL, json=ollama_payload, timeout=30)
        ollama_res.raise_for_status()
        vector = ollama_res.json().get("embedding")

        if not vector:
            return "错误: Ollama 未返回向量数据。请检查 nomic-embed-text 模型是否正常加载。"
        
        # 向量维度校验 (防止模型切换导致的维度不匹配)
        actual_dim = len(vector)
        if actual_dim != EXPECTED_VECTOR_DIM:
            logger.warning(f"向量维度不匹配: 期望 {EXPECTED_VECTOR_DIM}, 实际 {actual_dim}. 仍继续处理.")

        # ==========================================
        # 步骤 C: 向量 -> 代码片段 (呼叫 Qdrant)
        # ==========================================
        logger.info(f"Qdrant search: collection={COLLECTION_NAME}, top_k={top_k}")
        qdrant_payload = {
            "vector": vector,
            "limit": top_k,
            "with_payload": True
        }
        qdrant_res = requests.post(QDRANT_SEARCH_URL, json=qdrant_payload, timeout=15)
        qdrant_res.raise_for_status()
        search_results = qdrant_res.json().get("result", [])

        if not search_results:
            return f"未在代码库中找到与 '{query}' 相关的片段。"

        # ==========================================
        # 步骤 D: 拼装干净的纯文本返回
        # ==========================================
        formatted_result = f"🔍 找到与 **'{query}'** 最相关的 {len(search_results)} 个代码片段:\n\n"
        for idx, hit in enumerate(search_results):
            payload = hit.get("payload", {})
            file_path = payload.get(FIELD_FILEPATH, "Unknown File")
            code_text = payload.get(FIELD_CODE_CHUNK, "No content")
            score = hit.get("score", 0.0)
            start_line = payload.get("startLine", "?")
            end_line = payload.get("endLine", "?")
            
            formatted_result += f"--- 📄 [{file_path}]({file_path}) (相关度: {score:.3f}, 行 {start_line}-{end_line}) ---\n"
            formatted_result += f"```\n{code_text}\n```\n\n"

        return formatted_result

    except requests.exceptions.ConnectionError as e:
        logger.error(f"连接失败: {e}")
        return f"错误: 无法连接到向量搜索引擎。请确认 Qdrant (端口 6333) 和 Ollama (端口 11434) 服务是否正在运行。\n详情: {str(e)}"
    except requests.exceptions.Timeout as e:
        logger.error(f"请求超时: {e}")
        return f"错误: 请求超时。服务可能负载过高，请稍后重试。\n详情: {str(e)}"
    except requests.exceptions.RequestException as e:
        logger.error(f"HTTP 请求异常: {e}")
        return f"错误: 向量搜索引擎返回异常。\n详情: {str(e)}"
    except Exception as e:
        # 🚨 终极防线：无论网络多烂，绝对不抛出致命异常中断 AI！
        logger.error(f"致命异常: {e}", exc_info=True)
        return f"工具执行遭遇底层异常 (已拦截): {str(e)}"


if __name__ == "__main__":
    logger.info("Godot RAG Bridge MCP server starting...")
    mcp.run()
