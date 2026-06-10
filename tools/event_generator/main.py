#!/usr/bin/env python3
"""
正交事件生成管线 — 融合入口点 (main)

这是重构后的融合入口。用法与原有 generate_orthogonal_events.py 完全一致：

  export DEEPSEEK_API_KEY="sk-xxx"
  python3 -m tools.event_generator.main --config <json_or_py>
  python3 -m tools.event_generator.main --dry-run
  python3 -m tools.event_generator.main --trial

为保持向后兼容，也可通过 tools/generate_orthogonal_events.py 调用（指向此 main）。
"""

import argparse
import csv
import os
import random
import sys
import time
from pathlib import Path
from typing import Optional

# ── 自动将项目根目录加入 sys.path，消除 PYTHONPATH=. 的依赖 ──
_project_root = Path(__file__).resolve().parent.parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

# 🤓☝️ 契约即自由：通过严格的 imports，你能一眼看出 main 函数到底依赖了哪些领域
from tools.config import (
    default_config,
    load_config_from_json,
    EventPipelineConfig,
    DimensionCombo,
    OptionFeature,
)
from tools.plugin_base import (
    PLUGIN_REGISTRY,
    EventPromptPlugin,
    PluginContext,
    resolve_plugins,
)

# 确保插件在 main 启动前注册
import tools.plugins  # noqa: F401

from tools.event_generator.llm_client import LLMClient, parse_llm_response, validate_response
from tools.event_generator.prompts import build_system_prompt, build_user_prompt
from tools.event_generator.io_csv import write_csv_header, write_event_row, write_option_row, _build_option_dsl, _build_option_requirement
from tools.event_generator.state_managers import SandboxManager, SlidingBlacklist
from tools.event_generator.dimensions import expand_combinations, _make_combos
from tools.event_generator.dsl_parser import scale_all_operators


# ════════════════════════════════════════════════════════════════
# Plugin Hook 辅助函数
# ════════════════════════════════════════════════════════════════

def _build_plugin_context_extras(
    plugins: list[EventPromptPlugin],
    combos: list[DimensionCombo],
    cfg: EventPipelineConfig,
    parsed: dict,
    raw_response: str,
    combined_scale: float,
    uuid: str,
) -> dict[str, str]:
    """调用所有插件的 enrich_context() 并合并 context_extras。

    这是 Hook 3 的调度入口。每个插件的 enrich_context() 接收 PluginContext
    （全量管线状态），返回 key=value 对，最终合并为一个 dict 传给 write_event_row。
    """
    extras: dict[str, str] = {}
    ctx = PluginContext(
        combos=combos,
        cfg=cfg,
        raw_response=raw_response,
        parsed=parsed,
        combined_scale=combined_scale,
        uuid=uuid,
    )
    for plugin in plugins:
        try:
            result = plugin.enrich_context(ctx)
            if result:
                extras.update(result)
        except Exception as e:
            print(f"  ⚠️ 插件 '{plugin.plugin_id}'.enrich_context() 异常: {e}")
    return extras


# ════════════════════════════════════════════════════════════════
# 主流程
# ════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="正交事件生成管线")
    parser.add_argument("--config", default=None, help="JSON 配置文件路径（默认使用内置示例配置）")
    parser.add_argument("--output-dir", default=None, help="输出目录（覆盖配置中的路径）")
    parser.add_argument("--dry-run", action="store_true", help="只打印 Prompt，不调 API")
    parser.add_argument("--trial", action="store_true", help="试运行：调1次API，打印所有中间产物，不保存CSV")
    parser.add_argument("--max-events", type=int, default=0, help="最多生成事件数（0=全部）")
    parser.add_argument("--random", action="store_true", help="随机模式: 在 trial 模式下随机选择一个维度组合（而非总是第一个）")
    args = parser.parse_args()

    if args.random and not args.trial:
        print("⚠️  --random 仅在 --trial 模式下生效，已忽略")

    # ── 加载配置 ──
    if args.config:
        cfg = load_config_from_json(args.config)
    else:
        cfg = default_config()

    print(f"📖 配置: {cfg.name}")

    # ── 解析插件 ──
    plugins: list[EventPromptPlugin] = []
    if cfg.plugins:
        try:
            plugins = resolve_plugins(cfg.plugins)
            print(f"🔌 已加载插件: {[p.plugin_id for p in plugins]}")
        except KeyError as e:
            print(f"❌ 插件加载失败: {e}")
            sys.exit(1)

    # ── Phase 0: 插件初始化（扫描配置构建内部状态） ──
    for plugin in plugins:
        plugin.init(cfg)

    # ── 初始化滑动黑名单 ──
    blacklist: Optional[SlidingBlacklist] = None
    try:
        blacklist = SlidingBlacklist.init_from_config(cfg)
        if blacklist is not None:
            print(f"📋 滑动黑名单已启用: "
                  f"维度='{blacklist.dimension.name}', "
                  f"追踪字段='{blacklist.tracked_field}', "
                  f"最大条目={blacklist.max_items}")
    except ValueError as e:
        print(f"❌ 黑名单配置错误: {e}")
        sys.exit(1)

    dim_count = len(cfg.dimensions)
    if dim_count < 1:
        print(f"❌ 配置至少需要 1 个维度，当前有 {dim_count} 个")
        sys.exit(1)

    # ── 展开所有组合（支持 Dynamic Dimension） ──
    combinations = list(expand_combinations(cfg.dimensions))
    dim_value_counts = [
        f"{len(d.values)}" if not d.dynamic else f"({d.value_extractor_key})"
        for d in cfg.dimensions
    ]
    print(f"   组合数: {len(combinations)} ({'×'.join(dim_value_counts)})")

    if args.max_events > 0:
        combinations = combinations[: args.max_events]
        print(f"   限制生成: {len(combinations)} 个")

    # ── 准备输出 ──
    output_dir = args.output_dir or cfg.output_dir
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"{cfg.id}_events.csv")
    print(f"📝 输出: {output_path}")

    # ── 初始化 LLM ──
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        if args.dry_run:
            print("⚠️  未设置 DEEPSEEK_API_KEY（dry-run 跳过）")
        elif args.trial:
            print("⚠️  未设置 DEEPSEEK_API_KEY（trial 模式无法调 API）")
            print("   export DEEPSEEK_API_KEY='sk-xxx'")
            sys.exit(1)
        else:
            print("❌ 请设置环境变量 DEEPSEEK_API_KEY")
            print("   export DEEPSEEK_API_KEY='sk-xxx'")
            sys.exit(1)

    llm = LLMClient(api_key=api_key or "dry-run", model=cfg.api_model)

    # ── 初始化沙盒缓存 ──
    sandbox: Optional[SandboxManager] = None
    # 除非 dry-run，否则初始化沙盒（dry-run 没有 LLM 可用也没有必要）
    if not args.dry_run:
        sandbox = SandboxManager(
            config_path=args.config,
            llm=llm,
            cfg=cfg,
        )
        if sandbox.load():
            print(f"  ✅ 沙盒缓存就绪")
        else:
            print(f"  🏗️  沙盒缓存不存在，自动生成中...")
            sandbox.generate()
        print(f"  📍 沙盒路径: {sandbox.sandbox_path}")

    # 组装 system prompt
    system_prompt = build_system_prompt(cfg)
    print(f"\n📋 System Prompt ({len(system_prompt)} chars):")
    print("-" * 40)
    if args.trial:
        # trial 模式完整打印
        print(system_prompt)
    else:
        print(system_prompt[:600] + "..." if len(system_prompt) > 600 else system_prompt)
    print("-" * 40)

    if args.dry_run:
        print("\n🏁 Dry-run 模式，不会调用 API")
        first_values = combinations[0]
        first_combos = _make_combos(cfg.dimensions, first_values)
        # 沙盒在 dry-run 模式下未初始化，跳过
        sandbox_block = ""
        user_prompt = build_user_prompt(
            first_combos, cfg,
            plugins=plugins, blacklist=blacklist,
            sandbox_keywords_block=sandbox_block,
        )
        print(f"\n📋 示例 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)
        print("\n✅ Dry-run 完成")
        return

    # ════════════════════════════════════════════════════════════════
    # 试运行模式（--trial）
    # ════════════════════════════════════════════════════════════════

    if args.trial:
        print("\n🧪 试运行模式 — 将实际调用 API 1 次，不保存任何文件")

        # 随机或默认选择组合
        if args.random and len(combinations) > 1:
            values_tuple = random.choice(combinations)
            print(f"  🎲 随机模式: 从 {len(combinations)} 个组合中随机选取")
        else:
            values_tuple = combinations[0]
        combined_scale = 1.0
        scale_parts = []
        uuid_parts = [cfg.id]
        for val in values_tuple:
            combined_scale *= val.scale
            scale_parts.append(str(val.scale))
            uuid_parts.append(val.id)
        uuid = "_".join(uuid_parts).lower()

        current_combos = _make_combos(cfg.dimensions, values_tuple)

        print(f"\n📦 组合: {uuid}")
        print(f"  Scale: {'×'.join(scale_parts)} = {combined_scale}")

        # 打印维度详情
        print(f"\n📋 维度详情:")
        for combo in current_combos:
            print(f"  - {combo.dimension.name}: {combo.value.name} ({combo.value.description})")

        # ── 自适应边界收缩状态 ──
        current_min = cfg.word_count_min
        current_max = cfg.word_count_max
        SHRINK_STEP = 20
        MIN_GAP = 10

        sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
        user_prompt = build_user_prompt(
            current_combos, cfg,
            word_count_min=current_min, word_count_max=current_max,
            plugins=plugins,
            blacklist=blacklist,
            sandbox_keywords_block=sandbox_block,
        )
        print(f"\n📋 User Prompt ({len(user_prompt)} chars):")
        print("-" * 40)
        print(user_prompt)
        print("-" * 40)

        # ── API 调用（带重试 + 自适应收缩） ──
        success = False
        skip = False
        for attempt in range(cfg.max_retries + 1):
            if attempt > 0:
                print(f"\n  🔄 重试 {attempt}/{cfg.max_retries}...")
                time.sleep(1)

            try:
                print(f"\n🤖 调用 API ({cfg.api_model})...")
                response = llm.generate_event_text(system_prompt, user_prompt)
            except Exception as e:
                print(f"  ❌ API 调用失败: {e}")
                if attempt < cfg.max_retries:
                    continue
                print(f"  ⏭️ 跳过（已达最大重试次数）")
                skip = True
                break

            # 打印原始响应
            print(f"\n📨 API Raw Response ({len(response)} chars):")
            print("-" * 40)
            print(response)
            print("-" * 40)

            parsed = parse_llm_response(response)
            print(f"\n🔍 Parsed Result:")
            print(f"  title: {parsed['title']!r}")
            print(f"  description: {parsed['description']!r}")
            if parsed.get("options"):
                for k, v in parsed["options"].items():
                    print(f"  option [{k}]: {v!r}")

            error = validate_response(
                parsed, cfg,
                override_min=cfg.word_count_min, override_max=cfg.word_count_max,
            )

            # 🚨 额外校验：插件声明的字段必须在 parsed 中存在且非空
            if error is None and plugins:
                for plugin in plugins:
                    for field in plugin.get_extra_output_fields():
                        val = parsed.get(field, "")
                        if not val:
                            extra = parsed.get("_extra", {})
                            val = extra.get(field, "")
                        if not val or not val.strip():
                            error = f"缺少插件字段 '{field}'（{plugin.plugin_id} 要求）"
                            print(f"  ❌ {error}")
                            break
                    if error:
                        break

            if error is None:
                print(f"\n✅ 校验通过")
                title = parsed["title"]
                description = parsed["description"]

                # ── DSL 缩放 ──
                operator_dsls = [val.operator_dsl for val in values_tuple]
                try:
                    scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
                except ValueError as e:
                    print(f"  ❌ DSL 缩放失败: {e}")
                    break

                print(f"\n⚙️ 缩放后 DSL:")
                if scaled_dsl:
                    print(f"  {scaled_dsl}")
                else:
                    print(f"  (无操作)")

                # ── CSV 预览（使用与 write_event_row 一致的格式化）──
                print(f"\n📄 CSV 预览（不会写入文件）:")

                # ── Hook 3: 插件 context 富化 ──
                context_extras = _build_plugin_context_extras(
                    plugins, current_combos, cfg, parsed, response,
                    combined_scale, uuid,
                )

                # 🚨 从 context_extras 剥离 failed_hint，它只用于 option_req 模板替换
                failed_hint_val = context_extras.pop("failed_hint", "") if context_extras else ""

                if context_extras:
                    print(f"📎 插件 context 富化: {context_extras}")

                # 构建 context 列（与 write_event_row 一致的 tag 格式化）
                tags = cfg.universal_tags or ["bai_ye"]
                if tags:
                    tags_expr = "[" + "/".join(tags) + "]"
                else:
                    tags_expr = ""
                context = f"trigger_tags={tags_expr}|weight=10"
                if context_extras:
                    for k, v in context_extras.items():
                        if v:
                            context += f"|{k}={v}"

                # event 行（实际 CSV 格式）
                requirement_col = cfg.universal_requirement if cfg.universal_requirement else ""
                desc_csv = description.replace('"', '""')  # CSV 双引号转义
                desc_preview = desc_csv[:60] + "..." if len(desc_csv) > 60 else desc_csv
                print(f'  random_event,{uuid},{context},{requirement_col},"{title}","{desc_preview}",,,,,,')

                # ── option 行（per-option result/requirement + 固定选项支持）──
                # 每个选项独立计算 result DSL 和 requirement
                options = parsed.get("options", {})
                if cfg.option_features:
                    for choice in cfg.option_features:
                        # 文本：固定选项用 choice.text，AI 选项用 parsed response（有 fallback）
                        if choice.fixed:
                            opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
                        else:
                            opt_text = options.get(choice.id, "").strip()
                            if not opt_text:
                                opt_text = choice.text if choice.text.strip() else "（确认）"

                        # 结果 DSL：维度开销（按 accept_influence 过滤）+ per-option result
                        opt_dsl = _build_option_dsl(
                            current_combos, choice,
                            universal_result=cfg.universal_result or "",
                        )
                        dsl_csv = opt_dsl.replace('"', '""')

                        # requirement：per-option（或 universal fallback），含模板替换
                        opt_req = _build_option_requirement(
                            choice, failed_hint_val,
                            universal_option_requirement=cfg.universal_option_requirement or "",
                        )
                        req_csv = f'"{opt_req}"' if opt_req else ''

                        print(f'  >option,,,{req_csv},"{opt_text}","{dsl_csv}",,,,')
                else:
                    # 无 option_features 时：用默认选项 + universal fallback
                    dsl_csv = scaled_dsl.replace('"', '""')
                    opt_req = _build_option_requirement(
                        OptionFeature(id="default"),
                        failed_hint_val,
                        universal_option_requirement=cfg.universal_option_requirement or "",
                    )
                    req_csv = f'"{opt_req}"' if opt_req else ''
                    print(f'  >option,,,{req_csv},"（确认）","{dsl_csv}",,,,')

                # ── 更新滑动黑名单 ──
                if blacklist is not None:
                    blacklist.extract_and_update(parsed, current_combos)

                success = True
                break
            else:
                print(f"\n❌ 校验失败: {error}")
                if attempt < cfg.max_retries:
                    # ── 自适应边界收缩 ──
                    old_min, old_max = current_min, current_max
                    if "过短" in error:
                        current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                    elif "过长" in error:
                        current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                    if current_min != old_min or current_max != old_max:
                        print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                        # 重试时 sandbox 重新随机 pick，获得不同的创作种子
                        sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
                        user_prompt = build_user_prompt(
                            current_combos, cfg,
                            word_count_min=current_min, word_count_max=current_max,
                            plugins=plugins,
                            blacklist=blacklist,
                            sandbox_keywords_block=sandbox_block,
                        )
                    continue
                print(f"  ⏭️ 跳过（已达最大重试次数）")
                skip = True
                break

        if success:
            print(f"\n✅ 试运行完成 — API 调用成功，未保存任何文件")
        elif skip:
            print(f"\n⏭️ 试运行完成 — 已跳过，未保存任何文件")
        else:
            print(f"\n⚠️ 试运行完成 — 出现异常，未保存任何文件")
        return

    # ── 执行生成 ──
    success_count = 0
    skip_count = 0
    fail_count = 0

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        write_csv_header(writer)

        for idx, values_tuple in enumerate(combinations):
            # Scale: 所有维度值的 scale 乘积
            combined_scale = 1.0
            scale_parts = []
            uuid_parts = [cfg.id]
            for val in values_tuple:
                combined_scale *= val.scale
                scale_parts.append(str(val.scale))
                uuid_parts.append(val.id)
            uuid = "_".join(uuid_parts).lower()

            # 组装 DimensionCombo 列表
            current_combos = _make_combos(cfg.dimensions, values_tuple)

            print(f"\n[{idx + 1}/{len(combinations)}] {uuid}")
            print(f"  Scale: {'×'.join(scale_parts)} = {combined_scale}")

            # ── 自适应边界收缩状态（每组合独立重置） ──
            current_min = cfg.word_count_min
            current_max = cfg.word_count_max
            SHRINK_STEP = 20
            MIN_GAP = 10

            sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
            user_prompt = build_user_prompt(
                current_combos, cfg,
                word_count_min=current_min, word_count_max=current_max,
                plugins=plugins,
                blacklist=blacklist,
                sandbox_keywords_block=sandbox_block,
            )

            for attempt in range(cfg.max_retries + 1):
                if attempt > 0:
                    print(f"  🔄 重试 {attempt}/{cfg.max_retries}...")
                    time.sleep(1)

                try:
                    response = llm.generate_event_text(system_prompt, user_prompt)
                except Exception as e:
                    print(f"  ❌ API 调用失败: {e}")
                    if attempt < cfg.max_retries:
                        continue
                    print(f"  ⏭️ 跳过（已达最大重试次数）")
                    skip_count += 1
                    break

                parsed = parse_llm_response(response)
                # 🚨 校验始终使用原始字数边界，自适应收缩只影响 AI prompt 中的要求
                error = validate_response(
                    parsed, cfg,
                    override_min=cfg.word_count_min, override_max=cfg.word_count_max,
                )

                # 🚨 额外校验：插件声明的字段必须在 parsed 中存在且非空
                if error is None and plugins:
                    for plugin in plugins:
                        for field in plugin.get_extra_output_fields():
                            val = parsed.get(field, "")
                            if not val:
                                extra = parsed.get("_extra", {})
                                val = extra.get(field, "")
                            if not val or not val.strip():
                                error = f"缺少插件字段 '{field}'（{plugin.plugin_id} 要求）"
                                print(f"  ❌ {error}")
                                break
                        if error:
                            break

                if error is None:
                    title = parsed["title"]
                    description = parsed["description"]
                    print(f"  ✅ title: {title}")
                    print(f"     desc: {description[:60]}...")

                    # ── DSL 缩放：收集所有维度值的 operator_dsl ──
                    operator_dsls = [val.operator_dsl for val in values_tuple]
                    try:
                        scaled_dsl = scale_all_operators(operator_dsls, combined_scale)
                    except ValueError as e:
                        print(f"  ❌ DSL 缩放失败: {e}")
                        fail_count += 1
                        break

                    if scaled_dsl:
                        print(f"     DSL: {scaled_dsl}")
                    else:
                        print(f"     DSL: (无操作)")

                    # ── Hook 3: 插件 context 富化 ──
                    context_extras = _build_plugin_context_extras(
                        plugins, current_combos, cfg, parsed, response,
                        combined_scale, uuid,
                    )

                    # 🚨 从 context_extras 剥离 failed_hint，它只用于 option_req 模板替换
                    failed_hint_val = context_extras.pop("failed_hint", "") if context_extras else ""

                    if context_extras:
                        print(f"     📎 插件 context: {context_extras}")

                    write_event_row(
                        writer, uuid, title, description,
                        tags=cfg.universal_tags, requirement=cfg.universal_requirement,
                        context_extras=context_extras or None,
                    )

                    # ── 写选项行（per-option result/requirement + 固定选项支持）──
                    # 每个选项独立计算 result DSL 和 requirement
                    options = parsed.get("options", {})
                    if cfg.option_features:
                        for choice in cfg.option_features:
                            # 文本：固定选项用 choice.text，AI 选项用 parsed response（有 fallback）
                            if choice.fixed:
                                opt_text = choice.text if choice.text.strip() else "（冷眼旁观）"
                            else:
                                opt_text = options.get(choice.id, "").strip()
                                if not opt_text:
                                    opt_text = choice.text if choice.text.strip() else "（确认）"

                            # 结果 DSL：维度开销（按 accept_influence 过滤）+ per-option result
                            opt_dsl = _build_option_dsl(
                                current_combos, choice,
                                universal_result=cfg.universal_result or "",
                            )

                            # requirement：per-option（或 universal fallback），含模板替换
                            opt_req = _build_option_requirement(
                                choice, failed_hint_val,
                                universal_option_requirement=cfg.universal_option_requirement or "",
                            )

                            write_option_row(writer, opt_text, opt_dsl, requirement=opt_req)
                            print(f"     option [{choice.id}]: {opt_text}")
                    else:
                        # 回退：没有 option_features 时用默认选项 + universal fallback
                        option_text = "（确认）"
                        opt_req = _build_option_requirement(
                            OptionFeature(id="default"),
                            failed_hint_val,
                            universal_option_requirement=cfg.universal_option_requirement or "",
                        )
                        write_option_row(writer, option_text, scaled_dsl, requirement=opt_req)
                        print(f"     option: {option_text}")

                    # ── 更新滑动黑名单 ──
                    if blacklist is not None:
                        blacklist.extract_and_update(parsed, current_combos)

                    success_count += 1
                    break
                else:
                    print(f"  ❌ 验证失败: {error}")
                    if attempt < cfg.max_retries:
                        # ── 自适应边界收缩（阶梯增压）──
                        old_min, old_max = current_min, current_max
                        if "过短" in error:
                            current_min = min(current_min + SHRINK_STEP, current_max - MIN_GAP)
                        elif "过长" in error:
                            current_max = max(current_max - SHRINK_STEP, current_min + MIN_GAP)
                        if current_min != old_min or current_max != old_max:
                            print(f"  📐 自适应收缩: [{old_min}-{old_max}] → [{current_min}-{current_max}]")
                            sandbox_block = sandbox.get_prompt_block(current_combos) if sandbox is not None else ""
                            user_prompt = build_user_prompt(
                                current_combos, cfg,
                                word_count_min=current_min, word_count_max=current_max,
                                plugins=plugins,
                                blacklist=blacklist,
                                sandbox_keywords_block=sandbox_block,
                            )
                        continue
                    print(f"  ⏭️ 跳过（已达最大重试次数）")
                    skip_count += 1
                    break

    print(f"\n{'=' * 40}")
    print(f"📊 生成完成")
    print(f"   成功: {success_count}")
    print(f"   跳过: {skip_count}")
    print(f"   失败: {fail_count}")
    print(f"   输出: {output_path}")
    print(f"{'=' * 40}")


if __name__ == "__main__":
    main()
