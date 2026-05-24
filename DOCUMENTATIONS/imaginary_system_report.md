# Imaginary System 技术报告

## 1. 系统概述

Imaginary系统是诗词地图游戏中的核心机制之一，负责管理玩家通过游戏事件获得的"意象"，并将其用于诗词创作。该系统连接了事件触发、资源管理和创意合成三个核心游戏循环。

### 核心功能
- **意象获取**: 通过游戏事件获得意象，支持基于玩家状态的条件校验
- **意象管理**: 维护意象的等级、阈值和关联标签
- **诗词创作**: 使用选定的意象合成诗词，消耗玩家资源并触发后续事件

## 2. 核心组件

### 2.1 数据模型

#### ImaginaryTag (核心数据结构)
```gdscript
class ImaginaryTag:
    uuid: String              # 意象唯一标识 (格式: "emotion:ambition")
    name: String              # 显示名称
    current_level: int        # 当前等级 (0-2)
    basic_imaginaries: Array  # 关联的具体标签数组
    l3_threshold: int         # 达到等级3的阈值 (默认4)
```

**等级规则**:
- Level 1: basic_imaginaries.size() < l2_threshold (2)
- Level 2: l2_threshold <= basic_imaginaries.size() <= l3_threshold  
- Level 3: basic_imaginaries.size() > l3_threshold

#### EmotionConfigs (校验配置)
```gdscript
class EmotionConfigs:
    imagenary_uid: String     # 目标意象UID
    requirements: Array       # 校验条件数组
```

### 2.2 管理器类

#### ImaginaryManager
- **职责**: 处理意象的获取和等级管理
- **关键方法**:
  - `add_imagenary(ev: BaseEvent)`: 事件触发时添加意象
  - `_process_emotion_configs(ev: BaseEvent)`: 使用校验配置处理
  - `_process_target_tags(ev: BaseEvent)`: 回退方案，直接处理标签

#### ImagenaryEvaluator
- **职责**: 基于玩家状态校验意象获取条件
- **关键方法**:
  - `evaluate_local_configs(configs, player_state)`: 批量校验配置
  - `evaluate_single_config(config, player_state)`: 单个配置校验
- **特殊逻辑**: 对talent属性应用阈值折扣
  - talent > 50: 阈值打5折
  - talent > 30: 阈值打75折

#### TagManager
- **职责**: 标签解析和标准化
- **关键方法**:
  - `get_imaginary_from_tag(tag)`: 从标签获取对应的意象
  - `normalize_3part_depreciated_tag(tag)`: 标签格式标准化

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
                    有配置                                   无配置
                        │                                       │
                        ↓                                       ↓
            ImagenaryEvaluator校验                  _process_target_tags
                        │                                       │
                        ↓                                       ↓
            获取通过校验的UID数组              直接处理target_tags
                        │                                       │
                        └───────────────────┬───────────────────┘
                                            ↓
                            TagManager.get_imaginary_from_tag
                                            ↓
                            ImaginaryTag.basic_imaginaries.append(tag)
                                            ↓
                            根据阈值更新current_level
                                            ↓
                            EventBus.imaginary_changed.emit()
```

### 3.2 诗词创作流程

```
PoemCrafter.setup_imagenaries → Database获取有标签的意象
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
                            提取标签到PlayerState.current_action_tags
                                        ↓
                            EventManager.scan_poem_events(imas)
                                        ↓
                            更新l3_threshold, 重置current_level
```

### 3.3 意象消耗循环

每次诗词创作后：
1. **阈值提升**: `l3_threshold += 3` (让下一次升级更困难)
2. **等级重置**: `current_level = 1` (重新开始积累)
3. **标签保留**: basic_imaginaries数组保持不变

这种设计创造了"成长-消耗-再成长"的循环，鼓励玩家持续参与事件。

## 4. 关键设计决策

### 4.1 双模式获取机制
**决策**: 支持emotion_configs校验和target_tags回退两种模式
**理由**:
- **向前兼容**: 现有事件无需立即配置emotion_configs
- **渐进式**: 可以逐步为事件添加条件化获取逻辑
- **灵活性**: 简单事件用target_tags，复杂事件用emotion_configs

### 4.2 天赋折扣系统
**决策**: 高talent玩家获取意象的阈值更低
**理由**:
- **角色扮演**: 天赋高的诗人更容易获得某些灵感
- **游戏平衡**: 给予高属性玩家额外优势，但不破坏基本机制
- **可扩展**: 折扣逻辑可以扩展到其他属性

### 4.3 等级递进设计
**决策**: 三级等级系统，阈值递增
**理由**:
- **简洁性**: 三个等级足以提供深度而不至于复杂
- **清晰目标**: 玩家明确知道下一级需要多少标签
- **消耗循环**: 创作诗词后重置等级但保留标签，创造重复游玩价值

### 4.4 事件-意象-诗词链路
**决策**: 意象的标签直接用于扫描诗词事件
**理由**:
- **语义一致性**: 事件给什么标签，诗词就触发什么类型事件
- **数据流简化**: 避免复杂的数据转换和映射
- **可预测性**: 玩家可以预期选择某些意象会带来什么后果

## 5. 技术细节

### 5.1 数据存储
- **Database.imaginaries**: 全局意象字典，键为UUID
- **ImaginaryTag.basic_imaginaries**: 存储具体的标签UUID字符串
- **标签格式**: 四段式 "domain:category:specific:general"

### 5.2 信号系统
- `EventBus.event_shown`: 事件显示时触发
- `EventBus.imaginary_changed`: 意象状态变化时触发
- `EventBus.request_add_imaginary`: 主动请求添加意象

### 5.3 性能考虑
- **惰性更新**: PoemCrafter只在意象数量变化时重建UI
- **批量处理**: evaluate_local_configs支持批量校验
- **缓存友好**: ImaginaryTag作为资源对象，状态变化自动通知

### 5.4 错误处理
- **缺失意象**: 记录错误日志并跳过，不中断流程
- **格式错误**: TagManager自动标准化三段式标签为四段式
- **回退机制**: emotion_configs缺失时自动使用target_tags

## 6. 扩展性分析

### 6.1 当前限制
- 等级系统固定为3级
- 消耗公式相对简单
- 校验条件基于现有requirement系统

### 6.2 扩展方向
1. **动态等级**: 支持可配置的等级数量和阈值
2. **复合消耗**: 除了健康/天赋，可加入其他资源消耗
3. **意象组合**: 特定意象组合产生特殊效果
4. **时间衰减**: 意象随时间减弱或消失
5. **社交影响**: 意象获取和消耗影响NPC关系

## 7. 总结

Imaginary系统是一个设计精巧的资源管理循环，通过事件-意象-诗词的链路将游戏的叙事、策略和创意层面有机结合。其双模式获取机制和等级递进设计在保持简洁性的同时提供了足够的深度，天赋折扣和消耗循环则为玩家提供了明确的成长路径和重复游玩动力。

系统架构清晰，职责分离良好，通过事件总线实现松耦合，为未来的扩展和维护提供了良好的基础。

---

**相关文档**:
- UML类图: `DOCUMENTATIONS/imaginary_system_class_diagram.puml`
- UML序列图: `DOCUMENTATIONS/imaginary_system_sequence_diagram.puml`
- 核心代码: `core/imaginary_manager.gd`, `core/imagenary_evaluator.gd`, `ui/poem_crafter.gd`