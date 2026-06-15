"""
LLM 客户端 + 响应解析 + 校验 — 通信域。

包含:
  LLMClient           DeepSeek API 客户端
  parse_llm_response  解析 LLM 返回的 title/description/options/summary
  validate_response   校验解析后的响应
"""

from typing import Optional

from openai import OpenAI

from tools.config import EventPipelineConfig


class LLMClient:
    """DeepSeek API 客户端（兼容 OpenAI SDK）。"""

    def __init__(self, api_key: str, model: str = "deepseek-chat"):
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.deepseek.com",
        )
        self.model = model

    def generate_event_text(
        self,
        system_prompt: str,
        user_prompt: str,
        timeout: int = 30,
    ) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.8,
            max_tokens=1024,
            timeout=timeout,
        )
        return response.choices[0].message.content.strip()


def parse_llm_response(response: str) -> dict:
    """解析 LLM 返回的 title/description/options/summary 及任意额外字段。

    Hook 2 支持：插件声明的额外字段（如 failed_hint）会被自动捕获到
    parsed["_extra"] dict 中，供后续 enrich_context() 使用。

    summary 支持嵌套块解析（YAML-like 缩进）:
        summary:
          description: <文本>
          extra_field: <值>

    返回 dict 结构:
        title:       事件标题
        description: 事件描述
        options:     {option_id: option_text, ...}
        summary:     {field_name: field_value, ...}（summary 嵌套块）
        _extra:      {field_name: field_value, ...}（非标准字段）
    """
    title = ""
    description = ""
    options: dict[str, str] = {}
    summary: dict[str, str] = {}
    extra: dict[str, str] = {}
    in_options = False
    in_summary = False

    for raw_line in response.split("\n"):
        line = raw_line.strip()
        if not line:
            in_options = False
            in_summary = False
            continue

        # ── Block-mode handlers (必须优先于 keyword 匹配，避免 summary 内的
        #    description: 覆盖主 description) ──
        if in_summary:
            if ":" in line and raw_line[0] in (" ", "\t"):
                key, val = line.split(":", 1)
                summary[key.strip()] = val.strip()
                continue
            else:
                in_summary = False

        if in_options:
            if ":" in line and raw_line[0] in (" ", "\t"):
                key, val = line.split(":", 1)
                options[key.strip()] = val.strip()
                continue
            else:
                in_options = False

        # ── Keyword matching ──
        if line.lower().startswith("summary"):
            in_summary = True
        elif line.lower().startswith("options"):
            in_options = True
        elif line.startswith("title:") or line.startswith("title："):
            sep = "：" if "：" in line else ":"
            title = line.split(sep, 1)[1].strip()
        elif line.startswith("description:") or line.startswith("description："):
            sep = "：" if "：" in line else ":"
            description = line.split(sep, 1)[1].strip()
        elif ":" in line:
            # 捕获所有其他顶层 key: value 行
            sep_idx = line.find(":")
            key = line[:sep_idx].strip()
            val = line[sep_idx + 1:].strip()
            # 过滤掉空 key 和数字开头（避免误抓非字段行）
            if key and not key[0].isdigit() and key not in (
                "title", "description", "options", "summary",
            ):
                extra[key] = val

    return {
        "title": title,
        "description": description,
        "options": options,
        "summary": summary,
        "_extra": extra,
    }


def validate_response(
    parsed: dict,
    cfg: EventPipelineConfig,
    override_min: Optional[int] = None,
    override_max: Optional[int] = None,
    override_option_max: Optional[int] = None,
) -> Optional[str]:
    """验证 LLM 响应。返回 None 表示通过，返回字符串表示错误信息。

    可通过 override_min/override_max 覆盖 cfg 中的默认长度约束，
    用于自适应重试时动态调整验证边界。
    可通过 override_option_max 覆盖 cfg 中的默认选项字数约束。
    """
    effective_min = override_min if override_min is not None else cfg.word_count_min
    effective_max = override_max if override_max is not None else cfg.word_count_max
    effective_option_max = override_option_max if override_option_max is not None else cfg.option_word_count_max

    if not parsed["title"]:
        return "title 为空"
    if len(parsed["title"]) > 20:
        return f"title 过长 ({len(parsed['title'])}字，限制20字以内)"

    if not parsed["description"]:
        return "description 为空"

    desc_len = len(parsed["description"])
    # 统一使用百分比偏差：|实际-限制| / 限制 < 0.2 放过
    effective_min_tolerance = int(effective_min * 0.8)
    effective_max_tolerance = int(effective_max * 1.2)
    if desc_len < effective_min_tolerance:
        return f"description 过短 ({desc_len}字，允许{effective_min_tolerance}-{effective_max_tolerance}字，原始要求{effective_min}-{effective_max}字)"
    if desc_len > effective_max_tolerance:
        return f"description 过长 ({desc_len}字，允许{effective_min_tolerance}-{effective_max_tolerance}字，原始要求{effective_min}-{effective_max}字)"

    # 如果定义了选项，验证每个非固定选项（fixed=False）都有 AI 生成的文本
    # 固定选项（fixed=True）直接使用配置文本，不校验
    ai_options = [of for of in (cfg.option_features or []) if not of.fixed]
    options = parsed.get("options", {})
    for of in ai_options:
        opt_text = options.get(of.id, "").strip()
        if not opt_text:
            return f"选项 '{of.id}' 为空"
        # 统一使用百分比偏差：|实际-限制| / 限制 < 0.2 放过
        option_max_tolerance = int(effective_option_max * 1.2)
        if len(opt_text) > option_max_tolerance:
            return f"选项 '{of.id}' 过长 ({len(opt_text)}字，允许{option_max_tolerance}字以内，原始限制{effective_option_max}字以内)"

    return None
