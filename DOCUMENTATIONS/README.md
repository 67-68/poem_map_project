# 项目文档目录

本目录包含大唐诗词可视化项目的所有技术文档。

## 📘 快速导航

- **架构总览**：从 [architecture_moc.md](architecture_moc.md) 开始，了解整体架构和文档索引
- **核心功能**：查看核心循环相关文档，了解Action、标签、事件匹配机制
- **基础设施**：查看UI、消息流转等基础设施文档
- **数据层**：查看标签体系、数据结构等文档

## 📂 文档分类

### 1. 核心循环 (Core Loop)
- `scene_action_and_player_tag_filter.md` - 场景Action与玩家标签匹配机制
- `player_current_action_tag_life_cycle.md` - 玩家当前Action标签生命周期

### 2. 基础设施 (Infrastructure)
- `info_demonstration.md` - UI消息流转契约

### 3. 数据层 (Data Persistence)
- `dsl_documentation.md` - DSL功能和使用文档
- `dsl_csv_structure_guide.md` - DSL CSV表格结构指南
- `tag_pattern_confliction.md` - 标签体系设计规范
- `old_bugs.md` - 历史Bug记录

### 4. 架构与质量保证 (Architecture & QA)
- `linter_architecture_refactoring.md` - Event Data Linter架构重构文档

### 5. 资源标识层 (URN System)
- `urn_system.md` - 统一资源名称标识符系统，定义所有数据类型的 URN 协议
- `how_to_add_data_type.md` - 新增数据类型操作手册，列出需要改哪些文件

### 6. 诗词类型表 (Poem Types)
诗词 trait 的 `specific_topic` 字段使用以下枚举值，对应 `ENUMS.POEM_TYPE`：
| 枚举值 | 中文含义 | 说明 |
|-------|---------|------|
| `GAN_YE` | 干谒 | 求仕、拜谒相关 |
| `YING_ZHI` | 应制 | 奉和、应诏相关 |
| `DENG_GAO` | 登高 | 登临、望远相关（原误标为 ZENG_DA） |
| `HUAI_GU` | 怀古 | 咏史、怀古相关 |
| `JI_LV` | 羁旅 | 行旅、漂泊相关 |
| `SHAN_SHUI` | 山水 | 山水、田园相关 |
每个诗词 trait 的 `specific_topic` 必须严格匹配上表枚举值，大小写一致。

## 🛠️ 文档规范

- 文件名使用下划线分隔，避免特殊字符和空格
- 新增文档时需在 `architecture_moc.md` 中添加对应链接
- 保持文档分类与实际架构层级一致
- 优先使用 `ref_file` 和 `ref_snippet` 标签引用代码

## 📝 维护日志

- 2026-05-26: 完成Event Data Linter架构重构，建立契约设计模式和Rule流水线架构，消除反射依赖，性能提升约100倍
- 2026-05-26: 创建Linter架构重构文档，记录契约设计、流水线架构、数据抽象层等核心设计决策
- 2026-05-25: 更新DSL文档和CSV指南中的标签格式说明，采用最新的四段式标签规范（domain:category:type:specific），同时保持三段式向后兼容
- 2026-05-25: 创建DSL CSV表格结构指南，提供完整的CSV格式规范和示例数据
- 2026-05-25: 创建DSL功能和使用文档，整理DSL语法、标签体系、条件系统等核心内容
- 2026-05-23: 整理文档结构，统一文件命名规范，建立architecture_moc.md作为总览入口

## 键位
cmd + f1 -> 展示debug info
cmd + f2 -> show terminal
R -> emotional radar
S -> Social wall panel

## CI/CD工具
使用@googlesheet fetcher.tscn来获取线上修改