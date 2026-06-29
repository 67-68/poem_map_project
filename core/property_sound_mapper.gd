class_name PropertySoundMapper extends Object
## 属性变化音效映射器 (Property Sound Mapper)
##
## 职责：根据属性名和变化量，通过三级 fallback 级联查找匹配的音效文件。
## 纯查找工具类，不负责播放（播放由 AudioManager 统一管理）。
##
## 查找级联：
##   Step 1: named_amount key 精确匹配 → property/{key}.{ogg,wav,mp3}
##   Step 2: 属性名_方向 fallback → property/{prop}_{direction}.{ogg,wav,mp3}
##   Step 3: 仅属性名 fallback → property/{prop}.{ogg,wav,mp3}
##
## 方向推导: delta > 0 → "gain", delta < 0 → "loss"
##
## 音效文件路径: res://assets/sounds/property/
##
## Debug 要求：每个分支都存在 logging 日志

const LOG_TAG := "PropertySoundMapper"
const SOUND_DIR := "res://assets/sounds/property/"
const SUPPORTED_EXTENSIONS := ["ogg", "wav", "mp3"]


## 根据属性名和变化量获取音效流
## 返回 AudioStream 或 null（未找到时静默跳过）
static func get_property_sound(prop_name: String, delta: int) -> AudioStream:
	if delta == 0:
		Logging.debug("%s: delta=0, 跳过音效" % LOG_TAG)
		return null

	if prop_name.is_empty():
		Logging.debug("%s: prop_name 为空, 跳过音效" % LOG_TAG)
		return null

	# ── Step 1: named_amount key 精确匹配 ──
	# 通过 NamedDSLParser 的反向查表，找到 value + prop 都匹配的 key
	var stream = _try_exact_named_amount_match(prop_name, delta)
	if stream:
		Logging.info("%s: Step1 精确匹配成功: prop=%s, delta=%d" % [LOG_TAG, prop_name, delta])
		return stream

	# ── Step 2: 属性名_方向 fallback ──
	var direction = "gain" if delta > 0 else "loss"
	stream = _try_load_file(prop_name + "_" + direction)
	if stream:
		Logging.info("%s: Step2 属性+方向 fallback 成功: %s_%s" % [LOG_TAG, prop_name, direction])
		return stream

	# ── Step 3: 仅属性名 fallback ──
	stream = _try_load_file(prop_name)
	if stream:
		Logging.info("%s: Step3 仅属性名 fallback 成功: %s" % [LOG_TAG, prop_name])
		return stream

	# ── 全部未命中 ──
	Logging.debug("%s: 未找到匹配音效: prop=%s, delta=%d" % [LOG_TAG, prop_name, delta])
	return null


## 根据意象等级获取升级音效
static func get_imaginary_sound(level: int) -> AudioStream:
	if level < 1 or level > 3:
		Logging.warn("%s: 意象等级 %d 超出有效范围 [1,3]，无音效" % [LOG_TAG, level])
		return null

	var stream = _try_load_file("imaginary_gain_t%d" % level)
	if stream:
		Logging.info("%s: 意象升级音效匹配成功: level=%d" % [LOG_TAG, level])
		return stream

	Logging.debug("%s: 意象升级音效未找到: level=%d" % [LOG_TAG, level])
	return null


## ── 内部方法 ──

## Step 1: 通过 named_amounts.json 反向查找 key
static func _try_exact_named_amount_match(prop_name: String, delta: int) -> AudioStream:
	var amounts = NamedDSLParser._load_named_amounts()
	if amounts.is_empty():
		return null

	var prop_lower := prop_name.to_lower()

	for key in amounts:
		var amount_val = amounts[key] as int
		if amount_val != delta:
			continue

		# key 必须包含属性名 (e.g., "s_money_gain" contains "money")
		if not key.to_lower().contains(prop_lower):
			continue

		var stream = _try_load_file(key)
		if stream:
			return stream

	return null


## 尝试加载指定 basename 的音效文件（自动尝试 .ogg / .wav / .mp3）
static func _try_load_file(base_name: String) -> AudioStream:
	for ext in SUPPORTED_EXTENSIONS:
		var path: String = SOUND_DIR + base_name + "." + ext
		if ResourceLoader.exists(path):
			Logging.debug("%s: 加载音效: %s" % [LOG_TAG, path])
			return load(path) as AudioStream
	return null
