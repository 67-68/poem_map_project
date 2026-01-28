class_name PoemData extends WorldEvent # 从Note获取

enum Poem_BG {
    BOOK,
    NIGHT
}

@export var author_uuid: String # uuid
@export var popularity: float
@export var background: Poem_BG

# 这些数据会被作为一个独立的路径点加入path，如果当前没有路径点包含这个诗词title的tag
# 创建的路径点tag存储诗词

func _init(note_data: Dictionary):
    super._init(note_data)
    var properties = note_data.get('properties',{})
    author_uuid = properties.get('author_uuid','')
    popularity = properties.get('popularity',0)
    background = Poem_BG.get(properties.get('poem_background'),Poem_BG.BOOK)