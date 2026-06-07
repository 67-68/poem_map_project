# 情绪-意象系统设计文档

> ⚠️ **此文档描述的 EmotionConfigs 方案已被 V2 架构替代。**
> 新方案见 [`plans/emotion_imagery_orthogonal_pipeline_v2.md`](../../plans/emotion_imagery_orthogonal_pipeline_v2.md)
>
> **替代原因：** 旧方案让情绪直接映射意象蓝图（唯心主义），容易导致"在大唐夜宴上刷出饿殍"的 OOC 问题。
> V2 改为"场景圈定实体池 → 意象自带情绪亲缘度 → 打分选择器"（唯物主义），意象获取不会脱离物理场景约束。

## 设计意图

情绪-意象系统的核心设计理念是：**事件影响情绪，情绪在意象判定中解锁意象**。

这个设计创建了一个有意义的状态机，让玩家的情绪状态成为意象获得的 gating 机制，而不是简单地"事件触发 = 获得意象"。

## 核心概念

### 1. 情绪系统 (EMOTION)

情绪是玩家的临时状态（Volatile Stats），表示玩家当前的情感倾向。系统定义了5种核心情绪：

- `SORROW` (愁苦/悲凉) - 送别、怀古、失意时增加
- `ARROGANCE` (狂傲/得意) - 饮酒作乐、金榜题名时增加
- `ANGER` (愤懑) - 被贬、目睹不公时增加
- `TRANQUILITY` (旷达/空灵) - 山水田园、修道、释怀时增加
- `AMBITION` (世俗野心) - 想做官、想入世的愿望

情绪的特点：
- **临时性**：情绪会随事件变化，不是持久属性
- **可累加**：同一情绪可以多次增加或减少
- **影响判定**：情绪值决定玩家是否能获得特定意象

### 2. 意象系统 (ImaginaryTag)

意象是玩家通过事件获得的持久资源，用于诗词创作。每个意象包含：

- `uuid` - 意象唯一标识（如 "emotion:despair"）
- `name` - 显示名称
- `current_level` - 当前等级（0-2）
- `basic_imaginaries` - 结构化存储，包含获得上下文
- `l3_threshold` - 达到等级3的阈值

### 3. 情绪-意象连接机制

系统通过 `EmotionConfigs` 连接情绪和意象：

```gdscript
class EmotionConfigs:
    blueprint: ImaginaryTag           # 要获得的意象
    context_tags: Array[String]        # 叙事上下文
    requirements: BaseRequirements    # 获得条件（情绪校验）
```

## 数据流转

### 完整流程

```
1. 事件触发
   ↓
2. 玩家选择选项（包含 EmotionOperator）
   ↓
3. EmotionOperator 执行，改变玩家情绪
   PlayerState.change_emotion("sorrow", +15)
   ↓
4. ImaginaryManager.add_imagenary(event)
   ↓
5. 检查事件的 emotion_configs
   ↓
6. 对每个 emotion_config 执行 ImagenaryEvaluator.evaluate_single_config
   ↓
7. EmotionRequirement.compare(player_state)
   检查：player_state.get_emotion("sorrow") > 10 ?
   ↓
8. 如果校验通过：
   - 返回结构化数据 { blueprint, context_tags }
   - 调用 _append_tag(ima_blueprint, entry)
   - ImaginaryTag.basic_imaginaries.append(entry)
   ↓
9. 根据阈值更新意象等级
   ↓
10. 发送 EventBus.imaginary_changed 信号
```

### 关键决策点

#### 决策点1：情绪变化
- **位置**：事件的选项结果（choice_result.operators）
- **操作符**：`EmotionOperator`
- **效果**：`PlayerState.change_emotion(emotion_name, value)`
- **示例**：选择"挥手道别" → sorrow +15

#### 决策点2：意象校验
- **位置**：`EmotionConfigs.requirements`
- **校验器**：`EmotionRequirement`
- **条件**：`player_state.get_emotion(emotion_name) > threshold`
- **示例**：sorrow > 10 才能获得 despair 意象

#### 决策点3：意象获得
- **位置**：`ImaginaryManager._append_tag`
- **数据**：结构化存储 `{ "blueprint_id": String, "contexts": Array[String] }`
- **效果**：意象等级提升，可用于诗词创作

## 配置示例

### 事件配置示例 (normal_song_bie.tres)

```gdscript
# 1. 添加情绪操作符到选项结果
[sub_resource type="Resource" id="Resource_emotion_sorrow"]
script = ExtResource("6_emotion_op")
_emotion = 0  # ENUMS.EMOTION.SORROW
str_emotion = "sorrow"
value = 15

[sub_resource type="Resource" id="Resource_2hvti"]
script = ExtResource("3_fttgn")
operators = Array[ExtResource("1_ykdg5")]([
    SubResource("Resource_fcovv"),      # 原有的 stat_operator
    SubResource("Resource_emotion_sorrow")  # 新增的情绪操作符
])

# 2. 配置意象和情绪校验
[sub_resource type="Resource" id="Resource_emotion_req_sorrow"]
script = ExtResource("8_emotion_req")
volatile_stat = "sorrow"
value = 10
operator = 0  # GREATER_THAN

[sub_resource type="Resource" id="Resource_emotion_cfg_despair"]
script = ExtResource("7_emotion_cfg")
blueprint = ExtResource("9_imaginary_despair")
context_tags = Array[String](["farewell"])
requirements = SubResource("Resource_emotion_req_sorrow")

# 3. 在事件中添加 emotion_configs
[resource]
emotion_configs = Array[ExtResource("7_emotion_cfg")]([
    SubResource("Resource_emotion_cfg_despair"),
    # ... 其他意象配置
])
```

## 系统优势

### 1. 叙事一致性
- 玩家的情绪状态与游戏体验保持一致
- 送别事件增加 sorrow，只有 sorrow 高时才能获得 despair 意象

### 2. 策略深度
- 玩家需要考虑情绪管理
- 不同选择导向不同情绪，进而影响可获得的意象

### 3. 角色代入感
- 情绪系统反映角色的内心状态
- 意象获得需要相应的情感基础

### 4. 可扩展性
- 可以轻松添加新的情绪类型
- 可以为不同意象设置不同的情绪门槛
- 支持复杂的情绪组合条件

## 技术细节

### 情绪存储格式
- **存储位置**：`PlayerState.emotions: Dictionary`
- **键格式**：字符串（如 "sorrow", "ambition"）
- **值类型**：整数
- **转换函数**：`ENUMS.to_emotion_str(enum_value)`

### 情绪校验逻辑
```gdscript
func EmotionRequirement.compare(player_state: PlayerState) -> bool:
    var stat_front = player_state.get_emotion(volatile_stat)
    if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
        return stat_front < value
    else:
        return stat_front > value
```

### 意象等级规则
- **Level 1**: basic_imaginaries.size() < l2_threshold (2)
- **Level 2**: l2_threshold <= basic_imaginaries.size() <= l3_threshold
- **Level 3**: basic_imaginaries.size() > l3_threshold (4)

## 注意事项

1. **情绪平衡**：需要确保情绪的增加和消耗平衡，避免某些情绪永远过高或过低
2. **校验合理性**：情绪门槛应该合理，既不太容易也不太难
3. **叙事一致性**：事件的情绪效果应该与事件内容匹配
4. **反馈清晰**：玩家应该能清楚看到自己的情绪状态和意象获得条件

## 未来扩展

### 可能的增强功能
1. **情绪衰减**：情绪随时间自然衰减
2. **情绪组合**：支持多个情绪的组合条件（如 sorrow AND anger）
3. **情绪互斥**：某些情绪互斥，不能同时过高
4. **性格影响**：人物原型影响情绪变化的敏感度
5. **动态门槛**：情绪门槛根据游戏进程动态调整