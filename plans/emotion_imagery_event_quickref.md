# 情绪·意象事件系统 速览

## 情绪的本质

情绪(Emotion)是 **连续属性(Prop)**，不是掉落物。它是行为的 **伴生物(Byproduct)**，不是战利品。上限 100，写诗后对应情绪减半——"一吐为快"。

## 三大获取通道

| 通道 | 触发 | DSL 示例 |
|------|------|---------|
| **主动兑换** | 花钱听曲、喝酒交游 | `prop_add(name=TRANQUILITY; val=15)` |
| **选择残渣** | 叙事选项的副作用 | `prop_add(name=SORROW; val=15)` |
| **环境渲染** | 季节/地点被动注入 | 秋季每旬 SORROW +2 |

## on_enter 三种注入模式

- **A / 单点刺穿**：只加 1 种情绪，中高数值（最常用）
- **B / 零和博弈**：情绪 +20，对立情绪 -20（内心冲突）
- **C / 催化剂**：1 种情绪 + AMBITION（驱动剧情）

## 多分支选项模式

用 `requirements`（如 `prop_gt(name=ARROGANCE; val=20)`）守卫不同选项。每个选项产出对应情绪标签的意象。亮点：

- 玩家没积累 ANGER → 看不到"拍桌而起"的选项（灰色锁定本身就是叙事）
- 必须有无条件兜底选项，防止死锁
- 仅关键节点（≤15 个）使用，日常事件不用

## Gameplay 闭环

```
蓄水(攒情绪) → 爆发(夺意象) → 变现(写绝句) → 消耗(情绪清空)
```

---

# 正交事件生成器 速览

## 它解决什么问题

批量生产结构相同、但叙事色彩和数值不同的**单线事件**。管线根据维度组合自动计算数值 Scale，调用 LLM 生成文本，直接输出 DSLParser 兼容 CSV。

## 核心概念

### 正交矩阵

3 个维度，每个维度若干取值 → 笛卡尔积展开为 N 个事件。每个事件 = 维度值组合 × AI 文本。

### Scale 机制

每个维度值有 `scale` 乘数，组合后的 `final_scale = dim1.scale × dim2.scale × dim3.scale`，所有 DSL 数值乘以该系数。Scale 跨维度累积，高阶组合自动产生更大数值。

### 三件套配置

| 组件 | 职责 |
|------|------|
| `dimensions` | 正交轴定义（3 个维度，各含若干取值） |
| `prompt_features` | 风格挂件，注入 AI Prompt 微调文风 |
| `option_features` | 选项模板，定义 AI 为哪些选项生成文本 |
| `universal_*` | 所有事件共享的 requirement、result、trigger_tags |

## 文件位置

- Python 配置模型： [`tools/config.py`](tools/config.py)
- 生成脚本： [`tools/generate_orthogonal_events.py`](tools/generate_orthogonal_events.py)
- 示例配置： [`tools/bai_ye_honeymoon_config.json`](tools/bai_ye_honeymoon_config.json)
- 输出目录： `data/generated_events/`
- Godot 导入： `core/csv_cloud_loader.gd` → `import_generated_events`

## 管线边界

正交管线**只做单线事件**——一个事件带一个选项（或一组同质选项，结果 DSL 相同）。**多分支事件**（不同选项有不同 requirement 和不同结果）不属于它的职责范围，应手工配置 CSV。

## 用法

```bash
export DEEPSEEK_API_KEY="sk-xxx"
python3 tools/generate_orthogonal_events.py --config tools/bai_ye_honeymoon_config.json

# dry-run 只看 prompt 不调 API
python3 tools/generate_orthogonal_events.py --dry-run
```

产出 CSV → Godot 中点击 `import_generated_events` 按钮 → 事件进入事件池。

## 扩展到情绪事件（4×4 方案）

```
Dimension 1: 叙事场景 (Narrative Scene)
  ├── 艺术观赏 (scale=1.0)
  ├── 社交冲突 (scale=1.5)
  ├── 自然景物 (scale=1.0)
  └── 仕途机遇 (scale=2.0)

Dimension 2: 情绪守卫 (Emotion Guard)
  ├── SORROW (悲)    → requirement=prop_gt(name=SORROW; val=20)
  ├── ANGER (愤)     → requirement=prop_gt(name=ANGER; val=20)
  ├── ARROGANCE (狂) → requirement=prop_gt(name=ARROGANCE; val=20)
  └── TRANQUILITY (旷)→ requirement=prop_gt(name=TRANQUILITY; val=20)
```

每个组合生成一个单分支事件：1 个精英选项（情绪守卫 + 意象）+ 1 个兜底选项。4×4=16 个事件，完美适配现有管线架构。
