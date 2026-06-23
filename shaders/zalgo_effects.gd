@tool
extends RichTextEffect
class_name RichTextGlitch

# ── BBCode 标签名 ────────────────────────────────────────
var bbcode = "glitch"

# ── 后备参数 ──────────────────────────────────────────────
## 当 BBCode 标签未提供参数时，回退到此字典。
## 调用方通过实例变量传入：
##   glitch_fx.fallback_params = {"level": 5.0, "color_shift": 0.8}
## 优先级：char_fx.env (标签参数) > fallback_params > 硬编码默认值
@export var fallback_params: Dictionary = {}

# ── 默认值 ────────────────────────────────────────────────
const DEFAULT_LEVEL: float = 2.0
const DEFAULT_COLOR_SHIFT: float = 0.5
const COLOR_SHIFT_THRESHOLD: float = 0.8

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
    var time = char_fx.elapsed_time

    # 参数读取：标签 env → 实例 fallback_params → 硬编码默认值
    var level: float = DEFAULT_LEVEL
    var color_shift: float = DEFAULT_COLOR_SHIFT

    var env_level = char_fx.env.get("level", null)
    if env_level != null:
        level = env_level as float
    elif fallback_params.has("level"):
        level = fallback_params.get("level", DEFAULT_LEVEL) as float

    var env_shift = char_fx.env.get("color_shift", null)
    if env_shift != null:
        color_shift = env_shift as float
    elif fallback_params.has("color_shift"):
        color_shift = fallback_params.get("color_shift", DEFAULT_COLOR_SHIFT) as float

    # 字符位移
    var noise_x = (randf() - 0.5) * 2.0 * level
    var noise_y = (randf() - 0.5) * 2.0 * level
    char_fx.offset = Vector2(noise_x, noise_y)

    # 颜色偏移：模拟电压不稳
    if randf() > 1.0 - color_shift:
        char_fx.color = char_fx.color.lerp(Color.WHITE, 0.5)

    return true