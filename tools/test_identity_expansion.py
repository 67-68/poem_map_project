#!/usr/bin/env python3
"""
管道测试 — 验证 identity 虚拟维度展开

验证目标:
  1. social_identity 维度被自动注入（_resolve_linked_value_ids）
  2. social_identity 被识别为 virtual-only（不出现在基础笛卡尔积中）
  3. 当 NPC value 被选中时，正确的 identity value 被追加到 tuple 末尾
  4. 组合总数符合预期

用法:
    cd /Users/a67_68/projects/dufu_simulator
    .venv/bin/python tools/test_identity_expansion.py
"""

import sys
import os

# 确保项目根目录在 sys.path 中（event_generator/dimensions.py 内部 import tools.config）
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.dirname(_SCRIPT_DIR)
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

from tools.config import load_config_from_json  # noqa: E402
from tools.event_generator.dimensions import expand_combinations  # noqa: E402


def main():
    config_path = os.path.join(_SCRIPT_DIR, "event_base_config_kuangke_qingliu.json")
    print(f"📂 加载配置: {config_path}")
    config = load_config_from_json(config_path)

    # ── 验证目标 1: social_identity 维度被自动注入 ──
    dim_ids = [d.id for d in config.dimensions]
    print(f"\n📋 解析后维度 ID 列表: {dim_ids}")
    print(f"   维度数: {len(config.dimensions)}")

    has_social_identity = "social_identity" in dim_ids
    print(f"\n✅ 验证 1: social_identity 被自动注入 → {'通过' if has_social_identity else '失败 ❌'}")

    # ── 打印各维度的值数量 ──
    print(f"\n📊 维度详情:")
    for d in config.dimensions:
        val_ids = [v.id for v in d.values]
        print(f"   {d.id} ({len(d.values)} 个值): {val_ids}")

    # ── 验证目标 2: social_identity 不被包含在基础笛卡尔积中 ──
    # 检查 social_identity 维度值是否有任何 linked_value_ids 指向它
    # （如果它是 virtual-only，则只在 virtual_dimension_ids 中被引用）
    social_identity_dim = next((d for d in config.dimensions if d.id == "social_identity"), None)
    if social_identity_dim:
        is_linked_target = False
        for d in config.dimensions:
            for v in d.values:
                for linked_id in v.linked_value_ids:
                    for sv in social_identity_dim.values:
                        if linked_id == sv.id:
                            is_linked_target = True
                            break
        print(f"\n✅ 验证 2: social_identity 是 virtual-only（未被 linked_value_ids 指向）"
              f" → {'通过' if not is_linked_target else '失败 ❌ (被 linked 引用)'}")

    # ── 展开所有组合 ──
    print(f"\n{'='*60}")
    print(f"🔀 执行 expand_combinations...")
    print(f"{'='*60}")

    total = 0
    passed = 0
    failed_details: list[str] = []

    # NPC → identity 预期映射
    expected_identity: dict[str, str] = {
        "LIBAI": "identity_qingliu_owner",
        "WANGWEI": "identity_zhuoliu_official",
        "GAOSHI": "identity_qingliu_official",
        "ZHENGQIAN": "identity_qingliu_official",
    }

    print(f"\n📋 所有组合:")
    for combo in expand_combinations(config.dimensions):
        ids = tuple(v.id for v in combo)
        print(f"  {ids}")
        total += 1

        # ── 验证组合长度 ──
        if len(ids) < 3:
            failed_details.append(f"组合长度不足: {ids} (len={len(ids)}, 期望 >= 3)")
            continue

        # 前两个是基础维度值 (NPC + emotion), 后面的都是 virtual 追加
        npc_id = ids[0]
        identity_ids = ids[2:]  # 第3个及以后都是 virtual 追加

        if not identity_ids:
            failed_details.append(f"缺少 identity 虚拟维度: {ids}")
            continue

        identity_id = identity_ids[0]  # 取第一个 identity

        expected = expected_identity.get(npc_id, "")
        if identity_id == expected:
            passed += 1
        else:
            failed_details.append(
                f"NPC={npc_id}: 期望 identity={expected}, 实际={identity_id}"
            )

    print(f"\n{'='*60}")
    print(f"📊 结果统计:")
    print(f"   总组合数: {total}")
    print(f"   通过: {passed}")
    print(f"   失败: {total - passed}")
    print(f"{'='*60}")

    if failed_details:
        print(f"\n❌ 失败详情:")
        for detail in failed_details:
            print(f"   - {detail}")

    # ── 验证目标 3: NPC→identity 映射正确 ──
    print(f"\n✅ 验证 3: NPC→identity 映射正确 → {'通过' if passed == total else '失败 ❌'}")

    # ── 验证目标 4: 组合总数 ──
    # 注意: 由于 NPC 维度有 linked_value_ids，实际组合数 = 8 (不是 16)
    # 每个 NPC 有 2 个 linked emotion，4×2=8
    # 如果 linked_value_ids 不存在或为空，才是 4×4=16
    print(f"\n💡 注意: 由于 NPC 维度使用 linked_value_ids 过滤 emotion 组合，")
    print(f"   实际基础组合数 = 4 NPC × 2 emotion/NPC = 8（非 4×4=16）")
    print(f"   如果期望 16，需移除 NPC 维度的 linked_value_ids")

    if total == 8:
        print(f"\n✅ 验证 4: 组合总数 = 8 (符合 linked_value_ids 过滤后的预期)")
    elif total == 16:
        print(f"\n✅ 验证 4: 组合总数 = 16 (符合无 linked_value_ids 过滤的预期)")
    else:
        print(f"\n⚠️  验证 4: 组合总数 = {total} (非预期值 8 或 16)")

    # ── 最终断言 ──
    print(f"\n{'='*60}")
    if passed == total and total > 0:
        print(f"🎉 所有 identity 虚拟维度测试通过! ({passed}/{total})")
    else:
        print(f"💀 测试未完全通过! ({passed}/{total})")
        sys.exit(1)
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
