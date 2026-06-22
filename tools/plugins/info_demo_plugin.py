"""
InfoDemoPlugin — 配置驱动的信息演示插件。

为每个选项生成 info(msg="...") DSL，当选项被选中时，
Godot 侧 InfoDemoOperator 通过 EventBus.request_toast 弹出提示。

架构:
┌──────────────────────────────────────────┐
│  配置层 (Source of Truth)                │
│  option_features[].plugins.info_demo     │
│    {prompt, max_chars}                   │
├──────────────────────────────────────────┤
│  插件层 (Dumb Renderer)                  │
│  init() → 扫描并缓存规则                  │
│  get_prompt_fragment() → 注入 LLM 指令   │
│  get_extra_output_fields() → 声明字段    │
│  enrich_context() → 缓存 parsed（不写CSV）│
│  get_option_result_extras() → 生成 DSL   │
└──────────────────────────────────────────┘

用法:
  在 JSON 配置中启用并配置:
    {
      "plugins": ["info_demo"],
      "option_features": [
        {
          "id": "opt_kuangke",
          "plugins": {
            "info_demo": {
              "prompt": "用15字以内写一句狂客拂袖而去时的内心独白，要求冷静、不屑、简短",
              "max_chars": 15
            }
          }
        }
      ]
    }

未配置 plugins.info_demo 的选项不会生成 info() DSL。
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin

# ── DSL 安全清洗映射 ──
# info(msg="text") 中 text 不能包含 " (破坏引号)、) (破坏括号匹配)、换行符
# | 被 paren-aware 解析保护（括号内不切割）
# ; 被 quote-aware 解析保护（引号内不切割）
_DSL_SANITIZE_MAP = {
    '"': "'",       # 双引号 → 单引号
    ')': '）',       # 右括号 → 全角（保护 DSL 括号匹配）
    '(': '（',       # 左括号 → 全角（防御性）
    '\n': '',       # 换行 → 移除
    '\r': '',       # 回车 → 移除
}


def _sanitize_for_info_dsl(text: str) -> str:
    """清洗文本中的 DSL 特殊字符，使其安全嵌入 info(msg="...")。"""
    for char, replacement in _DSL_SANITIZE_MAP.items():
        text = text.replace(char, replacement)
    return text.strip()


class InfoDemoPlugin(EventPromptPlugin):
    """配置驱动的信息演示插件。

    行为完全由 option_features[].plugins.info_demo 驱动。
    零硬编码——插件只负责从配置读取规则并渲染到 Prompt 和 DSL。
    """

    @property
    def plugin_id(self) -> str:
        return "info_demo"

    # ── Phase 0: 配置扫描 ──

    def init(self, cfg) -> None:
        """扫描所有 option_features，提取 plugins.info_demo 配置。

        每个有 info_demo 配置的 option 对应一条规则，
        缓存到 self._demo_rules[option_id]。
        """
        self._demo_rules: dict[str, dict] = {}
        for opt in cfg.option_features:
            opt_cfg = opt.plugins.get("info_demo", {}) if opt.plugins else {}
            if not opt_cfg:
                continue
            self._demo_rules[opt.id] = {
                "prompt": opt_cfg.get("prompt", ""),
                "max_chars": opt_cfg.get("max_chars", 30),
            }
        # Hook 3→4 跨 Hook 缓存：在 enrich_context 中设置，在 get_option_result_extras 中消费
        self._cached_parsed: dict = {}

    # ── Hook 1: 动态构建 Prompt ──

    def get_prompt_fragment(self, combos, cfg) -> str:
        """根据 init() 阶段缓存的规则动态构建 LLM 指令。

        为每个有 info_demo 配置的选项生成独立的输出字段声明，
        并注入每个选项的 prompt、max_chars 约束。
        """
        rules = getattr(self, '_demo_rules', {})
        if not rules:
            return ""

        lines = ["\n请为每个选项输出独立的 info_demo 字段。info_demo 是一句简短的提示文字，"
                 "当玩家选择该选项后会在屏幕上以 toast 形式弹出。"]

        lines.append("\n各选项的 info_demo 规则如下：\n")
        for opt_id, rule in rules.items():
            sub_parts = [f"针对选项 '{opt_id}'："]
            if rule["prompt"]:
                sub_parts.append(f"  · 要求：{rule['prompt']}")
            sub_parts.append(f"  · 控制在{rule['max_chars']}字以内")
            lines.append("\n".join(sub_parts))

        lines.append("\n输出格式（请严格按照以下命名输出每个字段）：")
        for opt_id in rules:
            lines.append(f"info_demo_{opt_id}: <内容>")

        return "\n".join(lines)

    # ── Hook 2: 额外字段声明 ──

    def get_extra_output_fields(self) -> list[str]:
        """声明需要从 AI 响应中解析的 info_demo_{opt_id} 字段。"""
        rules = getattr(self, '_demo_rules', {})
        if not rules:
            return []
        return [f"info_demo_{opt_id}" for opt_id in rules]

    # ── Hook 3: 缓存 parsed（供 Hook 4 消费） ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """缓存当前事件的 parsed dict，供后续 get_option_result_extras() 使用。

        注意：此 Hook 不写入 CSV context 列（返回空 dict）。
        数据通过 self._cached_parsed 在 Hook 3→4 之间传递。
        """
        rules = getattr(self, '_demo_rules', {})
        if not rules:
            return {}

        # 从 parsed 或 _extra 中提取所有 info_demo 字段
        cached: dict[str, str] = {}
        for opt_id in rules:
            key = f"info_demo_{opt_id}"
            val = ctx.parsed.get(key, "")
            if not val:
                extra = ctx.parsed.get("_extra", {})
                val = extra.get(key, "")
            if val:
                cached[opt_id] = val

        self._cached_parsed = cached
        return {}  # 不写入 CSV context 列

    # ── Hook 4: 生成 info() DSL ──

    def get_option_result_extras(
        self,
        combos: list,
        choice: any,
    ) -> str:
        """从缓存中提取当前选项的 info_demo 文本，包装为 info(msg="...") DSL。

        清洗步骤：
          1. 替换 " → '（保护 DSL 引号）
          2. 替换 () → （）（保护 DSL 括号匹配）
          3. 移除换行符
          4. 裁剪至 max_chars
        """
        rules = getattr(self, '_demo_rules', {})
        if choice.id not in rules:
            return ""

        cached = getattr(self, '_cached_parsed', {})
        text = cached.get(choice.id, "")
        if not text:
            return ""

        # 按配置裁剪字数
        max_chars = rules[choice.id].get("max_chars", 30)
        if len(text) > max_chars:
            text = text[:max_chars]

        # 清洗 DSL 特殊字符
        text = _sanitize_for_info_dsl(text)
        if not text:
            return ""

        return f'info(msg="{text}")'


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(InfoDemoPlugin())
