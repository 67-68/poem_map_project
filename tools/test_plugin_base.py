"""
单元测试 — Plugin Hook 系统

运行:
    python3 -m unittest tools.test_plugin_base -v
"""
import unittest
import sys

sys.path.insert(0, ".")

from tools.config import (
    DimensionCombo,
    EventPipelineConfig,
    OptionFeature,
    PipelineDimension,
    PipelineDimensionValue,
)
from tools.plugin_base import (
    PLUGIN_REGISTRY,
    EventPromptPlugin,
    PluginContext,
    get_plugin,
    register_plugin,
    resolve_plugins,
)
from tools.generate_orthogonal_events import (
    _build_context_column,
    build_user_prompt,
    parse_llm_response,
)
from tools.plugins.failed_hint_plugin import FailedHintPlugin


# ════════════════════════════════════════════════════════════════
# 辅助：测试用插件
# ════════════════════════════════════════════════════════════════

class TestPluginA(EventPromptPlugin):
    @property
    def plugin_id(self):
        return "test_a"
    def get_prompt_fragment(self, combos, cfg):
        return "额外字段 hint_a: 测试用提示A"
    def get_extra_output_fields(self):
        return ["hint_a"]
    def enrich_context(self, ctx):
        return {"hint_a": ctx.parsed.get("hint_a", "fallback_a")}


class TestPluginB(EventPromptPlugin):
    @property
    def plugin_id(self):
        return "test_b"
    def get_prompt_fragment(self, combos, cfg):
        return "额外字段 hint_b: 测试用提示B"
    def get_extra_output_fields(self):
        return ["hint_b"]
    def enrich_context(self, ctx):
        return {"hint_b": ctx.parsed.get("hint_b", "fallback_b")}


# ════════════════════════════════════════════════════════════════
# 测试夹具（Test Fixtures）
# ════════════════════════════════════════════════════════════════

def _make_dummy_cfg(
    plugins: list[str] | None = None,
    option_features: list[OptionFeature] | None = None,
) -> EventPipelineConfig:
    return EventPipelineConfig(
        id="test_cfg",
        name="测试配置",
        word_count_min=10,
        word_count_max=50,
        plugins=plugins or [],
        option_features=option_features or [],
    )


def _make_dummy_combos() -> list[DimensionCombo]:
    dim = PipelineDimension(
        id="test_dim", name="测试维度",
        values=[PipelineDimensionValue(id="v1", name="值1", description="测试值1")],
    )
    val = dim.values[0]
    return [DimensionCombo(dimension=dim, value=val)]


# ════════════════════════════════════════════════════════════════
# Test: PluginBase — 注册与解析
# ════════════════════════════════════════════════════════════════

class TestPluginRegistry(unittest.TestCase):
    """PLUGIN_REGISTRY 注册与解析"""

    def setUp(self):
        # 注册测试插件
        self.plugin_a = TestPluginA()
        self.plugin_b = TestPluginB()
        register_plugin(self.plugin_a)
        register_plugin(self.plugin_b)

    def tearDown(self):
        # 清理注册表
        for pid in ["test_a", "test_b"]:
            PLUGIN_REGISTRY.pop(pid, None)

    def test_register_and_get(self):
        """注册后可通过 get_plugin 获取"""
        got = get_plugin("test_a")
        self.assertIsNotNone(got)
        self.assertEqual(got.plugin_id, "test_a")

    def test_get_nonexistent(self):
        """不存在的插件返回 None"""
        self.assertIsNone(get_plugin("nonexistent"))

    def test_resolve_plugins(self):
        """resolve_plugins 按 ID 列表解析"""
        resolved = resolve_plugins(["test_a", "test_b"])
        self.assertEqual(len(resolved), 2)
        self.assertEqual(resolved[0].plugin_id, "test_a")
        self.assertEqual(resolved[1].plugin_id, "test_b")

    def test_resolve_unknown_raises(self):
        """未注册的 ID 抛 KeyError"""
        with self.assertRaises(KeyError):
            resolve_plugins(["test_a", "ghost"])

    def test_resolve_empty_list(self):
        """空列表返回空"""
        self.assertEqual(resolve_plugins([]), [])

    def test_resolve_whitespace_ids_skipped(self):
        """空白 ID 被跳过"""
        resolved = resolve_plugins(["test_a", "", "  "])
        self.assertEqual(len(resolved), 1)
        self.assertEqual(resolved[0].plugin_id, "test_a")

    def test_duplicate_register_raises(self):
        """重复注册抛 ValueError"""
        dup = TestPluginA()
        with self.assertRaises(ValueError):
            register_plugin(dup)


# ════════════════════════════════════════════════════════════════
# Test: PluginBase — PluginContext
# ════════════════════════════════════════════════════════════════

class TestPluginContext(unittest.TestCase):
    """PluginContext dataclass"""

    def test_default_construction(self):
        ctx = PluginContext()
        self.assertEqual(ctx.combos, [])
        self.assertIsNone(ctx.cfg)
        self.assertEqual(ctx.raw_response, "")
        self.assertEqual(ctx.parsed, {})
        self.assertEqual(ctx.combined_scale, 1.0)
        self.assertEqual(ctx.uuid, "")

    def test_full_construction(self):
        ctx = PluginContext(
            combos=_make_dummy_combos(),
            cfg=_make_dummy_cfg(),
            raw_response="title: 测试\nhint_a: 提示内容",
            parsed={"title": "测试", "hint_a": "提示内容"},
            combined_scale=2.0,
            uuid="test_uuid",
        )
        self.assertEqual(len(ctx.combos), 1)
        self.assertEqual(ctx.parsed["hint_a"], "提示内容")
        self.assertEqual(ctx.combined_scale, 2.0)


# ════════════════════════════════════════════════════════════════
# Test: Hook 1 — build_user_prompt 插件注入
# ════════════════════════════════════════════════════════════════

class TestBuildUserPromptWithPlugins(unittest.TestCase):
    """build_user_prompt 在传入 plugins 时注入 prompt fragment"""

    def setUp(self):
        self.plugin_a = TestPluginA()
        self.plugin_b = TestPluginB()
        register_plugin(self.plugin_a)
        register_plugin(self.plugin_b)

    def tearDown(self):
        for pid in ["test_a", "test_b"]:
            PLUGIN_REGISTRY.pop(pid, None)

    def test_no_plugins_no_change(self):
        """不传 plugins 时 output 不变"""
        combos = _make_dummy_combos()
        cfg = _make_dummy_cfg()
        result = build_user_prompt(combos, cfg)
        self.assertNotIn("额外要求", result)

    def test_single_plugin_injects_fragment(self):
        """单个插件注入 prompt fragment"""
        combos = _make_dummy_combos()
        cfg = _make_dummy_cfg()
        result = build_user_prompt(combos, cfg, plugins=[self.plugin_a])
        self.assertIn("额外要求（test_a）", result)
        self.assertIn("hint_a", result)

    def test_two_plugins_both_injected(self):
        """两个插件各自注入"""
        combos = _make_dummy_combos()
        cfg = _make_dummy_cfg()
        result = build_user_prompt(combos, cfg, plugins=[self.plugin_a, self.plugin_b])
        self.assertIn("额外要求（test_a）", result)
        self.assertIn("额外要求（test_b）", result)
        self.assertIn("hint_a", result)
        self.assertIn("hint_b", result)

    def test_plugin_fragment_after_output_format(self):
        """插件 fragment 在输出格式要求之后"""
        combos = _make_dummy_combos()
        cfg = _make_dummy_cfg()
        result = build_user_prompt(combos, cfg, plugins=[self.plugin_a])
        # fragment 在 title:/description: 格式说明之后
        fmt_pos = result.find("title: <你的标题>")
        frag_pos = result.find("额外要求（test_a）")
        self.assertGreater(frag_pos, fmt_pos)


# ════════════════════════════════════════════════════════════════
# Test: Hook 2 — parse_llm_response 额外字段
# ════════════════════════════════════════════════════════════════

class TestParseLlmResponseExtraFields(unittest.TestCase):
    """parse_llm_response 捕获额外字段到 _extra"""

    def test_standard_fields_only(self):
        """标准响应只返回 title/description/options"""
        result = parse_llm_response("title: 测试\ndescription: 这是一段描述")
        self.assertEqual(result["title"], "测试")
        self.assertEqual(result["description"], "这是一段描述")
        self.assertEqual(result.get("_extra", {}), {})

    def test_extra_field_captured(self):
        """额外字段被捕获到 _extra"""
        result = parse_llm_response(
            "title: 测试\ndescription: 描述\nfailed_hint: 去找干晔借诗"
        )
        self.assertEqual(result["title"], "测试")
        self.assertEqual(result["_extra"]["failed_hint"], "去找干晔借诗")

    def test_multiple_extra_fields(self):
        """多个额外字段都捕获"""
        result = parse_llm_response(
            "title: 测试\ndescription: 描述\nhint_a: 提示A\nhint_b: 提示B"
        )
        self.assertEqual(result["_extra"]["hint_a"], "提示A")
        self.assertEqual(result["_extra"]["hint_b"], "提示B")

    def test_extra_field_with_options(self):
        """选项和额外字段共存"""
        result = parse_llm_response(
            "title: 测试\ndescription: 描述\noptions:\n option_accept: 接受\nfailed_hint: 找诗"
        )
        self.assertEqual(result["options"]["option_accept"], "接受")
        self.assertEqual(result["_extra"]["failed_hint"], "找诗")

    def test_title_not_in_extra(self):
        """title/description/options 不应出现在 _extra 中"""
        result = parse_llm_response(
            "title: 测试\ndescription: 描述\noptions:\n opt1: 选项一"
        )
        extra = result.get("_extra", {})
        self.assertNotIn("title", extra)
        self.assertNotIn("description", extra)
        self.assertNotIn("options", extra)

    def test_options_block_doesnt_leak_to_extra(self):
        """options 内的行不进入 _extra"""
        result = parse_llm_response(
            "title: 测试\ndescription: 描述\noptions:\n option_accept: 接受"
        )
        extra = result.get("_extra", {})
        self.assertNotIn("option_accept", extra)

    def test_no_extra_when_none(self):
        """无额外字段时 _extra 为空 dict"""
        result = parse_llm_response("title: 测试\ndescription: 描述")
        self.assertEqual(result.get("_extra", {}), {})


# ════════════════════════════════════════════════════════════════
# Test: Hook 3 — _build_context_column
# ════════════════════════════════════════════════════════════════

class TestBuildContextColumn(unittest.TestCase):
    """_build_context_column 富化 context 列"""

    def test_basic_no_extras(self):
        """无 extras 时输出基础格式"""
        result = _build_context_column(["bai_ye"])
        self.assertEqual(result, "trigger_tags=[bai_ye]|weight=10")

    def test_single_tag(self):
        """单标签"""
        result = _build_context_column(["action:main:baiye"])
        self.assertEqual(result, "trigger_tags=[action:main:baiye]|weight=10")

    def test_multiple_tags(self):
        """多标签"""
        result = _build_context_column(["tag_a", "tag_b"])
        self.assertEqual(result, "trigger_tags=[tag_a/tag_b]|weight=10")

    def test_empty_tags(self):
        """空标签列表"""
        result = _build_context_column([])
        self.assertEqual(result, "trigger_tags=|weight=10")

    def test_with_context_extras(self):
        """带插件富化"""
        result = _build_context_column(["bai_ye"], {"failed_hint": "去找诗"})
        self.assertEqual(result, "trigger_tags=[bai_ye]|weight=10|failed_hint=去找诗")

    def test_multiple_context_extras(self):
        """多个富化字段"""
        result = _build_context_column(
            ["bai_ye"],
            {"hint_a": "提示A", "hint_b": "提示B"},
        )
        self.assertIn("|hint_a=提示A", result)
        self.assertIn("|hint_b=提示B", result)

    def test_empty_context_extras_values_skipped(self):
        """空值的 extras 不追加"""
        result = _build_context_column(["bai_ye"], {"failed_hint": ""})
        self.assertEqual(result, "trigger_tags=[bai_ye]|weight=10")


# ════════════════════════════════════════════════════════════════
# Test: FailedHintPlugin 端到端
# ════════════════════════════════════════════════════════════════

class TestFailedHintPlugin(unittest.TestCase):
    """FailedHintPlugin 集成测试"""

    @classmethod
    def setUpClass(cls):
        # 确保插件已注册（import tools.plugins 触发）
        if "failed_hint" not in PLUGIN_REGISTRY:
            register_plugin(FailedHintPlugin())

    def test_plugin_id(self):
        plugin = get_plugin("failed_hint")
        self.assertIsNotNone(plugin)
        self.assertEqual(plugin.plugin_id, "failed_hint")

    def test_get_prompt_fragment(self):
        """prompt fragment 包含 failed_hint 相关说明"""
        plugin = FailedHintPlugin()
        cfg = _make_dummy_cfg(
            plugins=["failed_hint"],
            option_features=[
                OptionFeature(
                    id="option_accept",
                    text="接受",
                    plugins={
                        "failed_hint": {
                            "style": "mock_direct_speech",
                            "max_chars": 20,
                            "context": "NPC 验货后发现没有诗词时的反应",
                        }
                    },
                ),
            ],
        )
        plugin.init(cfg)
        fragment = plugin.get_prompt_fragment([], cfg)
        self.assertIn("failed_hint", fragment)
        self.assertIn("必须使用直接引语", fragment)
        self.assertIn("NPC 验货后发现没有诗词时的反应", fragment)

    def test_get_extra_output_fields(self):
        """声明 failed_hint 字段"""
        plugin = get_plugin("failed_hint")
        self.assertEqual(plugin.get_extra_output_fields(), ["failed_hint"])

    def test_enrich_context_with_hint(self):
        """从 parsed 中提取 failed_hint"""
        plugin = get_plugin("failed_hint")
        ctx = PluginContext(parsed={"failed_hint": "去找干晔借一首诗"})
        result = plugin.enrich_context(ctx)
        self.assertEqual(result, {"failed_hint": "去找干晔借一首诗"})

    def test_enrich_context_fallback_to_extra(self):
        """parsed 中无 failed_hint 时从 _extra 回退"""
        plugin = get_plugin("failed_hint")
        ctx = PluginContext(parsed={"_extra": {"failed_hint": "回退的提示"}})
        result = plugin.enrich_context(ctx)
        self.assertEqual(result, {"failed_hint": "回退的提示"})

    def test_enrich_context_empty_when_missing(self):
        """无 failed_hint 时返回空 dict"""
        plugin = get_plugin("failed_hint")
        ctx = PluginContext(parsed={})
        result = plugin.enrich_context(ctx)
        self.assertEqual(result, {})

    def test_end_to_end_prompt_and_parse(self):
        """端到端: prompt 注入 → AI 响应 → 解析 → context 富化"""
        cfg = _make_dummy_cfg(
            plugins=["failed_hint"],
            option_features=[
                OptionFeature(
                    id="option_accept",
                    text="接受",
                    plugins={
                        "failed_hint": {
                            "style": "mock_direct_speech",
                            "max_chars": 20,
                            "context": "NPC 验货后发现没有诗词时的反应",
                        }
                    },
                ),
            ],
        )
        plugin = FailedHintPlugin()
        plugin.init(cfg)

        # 模拟 build_user_prompt 含插件
        combos = _make_dummy_combos()
        prompt = build_user_prompt(combos, cfg, plugins=[plugin])
        self.assertIn("failed_hint", prompt)

        # 模拟 AI 响应
        ai_response = (
            "title: 索诗\n"
            "description: 李府门前，门子拦住你，说要想进门得先拿一首干晔的诗来。\n"
            "failed_hint: 去干晔府上求一首诗再来"
        )
        parsed = parse_llm_response(ai_response)
        self.assertEqual(parsed["title"], "索诗")
        self.assertIn("failed_hint", parsed.get("_extra", {}))

        # 模拟 enrich_context
        ctx = PluginContext(
            combos=combos,
            cfg=cfg,
            raw_response=ai_response,
            parsed=parsed,
            combined_scale=1.0,
            uuid="test_suoshi",
        )
        extras = plugin.enrich_context(ctx)
        self.assertEqual(extras, {"failed_hint": "去干晔府上求一首诗再来"})

        # 模拟 _build_context_column
        context = _build_context_column(["action:main:baiye"], extras)
        self.assertIn("failed_hint=去干晔府上求一首诗再来", context)


if __name__ == "__main__":
    unittest.main()
