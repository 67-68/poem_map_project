# 大唐诗词可视化 - 架构总览 (MOC)

> **📘 文档导航入口**：本文档是整个项目的架构总览，所有细分文档都从这里链接出去。建议从这里开始阅读，然后根据需要深入具体文档。

## 1. 核心循环 (Core Loop)
- **场景Action与玩家标签匹配机制** [scene_action_and_player_tag_filter.md](scene_action_and_player_tag_filter.md)
  > 两层过滤系统：地理维度（地区标签匹配）+ 行为维度（动态标签事件触发）
- **玩家当前Action标签生命周期** [[player_current_action_tag_life_cycle.md]](player_current_action_tag_life_cycle.md)
  > 临时标签池的注入、使用、清除流程，以及@export序列化风险分析

## 2. 基础设施 (Infrastructure)
- **UI 消息流转契约** [info_demonstration.md](info_demonstration.md)
  > 包括：错误信息弹窗 (NotificationUI) 的层级和调用方式，以及三种UI消息类型的规范使用

## 3. 数据层 (Data Persistence)
- **标签体系设计规范** [tag_pattern_confliction.md](tag_pattern_confliction.md)
  > 三段式到四段式的演进，TagManager标准化机制，向后兼容策略
- **历史Bug记录** [old_bugs.md](old_bugs.md)
  > 已修复问题的归档记录，包括根本原因分析和修复方案

---

## 📝 文档维护说明
- 所有文件名使用下划线分隔，避免特殊字符
- 新增文档时请在此处添加对应的链接
- 保持文档分类与实际架构层级一致