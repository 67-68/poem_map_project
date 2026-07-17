# StartLine — 入口场景路线可视层

## 涉及文件

| 文件 | 作用 |
|------|------|
| [`ui/start_line.gd`](ui/start_line.gd) | Line2D 脚本 — hover 触发曲线绘制与 Tween 动画 |
| [`ui/main_page.tscn`](ui/main_page.tscn) | 场景 — 包含 Line2D 节点与触发节点 PanelContainer |

## 功能意图

在入口场景的「京」标签 hover 2s 后，从起点 (665, 240) 到终点 (560, 310) 以 Bézier 曲线方式绘制一条路线。曲线中点在两个端点之间随机 jitter（±30px），每次 hover 重新随机。使用 width + alpha tween 驱动线的出现/消失，ease-in-out 过渡。mouse leave 时线消失（反向动画）。

## 状态转换

```
       mouse_entered          2s timeout (仍在 hover)
IDLE ──────────────▶ WAITING ──────────────────────────▶ VISIBLE
 ◄────────────────            ◄───────────────────────
   mouse_exited                  mouse_exited + tween_done
```

## 技术要点

- 不接入 HoverPopupManager，直接用 mouse_entered/mouse_exited + Timer
- 动态生成 Curve2D 三控点 Bézier：起点 → jittered 中点 → 终点
- Tween：width(0→3), modulate.a(0→1) 出现；反向退出
- 每次 hover 重新 jitter 中点，不缓存
