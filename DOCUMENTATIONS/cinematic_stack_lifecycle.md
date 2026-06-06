# Cinematic 栈生命周期文档

> 本文档解释了 Cinematic Overlay (过场文字序列) 在 NarrativeOverlay 栈系统中的完整生命周期、调用链、以及如何测试。

---

## 1. 核心概念：Cinematic 作为第 3 种栈条目

[`NarrativeOverlay`](characters/narrative_overlay.gd) 的 `_event_stack` 支持三种条目类型：

| 条目类型 | type 字段 | 生命周期管理 | 世界暂停 |
|---------|-----------|-------------|---------|
| `BaseEvent` | 无（默认） | PopEventOperator 显式 pop | ✅ |
| `Picker` | `"picker"` | `_on_end_picking` 回调后自动 pop | ✅ |
| `Cinematic` | `"cinematic"` | 播完后自动 pop | ✅ |

Cinematic 的实现原则：**像 Picker 一样是事件的临时模态子层**，播完后自销毁，不污染栈。

---

## 2. 栈状态流转

```
初始栈状态:
┌─────────────┐
│  事件 B      │  ← 通过 PushEventOperator 推入的栈事件
├─────────────┤
│  事件 A      │  ← 父事件
└─────────────┘

事件 B 的 consequence 执行 play_transition:
┌─────────────┐
│  Cinematic   │  ← 推入栈顶
├─────────────┤
│  事件 B      │
├─────────────┤
│  事件 A      │
└─────────────┘

Cinematic 播放完毕后自动 pop:
┌─────────────┐
│  事件 B      │  ← _process_next() 重新展示
├─────────────┤
│  事件 A      │
└─────────────┘
```

---

## 3. 完整调用链

### Phase 1: DSL 解析 → 操作符创建

```
DSL: play_transition(texts=["天宝四年...", "你踏入长安..."])
  └─ MicroDSLParser._exec_play_transition_op()
       ├─ 解析 texts 参数（支持 Array / PackedStringArray / 单字符串）
       ├─ 创建 PlayTransitionOperator
       └─ 设置 op.texts = ["天宝四年...", "你踏入长安..."]
```

### Phase 2: 事件 consequence 执行 → 推入栈

```
ConsequenceExecuter.execute_result(choice)
  └─ PlayTransitionOperator.operate()
       └─ EventBus.push_cinematic.emit(texts)
            └─ NarrativeOverlay._on_push_cinematic(texts)
                 ├─ 构造条目: { type: "cinematic", texts: [...], processed: false }
                 ├─ _event_stack.push_front(entry)
                 └─ if not _is_active: _process_stack()
                      ← 🔒 _is_active 在 execute_result 期间为 true，不触发
```

### Phase 3: `_is_active` 释放 → 播放 Cinematic

```
is_active = false
_process_next()
  └─ _process_stack()
       ├─ peek _event_stack[0]
       ├─ entry.type == "cinematic" → _show_cinematic_from_stack(entry)
       │    ├─ _is_active = true
       │    ├─ _saved_time_scale = Engine.time_scale
       │    ├─ TimeService.pause_world(true)
       │    │
       │    ├─ EventBus.cinematic_start.emit(texts)
       │    │    └─ CinematicOverlay._on_cinematic_start(texts)
       │    │         ├─ show()
       │    │         ├─ 淡入 (dimmer + text_label)
       │    │         ├─ 逐段打字机效果 + 淡入淡出切换
       │    │         ├─ 最终淡出
       │    │         ├─ hide()
       │    │         └─ EventBus.cinematic_finished.emit()
       │    │
       │    ├─ await EventBus.cinematic_finished  ← 等待过场播完
       │    │
       │    ├─ _event_stack.pop_front()  ← ✅ 自销毁
       │    ├─ TimeService.resume_world()
       │    ├─ Engine.time_scale = _saved_time_scale
       │    ├─ _is_active = false
       │    └─ _process_next()  ← 处理下一个栈/队列事件
       │
       └─ ... 下一个事件（事件 B 或其他）
```

---

## 4. CinematicOverlay 内部实现

### 节点结构

```
CinematicOverlay (CanvasLayer, layer=128)
  ├─ Dimmer (ColorRect) — 全屏黑色遮罩，初始 alpha=0
  └─ TextLabel (RichTextLabel) — 居中显示，初始 alpha=0
```

### API

```gdscript
# 公开 API（可直接调用）
func play_text_sequence(texts: Array[String], config: Dictionary = {}) -> void
  # config 可选字段:
  #   typewriter_speed: float (默认 0.05 秒/字)
  #   fade_duration: float (默认 0.5 秒)
  #   text_pause_duration: float (默认 1.5 秒，每段播完后停留)

# 信号
signal finished()  # 播放完毕（无论是通过 EventBus 触发还是直接调用）
```

### EventBus 自动接入

```gdscript
# _ready() 时自动连接
EventBus.cinematic_start.connect(_on_cinematic_start)

# _on_cinematic_start 自动调用 play_text_sequence
# 播完后自动 emit cinematic_finished
```

---

## 5. DSL 使用示例

### 在事件的 consequence 列中

```
play_transition(texts=["天宝四年，秋。", "你带着半生积蓄，踏入长安。"])
```

### 在代码中直接调用

```gdscript
# 方法 1: 通过 EventBus 推入栈（推荐，与事件系统集成）
EventBus.push_cinematic.emit(["第一段", "第二段", "第三段"])

# 方法 2: 直接调用 CinematicOverlay（不经过栈，独立播放）
var cinematic = $CinematicOverlay  # 或通过唯一名称获取
await cinematic.play_text_sequence(["段落1", "段落2"])
```

### 自定义配置

```
play_transition(texts=["快速淡入"], config={fade_duration=0.2, typewriter_speed=0.02})
```

---

## 6. 信号总线

[`EventBus`](core/eventbus.gd) 中与 Cinematic 相关的信号：

| 信号 | 发射者 | 接收者 | 载荷 |
|------|--------|--------|------|
| `push_cinematic` | `PlayTransitionOperator.operate()` | `NarrativeOverlay._on_push_cinematic()` | `texts: Array[String]` |
| `cinematic_start` | `NarrativeOverlay._show_cinematic_from_stack()` | `CinematicOverlay._on_cinematic_start()` | `texts: Array[String]` |
| `cinematic_finished` | `CinematicOverlay._on_cinematic_start()` | `NarrativeOverlay._show_cinematic_from_stack()` | 无 |

完整的信号时序：

```
push_cinematic ──→ NarrativeOverlay 推入栈
                      │
                      ▼ (当 _is_active 释放后)
cinematic_start ──→ CinematicOverlay 开始播放
                      │
                      ▼ (播放完毕)
cinematic_finished ──→ NarrativeOverlay pop 栈条目 + _process_next()
```

---

## 7. 竞态保护

### `_is_active` 锁

与 Picker 完全相同的保护机制 — `_show_cinematic_from_stack()` 在 `await` 之前设置 `_is_active = true`，防止 `cinematic_finished` 等待期间的其他栈操作触发嵌套处理。

### 防重复播放

```gdscript
# cinematic_overlay.gd
func _on_cinematic_start(texts: Array[String]) -> void:
    if _is_playing:
        Logging.warn("CinematicOverlay: 正在播放中，忽略重复请求")
        return
```

---

## 8. 测试指南

### 手动测试

1. 在 controller 中输入:
   ```
   $ dsl play_transition(texts=["测试段落1", "测试段落2"])
   ```
2. 观察 CinematicOverlay 是否显示黑屏 + 打字机文字
3. 观察结束后是否自动恢复世界
4. 测试与事件/Picker 的互斥：Cinematic 播放时不应有其他 UI 干扰

### 边界情况

- **空 texts 数组**: 应跳过播放，emit finished 但无视觉效果
- **typewriter_speed = 0**: 应瞬间显示所有文字
- **单段文字**: 不应有淡入淡出切换动画
- **冲突测试**: Cinematic 播放中触发事件 → 事件应入队等待
- **快速连续触发**: 第二次应被 _is_playing 保护忽略
