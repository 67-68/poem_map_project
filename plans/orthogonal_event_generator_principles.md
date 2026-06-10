# 正交事件生成器 — 核心原则

> **插件变成哑巴渲染器，配置是唯一的上帝。** 😡

---

## 原则 1：配置即代码（CIC）

所有行为规则定义在 JSON 配置中，插件不包含任何业务逻辑字符串。

```json
// ✅ 正确：配置定义规则
"plugins": {
  "failed_hint": {
    "style": "mock_direct_speech",
    "max_chars": 20,
    "context": "NPC 验货后发现没有诗词时的嘲讽反应"
  }
}

// ❌ 错误：插件硬编码字符串
// get_prompt_fragment() 返回 "请用直接引语，20字以内"
```

## 原则 2：插件是哑巴渲染器

插件 = 配置读取器 + Prompt 渲染器 + CSV 注入器。它知道：
- **从哪里读**（`option_features[].plugins[plugin_id]`）
- **渲染到哪里**（`get_prompt_fragment()` → User Prompt）
- **注入到哪里**（`enrich_context()` → CSV context 列）

但它不知道「说什么」——那是配置的事。

```python
# ✅ 正确：从配置读取，动态渲染
def get_prompt_fragment(self, combos, cfg) -> str:
    rule = self._hint_rules.get(opt_id, {})
    return f"控制在{rule['max_chars']}字以内"

# ❌ 错误：硬编码
def get_prompt_fragment(self, combos, cfg) -> str:
    return "控制在20字以内"
```

## 原则 3：每个选项有自己的插件自留地

插件的配置挂载在 `option_features[].plugins[plugin_id]` 下，互不干扰。

```json
{
  "option_features": [
    {
      "id": "option_accept",
      "plugins": {
        "failed_hint": { ... },        // 这是 failed_hint 的自留地
        "emotion_guard": { ... },      // 其他插件的自留地
        "blind_box": { ... }           // 各玩各的
      }
    }
  ]
}
```

**命名空间隔离** — 出了自己的 key 别碰别人的东西。🤓☝️

## 原则 4：Phase 0 初始化，Phase 1-3 消费

```
管线生命周期:
  init(cfg)    → 扫描配置，构建内部状态   (Phase 0)
  ↓
  get_prompt_fragment()  → 读取状态，渲染  (Phase 1)
  get_extra_output_fields() → 声明字段   (Phase 2)
  enrich_context()       → 提取到 CSV   (Phase 3)
```

`init()` 在整个管線中只调用一次，后续 hook 使用其缓存的内部状态。

## 原则 5：不要重复配置

如果 `narrative_constraint.resolution_style` 已经定义了约束语义，插件就不要重新声明——直接从那里读。

```json
{
  "narrative_constraint": {
    "resolution_style": "必须是 NPC 嘲讽反应，使用直接引语"
  },
  "plugins": {
    "failed_hint": {
      // 不需要重复定义 context，插件可以回退到 resolution_style
      "style": "mock_direct_speech",
      "max_chars": 20
    }
  }
}
```

## 测试:
- 使用DOCUMENTATIONS/events/prompt_engineering_principles.md检查配置是否过拟合
- 使用trail随机输出配置