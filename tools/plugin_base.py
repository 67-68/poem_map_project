"""
正交事件生成管线 — Plugin Hook 系统

提供 EventPromptPlugin 基类和 PLUGIN_REGISTRY 注册表。
插件可以在 3 个 Hook 点注入自定义行为：
  1. get_prompt_fragment() — User Prompt 中注入额外指令
  2. get_extra_output_fields() — 声明额外解析字段
  3. enrich_context() — 富化 CSV context 列

用法:
```python
from tools.plugin_base import EventPromptPlugin, register_plugin

class MyPlugin(EventPromptPlugin):
    @property
    def plugin_id(self) -> str:
        return "my_plugin"

    def get_prompt_fragment(self, combos, cfg) -> str:
        return "\\n另外请输出 my_field: xxx"

    def get_extra_output_fields(self) -> list[str]:
        return ["my_field"]

    def enrich_context(self, ctx) -> dict[str, str]:
        return {"my_field": ctx.parsed.get("my_field", "")}

register_plugin(MyPlugin())
```
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from tools.config import DimensionCombo, EventPipelineConfig


# ════════════════════════════════════════════════════════════════
# PLUGIN_REGISTRY — 全局插件注册表
# ════════════════════════════════════════════════════════════════

PLUGIN_REGISTRY: dict[str, "EventPromptPlugin"] = {}


def register_plugin(plugin: "EventPromptPlugin"):
    """注册一个插件实例到全局注册表。

    插件必须已设置 plugin_id，注册后可通过 cfg.plugins 列表引用。
    """
    pid = plugin.plugin_id
    if not pid:
        raise ValueError("Plugin 必须设置 plugin_id")
    if pid in PLUGIN_REGISTRY:
        raise ValueError(f"Plugin '{pid}' 已注册")
    PLUGIN_REGISTRY[pid] = plugin


def get_plugin(plugin_id: str) -> "EventPromptPlugin | None":
    """按 ID 获取已注册的插件实例。"""
    return PLUGIN_REGISTRY.get(plugin_id)


def resolve_plugins(plugin_ids: list[str]) -> list["EventPromptPlugin"]:
    """将 config.plugins 中的 ID 列表解析为插件实例列表。

    自动跳过空字符串，遇到未注册 ID 抛出 KeyError。
    """
    resolved = []
    for pid in plugin_ids:
        pid = pid.strip()
        if not pid:
            continue
        plugin = get_plugin(pid)
        if plugin is None:
            raise KeyError(
                f"未注册的 plugin ID: '{pid}'。"
                f" 可用插件: {list(PLUGIN_REGISTRY.keys())}"
            )
        resolved.append(plugin)
    return resolved


# ════════════════════════════════════════════════════════════════
# PluginContext — 传递给 enrich_context 的全量上下文
# ════════════════════════════════════════════════════════════════
# ⚠️ 注意：此 Context 与 Extractor 的 context dict 完全无关。
#    Extractor context = {"dimensions": {...}} 用于组合展开阶段。
#    PluginContext     = 解析后的 AI 响应 + 维度信息，用于后处理阶段。


@dataclass
class PluginContext:
    """插件上下文：传递给 enrich_context() 的全量管线状态。

    Attributes:
        combos:          当前事件的维度组合列表（DimensionCombo）
        cfg:             完整的事件管线配置
        raw_response:    AI 原始返回文本
        parsed:          解析后的结果 dict，包含 title/description/options
                         以及插件声明的额外字段（如 failed_hint）
        combined_scale:  当前组合的缩放系数（各维度 scale 乘积）
        uuid:            当前事件的 UUID（如 bai_ye_honeymoon_l0_typea_m0）
    """
    combos: list[Any] = field(default_factory=list)  # list[DimensionCombo]
    cfg: Any = None                                    # EventPipelineConfig
    raw_response: str = ""
    parsed: dict = field(default_factory=dict)
    combined_scale: float = 1.0
    uuid: str = ""


# ════════════════════════════════════════════════════════════════
# EventPromptPlugin — 插件基类
# ════════════════════════════════════════════════════════════════


class EventPromptPlugin:
    """事件 Prompt 插件基类。

    子类需覆盖的方法：
      plugin_id           — [必需] 插件唯一标识
      get_prompt_fragment — [可选] 返回注入 User Prompt 的文本
      get_extra_output_fields — [可选] 声明额外解析字段
      enrich_context      — [可选] 返回追加到 CSV context 列的 key=value 对

    用法示例见文件头部 docstring。
    """

    @property
    def plugin_id(self) -> str:
        """插件唯一标识符，在 PLUGIN_REGISTRY 中的 key。"""
        return ""

    # ── Hook 1: Prompt 注入 ──

    def get_prompt_fragment(
        self,
        combos: list[Any],
        cfg: Any,
    ) -> str:
        """返回注入到 User Prompt 的文本片段。

        在这里告诉 AI 需要输出额外的字段。
        返回的文本会追加到用户 prompt 的「输出要求」部分之后。

        参数:
            combos: 当前维度组合列表（DimensionCombo）
            cfg:    完整管线配置（EventPipelineConfig）

        返回:
            注入文本（含换行符），空字符串表示不注入。
        """
        return ""

    # ── Hook 2: 额外解析字段声明 ──

    def get_extra_output_fields(self) -> list[str]:
        """声明需要从 AI 响应中额外解析的字段名列表。

        解析器会自动从 AI 响应中提取形如「field_name: value」的行。
        例如返回 ["failed_hint"]，解析器会从响应中提取 failed_hint: xxx。

        返回:
            字段名列表，空列表表示不提取额外字段。
        """
        return []

    # ── Hook 3: Context 富化 ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """返回要追加到 CSV context 列的 key=value 对。

        接收完整的 PluginContext（含解析后的 parsed dict），
        返回的 dict 中的每个 (k, v) 会以 |k=v 格式追加到 context 列末尾。

        参数:
            ctx: PluginContext — 全量管线状态

        返回:
            key=value 对的 dict，空 dict 表示不追加。
        """
        return {}
