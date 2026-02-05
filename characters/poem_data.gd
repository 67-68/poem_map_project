class_name PoemData extends WorldEvent # 从Note获取

enum Poem_BG {
    BOOK,
    NIGHT
}

enum Poem_Grade { # 拾遗，雅颂，瑰意，绝唱
    SHIYI,
    YASONG,
    GUIYI,
    JUECHANG
}

@export var popularity: float
@export var background: Poem_BG
@export var emotion: float
@export var example: String

# 这些数据会被作为一个独立的路径点加入path，如果当前没有路径点包含这个诗词title的tag
# 创建的路径点tag存储诗词
static var repo_id = "POEM_REPO"

func _init(note_data: Dictionary):
    super._init(note_data)
    var properties = note_data.get('properties',{})
    popularity = properties.get('popularity',0)
    background = Poem_BG.get(properties.get('poem_background'),Poem_BG.BOOK)
    emotion = properties.get('emotion',0)
    example = properties.get('example',"")

# 在 PoemData.gd 内部添加

## 将诗词数据转化为一个用于初始化 PoetLifePoint 的原始字典
## 这种做法完美避开了编译期的循环引用问题
func to_life_path_point_data() -> Dictionary:
    # 1. 组装符合 GameEntity 结构的字典
    var data = {
        "uuid": self.uuid + "_point", # 必须有独立 ID
        "name": "创作：《" + self.name + "》",
        "description": self.description,
        "owner_uuids": self.owner_uuids.duplicate(),
        "tags": self.tags.duplicate(),
        
        # 2. 组装内部属性，对应我们之前修复的 props 解析逻辑
        "properties": {
            "position": self.position, # 这里传 Vector2 没问题，GDScript 字典支持
            "year": self.year,
            "time": self.year, # 双保险
            "location_uuid": self.location_uuid,
            "emotion": self.emotion,
            'example': self.example,
            # 注入元数据，方便以后反查
            "poem_ref": self.uuid,
            "event_type": "poem_creation"
        }
    }
    
    # 3. 可以在这里打上额外的 Tag，方便 UI 识别
    if not "poem_event" in data.tags:
        data['tags'].append('poem %s' % uuid)
        data['tags'].append('poem_creation')
        
    return data

func get_scarcity():
    if popularity >= 90:
        return Poem_Grade.JUECHANG
    elif  popularity >= 80:
        return Poem_Grade.GUIYI
    elif  popularity >= 60:
        return Poem_Grade.YASONG
    else:
        return Poem_Grade.SHIYI
    
func get_scarcity_str(data: Poem_Grade) -> String:
    if data == Poem_Grade.JUECHANG:
        return "绝唱"
    elif data == Poem_Grade.GUIYI:
        return '瑰意'
    elif data == Poem_Grade.YASONG:
        return "雅颂"
    else:
        return "拾遗"

func get_rich_poem():
    return Util.colorize_underlined_link(name,Color.DIM_GRAY,uuid)
