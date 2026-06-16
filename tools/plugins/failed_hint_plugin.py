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

注意: 本插件会自动注入 failed_hint 的「因果归责」写作质量规则（四铁律 + Good/Bad Case），
无论 option_features 是否有 per-option 配置。这些规则是静态的，来自
DOCUMENTATIONS/events/prompt_engineering_principles.md Section 7。
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin


# ── 支持的风格标识映射 ──
_STYLE_MAP = {
    "mock_direct_speech": "必须使用直接引语（NPC 原话，带引号）",
    "direct_speech": "使用直接引语",
    "objective_fact": "使用客观陈述",
    "inner_monologue": "使用 NPC 内心独白",
}

# ── 静态因果归责质量规则（始终注入） ──
_CAUSAL_ATTRIBUTION_RULES = """failed_hint 的写作必须遵循「因果归责」模型：

【核心原则】
failed_hint 的唯一职责是：让玩家感受到「因为我选择了这条路，所以我今天站在这里，只能看着，不能动。」
它不是补充说明，不是环境描写，也不是角色当下的生理反应。

【因果链模型】
玩家的历史选择 → 当前的人格/性格 (trait) → 面对这个时刻的无力 (failed_hint)

failed_hint 必须同时触及两层：
1. 性格层：因为你不是狂客 / 因为你选择了算计 —— 这是你现在的样子
2. 后果层：所以这个动作你做不了 / 这句话你说不出口 / 这个机会不属于你 —— 这是你现在的处境

【写作铁律】
1. 必须出现转折词「但是/但/却/不是」——转折词是因果链的铰链
2. 必须包含性格判断——「他不是那种人」「他没有那种疯劲」「他选择了计算」
3. 必须出现一个未遂的动作——手伸出去但收回、话到嘴边但咽回、脚迈出去但转身
4. 禁止纯环境描写、禁止纯生理反应（咳血、发抖、腿软）、禁止没有性格判断的犹豫

【Good Case — 因果归责正确】
「他看见李白扔过来的酒壶——手已经伸出去了。但他不是一个不计后果的人。他的手在袖口里攥紧，酒壶落在地上。」
→ 好在哪里：本能想接(未遂动作) → 性格判断(不是那种人) → 后果(酒壶落地)。三步都在说「这是你选的性格，这是你选的后果。」

【Bad Case — 因果链断裂】
「他站在门槛内，想迈出那一步，却想起昨夜咳出的血丝，于是退回屋里，轻轻掩上了门。」
→ 坏在哪里：只描述了犹豫。咳出的血丝是生理细节，不是性格因果。玩家不知道这是自己选的。
"""


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

        始终注入因果归责质量规则（四铁律 + Good/Bad Case）。
        如果有 per-option 配置，额外注入格式要求。
        """
        parts = [_CAUSAL_ATTRIBUTION_RULES]

        hint_rules = getattr(self, '_hint_rules', {})
        if hint_rules:
            lines = ["\n请为每个选项输出独立的 failed_hint 字段。格式要求如下：\n"]
            for opt_id, rule in hint_rules.items():
                sub_parts = [f"针对选项 '{opt_id}' 的 failed_hint 规则："]
                if rule["context"]:
                    sub_parts.append(f"· {rule['context']}")
                sub_parts.append(f"· {rule['style_desc']}")
                sub_parts.append(f"· 控制在{rule['max_chars']}字以内")
                lines.append("\n".join(sub_parts))
            lines.append("\n输出格式（请严格按照以下命名输出每个字段）：")
            for opt_id in hint_rules:
                lines.append(f"failed_hint_{opt_id}: <内容>")
            parts.append("\n".join(lines))

        return "\n".join(parts)

    # ── Hook 2: 额外字段声明 ──

    def get_extra_output_fields(self) -> list[str]:
        """改为动态返回 per-option 字段名列表。

        从 self._hint_rules 的 keys 生成 failed_hint_{opt_id} 字段名，
        使 LLM 能意识到要为每个有 failed_hint 配置的选项输出独立字段。
        """
        hint_rules = getattr(self, '_hint_rules', {})
        if not hint_rules:
            return []
        return [f"failed_hint_{opt_id}" for opt_id in hint_rules]

    # ── Hook 3: CSV Context 富化 ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """从 parsed 中提取所有 failed_hint_{opt_id} 字段到 context_extras。

        遍历 self._hint_rules 的 keys，为每个有 failed_hint 配置的选项
        提取对应的 LLM 输出字段。
        """
        result = {}
        hint_rules = getattr(self, '_hint_rules', {})
        for opt_id in hint_rules:
            key = f"failed_hint_{opt_id}"
            hint = ctx.parsed.get(key, "")
            if not hint:
                extra = ctx.parsed.get("_extra", {})
                hint = extra.get(key, "")
            if hint:
                result[key] = hint
        return result

    # ── Hook 4: 提供上下文内联提示 ──

    def get_option_result_extras(self, ctx: PluginContext) -> dict[str, str]:
        """废弃：之前把 per-option failed_hint 注入 result DSL，现在不再需要。

        failed_hint 现在在 main.py 中已改为每选项动态查找，无需插件侧提前组装。
        """
        return {}


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(FailedHintPlugin())
