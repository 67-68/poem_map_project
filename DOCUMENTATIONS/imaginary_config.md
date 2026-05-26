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