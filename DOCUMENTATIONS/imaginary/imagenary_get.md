## 🎯 主要获取方式：通过随机事件

当系统触发一个 **RandomEvent** 类型的事件时，会自动获得对应的 imagenary：

1. **触发条件：** `EventBus.event_shown` 信号发出时（事件展示给玩家）
2. **处理流程：** <ref_file file="/Users/a67_68/projects/dufu_simulator/core/imaginary_manager.gd" lines="3-21" />
   - 只处理 `RandomEvent` 类型的事件
   - 遍历事件的 `target_tags` 数组
   - 通过 tag 的四段式格式（如 `prefix:imaginary_uuid:suffix:general`）提取对应的 `ImaginaryTag`
   - 将 tag 添加到该 imaginary 的 `basic_imaginaries` 数组中

## 📊 等级晋升机制

每个 imaginary 有累积计数，达到阈值自动升级：<ref_file file="/Users/a67_68/projects/dufu_simulator/core/imaginary_manager.gd" lines="31-44" />

- **Level 3：** 当 `basic_imaginaries.size() > l3_threshold`
- **Level 2：** 当 `basic_imaginaries.size() >= l2_threshold`  
- **Level 1：** 默认等级

## 🔧 手动添加方式

通过 `EventBus.request_add_imaginary` 信号可以直接添加特定 tag：<ref_file file="/Users/a67_68/projects/dufu_simulator/core/imaginary_manager.gd" lines="23-29" />

## 💡 用途

Imagenary 主要用于解锁传奇诗词（Legendary Poem），需要满足特定需求和等级：<ref_file file="/Users/a67_68/projects/dufu_simulator/core/event_manager.gd" lines="42-44" />

简单说：**通过触发随机事件积累意象标签，标签越多等级越高，高等级意象是创作传奇诗词的必要条件。** 🎭