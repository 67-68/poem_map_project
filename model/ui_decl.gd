@tool
class_name UIDecl extends Resource

# ╔══════════════════════════════════════════════════════════════════╗
# ║  EventUIDecl — BaseEvent 的 UI 声明数据类                         ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# 职责：
#   将 BaseEvent 中与 UI 呈现相关的可配置属性收敛到一个独立的 Resource
#   子类中。NarrativeOverlay / EventUI 读取此数据类即可获知当前事件的
#   全部 UI 呈现策略，无需翻阅 BaseEvent 的多个分散字段。
#
# 契约：
#   - 纯数据容器，不包含任何逻辑
#   - 所有字段均为 @export，可在 .tres 中直接编辑
#   - 字段语义与 BaseEvent 上同名字段完全等价（如迁移则直接引用此对象）

# ── 显示速度枚举（纯数据标记） ──────────────────────────
# FAST=0:  瞬间填充所有 UI 元素（默认，适用日常/随机事件）
# SLOW=1:  打字机逐阶段显示（适用 story_arcs 线性剧本）
# SLOWEST=2: 更慢的打字机速度
enum DisplaySpeed { FAST = 0, SLOW = 1, SLOWEST = 2 }

@export var display_speed: int = DisplaySpeed.FAST

# ── 自动推进超时（秒）───────────────────────────────────
# 0 选项 + lasting_time > 0 → 展示后自动关闭
# 1 选项 + lasting_time > 0 → 自动选择该选项
# lasting_time == 0 → 退化为现有行为（手动选择/跳过）
# 在 BaseEvent.init() 中：context 有 lasting_time key → 覆盖此值
@export var lasting_time: float = 0.0

# ── 背景音乐 ────────────────────────────────────────────
@export var audio: AudioStream = null

# ── 墓志铭文本 ──────────────────────────────────────────
# 事件结束后印在纸带上的铭文
@export var epitaph_text: String = ''

# ── 例文文本 ────────────────────────────────────────────
# 事件条目中展示的引用诗文或示例文本
@export var example: String = ''

@export_enum('gold', 'white') var color_of_title_text = ''
@export_enum('gold', 'white', 'zhusha_red') var color_of_default_text = ''
@export var background_narrative: Texture2D = null

## NarrativeOverlay 纸带入场动画策略
## 0 = ANIMATION_STRATEGY.DEFAULT（从顶部滑入）
## 1 = ANIMATION_STRATEGY.SLIDE_FROM_BOTTOM（从底部滑入）
@export var animation_strategy: int = 0

# ── 颜色解析（静态工具方法）────────────────────────────

static func resolve_color(enum_value: String, palette: String = 'title') -> Color:
	match palette:
		'title':
			match enum_value:
				'gold':
					return Color(0.898, 0.788, 0.188, 1.0)
				'white':
					return Color.WHITE
		'default':
			match enum_value:
				'gold':
					return Color(0.898, 0.788, 0.188, 1.0)
				'white':
					return Color.WHITE
				'zhusha_red':
					return Color(0.74, 0.20, 0.12, 1.0)
	return Color()