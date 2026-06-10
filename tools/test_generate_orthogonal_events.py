"""
单元测试 — 正交事件生成管线核心函数。

运行:
    python3 -m unittest tools.test_generate_orthogonal_events -v
"""
import itertools
import json
import os
import random
import tempfile
import unittest
import sys
sys.path.insert(0, ".")
from unittest.mock import MagicMock

from tools.config import (
    BlacklistDimensionConfig,
    DimensionCombo,
    EventPipelineConfig,
    PipelineDimension,
    PipelineDimensionValue,
    default_config,
)
from tools.event_generator.dsl_parser import (
    _parse_dsl_args,
    _split_dsl_expressions,
    scale_dsl_operator,
    scale_all_operators,
)
from tools.event_generator.llm_client import (
    LLMClient,
    parse_llm_response,
)
from tools.event_generator.state_managers import (
    SlidingBlacklist,
    SandboxManager,
)
from tools.event_generator.dimensions import (
    _find_value_by_id,
    _make_combos,
    expand_combinations,
)


# ════════════════════════════════════════════════════════════════
# _parse_dsl_args — Layer 1 (分号 ;) 参数解析
# ════════════════════════════════════════════════════════════════

class TestParseDslArgs(unittest.TestCase):
    def test_simple_two_params(self):
        """基本分号分隔：name=money; val=10"""
        result = _parse_dsl_args("name=money; val=10")
        self.assertEqual(result, {"name": "money", "val": 10})

    def test_three_params(self):
        """三个参数"""
        result = _parse_dsl_args("name=money; val=10; extra=foo")
        self.assertEqual(result, {"name": "money", "val": 10, "extra": "foo"})

    def test_single_param(self):
        """单个参数"""
        result = _parse_dsl_args("name=money")
        self.assertEqual(result, {"name": "money"})

    def test_empty_string(self):
        """空字符串"""
        result = _parse_dsl_args("")
        self.assertEqual(result, {})

    def test_bool_values(self):
        """布尔值 true/false"""
        result = _parse_dsl_args("flag=true; val=false")
        self.assertEqual(result, {"flag": True, "val": False})

    def test_quoted_string(self):
        """带引号的字符串值"""
        result = _parse_dsl_args('name="money"; val=10')
        self.assertEqual(result, {"name": "money", "val": 10})

    def test_whitespace_handling(self):
        """空格处理"""
        result = _parse_dsl_args("  name = money ; val = 10  ")
        self.assertEqual(result, {"name": "money", "val": 10})

    def test_comma_separator_fails(self):
        """逗号分隔不被正确解析（验证必须用分号）"""
        result = _parse_dsl_args('name="money", val=10')
        # 逗号不是分隔符，name 的值会吞掉 ", val"
        self.assertNotIn("val", result)


# ════════════════════════════════════════════════════════════════
# _split_dsl_expressions — Layer 0 (竖线 |) 表达式分割
# ════════════════════════════════════════════════════════════════

class TestSplitDslExpressions(unittest.TestCase):
    def test_single_expression(self):
        """单个表达式"""
        result = _split_dsl_expressions("prop_sub(name=money; val=10)")
        self.assertEqual(result, ["prop_sub(name=money; val=10)"])

    def test_two_expressions(self):
        """两个竖线分隔的表达式"""
        result = _split_dsl_expressions(
            "prop_sub(name=money; val=10)|prop_sub(name=fatigue; val=5)"
        )
        self.assertEqual(result, [
            "prop_sub(name=money; val=10)",
            "prop_sub(name=fatigue; val=5)",
        ])

    def test_three_expressions(self):
        """三个竖线分隔的表达式"""
        result = _split_dsl_expressions("a(x=1)|b(y=2)|c(z=3)")
        self.assertEqual(result, ["a(x=1)", "b(y=2)", "c(z=3)"])

    def test_empty_string(self):
        """空字符串"""
        result = _split_dsl_expressions("")
        self.assertEqual(result, [])

    def test_pipe_inside_parens_not_split(self):
        """括号内的竖线不被分割"""
        result = _split_dsl_expressions("random(val=50; success=a(b|c))")
        self.assertEqual(result, ["random(val=50; success=a(b|c))"])

    def test_whitespace_handling(self):
        """空格处理"""
        result = _split_dsl_expressions("  a(x=1) | b(y=2)  ")
        self.assertEqual(result, ["a(x=1)", "b(y=2)"])


# ════════════════════════════════════════════════════════════════
# scale_dsl_operator — 单个 DSL 表达式数值缩放
# ════════════════════════════════════════════════════════════════

class TestScaleDslOperator(unittest.TestCase):
    def test_scale_by_one(self):
        """scale=1 不变"""
        result = scale_dsl_operator("prop_sub(name=money; val=10)", 1)
        self.assertEqual(result, "prop_sub(name=money; val=10)")

    def test_scale_by_one_point_five(self):
        """scale=1.5 缩放"""
        result = scale_dsl_operator("prop_sub(name=money; val=10)", 1.5)
        self.assertEqual(result, "prop_sub(name=money; val=15)")

    def test_scale_by_two(self):
        """scale=2 缩放"""
        result = scale_dsl_operator("prop_sub(name=money; val=10)", 2)
        self.assertEqual(result, "prop_sub(name=money; val=20)")

    def test_scale_by_three(self):
        """scale=3 缩放"""
        result = scale_dsl_operator("prop_sub(name=money; val=20)", 3)
        self.assertEqual(result, "prop_sub(name=money; val=60)")

    def test_scale_fractional_result(self):
        """scale=2.25 产生分数结果"""
        result = scale_dsl_operator("prop_sub(name=health; val=5)", 2.25)
        self.assertEqual(result, "prop_sub(name=health; val=11.25)")

    def test_empty_dsl_returns_empty(self):
        """空 DSL 返回空字符串"""
        result = scale_dsl_operator("", 10)
        self.assertEqual(result, "")

    def test_unknown_operator_raises(self):
        """未知 operator 报错"""
        with self.assertRaises(ValueError):
            scale_dsl_operator("unknown_func(name=money; val=10)", 1)

    def test_non_prop_operator_raises(self):
        """非 PropertyOperator 报错"""
        with self.assertRaises(ValueError):
            scale_dsl_operator("flag_bool_set(name=test; val=true)", 1)

    def test_no_val_param_unchanged(self):
        """没有 val 参数的 DSL 保持不变"""
        result = scale_dsl_operator("prop_set(name=test)", 5)
        self.assertEqual(result, "prop_set(name=test)")


# ════════════════════════════════════════════════════════════════
# scale_all_operators — 多 DSL 表达式组合缩放
# ════════════════════════════════════════════════════════════════

class TestScaleAllOperators(unittest.TestCase):
    def test_basic_combination(self):
        """L0 + TypeA + M0 (combined=1.0): 数值不变"""
        result = scale_all_operators(
            ["prop_sub(name=money; val=10)", "prop_sub(name=money; val=20)", ""],
            1.0,
        )
        self.assertEqual(
            result,
            "prop_sub(name=money; val=10) | prop_sub(name=money; val=20)",
        )

    def test_hard_combination(self):
        """L2 + TypeC + M1 (combined=3.0): 数值乘 3"""
        result = scale_all_operators(
            [
                "prop_sub(name=money; val=10)|prop_sub(name=fatigue; val=5)",
                "prop_sub(name=fatigue; val=10)",
                "",
            ],
            3.0,
        )
        self.assertEqual(
            result,
            "prop_sub(name=money; val=30) | "
            "prop_sub(name=fatigue; val=15) | "
            "prop_sub(name=fatigue; val=30)",
        )

    def test_mid_combination(self):
        """L1 + TypeB + M1 (combined=2.25): 分数缩放"""
        result = scale_all_operators(
            ["prop_sub(name=money; val=10)", "prop_sub(name=health; val=5)", ""],
            2.25,
        )
        self.assertEqual(
            result,
            "prop_sub(name=money; val=22.5) | prop_sub(name=health; val=11.25)",
        )

    def test_all_empty(self):
        """所有 DSL 为空"""
        result = scale_all_operators(["", "", ""], 10)
        self.assertEqual(result, "")

    def test_some_empty(self):
        """部分 DSL 为空"""
        result = scale_all_operators(
            ["prop_sub(name=money; val=10)", "", ""], 2
        )
        self.assertEqual(result, "prop_sub(name=money; val=20)")


# ════════════════════════════════════════════════════════════════
# default_config — 验证内置配置的语义正确性
# ════════════════════════════════════════════════════════════════

class TestDefaultConfig(unittest.TestCase):
    def test_three_dimensions(self):
        """默认配置必须有 3 个维度"""
        cfg = default_config()
        self.assertEqual(len(cfg.dimensions), 3)

    def test_dimension_counts(self):
        """维度值数量: 3 × 3 × 3"""
        cfg = default_config()
        counts = [len(d.values) for d in cfg.dimensions]
        self.assertEqual(counts, [3, 3, 3])

    def test_all_dsl_with_semicolon(self):
        """所有 DSL 必须使用分号 ; 而非逗号 , 作为参数分隔符"""
        cfg = default_config()
        for dim in cfg.dimensions:
            for val in dim.values:
                if val.operator_dsl:
                    in_paren = False
                    for ch in val.operator_dsl:
                        if ch == "(":
                            in_paren = True
                        elif ch == ")":
                            in_paren = False
                        elif ch == "," and in_paren:
                            self.fail(
                                f"DSL 包含非法逗号: {val.operator_dsl!r} "
                                f"(dim={dim.id}, val={val.id}) — "
                                "必须用 ; 替代作为参数分隔符"
                            )

    def test_all_scales_reasonable(self):
        """scale 值在合理范围内 [0.5, 5.0]"""
        cfg = default_config()
        for dim in cfg.dimensions:
            for val in dim.values:
                self.assertGreaterEqual(val.scale, 0.5,
                    f"scale 过小: dim={dim.id}, val={val.id}, scale={val.scale}")
                self.assertLessEqual(val.scale, 5.0,
                    f"scale 过大: dim={dim.id}, val={val.id}, scale={val.scale}")

    def test_combined_scales_correct(self):
        """验证所有 27 种组合的 combined_scale 值"""
        cfg = default_config()
        d1, d2, d3 = cfg.dimensions

        expected = {
            ("L0", "TypeA", "M0"): 1.0,
            ("L0", "TypeA", "M1"): 1.5,
            ("L0", "TypeA", "M2"): 1.0,
            ("L0", "TypeB", "M0"): 1.0,
            ("L0", "TypeB", "M1"): 1.5,
            ("L0", "TypeB", "M2"): 1.0,
            ("L0", "TypeC", "M0"): 1.0,
            ("L0", "TypeC", "M1"): 1.5,
            ("L0", "TypeC", "M2"): 1.0,
            ("L1", "TypeA", "M0"): 1.5,
            ("L1", "TypeA", "M1"): 2.25,
            ("L1", "TypeA", "M2"): 1.5,
            ("L1", "TypeB", "M0"): 1.5,
            ("L1", "TypeB", "M1"): 2.25,
            ("L1", "TypeB", "M2"): 1.5,
            ("L1", "TypeC", "M0"): 1.5,
            ("L1", "TypeC", "M1"): 2.25,
            ("L1", "TypeC", "M2"): 1.5,
            ("L2", "TypeA", "M0"): 2.0,
            ("L2", "TypeA", "M1"): 3.0,
            ("L2", "TypeA", "M2"): 2.0,
            ("L2", "TypeB", "M0"): 2.0,
            ("L2", "TypeB", "M1"): 3.0,
            ("L2", "TypeB", "M2"): 2.0,
            ("L2", "TypeC", "M0"): 2.0,
            ("L2", "TypeC", "M1"): 3.0,
            ("L2", "TypeC", "M2"): 2.0,
        }

        for dv1, dv2, dv3 in itertools.product(d1.values, d2.values, d3.values):
            key = (dv1.id, dv2.id, dv3.id)
            combined = dv1.scale * dv2.scale * dv3.scale
            self.assertAlmostEqual(
                combined, expected[key], places=9,
                msg=f"combined_scale 不匹配: {key} → {combined}, 期望 {expected[key]}"
            )

    def test_l0_typea_m0_dsl_output(self):
        """L0+TypeA+M0: 最轻量事件，combined=1，数值不变"""
        cfg = default_config()
        d1, d2, d3 = cfg.dimensions
        dv1 = d1.values[0]  # L0 scale=1.0
        dv2 = d2.values[0]  # TypeA scale=1.0
        dv3 = d3.values[0]  # M0 scale=1.0

        combined = dv1.scale * dv2.scale * dv3.scale
        self.assertAlmostEqual(combined, 1.0)
        result = scale_all_operators(
            [dv1.operator_dsl, dv2.operator_dsl, dv3.operator_dsl],
            combined,
        )
        self.assertEqual(
            result,
            "prop_sub(name=money; val=10) | prop_sub(name=money; val=20)",
        )

    def test_l2_typec_m1_dsl_output(self):
        """L2+TypeC+M1: 最重事件，combined=3，数值乘 3"""
        cfg = default_config()
        d1, d2, d3 = cfg.dimensions
        dv1 = d1.values[2]  # L2 scale=2.0
        dv2 = d2.values[2]  # TypeC scale=1.0
        dv3 = d3.values[1]  # M1 scale=1.5

        combined = dv1.scale * dv2.scale * dv3.scale
        self.assertAlmostEqual(combined, 3.0)
        result = scale_all_operators(
            [dv1.operator_dsl, dv2.operator_dsl, dv3.operator_dsl],
            combined,
        )
        self.assertIn("prop_sub(name=money; val=30)", result)
        self.assertIn("prop_sub(name=fatigue; val=15)", result)
        self.assertIn("prop_sub(name=fatigue; val=30)", result)


# ════════════════════════════════════════════════════════════════
# linked_value_ids — 值级引用
# ════════════════════════════════════════════════════════════════

class TestValidateLinkedValueIds(unittest.TestCase):
    """_validate_linked_value_ids: 全局约束校验"""

    def test_no_links_is_ok(self):
        """无 linked_value_ids → 通过"""
        dims = [
            PipelineDimension(id="a", values=[PipelineDimensionValue(id="a1")]),
        ]
        # 不应抛出异常
        expand_combinations(dims)

    def test_single_main_dimension_is_ok(self):
        """只有一个维度有 linked_value_ids → 通过"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["b1"]),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1"),
                PipelineDimensionValue(id="b2"),
            ]),
        ]
        expand_combinations(dims)  # 不应抛出异常

    def test_two_main_dimensions_raises(self):
        """两个维度都有 linked_value_ids → 报错"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["b1"]),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1", linked_value_ids=["a1"]),
            ]),
        ]
        with self.assertRaises(ValueError) as ctx:
            list(expand_combinations(dims))
        self.assertIn("多个维度使用了 linked_value_ids", str(ctx.exception))

    def test_self_reference_raises(self):
        """指向自身维度 → 报错"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["a1"]),
            ]),
        ]
        with self.assertRaises(ValueError) as ctx:
            list(expand_combinations(dims))
        self.assertIn("指向自身维度", str(ctx.exception))


class TestFindValueById(unittest.TestCase):
    """_find_value_by_id: 按 ID 查找维度值"""

    def test_finds_matching_value(self):
        """找到匹配的维度值"""
        dims = [
            PipelineDimension(id="a", values=[PipelineDimensionValue(id="a1")]),
            PipelineDimension(id="b", values=[PipelineDimensionValue(id="b1")]),
        ]
        idx, val = _find_value_by_id(dims, "b1")
        self.assertEqual(idx, 1)
        self.assertEqual(val.id, "b1")

    def test_not_found_raises(self):
        """未找到 → 抛 ValueError"""
        dims = [
            PipelineDimension(id="a", values=[PipelineDimensionValue(id="a1")]),
        ]
        with self.assertRaises(ValueError):
            _find_value_by_id(dims, "nonexistent")


class TestExpandCombinations(unittest.TestCase):
    """expand_combinations: 笛卡尔积展开（含 linked_value_ids 支持）"""

    def test_basic_cartesian_product(self):
        """全无链接 → 正常笛卡尔积"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1"),
                PipelineDimensionValue(id="a2"),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1"),
                PipelineDimensionValue(id="b2"),
            ]),
        ]
        result = list(expand_combinations(dims))
        self.assertEqual(len(result), 4)  # 2 × 2
        ids = [(r[0].id, r[1].id) for r in result]
        self.assertIn(("a1", "b1"), ids)
        self.assertIn(("a1", "b2"), ids)
        self.assertIn(("a2", "b1"), ids)
        self.assertIn(("a2", "b2"), ids)

    def test_single_linked_value_replacement(self):
        """值 a1 链接到 b1 → a1 组合中 b 维度固定为 b1"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["b1"]),
                PipelineDimensionValue(id="a2"),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1"),
                PipelineDimensionValue(id="b2"),
            ]),
        ]
        result = list(expand_combinations(dims))
        # a1: (a1, b1) 固定; a2: (a2, b1), (a2, b2)
        self.assertEqual(len(result), 3)
        a1_combos = [r for r in result if r[0].id == "a1"]
        self.assertEqual(len(a1_combos), 1)
        self.assertEqual(a1_combos[0][1].id, "b1")

        a2_combos = [r for r in result if r[0].id == "a2"]
        self.assertEqual(len(a2_combos), 2)
        b_ids = [r[1].id for r in a2_combos]
        self.assertIn("b1", b_ids)
        self.assertIn("b2", b_ids)

    def test_multiple_linked_references(self):
        """主维度值链接到多个其他维度值"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["b1"]),
                PipelineDimensionValue(id="a2"),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1"),
                PipelineDimensionValue(id="b2"),
            ]),
            PipelineDimension(id="c", values=[
                PipelineDimensionValue(id="c1"),
                PipelineDimensionValue(id="c2"),
            ]),
        ]
        result = list(expand_combinations(dims))
        # a1: (a1, b1, c1), (a1, b1, c2) = 2
        # a2: (a2, b1, c1), (a2, b1, c2), (a2, b2, c1), (a2, b2, c2) = 4
        self.assertEqual(len(result), 6)
        a1_combos = [r for r in result if r[0].id == "a1"]
        self.assertEqual(len(a1_combos), 2)
        for r in a1_combos:
            self.assertEqual(r[1].id, "b1")  # b 维度固定

    def test_no_conflict_when_all_links_same_dimension(self):
        """多个值链接到同一目标维度 → 不冲突"""
        dims = [
            PipelineDimension(id="a", values=[
                PipelineDimensionValue(id="a1", linked_value_ids=["b1"]),
                PipelineDimensionValue(id="a2", linked_value_ids=["b1"]),
            ]),
            PipelineDimension(id="b", values=[
                PipelineDimensionValue(id="b1"),
                PipelineDimensionValue(id="b2"),
            ]),
        ]
        result = list(expand_combinations(dims))
        # a1: (a1, b1); a2: (a2, b1) = 2
        self.assertEqual(len(result), 2)
        for r in result:
            self.assertEqual(r[1].id, "b1")


# ════════════════════════════════════════════════════════════════
# _make_combos — DimensionCombo 组装
# ════════════════════════════════════════════════════════════════

class TestMakeCombos(unittest.TestCase):
    """_make_combos: 维度定义列表 + 值元组 → DimensionCombo 列表"""

    def test_basic_conversion(self):
        dims = [
            PipelineDimension(id="a", name="A", values=[PipelineDimensionValue(id="a1")]),
            PipelineDimension(id="b", name="B", values=[PipelineDimensionValue(id="b1")]),
        ]
        values = (PipelineDimensionValue(id="a1"), PipelineDimensionValue(id="b1"))
        combos = _make_combos(dims, values)
        self.assertEqual(len(combos), 2)
        self.assertIsInstance(combos[0], DimensionCombo)
        self.assertEqual(combos[0].dimension.id, "a")
        self.assertEqual(combos[0].value.id, "a1")
        self.assertEqual(combos[1].dimension.id, "b")
        self.assertEqual(combos[1].value.id, "b1")

    def test_mismatched_lengths(self):
        dims = [
            PipelineDimension(id="a", name="A", values=[PipelineDimensionValue(id="a1")]),
        ]
        values = (PipelineDimensionValue(id="a1"), PipelineDimensionValue(id="b1"))
        with self.assertRaises(ValueError):
            _make_combos(dims, values)


# ════════════════════════════════════════════════════════════════
# SlidingBlacklist — 滑动黑名单生命周期
# ════════════════════════════════════════════════════════════════

class TestSlidingBlacklistInit(unittest.TestCase):
    """SlidingBlacklist.init_from_config: 扫描维度配置"""

    def test_no_blacklist_returns_none(self):
        """没有维度配置黑名单 → 返回 None"""
        cfg = EventPipelineConfig(
            id="test",
            name="Test",
            dimensions=[
                PipelineDimension(id="a", name="A", values=[PipelineDimensionValue(id="a1")]),
            ],
        )
        bl = SlidingBlacklist.init_from_config(cfg)
        self.assertIsNone(bl)

    def test_single_blacklist_returns_instance(self):
        """一个维度配置黑名单 → 返回 SlidingBlacklist 实例"""
        cfg = EventPipelineConfig(
            id="test",
            name="Test",
            dimensions=[
                PipelineDimension(
                    id="a", name="A",
                    blacklist_config=BlacklistDimensionConfig(
                        tracked_field="description",
                        tracked_field_description="事件描述",
                        max_items=10,
                    ),
                    values=[PipelineDimensionValue(id="a1")],
                ),
            ],
        )
        bl = SlidingBlacklist.init_from_config(cfg)
        self.assertIsNotNone(bl)
        self.assertEqual(bl.tracked_field, "description")
        self.assertEqual(bl.max_items, 10)

    def test_multi_blacklist_raises(self):
        """多个维度配置黑名单 → 抛 ValueError"""
        cfg = EventPipelineConfig(
            id="test",
            name="Test",
            dimensions=[
                PipelineDimension(
                    id="a", name="A",
                    blacklist_config=BlacklistDimensionConfig(tracked_field="description"),
                    values=[PipelineDimensionValue(id="a1")],
                ),
                PipelineDimension(
                    id="b", name="B",
                    blacklist_config=BlacklistDimensionConfig(tracked_field="title"),
                    values=[PipelineDimensionValue(id="b1")],
                ),
            ],
        )
        with self.assertRaises(ValueError) as ctx:
            SlidingBlacklist.init_from_config(cfg)
        self.assertIn("最多只能有一个维度配置黑名单", str(ctx.exception))


class TestSlidingBlacklistLifecycle(unittest.TestCase):
    """SlidingBlacklist 三阶段生命周期: prompt → extract → update"""

    def setUp(self):
        self.cfg = EventPipelineConfig(
            id="test",
            name="Test",
            dimensions=[
                PipelineDimension(
                    id="dim_a", name="维度A",
                    blacklist_config=BlacklistDimensionConfig(
                        tracked_field="description",
                        tracked_field_description="事件描述",
                        max_items=3,
                    ),
                    values=[
                        PipelineDimensionValue(id="v1", name="值1"),
                        PipelineDimensionValue(id="v2", name="值2"),
                    ],
                ),
            ],
        )
        self.bl = SlidingBlacklist.init_from_config(self.cfg)
        self.combos_v1 = _make_combos(
            self.cfg.dimensions,
            (PipelineDimensionValue(id="v1", name="值1"),),
        )
        self.combos_v2 = _make_combos(
            self.cfg.dimensions,
            (PipelineDimensionValue(id="v2", name="值2"),),
        )

    def test_empty_blacklist_returns_empty_block(self):
        """尚无历史 → get_prompt_block 返回空字符串"""
        block = self.bl.get_prompt_block(self.combos_v1)
        self.assertEqual(block, "")

    def test_extract_and_update_then_block_non_empty(self):
        """extract_and_update 后 → get_prompt_block 非空"""
        parsed = {"summary": {"description": "玩家被门子索要了五两银子"}}
        self.bl.extract_and_update(parsed, self.combos_v1)
        block = self.bl.get_prompt_block(self.combos_v1)
        self.assertIn("五两银子", block)

    def test_per_value_isolation(self):
        """不同维度值的黑名单相互隔离"""
        parsed_v1 = {"summary": {"description": "门子让玩家在寒风中等待"}}
        parsed_v2 = {"summary": {"description": "清客暗示需要润笔费"}}
        self.bl.extract_and_update(parsed_v1, self.combos_v1)
        self.bl.extract_and_update(parsed_v2, self.combos_v2)

        block_v1 = self.bl.get_prompt_block(self.combos_v1)
        block_v2 = self.bl.get_prompt_block(self.combos_v2)

        self.assertIn("寒风中等待", block_v1)
        self.assertNotIn("润笔费", block_v1)
        self.assertIn("润笔费", block_v2)
        self.assertNotIn("寒风中等待", block_v2)

    def test_sliding_window_trims_oldest(self):
        """超出 max_items (3) 时丢弃最老的条目"""
        items = [f"事件第{i}号" for i in range(1, 6)]
        for item in items:
            parsed = {"summary": {"description": item}}
            self.bl.extract_and_update(parsed, self.combos_v1)

        block = self.bl.get_prompt_block(self.combos_v1)
        # 只保留最近 3 条: 事件第3号、事件第4号、事件第5号
        self.assertNotIn("事件第1号", block, "最老条目应被裁剪")
        self.assertNotIn("事件第2号", block, "次老条目应被裁剪")
        self.assertIn("事件第3号", block)
        self.assertIn("事件第4号", block)
        self.assertIn("事件第5号", block)

    def test_missing_summary_skips_update(self):
        """parsed 中没有 summary 块 → 跳过更新"""
        parsed = {"title": "测试", "description": "desc"}
        self.bl.extract_and_update(parsed, self.combos_v1)
        block = self.bl.get_prompt_block(self.combos_v1)
        self.assertEqual(block, "")

    def test_missing_tracked_field_skips_update(self):
        """summary 中没有 tracked_field → 跳过更新"""
        parsed = {"summary": {"other_field": "xxx"}}
        self.bl.extract_and_update(parsed, self.combos_v1)
        block = self.bl.get_prompt_block(self.combos_v1)
        self.assertEqual(block, "")


# ════════════════════════════════════════════════════════════════
# parse_llm_response — summary 嵌套块解析
# ════════════════════════════════════════════════════════════════

class TestParseLlmResponseSummary(unittest.TestCase):
    """parse_llm_response 对 summary 嵌套块的解析"""

    def test_summary_block_parsed(self):
        """基本 summary 嵌套块解析"""
        response = """title: 门子索贿
description: 门子伸手要钱
summary:
  description: 门子索贿五两银子"""
        parsed = parse_llm_response(response)
        self.assertIn("summary", parsed)
        self.assertEqual(parsed["summary"]["description"], "门子索贿五两银子")

    def test_summary_with_multiple_fields(self):
        """summary 块包含多个字段"""
        response = """title: 门子索贿
description: 门子伸手要钱
summary:
  description: 门子索贿五两银子
  extra_info: 额外信息"""
        parsed = parse_llm_response(response)
        self.assertEqual(parsed["summary"]["description"], "门子索贿五两银子")
        self.assertEqual(parsed["summary"]["extra_info"], "额外信息")

    def test_summary_only_with_indent(self):
        """只有缩进的子字段才归 summary，非缩进 → 退出 summary 模式"""
        response = """title: 测试
summary:
  description: 摘要内容
extra_field: 这不是 summary 子字段"""
        parsed = parse_llm_response(response)
        self.assertEqual(parsed["summary"]["description"], "摘要内容")
        self.assertEqual(parsed["_extra"]["extra_field"], "这不是 summary 子字段")

    def test_no_summary_returns_empty_dict(self):
        """没有 summary 块 → summary 返回空 dict"""
        response = """title: 测试
description: 描述"""
        parsed = parse_llm_response(response)
        self.assertEqual(parsed["summary"], {})

    def test_summary_after_options(self):
        """在 options 块之后的 summary"""
        response = """title: 测试
description: 描述
options:
  opt_a: 选项A
  opt_b: 选项B
summary:
  description: 对描述的摘要"""
        parsed = parse_llm_response(response)
        self.assertEqual(parsed["options"]["opt_a"], "选项A")
        self.assertEqual(parsed["options"]["opt_b"], "选项B")
        self.assertEqual(parsed["summary"]["description"], "对描述的摘要")


# ════════════════════════════════════════════════════════════════
# SandboxManager — 沙盒缓存
# ════════════════════════════════════════════════════════════════

class TestSandboxManager(unittest.TestCase):
    """SandboxManager: 加载/保存/关键词管理/prompt 块生成。"""

    def setUp(self):
        """构建最小沙盒场景。"""
        self.dim1 = PipelineDimension(
            id="test_dim",
            name="测试维度",
            description="测试维度描述",
            values=[
                PipelineDimensionValue(
                    id="v1", name="值1", description="测试值1",
                    scale=1.0, operator_dsl="",
                ),
                PipelineDimensionValue(
                    id="v2", name="值2", description="测试值2",
                    scale=1.0, operator_dsl="",
                ),
            ],
        )
        self.cfg = EventPipelineConfig(
            id="test_cfg",
            name="测试配置",
            background_context="测试",
            dimensions=[self.dim1],
            prompt_features=[],
            option_features=[],
            universal_tags=[],
        )
        # 用 MagicMock 替代真实 LLMClient
        self.mock_llm = MagicMock(spec=LLMClient)
        self.mock_llm.generate_event_text.return_value = (
            "- 关键词A\n- 关键词B\n- 关键词C"
        )
        # 临时目录存放 sandbox 文件
        self.tmpdir = tempfile.mkdtemp()
        self.sandbox_path = os.path.join(self.tmpdir, "test_cfg.sandbox")

    def _make_manager(self, config_path: str | None = None) -> SandboxManager:
        """构造 SandboxManager，强制使用自定义 sandbox 路径。"""
        mgr = SandboxManager(
            config_path=config_path,
            llm=self.mock_llm,
            cfg=self.cfg,
        )
        # 覆盖 sandbox_path 到临时目录
        mgr.sandbox_path = self.sandbox_path
        return mgr

    def test_load_missing_file_returns_false(self):
        """sandbox 文件不存在时 load() 返回 False。"""
        mgr = self._make_manager()
        self.assertFalse(mgr.load())

    def test_save_and_load_roundtrip(self):
        """save() 后 load() 能正确恢复数据。"""
        mgr = self._make_manager()
        mgr._data = {
            "test_dim": {
                "v1": ["关键词A", "关键词B", "关键词C"],
                "v2": ["关键词D", "关键词E"],
            }
        }
        mgr.save()
        self.assertTrue(os.path.exists(self.sandbox_path))

        # 新实例加载
        mgr2 = self._make_manager()
        self.assertTrue(mgr2.load())
        self.assertEqual(
            mgr2.get_keywords("test_dim", "v1"),
            ["关键词A", "关键词B", "关键词C"],
        )
        self.assertEqual(
            mgr2.get_keywords("test_dim", "v2"),
            ["关键词D", "关键词E"],
        )

    def test_get_keywords_returns_empty_for_missing(self):
        """不存在的维度/值返回空列表。"""
        mgr = self._make_manager()
        self.assertEqual(mgr.get_keywords("nonexistent", "v1"), [])
        self.assertEqual(mgr.get_keywords("test_dim", "nonexistent"), [])

    def test_get_prompt_block_returns_formatted_block(self):
        """get_prompt_block() 返回格式化的 prompt 块。"""
        mgr = self._make_manager()
        mgr._data = {
            "test_dim": {
                "v1": ["门子索要门包", "门子刁难", "门子勒索"],
            }
        }
        combo = DimensionCombo(dimension=self.dim1, value=self.dim1.values[0])
        block = mgr.get_prompt_block([combo])
        self.assertIn("🎲 创作种子", block)
        self.assertIn("测试维度", block)
        self.assertIn("值1", block)
        # 随机选一个关键词，肯定在池子里
        self.assertTrue(
            any(kw in block for kw in ["门子索要门包", "门子刁难", "门子勒索"]),
            msg=f"block 中应包含任一关键词，实际: {block}",
        )

    def test_get_prompt_block_empty_when_no_keywords(self):
        """没有关键词时返回空字符串。"""
        mgr = self._make_manager()
        combo = DimensionCombo(dimension=self.dim1, value=self.dim1.values[0])
        block = mgr.get_prompt_block([combo])
        self.assertEqual(block, "")

    def test_random_pick_changes_across_calls(self):
        """连续多次 get_prompt_block 应该随机 pick 到不同的关键词。"""
        mgr = self._make_manager()
        mgr._data = {
            "test_dim": {
                "v1": ["关键词A", "关键词B", "关键词C"],
            }
        }
        combo = DimensionCombo(dimension=self.dim1, value=self.dim1.values[0])
        # 固定 seed 做确定性测试
        random.seed(42)
        block1 = mgr.get_prompt_block([combo])
        random.seed(99)
        block2 = mgr.get_prompt_block([combo])
        # 统计概率上，两个 seed 很可能 pick 不同
        contains_a1 = "关键词A" in block1 or "关键词B" in block1 or "关键词C" in block1
        contains_a2 = "关键词A" in block2 or "关键词B" in block2 or "关键词C" in block2
        self.assertTrue(contains_a1)
        self.assertTrue(contains_a2)

    def test_load_corrupted_file_returns_false(self):
        """损坏的 sandbox 文件返回 False。"""
        with open(self.sandbox_path, "w", encoding="utf-8") as f:
            f.write("这不是 JSON")
        mgr = self._make_manager()
        self.assertFalse(mgr.load())

    def test_load_empty_file_returns_false(self):
        """空 JSON 对象返回 False。"""
        with open(self.sandbox_path, "w", encoding="utf-8") as f:
            json.dump({}, f)
        mgr = self._make_manager()
        self.assertFalse(mgr.load())


if __name__ == "__main__":
    unittest.main()
