# 事件选项 Affordability 检查 — 功能意图

**状态**: ✅ 已实现

---

## 意图摘要（<200字）

为事件选项（EventBtn）在显示前检查 `choice_result.operators` 的资源可支付性。PropertyOperator 消耗委托 ActionManager.check_archetype_property_costs()，TraitOperator REMOVE 检查 PlayerState.has_trait()。不可支付时灰化按钮 + Toast 原因，与现有 requirement 灰化模式一致。

---

## 核心玩法

- **触发时机**：EventBtn._init_option() 中 requirement 检查通过后
- **PropertyOperator**：val < 0 → 委托 ActionManager.check_archetype_property_costs()（含 modifier 调整 + 精确数值）
- **TraitOperator**：REMOVE → 检查 PlayerState.has_trait(trait_key)，未拥有则灰化
- **正向值 / ADD**：不拦截（溢出在 operate() 自然 capped）
- **灰化行为**：tooltip_text = reason，点击后 modulate=GRAY + Toast
- **多 reason**：「、」拼接

---

## 数据流

```
EventBtn._init_option()
  │
  ├─ requirement.compare() → fail → 灰化（现有逻辑）
  │
  ├─ OptionAffordabilityChecker.check(choice_result.operators)
  │     │
  │     ├─ PropertyOperator(val<0) → ActionManager.check_archetype_property_costs() → reasons
  │     ├─ TraitOperator(REMOVE)    → PlayerState.has_trait() → reason
  │     └─ 其他                     → 跳过
  │
  ├─ can_afford=false → _affordability_reason = "、".join(reasons) → 灰化
  └─ can_afford=true  → 正常注册 + hover + confirmed
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/hints/option_affordability_checker.gd` | **新建** | 核心检查逻辑，输入 operators，输出 {can_afford, reasons} |
| `characters/event_btn.gd` | **修改** | _init_option() 中注入 affordability 检查；disable_btn() 支持 affordability reason；新增 _affordability_reason 字段 |
| `data/1_core_rules/translations/_dynamic_events.csv` | **修改** | 新增 CODE_OPTION_AFFORDABILITY_CHECKER_0 翻译 |

---

## 状态转换

```
[EventBtn 创建] → _init_option()
  │
  ├─ requirement 存在且未通过
  │   → tooltip_text = req.get_failed_hint()
  │   → pressed.connect(disable_btn)
  │   → 点击: modulate=GRAY, Toast=failed_hint
  │
  ├─ requirement 通过或不存在 → affordability 检查
  │   │
  │   ├─ choice_result 无 operators / 全部可支付
  │   │   → 正常注册 + BELOW_OVERLAY hover + confirmed
  │   │
  │   └─ choice_result 有不可支付的 operator
  │       → _affordability_reason = "、".join(reasons)
  │       → tooltip_text = _affordability_reason
  │       → pressed.connect(disable_btn)
  │       → 点击: modulate=GRAY, Toast=_affordability_reason
  │
  └─ 全部通过 → 正常触发 confirmed()
```
