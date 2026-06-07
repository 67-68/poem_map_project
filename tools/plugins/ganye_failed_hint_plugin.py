"""
GanyeFailedHintPlugin — 干谒诗失败条件提示插件

与 failed_hint_plugin.py 的区别：
- 专门针对 拜谒-真实面目（70-100）阶段的 干谒诗 requirement 设计
- Prompt 更强调"权力阻击"和"资源掠夺"的恶意语境
- failed_hint 字段直接注入到 option 的 requirement 列的 poem_has() DSL 中

Hook 1 (Prompt 注入):
   告诉 AI 在输出中增加 failed_hint 字段，内容为玩家因没有干谒诗而失败的场景描述。

Hook 2 (额外字段解析):
   声明 "failed_hint" 字段，解析器自动从 AI 响应中提取。

Hook 3 (Context 富化):
   将 failed_hint 的值提取出来，供生成管线注入到 option_requirement 模板中。

用法:
   在 JSON 配置中启用:
     {
       "plugins": ["ganye_failed_hint"],
       "universal_option_requirement": "poem_has(type=GAN_YE; min_level=1; failed_hint=\"{failed_hint}\")",
       ...
     }
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin


class GanyeFailedHintPlugin(EventPromptPlugin):
    """在事件中注入干谒诗失败条件提示的插件。

    AI 会输出一个 failed_hint 字段，描述玩家因没有干谒诗而无法通过权力阻击。
    该字段会通过模板替换注入到 option 的 requirement 列。
    """

    @property
    def plugin_id(self) -> str:
        return "ganye_failed_hint"

    # ── Hook 1: Prompt 注入 ──

    def get_prompt_fragment(self, combos, cfg) -> str:
        """告诉 AI 输出 failed_hint 字段，强调干谒诗语境。"""
        return (
            "另外，请输出一个 failed_hint 字段。\n"
            "failed_hint: 玩家因没有"
            "\u201c干谒诗\u201d"
            "（拜谒权贵用的诗）而无法通过当前权力阻击。"
            "写出人物说的话或客观事实，比如门子索要"
            "\u201c门包诗\u201d"
            "、清客挑剔诗词不合格、权贵以诗为名羞辱玩家。"
            "语气要冷酷、恶意，体现权力碾压感。用一句话描述，控制在30字以内。"
            "\n"
            "输出格式示例：\n"
            "failed_hint: <权力阻击的一句話描述>"
        )

    # ── Hook 2: 额外解析字段声明 ──

    def get_extra_output_fields(self) -> list[str]:
        return ["failed_hint"]

    # ── Hook 3: Context 富化 ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """将 failed_hint 从 parsed 提取到 context_extras。"""
        hint = ctx.parsed.get("failed_hint", "")
        if not hint:
            # 回退到 _extra（如果解析时未命中精确字段，可能在 _extra 里）
            extra = ctx.parsed.get("_extra", {})
            hint = extra.get("failed_hint", "")
        return {"failed_hint": hint} if hint else {}


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(GanyeFailedHintPlugin())
