# 飞花令 / 行酒令 — 功能意图

**状态**: ✅ 已实现（2025.05.31）

---

## 意图摘要（<200字）

飞花令是一个**一圈定胜负的资源转换型 mini-game**。系统随机出一个关键字（如"月"），NPC 在后台根据才气自动结算胜负并生成战报文本；轮到玩家时，提供三种选项：消耗带对应标签的意象卡完美作答（得大量名望+稀有意象）、消耗灵感硬接（得少量名望）、或罚酒（加醉意掉面子）。整个过程只有一个单体事件 + Provider 动态生成选项，用完即弃，不堆叠事件栈。

---

## 核心玩法

- **一键开局**: 从固定字库（风花雪月剑酒等 12 个高频字）随机抽取主题关键字
- **NPC 预结算**: 参与者根据才气(TALENT)属性做 RNG，成功/失败在 `on_enter` 阶段算完，生成一段连续战报文本（"李白出口成章，高适支支吾吾自罚一杯。所有人的目光转向了你"）
- **玩家三选一**:
  - 消耗带关键字标签的意象 → 大量名望 + 稀有意象
  - 消耗灵感(≥20)硬接 → 少量名望
  - 自罚 → 加醉意，掉面子
- **一圈结束**: 根据当前人数多少生成战报，玩家收尾，事件弹出，不循环

诗词库以及字来源从灵感转换来，具体是什么灵感在@source_of_truth中硬编码指定

---

## 已实现架构

### 事件链（3 事件 1 provider）

```
feihualing_start  →  (player picks keyword)  →  feihualing_choose_word
                                                    ↓
                                              feihualing_other_done
                                              (NPC auto-settle + report)
                                                    ↓
                                              provider 3 options
                                              (意象/灵感/罚酒)
```

| 事件 | 角色 | DSL 入口 |
|------|------|----------|
| `feihualing_start` | 展示背景规则 + 让玩家选字 | [`random_events.csv`](/data/random_events/random_events.csv:10) |
| `feihualing_choose_word` | 玩家确认关键字 | [`random_events.csv`](/data/random_events/random_events.csv:12) |
| `feihualing_other_done` | NPC 结算 + 报告生成 | [`feihualing_other_done.tres`](/data/random_events/feihualing_other_done.tres:1) |

### NPC 结算流程

`feihualing_other_done` 的 `on_enter` 执行两个 DSL 步骤：

1. **`context_fetch`** — 通过 [`ContextFetchOperators`](/core/operators/context_fetch_operators.gd:1) 查询玩家选的意象描述
   - `datasource=imaginaries` + `prop=description` → 把意象描述注入 context
2. **`npc_batch_check`** — 通过 [`NpcBatchCheckOperator`](/core/operators/npc_batch_check_operator.gd:1) 结算所有宾客
   - 对 `guests` 列表中的每个 NPC，调用 `Database.query_prop(npc_id, "TALENT")` 获取才气值
   - 做 RNG 判断成功/失败
   - 用翻译键 `FEIHUALING_SUCCESS` / `FEIHUALING_FAIL` 逐行生成战报文本
   - 战报拼接注入 context

### Provider 选项渲染

通过 [`ItemProvider`](/core/model/item_provider.gd:1) 提供 2-3 个动态选项：

- 配置在 [`random_events.csv`](/data/random_events/random_events.csv:30) 的 feihualing_other_done provider 段
- 选项文本通过 `display_datasource` + `display_prop` 机制从已加载的 context 取值
- 直接使用 display 字段值（不通过 fetcher），因为 lifecycle 约束阻止在 provider 阶段执行新 fetcher

### 数据依赖

| 数据 | 来源 | 说明 |
|------|------|------|
| 意象标签（风/花/雪/月） | [`tres_imaginaries/environment__*.tres`](/data/tres_imaginaries/) | 4 个 ImaginaryTag Resource |
| 意象注册 | [`tres_imaginaries_registry.tres`](/data/tres_imaginaries_registry.tres:1) | 映射 uuid → path |
| NPC 才气 TALENT | NPCDocument.prop | libai=80, wangwei=75, zhengqian=70 |
| NPC 文档注册 | [`npc_document_registry.tres`](/data/npc_document_registry.tres:1) | libai, wangwei, zhengqian |
| 翻译文本 | [`dynamic_events.csv`](/data/translations/dynamic_events.csv:1) | FEIHUALING_SUCCESS/FAIL + CHAR_NAME_* |

### 翻译加载（重要坑）

`@tool` Resource 脚本的 `tr()` 调用绕过了 Godot 4 的 `[locale]` 自动加载机制。修复方式：

在 [`Database._init()`](/core/database.gd:48) 中显式调用 `TranslationServer.add_translation()` 注入翻译资源。详见 [`old_bugs.md`](/DOCUMENTATIONS/old_bugs.md:537)。

### 关键字拓展

关键字可以后续按州府做地区特征绑定（长安出"权/华"，蜀地出"山/悲"），第一阶段先固定字库（风花雪月）。
