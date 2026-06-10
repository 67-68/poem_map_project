"""
FailedHintPlugin — 配置驱动的失败提示插件（统一版）

合并自 ganye_failed_hint_plugin.py + failed_hint_plugin.py。

核心变化：
- 不再是硬编码行为，而是从配置中读取规则，动态构建 Prompt
- Phase 0 init(cfg) 扫描 option_features[].plugins.failed_hint
- get_prompt_fragment() 根据配置动态渲染，零硬编码

┌──────────────────────────────────────────┐
│  配置层 (Source of Truth)                │
│  option_features[].plugins.failed_hint   │
│    {style, max_chars, context}           │
├──────────────────────────────────────────┤
│  插件层 (Dumb Renderer)                  │
│  init() → 扫描并缓存                     │
│  get_prompt_fragment() → 动态构建         │
│  enrich_context() → 提取到 CSV            │
└──────────────────────────────────────────┘

用法:
  在 JSON 配置中启用并配置:
    {
      "plugins": ["failed_hint"],
      "option_features": [
        {
          "id": "option_accept",
          "plugins": {
            "failed_hint": {
              "style": "mock_direct_speech",
              "max_chars": 20,
              "context": "NPC 验货后发现没有诗词时的嘲讽反应"
            }
          }
        }
      ]
    }

向后兼容:
  如果 option 没有 plugins.failed_hint 配置，插件不会为该选项注入任何内容。
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin


# ── 支持的风格标识映射 ──
_STYLE_MAP = {
    "mock_direct_speech": "必须使用直接引语（NPC 原话，带引号）",
    "direct_speech": "使用直接引语",
    "objective_fact": "使用客观陈述",
    "inner_monologue": "使用 NPC 内心独白",
}


class FailedHintPlugin(EventPromptPlugin):
    """配置驱动的失败提示插件。

    行为完全由 option_features[].plugins.failed_hint 驱动。
    无任何硬编码内容——插件只负责从配置读取规则并渲染到 Prompt。
    """

    @property
    def plugin_id(self) -> str:
        return "failed_hint"

    # ── Phase 0: 配置扫描 ──

    def init(self, cfg) -> None:
        """扫描所有 option_features，提取 plugins.failed_hint 配置。

        每个有 failed_hint 配置的 option 对应一条规则，
        缓存到 self._hint_rules[option_id]。
        """
        self._hint_rules: dict[str, dict] = {}
        for opt in cfg.option_features:
            opt_cfg = opt.plugins.get("failed_hint", {}) if opt.plugins else {}
            if not opt_cfg:
                continue
            style = opt_cfg.get("style", "direct_speech")
            self._hint_rules[opt.id] = {
                "style": style,
                "style_desc": _STYLE_MAP.get(style, f"风格: {style}"),
                "max_chars": opt_cfg.get("max_chars", 30),
                "context": opt_cfg.get("context", ""),
            }

    # ── Hook 1: 动态构建 Prompt ──

    def get_prompt_fragment(self, combos, cfg) -> str:
        """根据 init() 阶段缓存的规则动态构建 Prompt 文本。

        如果没有任何 option 配置了 plugins.failed_hint，返回空字符串。
        """
        hint_rules = getattr(self, '_hint_rules', {})
        if not hint_rules:
            return ""

        lines = ["另外，请输出一个 failed_hint 字段。\n"]

        for opt_id, rule in hint_rules.items():
            parts = [f"针对选项 '{opt_id}' 的 failed_hint 规则："]
            if rule["context"]:
                parts.append(f"· {rule['context']}")
            parts.append(f"· {rule['style_desc']}")
            parts.append(f"· 控制在{rule['max_chars']}字以内")
            lines.append("\n".join(parts))

        lines.append("\n输出格式：\nfailed_hint: <内容>")
        return "\n".join(lines)

    # ── Hook 2: 额外字段声明 ──

    def get_extra_output_fields(self) -> list[str]:
        return ["failed_hint"]

    # ── Hook 3: CSV Context 富化 ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """从 parsed 中提取 failed_hint 字段到 context_extras。

        先尝试顶层字段，再回退到 _extra（兼容不同解析路径）。
        """
        hint = ctx.parsed.get("failed_hint", "")
        if not hint:
            extra = ctx.parsed.get("_extra", {})
            hint = extra.get("failed_hint", "")
        return {"failed_hint": hint} if hint else {}


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(FailedHintPlugin())
