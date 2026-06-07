# 情绪·意象事件系统 速览

> ⚠️ **此文档的 4×4 方案已被替代。**
> 完整最新架构见：[`plans/emotion_imagery_orthogonal_pipeline_v2.md`](emotion_imagery_orthogonal_pipeline_v2.md)
>
> **替代原因：** 旧方案仍停留在"情绪映射意象"的唯心主义路线。V2 升级为"场景圈定实体池 → 实体自带情绪亲缘度 → 按需打分选择"的唯物主义路线，彻底解决 OOC 问题。

## 速览

### 情绪的本质

情绪(Emotion)是 **连续属性(Prop)**，不是掉落物。它是行为的 **伴生物(Byproduct)**，不是战利品。上限 100，写诗后对应情绪减半——"一吐为快"。

### 三大获取通道

| 通道 | 触发 | DSL 示例 |
|------|------|---------|
| **主动兑换** | 花钱听曲、喝酒交游 | `prop_add(name=TRANQUILITY; val=15)` |
| **选择残渣** | 叙事选项的副作用 | `prop_add(name=SORROW; val=15)` |
| **环境渲染** | 季节/地点被动注入 | 秋季每旬 SORROW +2 |

### on_enter 三种注入模式

- **A / 单点刺穿**：只加 1 种情绪，中高数值（最常用）
- **B / 零和博弈**：情绪 +20，对立情绪 -20（内心冲突）
- **C / 催化剂**：1 种情绪 + AMBITION（驱动剧情）

### 多分支选项模式

用 `requirements`（如 `prop_gt(name=ARROGANCE; val=20)`）守卫不同选项。每个选项产出对应情绪标签的意象。亮点：

- 玩家没积累 ANGER → 看不到"拍桌而起"的选项（灰色锁定本身就是叙事）
- 必须有无条件兜底选项，防止死锁
- 仅关键节点（≤30 个）使用，日常事件不用

### Gameplay 闭环

```
蓄水(攒情绪) → 爆发(夺意象) → 变现(写绝句) → 消耗(情绪清空)
```

---

# 正交事件生成器 V2 速览

## 核心变更

从 5 维穷举（3125 事件）降维到 2 维锚点法（~100 事件）。

### 两维定义

| 维度 | 内容 | 取值数 |
|------|------|--------|
| **场景模板 (Scene Template)** | 大唐核心场景，自带 Tag 预设和意象白名单 | 10 个 |
| **情绪滤镜 (Emotion Filter)** | 6 单情绪或 3 对立对 | 6 或 3 |

### 意象掉落机制（核心升级）

意象不是由情绪"生成"的，而是：

```
场景提供物理合法意象池（白名单）
    → 每个意象有情绪亲缘度（0-100）
        → 按情绪打出最高分的意象掉落
            → 最高分 < 30 则丢弃该组合
```

### 生成量

| 模式 | 组合数 | 说明 |
|------|--------|------|
| 单情绪事件 | 10×6=60 | 1 精英 + 1 兜底 |
| 对立分支事件 | 10×3=30 | 2 精英 + 1 兜底 |
| 无情绪日常 | 10 | 纯场景渲染 |
| **总计** | **~100** | 可玩事件库 |

## 关键文件

- 完整架构文档： [`plans/emotion_imagery_orthogonal_pipeline_v2.md`](emotion_imagery_orthogonal_pipeline_v2.md)
- Python 配置模型： [`tools/config.py`](../tools/config.py)
- 生成脚本： [`tools/generate_orthogonal_events.py`](../tools/generate_orthogonal_events.py)
- 五维宪法： [`DOCUMENTATIONS/events/tag_dictioinary.md`](../DOCUMENTATIONS/events/tag_dictioinary.md)

## 用法（即将变更）

> 注意：当前生成器仍使用 3 维度旧模式。V2 扩展后将新增 `--mode emotion` 标志。

```bash
export DEEPSEEK_API_KEY="sk-xxx"
python3 tools/generate_orthogonal_events.py --config tools/emotion_events_config.json
```

产出 CSV → Godot 中点击 `import_generated_events` 按钮 → 事件进入事件池。
