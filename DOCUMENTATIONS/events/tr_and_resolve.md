# `tr_and_resolve` 翻译 + 动态插值系统

## 概述

`Util.tr_and_resolve()` 是一个静态方法，将 **翻译查表** 和 **模板插值** 串联为一条流水线。

## 规则

```
输入文本
  │
  ├─ 是 CONSTANT（如 CHOOSE_TARGET）？
  │   → TranslationServer.translate() 查表翻译
  │   ↓
  └─ 统一检查结果是否含 {@key}/{key} 占位符
      → 有则 resolve_template 插值
      → 无则直接返回
```

**核心：`tr()` 和插值是串联的两个步骤，非互斥。** 普通文本跳过步骤1，但统一进入步骤2。

### 执行示例

| 输入 | CONSTANT? | tr() 后 | 插值后 |
|------|-----------|---------|--------|
| `CHOOSE_TARGET` | ✅ | `选择 {@target} 作为目标` | `选择 杜甫 作为目标` |
| `前往长安` | ❌ | 跳过 tr() | `前往长安` |
| `给 {@target} 写信` | ❌ | 跳过 tr() | `给 杜甫 写信` |

### CONSTANT 判定

`_is_constant_key()`：**全大写 + 允许下划线和数字**

| 文本 | 判定 |
|------|------|
| `CHOOSE_TARGET` | ✅ CONSTANT |
| `CHOOSE_TARGET_01` | ✅ CONSTANT |
| `前往长安` | ❌ |
| `给 {@target} 写信` | ❌ |
| `ChooseTarget` | ❌ |

## 文件位置

| 文件 | 内容 |
|------|------|
| [`core/util.gd`](../../core/util.gd:422) | `tr_and_resolve()` 和 `_is_constant_key()` 实现 |
| [`model/event/event_option.gd`](../../model/event/event_option.gd:29) | 当前调用方（EventOption.init） |

## 使用场景

### 1. 翻译 key + 带占位符

CSV 配置：

```
Desc
CHOOSE_TARGET
```

翻译表：

```csv
keys,zh_CN
CHOOSE_TARGET,选择 {@target_name} 作为目标
```

运行时：`"CHOOSE_TARGET"` → tr → `"选择 {@target_name} 作为目标"` → resolve → `"选择 杜甫 作为目标"`

### 2. 普通文本（无翻译无插值）

```
Desc
前往长安
```

运行时：非 CONSTANT → 跳过 tr() → 无占位符 → 返回 `"前往长安"`

### 3. 普通文本 + 占位符（无翻译）

```
Desc
给 {@target_name} 写信
```

运行时：非 CONSTANT → 跳过 tr() → 有 `{@target_name}` → resolve → `"给 杜甫 写信"`

## 翻译表配置

在 `.translation` 文件中添加条目：

```csv
keys,zh_CN
CHOOSE_TARGET,选择 {@target_name} 作为目标
CHOOSE_TARGET_NO_PLACEHOLDER,选择杜甫作为目标
```

## 与 `resolve_template` 的关系

| 方法 | 职责 |
|------|------|
| `Util.resolve_template()` | 纯插值：`{@key}` / `{prop}` → 运行时值 |
| `Util.tr_and_resolve()` | 翻译 + 插值串联，内部调 `resolve_template` |

共享占位符语法：

| 占位符 | 来源 | 示例 |
|--------|------|------|
| `{prop}` | 对象属性 | `{description}` → self.description |
| `{@key}` | context 字典 | `{@target_name}` → context["target_name"] |

## 扩展使用

```gdscript
var text = Util.tr_and_resolve(
    raw_text,      # 翻译 key 或普通文本
    context_dict,  # 用于 {@key}
    self           # 用于 {prop}
)
```

## 常见问题

### Q: 为什么不用 `tr()` 而是 `TranslationServer.translate()`？

`Util` 是 `RefCounted`（非 `Node`），静态方法无法调 `Node.tr()`。`TranslationServer.translate()` 是 Godot 单例 API，等效于 `tr()`。

### Q: 为什么逐字符检测全大写，而不是 `text == text.to_upper()`？

`to_upper()` 对中文无影响，会错误地将 `"前往长安"` 判为"全大写"。逐字符只允许 A-Z、_、0-9，准确排除中文和特殊字符。

### Q: 普通文本带占位符能正常工作吗？

能。非 CONSTANT 只是跳过 `tr()`，`resolve_template` 插值依然执行。例如 `"给 {@target} 写信"` 会正确解析为 `"给 杜甫 写信"`。
