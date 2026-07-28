# 事件选项 Affordability 检查 + 锁定 Hover + 全锁定 Fallback — 功能意图

**状态**: ✅ 已实现

---

## 意图摘要（<200字）

为事件选项在显示前校验 `choice_result.operators` 的资源可支付性。PropertyOperator(val<0) 委托 ActionManager，TraitOperator(REMOVE) 查 PlayerState。锁定按钮仍可 hover 查看效果+原因。若全部选项被锁定，自动追加「仓皇逃跑」fallback（-3天），防止卡死。

---

## 核心玩法

### Affordability 检查（OptionAffordabilityChecker）
- PropertyOperator(val<0)：委托 `ActionManager.check_archetype_property_costs()`（含 modifier 调整 + 精确数值）
- TraitOperator(REMOVE)：检查 `PlayerState.has_trait(trait_key)`
- 正值/ADD/其他：不拦截

### 锁定 Hover（EventBtn._register_locked_hover）
- 向量层顶部追加 `[无法选择]：{原因}`
- 下方正常展示 operator 效果预览
- BELOW_OVERLAY 流注册，与正常 hover 相同

### 全锁定 Fallback（OptionBtns._append_fallback_if_all_locked）
- 检测所有已创建按钮 `disabled == true`
- 合成 `EventOption("仓皇逃跑", TimeOperator(day=3))`
- 始终可选，无 requirement/affordability 拦截

---

## 数据流

```
EventBtn._init_option()
  ├─ requirement.compare() → fail
  │   → _is_locked=true, tooltip_text=failed_hint
  │   → _register_locked_hover(tooltip_text)  ← 🆕
  │   → pressed.connect(disable_btn)
  │
  ├─ OptionAffordabilityChecker.check()
  │   → fail
  │   → _is_locked=true, _affordability_reason=reasons
  │   → _register_locked_hover(_affordability_reason)  ← 🆕
  │   → pressed.connect(disable_btn)
  │
  └─ 全部通过 → _register_event_btn_hover() + confirmed()


OptionBtns.apply_btns()
  ├─ 创建所有 EventBtn
  ├─ _append_fallback_if_all_locked()  ← 🆕
  │     ├─ 任一 btn.disabled==false → 跳过
  │     └─ 全部 disabled → 追加 fallback EventBtn("仓皇逃跑")
  └─ _register_number_keys()
```

---

## 涉及文件

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `core/hints/option_affordability_checker.gd` | **新建** | 核心检查逻辑 |
| `characters/event_btn.gd` | **修改** | + `_is_locked` 字段；+ `_register_locked_hover()`；锁定路径注入 hover；`disable_btn()` 优先使用 affordability reason |
| `ui/option_btns.gd` | **修改** | + `_append_fallback_if_all_locked()`；`apply_btns()` 末尾调用 |
| `data/1_core_rules/translations/_dynamic_events.csv` | **修改** | 新增 3 个翻译 key |

### i18n 新增

| Key | 中文 | English |
|-----|------|---------|
| `CODE_OPTION_AFFORDABILITY_CHECKER_0` | 未拥有「%s」 | Does not have 「%s」 |
| `CODE_EVENT_BTN_LOCKED_PREFIX` | [无法选择]：%s | [Unavailable]: %s |
| `CODE_OPTION_BTNS_FALLBACK_DESCRIPTION` | 仓皇逃跑 | Flee in panic |

---

## 状态转换

```
[EventBtn 创建] → _init_option()
  │
  ├─ requirement 存在且未通过
  │   → _is_locked = true
  │   → tooltip_text = req.get_failed_hint()
  │   → _register_locked_hover(tooltip_text)   ← 🆕 hover 可见
  │   → pressed.connect(disable_btn)
  │   → 点击: modulate=GRAY + disabled=true + Toast
  │
  ├─ affordability 检查失败
  │   → _is_locked = true
  │   → _affordability_reason = "、".join(reasons)
  │   → _register_locked_hover(_affordability_reason)  ← 🆕 hover 可见
  │   → pressed.connect(disable_btn)
  │   → 点击: modulate=GRAY + disabled=true + Toast
  │
  └─ 全部通过 → 正常注册 + hover + confirmed

[OptionBtns 全锁定检测]
  │
  ├─ 存在未锁定按钮 → 正常结束
  └─ 全部 disabled
      → 创建 fallback EventOption("仓皇逃跑")
      → TimeOperator(day=3) → 消耗 3 天时间
      → EventBtn 正常初始化（无 requirement/affordability 拦截）
