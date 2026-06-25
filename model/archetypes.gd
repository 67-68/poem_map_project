class_name Archetypes extends RefCounted
enum ARCHETYPE {
	RECKLESS,       # 狂放 / 纵酒 / 藐视权威
	ZEN,            # 隐逸 / 旷达 / 释怀
	INDIGNANT,      # 愤世嫉俗 / 忧国忧民 / 狂怒
	MELANCHOLY,     # 悲秋 / 离愁 / 羁旅
	FLATTERER,      # 入世 / 干谒 / 妥协
	HEDONISTIC      # 声色犬马 / 逃避现实
}

static var archetype_effects = {
	ARCHETYPE.RECKLESS: {
		"emotions": {
			ENUMS.EMOTION.ARROGANCE: 15,
			ENUMS.EMOTION.TRANQUILITY: -10
		},
		"props": {}
	},
	ARCHETYPE.ZEN: {
		"emotions": {
			ENUMS.EMOTION.TRANQUILITY: 20,
			ENUMS.EMOTION.AMBITION: -15,
			ENUMS.EMOTION.ANGER: -10
		},
		"props": {}
	},
	ARCHETYPE.INDIGNANT: {
		"emotions": {
			ENUMS.EMOTION.ANGER: 15,
			ENUMS.EMOTION.SORROW: 5,
			ENUMS.EMOTION.ARROGANCE: -5
		},
		"props": {}
	},
	ARCHETYPE.MELANCHOLY: {
		"emotions": {
			ENUMS.EMOTION.SORROW: 15,
			ENUMS.EMOTION.AMBITION: -5
		},
		"props": {}
	},
	ARCHETYPE.FLATTERER: {
		"emotions": {
			ENUMS.EMOTION.AMBITION: 15,
			ENUMS.EMOTION.ARROGANCE: -15,
			ENUMS.EMOTION.TRANQUILITY: -10
		},
		"props": {}
	},
	ARCHETYPE.HEDONISTIC: {
		"emotions": {
			ENUMS.EMOTION.SORROW: -10,
			ENUMS.EMOTION.AMBITION: -10
		},
		"props": {}
	}
}

static func translate_archetype(archetype: ARCHETYPE, player: Node):
	"""
	把ARCHETYPE转化为他们的效果，使用字典对照
	effect: some_emotion_or_props += 50
	"""
	if not archetype_effects.has(archetype):
		Logging.err('Archetype %s not found in effects' % archetype)
		return

	var effects = archetype_effects[archetype]

	# 处理情绪变化
	if effects.has("emotions"):
		for emotion_enum in effects["emotions"]:
			var emotion_str = ENUMS.to_emotion_str(emotion_enum)
			var amount = effects["emotions"][emotion_enum]
			player.change_emotion(emotion_str, amount)

	# 处理属性变化
	if effects.has("props"):
		for prop_enum in effects["props"]:
			var prop_str = ENUMS.to_prop_str(prop_enum)
			var amount = effects["props"][prop_enum]
			player.change_stat(prop_str, amount)