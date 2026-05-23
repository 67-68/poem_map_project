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