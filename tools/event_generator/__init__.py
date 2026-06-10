"""
tools/event_generator — 正交事件生成管线模块包。

模块边界:
  main.py            入口: argparse + 顶层 for 循环流程控制
  llm_client.py      LLMClient + parse_llm_response + validate_response
  prompts.py         build_system_prompt + build_user_prompt
  dsl_parser.py      纯函数 DSL 缩放器
  io_csv.py          CSV 输出
  state_managers.py  SandboxManager + SlidingBlacklist
  dimensions.py      EXTRACTOR_REGISTRY + expand_combinations + _make_combos
"""
