class_name PROPERTIES
enum {
	OFFICIAL_PRESTIGE,
	LITERARY_FAME,
	TALENT
}

const exported_props = [
	"official_prestige",
	"literary_fame",
	"talent"
]

static func to_str(name: int):
	"""
	转化Enum到property string
	返回空值代表name不合格
	"""
	var enum_str_map = {
		PROPERTIES.OFFICIAL_PRESTIGE: 'official_prestige',
		PROPERTIES.LITERARY_FAME: 'literary_fame',
		PROPERTIES.TALENT: "talent"
	}
	return enum_str_map.get(name)

