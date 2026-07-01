> ⚠️ **本文件已废弃 (2026-07-01)** — 意象系统已全面简化。权威文档请参见 [`plans/imagery_simplification_refactor.md`](../../plans/imagery_simplification_refactor.md)
> 五维宪法 Tag 系统、四段式字符串解析、`detail_imaginaries`、`perceptions` 字段均已删除。

This is used for each event, after they done judge whether if should give a imagenary

// 局部掉落池配置切片 (纯数据，零硬编码逻辑)
[
  {
    "imagery": "actor:health:drunk:poetic_sorrow",
    "requirements": [
      {"stat": "drunk_level", "op": ">=", "val": 30},
      {"stat": "talent", "op": ">=", "val": 80}  // 诗人专属
    ]
  },
  {
    "imagery": "actor:health:drunk:cursing", # 这里的中间两个部分是imaginary_blueprint的，后面的cursing作为context存在
    "requirements": [
      {"stat": "drunk_level", "op": ">=", "val": 30},
      {"stat": "talent", "op": "<", "val": 80}   // 蠢货兜底
    ]
  }
]