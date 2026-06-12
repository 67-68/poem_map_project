我来帮你分析当前项目的事件流走向。先探索一下代码结构。

## 当前事件流分析 🧠

你的事件系统是一个基于时间驱动的随机事件池架构。让我梳理一下完整的调用链：

### 核心事件流向 🎯

```
TimeService (时间服务)
  ↓ on_xun_tick信号 (每旬触发)
EventManager (事件管理器)
  ↓ scan_events() → 扫描事件池
  ↓ 过滤 + 权重随机抽取
EventBus.request_event_key (事件总线)
  ↓ 传递事件UUID
NarrativeOverlay (叙事层) 
  ↓ apply_narrative() → 显示事件UI
  ↓ 玩家选择选项
ConsequenceExecuter (后果执行器)
  ↓ execute_result() → 执行操作符
ImaginaryManager (意象管理器)
  ↓ add_imagenary() → 处理意象判定
```

### 关键节点详解 📋

**1. 时间触发** (<ref_file file="/Users/lennon/Projects/poem_map_project/core/time_service.gd" lines="112-116" />)
- `TimeService._process()` 每帧更新游戏时间
- 每旬（10天）触发 `on_xun_tick` 信号
- EventManager监听此信号启动事件扫描

**2. 事件扫描** (<ref_file file="/Users/lennon/Projects/poem_map_project/core/event_manager.gd" lines="18-35" />)
- 从Database获取候选事件池
- 创建EventTicket包装事件
- 应用filters过滤（RequirementFilter + ActionTagFilter）
- 使用权重算法抽取事件

**3. 权重抽取** (<ref_file file="/Users/lennon/Projects/poem_map_project/core/event_manager.gd" lines="115-152" />)
- 工业级"无事发生"算法：设置null_weight作为空转权重
- 随机抽取，可能返回null（无事发生）
- 支持fallback_event_uuid作为兜底事件

**4. 事件展示** (<ref_file file="/Users/lennon/Projects/poem_map_project/characters/narrative_overlay.gd" lines="56-78" />)
- NarrativeOverlay监听request_event_key
- 从Database获取事件数据
- 暂停世界，显示UI，播放动画

**5. 后果执行** (<ref_file file="/Users/lennon/Projects/poem_map_project/core/consequence_executer.gd" lines="3-7" />)
- 用户选择后，ConsequenceExecuter执行ChoiceResult
- ChoiceResult包含多个BaseOperator
- 每个Operator执行具体逻辑（修改属性、添加trait等）

### 设计评价 🤓☝️

**优点：**
- 解耦良好：时间→事件池→UI→后果执行，职责清晰
- 灵活的过滤机制：支持requirements和action_tags双重过滤
- 权重系统+无事发生机制：控制事件密度，避免事件轰炸

**潜在问题：**
- 事件池扫描每旬都全量重新计算，如果事件量大可能性能瓶颈 💀
- 过滤逻辑硬编码在filters数组中，扩展性有限
- 权重计算在主线程，复杂计算可能卡顿

### 事件类型支持 🎭

当前支持三种事件扫描模式：
- `scan_events()` - 普通随机事件
- `scan_poem_events()` - 诗词相关事件
- `scan_death_events()` - 结局事件

### Era 时代感知事件路由 📅

从 `4_eras/` 目录结构引入后，事件系统新增了时代感知能力：

```
Database (数据核心)
  ↓ _init() → scan result.bases
  ↓ 提取所有 RandomEvent 资源
  ↓ _extract_pool_tag() → 从 trigger_tags 提取 action:main:xxx 作为池标签
  ↓ event.era → 同步构建 _events_by_era 索引
  ↓
get_random_events(main_tag, era):
  ├─ 按 main_tag 定位到 random_events[pool_tag]
  ├─ era="" → 返回全量池（不过滤）
  └─ era="745_ambition" → 合并 era=""（全局） + era="745_ambition"（时代专属）
```

**核心原则 — 目录是给人看的，系统整理资源使用 tag：**
- 事件的 `trigger_tags` 决定了它属于哪个事件池（如 `action:main:baiye`）
- 事件的 `era` 字段决定了它在哪个时代可用
- 目录结构仅作组织用途，不参与路由
- 子目录（如 `honey_moon/`、`real_appearance/`）仅通过 `requirements` 区分，不做子池隔离

**时代事件数据流：**
```
TimeService.on_xun_tick
  ↓
EventManager.scan_events(context)
  ├─ context.era ← 从 GameState.current_era 获取（由 TimeService 推算）
  ├─ context.main_tag ← 当前玩家的 action tag
  ↓
Database.get_random_events(main_tag, era)
  ├─ 定位到 main_tag 对应的事件池
  ├─ 合并全局（era=""）+ 时代专属（era 匹配）事件
  ↓
返回 { uuid: RandomEvent } 给 EventManager
```

**CSV 中的 era 声明：**
```
context: trigger_tags=[action:main:baiye]|weight=10|era=745_ambition
                      ↑ 池标签              ↑ 时代标记
```

**注意：**
- `era` 空字符串 = 全时代可用（全局事件）
- 非空 `era` = 仅在对应时代可用
- 查询时做 UNION 合并（全局 + 时代专属都参与抽取）
- `GameState.current_era` 需要在 `GameState` 中新增（从 `TimeService` 推算）