# Old Bugs

## 2026-05-23: 标签格式不一致导致事件匹配失败

### 问题描述
Scene Action的`action_tags`和Random Event的`target_tags`之间存在标签格式不一致问题，导致事件匹配失败。

### 根本原因
- **Action.action_tags生成过程**：通过`ENUMS.to_action_str()`将枚举转换为字符串，只做下划线→冒号转换，产生三段式标签（如`actor:health:sick`）
- **Event.target_tags生成过程**：通过`TagManager.normalize_3part_depreciated_tag()`标准化，自动将三段式补全为四段式（如`actor:health:sick:general`）
- **匹配逻辑**：使用精确字符串匹配`if e.target_tags.has(tag)`
- **结果**：三段式标签无法匹配四段式标签，导致事件触发失败

### 影响范围
- 所有基于旧枚举的Scene Action都可能触发不了对应的事件
- 潜在影响游戏核心功能（事件系统）

### 修复方案
1. 在注入`current_action_tags`时统一使用`TagManager.normalize_3part_depreciated_tag()`标准化标签
2. 在`ActionTagFilter.filter()`中添加检查，发现三段式标签时push_error警告
3. 修改所有注入点：
   - `scene_action_panel.gd` - 执行Action时
   - `time_operator.gd` - 时间流逝时
   - `poem_crafter.gd` - 制作诗词时
   - `survival_manager.gd` - 已是四段式，无需修改

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/ui/scene_action_panel.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/model/action_tag_filter.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/model/time_operator.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/ui/poem_crafter.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/core/survival_manager.gd" />

## 2026-05-24: 枚举重构后RandomEvent数据文件未同步导致tag值超出范围

### 问题描述
在`random_event.gd`第10行调用`ENUMS.to_action_str(tag)`时，tag值为44，触发断点失败。实际`ACTION_TAGS`枚举只有25个值（0-24），但RandomEvent数据文件中存储了超出范围的枚举索引。

### 根本原因
- **枚举重构**：之前删除了部分`ACTION_TAGS`枚举值，枚举总数减少到25个（0-24）
- **RandomEvent数据未同步**：RandomEvent的.tres文件中`_action_tags`数组包含超出当前枚举范围的旧索引，而Action文件保持正常
- **具体问题文件**：
  - `normal_bai_ye.tres`: `_action_tags = Array[int]([44, 30, 36, 35, 37, 39])` ❌
  - 其他RandomEvent文件可能也存在类似问题
- **Action文件正常**：`data/tres_actions/bai_ye.tres`的`_action_tags = Array[int]([4, 9, 10, 14, 18])` ✅ 在有效范围内

### 影响范围
- 包含超出范围枚举值的RandomEvent资源文件
- 导致调用`ENUMS.to_action_str()`时触发断点breakpoint，无法正确转换标签
- 影响事件系统的标签匹配功能，RandomEvent无法正确筛选和触发

### 修复方案
1. 在Godot编辑器中重新打开并保存所有受影响的RandomEvent .tres文件
2. 确保每个`_action_tags`数组中的值都在当前`ACTION_TAGS`枚举的有效范围内（0-24）
3. 验证修复后运行event_action_tag_linter确保没有遗留的无效标签

### 修复文件
- <ref_file file="/Users/lennon/Projects/poem_map_project/data/tres_random_event/normal_bai_ye.tres" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/model/enumerates.gd" />
- <ref_file file="/Users/lennon/Projects/poem_map_project/model/random_event.gd" />


### 2025.05.25
@enumerates 中action tag非真正四段式 + 中间有个_ + 新的deepseek action是三段式，在 @action tag filter导致问题，因为它会自动补全3段 -> 4, 导致deepseek action 和 target tag无法匹配
准确来说不是这里，前面的某个环节导致了问题

### 2025.05.25
没有！清空！缓存！
使用！create_resources_registry!

### 2025.05.25
如果在@tool有问题，那么重启编辑器