# AI 行为约束：项目规则约定

## 背景

团队使用 Roo Code (AI coding assistant)。为了让 AI 理解项目约束，需要一种机制来注入全局规则。

## 约定：`.roo/rules/`

我们选择将**所有项目级 AI 约束**放在 `.roo/rules/` 目录下。该目录下的每个 `.md` 文件会被自动注入到每个 AI 模式的系统提示词开头。

当前已生效的规则见 [`.roo/rules/core-conventions.md`](/.roo/rules/core-conventions.md)（Godot headless、Docker 执行、版本锁定）。

## 为什么用这个方案

- **声明式**：加一个 `.md` 文件就行，不需要改配置
- **所有模式一致**：不管是 code、debug、architect 模式，都强制遵守
- **可追踪**：规则文件在 git 里，变更历史清晰

## 新增规则

直接在 `.roo/rules/` 下创建 `.md` 文件，reload 后自动生效。
