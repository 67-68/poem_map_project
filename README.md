# 大唐诗词可视化 — Du Fu's Tang Dynasty Simulator

> *"穿过长安的雨，走遍蜀道的风，以诗为命活一次。"*

一款以 **唐代诗人** 为主角的 **交互式诗词人生模拟器**，使用 Godot Engine 构建。通过数据驱动的事件系统，还原安史之乱前后诗人的漂泊、创作与命运。

---

## 📦 项目概览

| 条目 | 内容 |
|------|------|
| **引擎** | Godot Engine (GDScript) |
| **类型** | 历史模拟 / 叙事驱动 / 诗词创作 |
| **背景** | 唐朝（约 740–770 AD），安史之乱前后 |
| **主角** | 杜甫（及可选的诗人角色） |
| **数据驱动** | CSV + DSL 定义事件、状态转移、角色属性 |
| **当前版本** | `0.8.0`（开发中） |

---

## 🎮 核心玩法

### 🗺️ 漫游大唐

游戏以唐朝疆域地图为舞台，划分为州府（province）与领土（territory）。玩家在地图上移动，不同地区影响可用的行动与事件：

- 长安 — 权谋中心，应制诗与官场
- 洛阳 — 文化交汇，交游与唱和
- 蜀地 — 避乱与山水诗
- 边塞 — 战争与羁旅

地区标签系统（`area_tags`）决定了当前地点可触发的 Action，同一件事在长安和蜀地可能有截然不同的走向。

### ⏳ 时间与生命

时间以 **旬（10 天）** 为单位自动推进。每个人物都有自己的生命轨迹：

- ⏰ **每旬扫描** — 自动检查事件池，触发符合条件的随机事件
- ⌛ **有限人生** — 随时间推移，健康衰减、病痛累积，最终触发结局事件
- 🏛️ **年号纪年** — 跟随真实历史年号（天宝、至德、乾元……）

### 🎯 核心循环：Action → 标签 → 事件

```
执行 Action
     ↓ 注入临时标签到 PlayerState
事件扫描匹配（基于标签 + 权重）
     ↓ 条件过滤（requirements）
展示事件 → 选择选项
     ↓ 执行后果（属性变化、flag 变更、触发下游事件）
时间推进 → 进入下一旬
```

这是一个**两层过滤系统**：

1. **地理层** — Action 必须在玩家当前位置有地区标签交集才能出现
2. **行为层** — 执行 Action 后标签被注入，事件通过标签匹配触发，**命中次数越多权重越高**

### ✍️ 诗词创作

积累 **灵感（INSPIRATION）** 与 **意象（Imaginary）**，在 `PoemCrafter` 中创作诗词：

- 意象是诗词的"材料"（月、酒、剑、秋……）
- 不同的意象组合产出不同主题的诗词
- 创作的诗词会获得印章等级（拾遗 → 雅颂 → 瑰意 → 绝唱）
- 诗词本身也可能成为触发后续事件的"钥匙"

### 🧠 属性系统 (PROPS)

| 属性 | 说明 | 类型 |
|------|------|------|
| `OFFICIAL_PRESTIGE` | 官职声望 | 持久 |
| `LITERARY_FAME` | 文学声望 | 持久 |
| `TALENT` | 才华 | 持久 |
| `MONEY` | 金钱 | 持久 |
| `HEALTH` | 健康 | 持久 |
| `FATIGUE` | 短期疲惫，影响才华产出效率 | 临时 |
| `DRUNK` | 醉酒（双刃剑） | 临时 |
| `SICK` | 病痛，到阈值强制休息 | 临时 |
| `INSPIRATION` | 灵感，用于兑换意象 | 代币 |

**属性变化受多层乘数影响**：当前抱负（Ambition）→ 地区 Buff → 个人特质（Trait），形成复杂的 buff 链。

### 😡 情绪系统 (EMOTION)

| 情绪 | 说明 |
|------|------|
| `SORROW` | 愁苦/悲凉 |
| `ARROGANCE` | 狂傲/得意 |
| `ANGER` | 愤懑 |
| `TRANQUILITY` | 旷达/空灵 |
| `AMBITION` | 入世野心 |

情绪影响意象获取的倾向——悲愤时易得"秋"与"泪"，狂傲时易得"酒"与"剑"。

### 🏷️ 特质系统 (TRAIT)

Trait 是玩家的被动能力/状态，通过事件获得或失去。每个 Trait 可以带 `buffer_to_prop` 和 `buffer_to_region` 乘数，影响属性变化量。

主线特质按等级划分（如 `MAIN_BAIYE_1` → `MAIN_BAIYE_4`），代表在某条路线上的深入程度。

---

## 📐 架构设计

### 数据驱动 + DSL

**核心信条：配置优于编码。** 游戏内容（事件、状态转移、角色数据）尽可能通过 CSV + DSL 定义，减少硬编码。

```
Google Sheets (线上 CSV)
    ↓ csv_cloud_loader
本地 CSV / .tres 资源
    ↓ DSLParser / MicroDSLParser
运行时对象（RandomEvent / StateTransistor / ...）
    ↓ 事件系统
玩家交互
```

### DSL 语法

事件配置使用自定义 DSL，**命名参数函数调用**格式：

```csv
requirements: prop_gt(name=money; val=50) | flag_bool_has(name=met_libai)
operations:   prop_add(name=money; val=100) | trait_add(name=reputation_rising)
```

取代了旧式的冒号分割语法（`prop:money:>50`），**消灭位置依赖，参数名即文档** 🤓☝️。

### 事件系统架构

```
时间信号 (on_xun_tick)
    ↓
EventManager.scan_events()
    ↓ 过滤 + 权重随机抽取
EventBus.request_event_key
    ↓
NarrativeOverlay.apply_narrative()
    ↓ 展示事件 UI
玩家选择选项
    ↓
ConsequenceExecuter.execute_result()
    ↓
属性变更 / Flag 设置 / 触发下游事件
```

**支持的事件类型：**
- `random_event` — 随机事件
- `history_event` — 历史事件
- `poem_event` — 诗词相关事件
- `death_event` — 结局事件
- `decided_event` — 已决策事件
- `focused_chat` — 聚焦对话
- `chat_bubble` — 聊天气泡

**高级机制：**
- **Push/Pop 事件栈**（LIFO）— 中断当前事件流，优先处理栈顶事件
- **事件队列**（FIFO）— 不紧急的事件排队等待
- **Provider 系统** — 从 context 列表动态生成选项（如"酒馆里有 3 个 NPC，选择走向谁"）
- **Interruption 机制** — 事件触发前检查条件，满足则用另一个事件替代
- **Context 隔离契约** — 每个事件、选项、Operator 拥有独立的 context 沙盒，防止数据污染

### URN 资源标识系统

所有资源使用统一 URN 协议：

```
urn:poem_map:<resource-type>:<resource-id>
```

示例：`urn:poem_map:poet:libai_001`、`urn:poem_map:poem:jiang_jin_jiu`

支持 30+ 资源类型（诗人、诗词、省份、势力、事件、flag、trait……）。

### StateTransistor 状态转移器

声明式的状态转移描述单元——"在条件满足时，把某个资源从状态 A 转移到状态 B"。支持：

- Flag 开关/累加/清空
- 条件守卫（requirements）
- 后效操作（operators）
- 链式事件触发

### 三层铁幕契约

事件生命周期被严格划分为三层，**禁止越界**：

| 层级 | 时机 | 职责 | 禁止 |
|------|------|------|------|
| **Event on_enter** | 事件展示前 | 舞台置景：初始化 flag、注入 context | 玩家选择后才该发生的操作 |
| **Option requirements** | 按钮创建时 | 只读守卫：检查条件决定选项可用性 | 任何带副作用的操作 |
| **Option choice_result** | 玩家选择后 | 因果爆破：执行后果 | 初始化语义的操作 |

### 标签体系 (4-Part Tags)

```
domain:category:type:specific
```

示例：
- `actor:status:temporary:drunk` — 人物醉酒状态
- `city:econ:level:prosperous` — 城市经济繁荣
- `action:intent:study:poetry` — 学习诗歌的意图
- `intel:story_lock:event:anlushan_rebel` — 安禄山剧情锁

兼容旧的三段式格式，引擎侧通过 `TagManager.normalize_3part_depreciated_tag()` 做向后兼容。

---

## 🗂️ 项目结构

```
├── core/                    # 核心系统
│   ├── database.gd          # 全局数据库（所有资源的加载入口）
│   ├── player_state.gd      # 玩家状态单例
│   ├── event_manager.gd     # 事件管理器（扫描/过滤/权重抽取）
│   ├── eventbus.gd          # 事件总线
│   ├── consequence_executer.gd  # 后果执行器
│   ├── time_service.gd      # 时间服务
│   ├── util.gd              # 工具函数（merge_context, tr_and_resolve...）
│   ├── model/               # 核心模型
│   │   ├── base_operator.gd       # Operator 基类
│   │   ├── base_requirement.gd    # Requirement 基类
│   │   ├── base_provider.gd       # Provider 基类
│   │   ├── property_operator.gd   # 属性操作符
│   │   ├── property_requirement.gd # 属性需求
│   │   └── conditional_operator.gd # 条件操作符
│   ├── operators/           # 操作符实现
│   │   ├── flag_operator.gd       # Flag 操作
│   │   ├── temp_flag_operator.gd  # 临时 Flag（自动回滚）
│   │   ├── push_event_operator.gd # 推栈事件
│   │   ├── queue_event_operator.gd # 排队事件
│   │   ├── emotion_operator.gd    # 情绪操作
│   │   ├── imaginary_operator.gd  # 意象操作
│   │   ├── trait_choose_operator.gd # 诗词品味选择
│   │   └── ...
│   ├── requirements/        # 需求/条件实现
│   │   ├── flag_requirement.gd    # Flag 条件
│   │   └── ...
│   └── linter_rules/        # Linter 规则（数据质量检查）
│       ├── schema_linter_rule.gd
│       ├── linker_linter_rule.gd
│       └── business_linter_rule.gd
├── model/                   # 数据模型
│   ├── enumerates.gd        # 全局枚举（PROPS, EMOTION, TRAITS...）
│   ├── urn.gd               # URN 系统
│   ├── event.gd             # 事件基类
│   ├── random_event.gd      # 随机事件
│   ├── choice_result.gd     # 选择结果
│   └── event/               # 事件选项体系
│       ├── base_option.gd
│       ├── event_option.gd
│       ├── custom_event_option.gd
│       ├── complex_event_option.gd
│       └── property_option.gd
├── parser/                  # DSL 解析器
│   ├── dsl_parser.gd        # 主解析器
│   ├── micro_dsl_parser.gd  # 微型解析器
│   └── named_dsl_parser.gd  # 命名参数解析器
├── ui/                      # UI 组件
│   ├── left_player_panel.gd      # 玩家面板
│   ├── right_info_panel.gd       # 信息面板
│   ├── decision_panel.gd         # 决策面板
│   ├── emotion_radar.gd          # 情绪雷达图
│   ├── social_wall_panel.gd      # 社交墙
│   ├── poem_crafter.gd           # 诗词创作界面
│   ├── scene_action_panel.gd     # 场景行动面板
│   ├── ambition_hud.gd           # 抱负 HUD
│   └── ...
├── world/                   # 游戏世界
│   ├── camera.gd            # 相机控制
│   ├── day_light.gd         # 昼夜光照
│   ├── character_point.gd   # 角色点
│   ├── dialogue_bubble.gd   # 对话气泡
│   └── ...
├── characters/              # 角色系统
│   ├── narrative_overlay.gd     # 叙事层（事件展示 UI）
│   ├── event_btn.gd             # 事件按钮
│   ├── messager.gd              # 信使系统
│   └── poem_data.gd / poet_data.gd
├── data/                    # 数据文件（.tres + CSV）
│   ├── tres_*_registry.tres    # 各类资源注册表
│   ├── tres_properties/        # 属性资源
│   ├── tres_traits/            # 特质资源
│   ├── tres_flags/             # Flag 资源
│   ├── random_events/          # 事件资源
│   └── ...
├── assets/                  # 美术资产
│   ├── maps/                # 地图数据（CSV + 贴图）
│   ├── poem_bgs/            # 诗词背景
│   └── stamps/              # 印章图
├── tests/                   # 单元测试（GUT）
├── DOCUMENTATIONS/          # 技术文档
│   ├── architecture_moc.md  # 架构总览
│   ├── dsl/                 # DSL 文档
│   ├── events/              # 事件系统文档
│   └── ...
└── README.md                # 本文件
```

---

## 🎹 操作说明

| 按键 | 功能 |
|------|------|
| `Cmd + F1` | 显示 Debug 信息覆盖层 |
| `Cmd + F2` | 打开/关闭调试控制器（CLI） |
| `R` | 打开情绪雷达图 |
| `S` | 打开社交墙面板 |

### 调试控制器命令

在 `Cmd + F2` 打开的控制器中可输入：

```
send_signal <signal_name> <argument>     # 发送信号
give_trait <trait_uuid>                  # 添加特质
event_result <event_id>                  # 触发事件结果
add_imaginary <name>                     # 添加意象
<<method> <argument>                     # 调用 GameState/Database 方法
$<event_key>                             # 快捷触发事件
$ dsl <operator_chain>                   # 直接执行 DSL 操作符链
```

多行命令支持换行批量执行。

---

## 🛠️ 开发指南

### 添加新的事件

1. 在 Google Sheets（或本地 CSV）中按模板格式添加一行
2. 填写：Event_ID、Trigger_Tags、requirements、Title、Desc、Options 等字段
3. 使用 DSL 语法编写条件和结果
4. 运行 `csv_cloud_loader` 同步到本地

### 添加新的 PROPS

1. 在 `model/enumerates.gd` 的 `PROPS` 枚举中添加
2. 在 `data/tres_properties_registry.tres` 中注册
3. 在 `data/tres_properties/` 下创建属性资源文件
4. （可选）在 `PlayerState._ready()` 中设置初始值

### 添加新的 URN 类型

修改 4 个文件：`enumerates.gd`（注册类型）→ `database.gd`（加载数据 + 查找链）→ `urn_system.md`（更新文档）

### Linter 流水线

数据质量检查分为三层：
1. **Schema 检查官** — 数据结构完整性
2. **链接检查官** — 跨事件引用关系（Flag/Trait 供需）
3. **业务规则检查官** — 策划业务逻辑校验

添加新的 Linter Rule 只需新建一个继承 `BaseLinterRule` 的类，在流水线中加一行。

---

## 🧪 测试

使用 GUT (Godot Unit Test) 框架：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=<test_file>
```

现有测试覆盖：
- DSL 解析层（tag parsing, context parsing）
- Operator 运行时（operate/compare）
- 事件数据完整性

---

## 📚 文档索引

| 文档 | 内容 |
|------|------|
| [`DOCUMENTATIONS/architecture_moc.md`](DOCUMENTATIONS/architecture_moc.md) | 架构总览（MOC） |
| [`DOCUMENTATIONS/dsl/dsl_syntax_reference.md`](DOCUMENTATIONS/dsl/dsl_syntax_reference.md) | DSL 语法参考 |
| [`DOCUMENTATIONS/dsl/dsl_csv_structure_guide.md`](DOCUMENTATIONS/dsl/dsl_csv_structure_guide.md) | CSV 数据结构指南 |
| [`DOCUMENTATIONS/urn_system.md`](DOCUMENTATIONS/urn_system.md) | URN 标识系统 |
| [`DOCUMENTATIONS/state_transistor.md`](DOCUMENTATIONS/state_transistor.md) | 状态转移器 |
| [`DOCUMENTATIONS/props_system.md`](DOCUMENTATIONS/props_system.md) | 属性系统 |
| [`DOCUMENTATIONS/controller_method.md`](DOCUMENTATIONS/controller_method.md) | 调试控制器 |
| [`DOCUMENTATIONS/events/current_event_dataflow.md`](DOCUMENTATIONS/events/current_event_dataflow.md) | 事件数据流 |
| [`DOCUMENTATIONS/events/context_isolation_contract.md`](DOCUMENTATIONS/events/context_isolation_contract.md) | Context 隔离契约 |
| [`DOCUMENTATIONS/events/operator_variable_lifecycle.md`](DOCUMENTATIONS/events/operator_variable_lifecycle.md) | Operator 变量生命周期 + 三层铁幕契约 |

---

## 📝 更新日志

见 [`change_log.md`](change_log.md)

当前版本 `0.8.0` — 新增：
- EU4 风格弹窗事件系统
- 省份连接调试工具
- 年号纪年
- 对话气泡系统
- 事件链触发
- DSL 直接执行命令（`$ dsl`）

---

## ⚠️ 开发状态

**Active Development** 🚧

项目处于早期开发阶段，API 和数据结构仍在快速迭代。文档可能滞后于代码。如果你发现文档和代码不一致，以代码为准，欢迎提 Issue。

---

## 🙏 致谢

- Godot Engine — 开源游戏引擎
- 所有为唐诗可视化提供灵感和数据的历史文献
- 长安的雨，蜀道的风，和每一首不曾被遗忘的诗
