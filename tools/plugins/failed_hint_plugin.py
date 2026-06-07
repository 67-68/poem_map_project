"""
FailedHintPlugin — 事件失败条件提示插件

Hook 1 (Prompt 注入):
  告诉 AI 在输出中增加 failed_hint 字段，内容为事件失败的条件说明。
  
  Prompt 示例:
    "写出失败的条件，和需要一首干晔诗词有关，呈现人物说的话或者客观事实，
     比如说其他人交的诗词，或者别人向你讨要诗词"

Hook 2 (额外字段解析):
  声明 "failed_hint" 字段，解析器自动从 AI 响应中提取。

Hook 3 (Context 富化):
  将 failed_hint 的值追加到 CSV context 列的末尾，格式为:
    trigger_tags=[...]|weight=10|failed_hint=去找干晔借一首诗吧

用法:
  在 JSON 配置中启用:
    {
      "plugins": ["failed_hint"],
      ...
    }
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin


class FailedHintPlugin(EventPromptPlugin):
    """在事件中注入失败条件提示的插件。

    AI 会输出一个 failed_hint 字段，描述事件失败时需要满足的条件。
    该字段会追加到 CSV 的 context 列，供 Godot 端 condition 系统消费。
    """

    @property
    def plugin_id(self) -> str:
        return "failed_hint"

    # ── Hook 1: Prompt 注入 ──

    def get_prompt_fragment(self, combos, cfg) -> str:
        """告诉 AI 输出 failed_hint 字段。"""
        return (
            "另外，请输出一个 failed_hint 字段。\n"
            "failed_hint: 写出触发失败结局的条件，该条件必须和需要一首干晔诗词有关。"
            "呈现人物说的话或者客观事实，比如说其他人交的诗词，或者别人向你讨要诗词。"
            "用一句话描述，控制在30字以内。"
            "\n"
            "输出格式示例：\n"
            "failed_hint: <失败条件的一句话描述>"
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

register_plugin(FailedHintPlugin())
