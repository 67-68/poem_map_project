"""
BlacklistPlugin — 内置黑名单插件（默认启用）

自动为所有 config 提供维度级滑动黑名单去重能力，无需在 JSON 中声明。
覆盖字段：
  - description: 默认启用（始终追踪）
  - option_{id}: 自动从 cfg.option_features 的 id 推导
  - title: 默认不启用（打印 ⚠️ 提示）

行为：
  Phase 0 init(cfg):
    - 确定 key dimension（优先 blacklist_config，否则用第一个维度）
    - 为每个 tracked_field 初始化滑动窗口历史
    - 打印诊断信息

  Phase 1 get_prompt_fragment():
    - 对每个 tracked_field 生成 summary 输出要求
    - 注入各字段的当前维度值黑名单历史
    - 打印注入详情（注入条数 + 内容预览）

  Phase 3 enrich_context():
    - 从 parsed.summary 块提取各字段摘要（description + options）
    - 更新对应的黑名单历史
    - 打印更新详情（加入了什么内容）

向后兼容：
  - 如果 JSON 中配置了 blacklist_config，使用其中指定的维度作为 key dimension
  - 否则使用第一个维度
  - max_items 默认 20，可通过 blacklist_config.max_items 覆盖
"""

from tools.plugin_base import EventPromptPlugin, PluginContext, register_plugin

# ── 默认滑动窗口大小 ──
_DEFAULT_MAX_ITEMS = 20
# ── 始终不追踪的字段 ──
_NEVER_TRACKED = ["title", "on_enter", "results", "interruptions"]


class BlacklistPlugin(EventPromptPlugin):
    """内置黑名单插件 — 配置无关，所有 config 默认启用。"""

    @property
    def plugin_id(self) -> str:
        return "_builtin_blacklist"

    # ── Phase 0: 初始化 ──

    def init(self, cfg) -> None:
        """扫描配置，确定 key dimension 和 tracked_fields。

        关键行为：
          - 如果配置中有维度声明了 blacklist_config，用该维度（向后兼容）
          - 否则使用第一个维度
          - tracked_fields = ["description"] + 所有非 fixed 的 option id
          - max_items 优先从 blacklist_config 读取，否则默认 20
        """
        # ── 确定 key dimension ──
        self._key_dim = None
        self._max_items = _DEFAULT_MAX_ITEMS

        # 优先找有 blacklist_config 的维度
        for d in cfg.dimensions:
            if d.blacklist_config is not None:
                self._key_dim = d
                self._max_items = d.blacklist_config.max_items
                break

        # 回退到第一个维度
        if self._key_dim is None and cfg.dimensions:
            self._key_dim = cfg.dimensions[0]

        # ── 确定 tracked_fields ──
        self._tracked_fields: list[str] = ["description"]
        if cfg.option_features:
            for opt in cfg.option_features:
                field_name = f"option_{opt.id}"
                if field_name not in self._tracked_fields:
                    self._tracked_fields.append(field_name)

        # ── 初始化历史存储: {field_name: {val_id: [item, ...]}} ──
        self._history: dict[str, dict[str, list[str]]] = {}
        for field in self._tracked_fields:
            self._history[field] = {}

        # ── 打印诊断信息 ──
        self._print_diagnostics()

    def _print_diagnostics(self) -> None:
        """打印黑名单诊断信息：什么字段启用了、什么字段没启用。"""
        dim_name = self._key_dim.name if self._key_dim else "(无维度)"
        print(f"📋 黑名单诊断 — key dimension: '{dim_name}', max_items: {self._max_items}")
        for field in self._tracked_fields:
            total = sum(len(items) for items in self._history[field].values())
            print(f"    ✅ {field} — 已启用追踪（当前共 {total} 条历史）")
        # 打印"未启用"提示
        all_possible = set(["title"] + self._tracked_fields)
        not_tracked = [f for f in _NEVER_TRACKED if f not in self._tracked_fields]
        if not_tracked:
            for f in not_tracked:
                print(f"    ⚠️  {f} — 未启用追踪")

    # ── 工具方法 ──

    def _get_val_id(self, combos: list) -> str:
        """从 combos 中找到 key dimension 对应的值 ID。"""
        if self._key_dim is None:
            return "_default"
        for combo in combos:
            if combo.dimension.id == self._key_dim.id:
                return combo.value.id
        # fallback: 使用第一个 combo 的值
        if combos:
            return combos[0].value.id
        return "_default"

    def _get_field_display_name(self, field: str) -> str:
        """获取字段的中文语义描述，用于 prompt。"""
        if field == "description":
            return "事件描述（包括具体情节发展和NPC互动细节）"
        if field.startswith("option_"):
            opt_id = field[len("option_"):]
            return f"选项「{opt_id}」的文本摘要"
        return field

    # ── Phase 1: Prompt 注入 ──

    def get_prompt_fragment(self, combos: list, cfg) -> str:
        """生成黑名单完整 prompt 片段。

        包含两部分：
          1. summary 输出格式要求（对每个 tracked_field）
          2. 当前维度值的黑名单历史列表
        """
        if not self._tracked_fields or self._key_dim is None:
            return ""

        val_id = self._get_val_id(combos)
        lines: list[str] = []

        # ── Part 1: Summary 输出要求 ──
        summary_fields_lines: list[str] = []
        for field in self._tracked_fields:
            desc = self._get_field_display_name(field)
            summary_fields_lines.append(f"  {field}: <对{desc}的摘要>")

        if summary_fields_lines:
            lines.append("同时，在输出的最后附加一个 summary 块，包含以下字段的摘要总结：\n")
            lines.append("summary:")
            lines.extend(summary_fields_lines)

        lines.append("")

        # ── Part 2: 黑名单历史注入 ──
        has_any_history = False
        for field in self._tracked_fields:
            field_history = self._history.get(field, {}).get(val_id, [])
            if not field_history:
                continue
            has_any_history = True
            desc = self._get_field_display_name(field)
            lines.append(f"\n## ⛔ 黑名单 — {desc}")
            lines.append(
                f"以下是为当前维度值「{val_id}」已生成的 {field}，"
                "请确保新生成的内容与已有内容在情节上有明显区分：\n"
            )
            for i, item in enumerate(field_history, 1):
                text = item[:100] + "..." if len(item) > 100 else item
                lines.append(f"{i}. {text}")
            # 📖 只读引用：将已有黑名单注入 prompt，不修改历史
            print(f"  📖 引用黑名单 [{self._key_dim.name} / {val_id} / {field}]: "
                  f"{len(field_history)} 条历史 → 注入 prompt（只读）")
            if field_history:
                preview = field_history[-1][:60] + "..." if len(field_history[-1]) > 60 else field_history[-1]
                print(f"     最近一条: \"{preview}\"")

        if not has_any_history:
            return "\n".join(lines).strip()

        return "\n".join(lines)

    # ── Phase 3: 响应提取与更新 ──

    def enrich_context(self, ctx: PluginContext) -> dict[str, str]:
        """从 parsed 响应的 summary 块提取各字段摘要并更新黑名单历史。

        提取来源：
          - summary.description → 对应 description 字段
          - summary.option_{id} → 对应 option 字段

        注意：只提取摘要（summary 块），不 fallback 到原始 option 文本。
        如果 LLM 未输出某个字段的摘要，该字段本轮不追加到黑名单。

        返回空 dict（不向 CSV 追加额外列）。
        """
        if self._key_dim is None:
            return {}

        combos = ctx.combos
        parsed = ctx.parsed
        val_id = self._get_val_id(combos)

        # ── 从 summary 块提取 ──
        summary = parsed.get("summary", {})
        if not isinstance(summary, dict):
            summary = {}

        # ── 提取 description ──
        desc_val = summary.get("description", "")
        if desc_val and desc_val.strip():
            self._add_to_history("description", val_id, desc_val.strip())

        # ── 提取各 option 字段 ──
        for field in self._tracked_fields:
            if not field.startswith("option_"):
                continue

            # 只从 summary 块提取摘要，不 fallback 到原始 option 文本
            opt_val = summary.get(field, "")
            if opt_val and opt_val.strip():
                self._add_to_history(field, val_id, opt_val.strip())

        return {}

    def _add_to_history(self, field: str, val_id: str, value: str) -> None:
        """向指定字段的黑名单历史追加一条记录，并打印日志。"""
        if field not in self._history:
            return
        if val_id not in self._history[field]:
            self._history[field][val_id] = []
        self._history[field][val_id].append(value)

        # 滑动窗口裁剪
        if len(self._history[field][val_id]) > self._max_items:
            self._history[field][val_id] = self._history[field][val_id][-self._max_items:]

        # 打印详细日志
        preview = value[:60] + "..." if len(value) > 60 else value
        total = len(self._history[field][val_id])
        dim_name = self._key_dim.name if self._key_dim else "?"
        # ✍️ 写入：验证通过后存入黑名单历史
        print(f"  ✍️ 更新黑名单 [{dim_name} / {val_id} / {field}] "
              f"(#{total}/{self._max_items}): \"{preview}\"")


# ════════════════════════════════════════════════════════════════
# 自动注册（import 时触发）
# ════════════════════════════════════════════════════════════════

register_plugin(BlacklistPlugin())
