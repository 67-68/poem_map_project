"""
意象获取插件 — Hook 4 实现。

从维度值的 tags 中提取非 action: 开头的意象 tag，
生成 imagery_add DSL 追加到选项结果。

行为:
  Phase 0: init(cfg) — 扫描各维度值判断是否有 tags 数据
  Phase 4: get_option_result_extras — 从 combos 中提取第一个非 action tag，
           返回 "imagery_add(name=<tag>)"，空串表示无操作

用法:
  在 JSON 配置的顶层 plugins 中引用:
    {
      "plugins": ["imagery_acquisition"],
      ...
    }
"""

from tools.plugin_base import EventPromptPlugin, register_plugin


class ImageryAcquisitionPlugin(EventPromptPlugin):
    """意象获取插件 — 通过 Hook 4 将维度值的意象 tag 追加到选项结果 DSL。"""

    @property
    def plugin_id(self) -> str:
        return "imagery_acquisition"

    # ── Phase 0: 扫描配置判断是否有 tags 数据 ──

    def init(self, cfg) -> None:
        """扫描所有维度的 values，检查是否有非空 tags 字段。"""
        self._has_tags = any(
            any(val.tags for val in dim.values)
            for dim in cfg.dimensions
        )

    # ── Phase 4: 提取意象 tag 生成 imagery_add DSL ──

    def get_option_result_extras(
        self,
        combos: list[any],
        choice: any,
    ) -> str:
        """从维度值 tags 中提取第一个非 action: 前缀的意象 tag。

        遍历 dimension combos，找到第一个不以 'action:' 开头的 tag，
        返回 "imagery_add(name=<tag>)"。

        如果没有任何非 action tag，返回空字符串。
        """
        if not getattr(self, '_has_tags', False):
            return ""

        for combo in combos:
            if not combo.value.tags:
                continue
            for tag in combo.value.tags:
                tag = tag.strip()
                if not tag.startswith("action:"):
                    return f"imagery_add(name={tag})"

        return ""


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(ImageryAcquisitionPlugin())
