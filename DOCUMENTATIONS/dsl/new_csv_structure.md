# 新 CSV 层级结构契约 (Pushdown Automaton Format)

## 概述

新 CSV 格式从扁平的"一行一事件"改为**下推自动机（Pushdown Automaton）** 的层级结构。每行通过 `>` 深度标记表达树状嵌套关系，支持事件 → 选项 → 子选项的多层结构。

## 契约：深度标记 (Depth Marker)

### 规则

- 第一列（`depth` 列）用 `>` 字符表示当前行的嵌套深度
- **`>` 的数量 = 深度值**。空值 = depth 0
- **最大深度限制：4 层**（depth 0 ~ 3，即 ` `, `>`, `>>`, `>>>`）

| 标记 | 深度 | 含义 |
|------|------|------|
| _(空)_ | 0 | 顶层事件（`random_event`） |
| `>` | 1 | 一级子行（`option`，挂载到顶层事件） |
| `>>` | 2 | 二级子行（子选项，挂载到一级选项） |
| `>>>` | 3 | 三级子行（更深层嵌套） |
| `>>>>` | 4+ | **禁止** — 超过最大深度限制 |

### 完整表头

```csv
depth,row_type,uuid,context,requirements,title,description,results
```

| 列名 | 必需 | 说明 |
|------|------|------|
| `depth` | 是 | `>` 深度标记，空值=顶层 |
| `row_type` | 是 | 行类型：`random_event` 或 `option` |
| `uuid` | 是 | 唯一标识符 |
| `context` | 否 | Context DSL 字符串（见 context 设计文档） |
| `requirements` | 否 | 触发条件 DSL |
| `title` | 否 | 显示标题 |
| `description` | 否 | 详细描述 |
| `results` | 否 | 事件/选项级结果 DSL |

## 示例

```csv
depth,row_type,uuid,context,requirements,title,description,results
,random_event,evt_changan_01,"tag:actor:status:temporary:drunk,city:econ:level:prosperous|weight:15.5|background:(bg_tavern_night)",prop:money:>50,长安酒馆奇遇,你在酒馆遇到一位神秘诗人,prop:literary_fame:+5
>,option,opt_bribe,"weight:0.8",prop:money:>100,塞钱贿赂,,prop:money:-100,trait:add:corrupt
>,option,opt_poetry,"weight:1.2",prop:literary_fame:>20,与之对诗,,prop:literary_fame:+15,prop:money:-30
,random_event,evt_market_02,"tag:city:econ:level:prosperous|weight:10.0",,市场见闻,集市上人来人往,,
>,option,opt_buy,"weight:0.5",prop:money:>30,买些小玩意,,prop:money:-30
```

## 解析规则

1. **逐行读取**，通过 `depth` 列确定当前行深度
2. **维护一个事件栈**：栈深度 = 当前解析深度
3. 遇到 `random_event` 行 → **压栈**（push）
4. 遇到 `option` 行 → 解析为 `EventOption`，**挂载到栈顶事件**
5. 深度减小时 → **弹栈**（pop），弹出的顶层事件标记为"完成"
6. 遍历结束后，栈中剩余事件全部弹出并加入结果集

## 状态转移

```
当前状态 + (depth, row_type) → 下一状态 + 操作
─────────────────────────────────────────
IDLE    + (0, random_event) → IN_EVENT   + push
IN_EVENT + (0, random_event) → IN_EVENT   + pop + push
IN_EVENT + (1, option)       → IN_EVENT   + 挂载到栈顶
IN_EVENT + (2+, option)      → IN_EVENT   + 挂载到栈顶（更深层）
任何状态 + (N, 空/未知)      → 当前状态   + 跳过
```

## 为什么是下推自动机？

- **表达能力**：CSV 是扁平的，但游戏事件天然是树状的（事件→选项→子选项）。下推自动机用最小的语法代价（一个 `>` 字符）实现了树状结构的序列化。
- **可读性**：对齐的 `>` 列让嵌套关系一目了然，人类肉眼可读。
- **解析确定性**：`_get_row_depth()` 扫描所有列查找 `>` 值，不存在歧义。详见 [`parser/dsl_parser.gd`](../../parser/dsl_parser.gd:6) 的 `_get_row_depth` 函数。
- **适合 4 层以内**：游戏场景的选项嵌套极少超过 3 层，4 层上限足够覆盖所有合理场景。

## 相关代码

- 下推自动机入口：[`DSLParser.parse_csv_data()`](../../parser/dsl_parser.gd:609)
- 状态转移函数：[`DSLParser._pda_transition()`](../../parser/dsl_parser.gd:640)
- 深度提取：[`DSLParser._get_row_depth()`](../../parser/dsl_parser.gd:6)
- 事件行解析：[`DSLParser.parse_random_event()`](../../parser/dsl_parser.gd:91)
- 选项行解析：[`DSLParser.parse_option_row()`](../../parser/dsl_parser.gd:152)
