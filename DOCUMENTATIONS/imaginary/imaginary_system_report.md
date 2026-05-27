# Imaginary System 技术报告

## 1. 系统概述

Imaginary系统是诗词地图游戏中的核心机制之一，负责管理玩家通过游戏事件获得的"意象"，并将其用于诗词创作。该系统连接了事件触发、资源管理和创意合成三个核心游戏循环，采用强类型引用替代字符串查表，废除字符串冒号分割协议。

**核心设计理念**：事件影响情绪，情绪在意象判定中解锁意象。这创建了一个有意义的状态机，让玩家的情绪状态成为意象获得的 gating 机制。

详见：[情绪-意象系统设计文档](./emotion_imaginary_system.md)

### 核心功能
- **意象获取**: 通过游戏事件获得意象，支持基于玩家状态的条件校验
- **意象管理**: 维护意象的等级、阈值和结构化上下文
- **诗词创作**: 使用选定的意象合成诗词，消耗玩家资源并触发后续事件

## 2. 核心组件

### 2.1 数据模型

#### ImaginaryTag (核心数据结构)
```gdscript
class ImaginaryTag:
    uuid: String              # 意象唯一标识 (格式: "emotion:ambition")
    name: String              # 显示名称
    current_level: int        # 当前等级 (0-2)
    basic_imaginaries: Array[Dictionary]  # 结构化存储
    l3_threshold: int         # 达到等级3的阈值 (默认4)
```

**basic_imaginaries 结构**:
```gdscript
[
    {
        "blueprint_id": "emotion:ambition",
        "contexts": ["with_li_bai", "drunk"]
    },
    {
        "blueprint_id": "court:corrupt", 
        "contexts": []
    }
]
```

**等级规则**:
- Level 1: basic_imaginaries.size() < l2_threshold (2)
- Level 2: l2_threshold <= basic_imaginaries.size() <= l3_threshold  
- Level 3: basic_imaginaries.size() > l3_threshold

#### EmotionConfigs (校验配置)
```gdscript
class EmotionConfigs:
    blueprint: ImaginaryTag  # 直接引用资源，废除字符串查表
    context_tags: Array[String] = []  # 专门存上下文，如 ["with_li_bai", "sad"]
    requirements: Array      # 校验条件数组
```

**设计改进**:
- 使用强类型 `ImaginaryTag` 引用替代 `String` UID
- 独立数组 `context_tags` 存储叙事上下文
- 在编辑器中可直接拖拽 .tres 资源配置

### 2.2 管理器类

#### ImaginaryManager
- **职责**: 处理意象的获取和等级管理
- **关键方法**:
  - `add_imagenary(ev: BaseEvent)`: 事件触发时添加意象
  - `_process_emotion_configs(ev: BaseEvent)`: 使用校验配置处理（推荐）
  - `_append_tag(ima: ImaginaryTag, entry: Dictionary)`: 结构化数据添加
- **废弃方法**:
  - `_process_target_tags(ev: BaseEvent)`: 已标记废弃，字符串分割协议已废除
  - `add_tag_to_imaginary(tag: String)`: 已标记废弃，建议使用 emotion_configs

#### ImagenaryEvaluator
- **职责**: 基于玩家状态校验意象获取条件
- **关键方法**:
  - `evaluate_local_configs(configs, player_state)`: 批量校验，返回结构化数据
  - `evaluate_single_config(config, player_state)`: 单个配置校验
- **返回格式**:
```gdscript
Array[Dictionary] = [
    {
        "blueprint": ImaginaryTag,  # 直接对象引用
        "context_tags": Array[String]
    }
]
```
- **特殊逻辑**: 对talent属性应用阈值折扣
  - talent > 50: 阈值打5折
  - talent > 30: 阈值打75折

#### TagManager
- **职责**: 标签解析和标准化
- **关键方法**:
  - `get_tag(tag_id: String)`: 获取标签对象
  - `normalize_3part_depreciated_tag(tag)`: 标签格式标准化
- **已废除**: `get_imaginary_from_tag(tag)` 方法，字符串冒号分割协议已废除

### 2.3 使用层组件

#### PoemCrafter
- **职责**: 诗词创作UI和逻辑控制器
- **关键方法**:
  - `setup_imagenaries()`: 初始化可选意象列表
  - `_on_button_pressed()`: 执行诗词创作
- **交互流程**:
  1. 玩家选择最多3个意象
  2. 实时计算创作消耗
  3. 确认后执行操作并触发事件
- **数据适配**: 从结构化 `basic_imaginaries` 提取 `blueprint_id` 用于标签匹配

#### PoemCraftingCalculator
- **职责**: 计算诗词创作的资源消耗
- **计算公式**:
  ```
  base_health = Σ(imaginary.current_level * level_factor + 0.5 * imaginary.l3_threshold)
  level_factor = 0.5 (有等级2意象) 或 0.2 (否则)
  talent_cost = Σ(level2_imaginary.current_level * 1.5)
  ```

## 3. 数据流程

### 3.1 意象获取流程

```
事件触发 → EventBus.event_shown → ImaginaryManager.add_imagenary
                                            ↓
                                    检查emotion_configs
                                            ↓
                        ┌───────────────────┴───────────────────┐
                        │                                       │
                    有配置                                   无配置 (已废弃)
                        │                                       │
                        ↓                                       ↓
            ImagenaryEvaluator校验                  _process_target_tags (废弃)
                        │                                       │
                        ↓                                       ↓
        返回结构化数据: { blueprint, context_tags }    直接跳过，输出警告
                        │
                        ↓
            直接使用 blueprint 对象，无需 Database 查表
                        │
                        ↓
            构造结构化 entry: { blueprint_id, contexts }
                        │
                        ↓
            ImaginaryTag.basic_imaginaries.append(entry)
                        │
                        ↓
            根据阈值更新 current_level
                        │
                        ↓
            EventBus.imaginary_changed.emit()
```

**数据流转特点**:
- **强类型引用**: `EmotionConfigs.blueprint` 直接是 `ImaginaryTag` 对象
- **结构化存储**: `basic_imaginaries` 存储字典而非字符串
- **废除分割协议**: 不再使用 `split(":")` 解析 UID

### 3.2 诗词创作流程

```
PoemCrafter.setup_imagenaries → Database获取有basic_imaginaries的意象
                                        ↓
                            创建ImagenaryItem UI组件
                                        ↓
玩家选择意象 → on_item_clicked → 加入selected_imaginaries
                                        ↓
                            达到3个时调用PoemCraftingCalculator.calculate
                                        ↓
                            显示消耗预览 → 玩家确认
                                        ↓
                            _on_button_pressed → execute operators
                                        ↓
        从 basic_imaginaries 提取 blueprint_id 到 PlayerState.current_action_tags
                                        ↓
                            EventManager.scan_poem_events(imas)
                                        ↓
                            更新l3_threshold, 重置current_level
```

**数据提取逻辑**:
```gdscript
for entry in ima.basic_imaginaries:
    var blueprint_id = entry.get("blueprint_id", "")
    if not blueprint_id.is_empty():
        PlayerState.current_action_tags.append(blueprint_id)
```

### 3.3 意象消耗循环

每次诗词创作后：
1. **阈值提升**: `l3_threshold += 3` (让下一次升级更困难)
2. **等级重置**: `current_level = 1` (重新开始积累)
3. **结构保留**: basic_imaginaries数组保持不变，包含完整的上下文信息

这种设计创造了"成长-消耗-再成长"的循环，鼓励玩家持续参与事件，同时保留叙事上下文。

## 4. 关键设计决策

### 4.1 强类型引用替代字符串查表
**决策**: 废除字符串冒号分割协议，使用强类型 `ImaginaryTag` 引用
**理由**:
- **类型安全**: 编译期检查，避免运行时字符串解析错误
- **编辑器友好**: 可在编辑器中直接拖拽 .tres 资源配置
- **性能优化**: 消除字符串分割和 Database 查表开销
- **代码清晰**: 直观的对象引用，减少魔法字符串

### 4.2 结构化数据存储
**决策**: basic_imaginaries 从 `Array[String]` 改为 `Array[Dictionary]`
**理由**:
- **上下文分离**: `context_tags` 独立存储，支持丰富叙事状态
- **扩展性**: 字典结构便于添加新字段（如时间戳、来源等）
- **数据完整性**: 单个 entry 包含完整信息，无需额外查询
- **向前兼容**: 可通过迁移脚本转换旧数据

### 4.3 天赋折扣系统
**决策**: 高talent玩家获取意象的阈值更低
**理由**:
- **角色扮演**: 天赋高的诗人更容易获得某些灵感
- **游戏平衡**: 给予高属性玩家额外优势，但不破坏基本机制
- **可扩展**: 折扣逻辑可以扩展到其他属性

### 4.4 等级递进设计
**决策**: 三级等级系统，阈值递增
**理由**:
- **简洁性**: 三个等级足以提供深度而不至于复杂
- **清晰目标**: 玩家明确知道下一级需要多少积累
- **消耗循环**: 创作诗词后重置等级但保留结构化数据，创造重复游玩价值

### 4.5 事件-意象-诗词链路
**决策**: 意象的 blueprint_id 直接用于扫描诗词事件
**理由**:
- **语义一致性**: 事件配置什么 blueprint，诗词就触发什么类型事件
- **数据流简化**: 直接从结构化数据提取 ID，无需复杂转换
- **可预测性**: 玩家可以预期选择某些意象会带来什么后果

### 4.6 渐进式重构策略
**决策**: 保留废弃方法接口，输出警告日志
**理由**:
- **平滑过渡**: 现有代码不会立即中断，有时间逐步迁移
- **明确方向**: 警告日志指导开发者使用新接口
- **风险控制**: 可在测试环境中验证新逻辑后再全面切换

## 5. 技术细节

### 5.1 数据存储
- **Database.imaginaries**: 全局意象字典，键为两段式 UUID（如 "emotion:ambition"）
- **ImaginaryTag.basic_imaginaries**: 结构化数组，每个元素为字典
- **字典结构**: `{ "blueprint_id": String, "contexts": Array[String] }`
- **资源引用**: EmotionConfigs.blueprint 直接引用 ImaginaryTag 资源

### 5.2 信号系统
- `EventBus.event_shown`: 事件显示时触发
- `EventBus.imaginary_changed`: 意象状态变化时触发
- `EventBus.request_add_imaginary`: 主动请求添加意象（已废弃）

### 5.3 性能考虑
- **直通数据流**: 强类型引用消除字符串分割和查表开销
- **惰性更新**: PoemCrafter只在意象数量变化时重建UI
- **批量处理**: evaluate_local_configs支持批量校验，返回结构化数据
- **缓存友好**: ImaginaryTag作为资源对象，状态变化自动通知

### 5.4 错误处理
- **空引用检查**: 验证 `EmotionConfigs.blueprint` 不为 null
- **格式验证**: 从字典提取数据时检查字段存在性
- **废弃警告**: 对使用已废弃方法的代码输出警告日志
- **优雅降级**: 校验失败时跳过单个配置，不影响其他配置处理

### 5.5 迁移兼容性
- **数据迁移**: 需要将旧的 `Array[String]` 转换为新的 `Array[Dictionary]`
- **资源配置**: 现有事件需要重新配置，使用 blueprint 引用而非字符串 UID
- **API 变更**: 调用方代码需要适配新的数据结构和接口

## 6. 扩展性分析

### 6.1 当前限制
- 等级系统固定为3级
- 消耗公式相对简单
- 校验条件基于现有requirement系统
- 结构化存储的字段相对固定

### 6.2 扩展方向
1. **动态等级**: 支持可配置的等级数量和阈值
2. **复合消耗**: 除了健康/天赋，可加入其他资源消耗
3. **意象组合**: 特定 blueprint_id 和 context 组合产生特殊效果
4. **时间衰减**: 为字典添加时间戳，支持意象随时间减弱或消失
5. **社交影响**: 基于 context_tags 实现意象获取和消耗影响NPC关系
6. **叙事深度**: 扩展 contexts 字段支持更丰富的叙事状态
7. **资源序列化**: 支持结构化数据的存档和加载

### 6.3 重构收益
- **类型安全**: 编译期检查减少运行时错误
- **维护成本**: 强类型引用使重构更加安全
- **开发效率**: 编辑器资源拖拽配置更直观
- **性能提升**: 消除字符串解析开销

## 7. 总结

Imaginary系统通过本次重构，从基于字符串查表的脆弱架构升级为强类型引用的现代化设计。废除字符串冒号分割协议后，系统在类型安全、性能优化和开发体验方面都得到显著提升。

核心改进包括：
- **强类型引用**: EmotionConfigs 使用 ImaginaryTag 直接引用，消除字符串解析
- **结构化存储**: basic_imaginaries 采用字典结构，支持丰富上下文信息
- **数据流简化**: 直通的对象引用链路，无需 Database 查表和字符串分割
- **渐进式重构**: 保留废弃接口，确保平滑过渡

系统的架构清晰度进一步提升，职责分离更加明确，为未来的扩展和维护提供了更坚实的基础。事件-意象-诗词的链路通过强类型连接，既保持了原有设计的灵活性，又大幅提高了系统的健壮性。

---

**相关文档**:
- 技术报告: `DOCUMENTATIONS/imaginary_system_report.md` (本文档)
- 核心代码: `core/imaginary_manager.gd`, `core/imagenary_evaluator.gd`, `ui/poem_crafter.gd`
- 数据模型: `core/model/emotion_configs.gd`, `core/model/imaginary.gd`