class_name PoemData extends WorldEvent # 从Note获取

enum Poem_BG {
    BOOK,
    NIGHT
}

@export var popularity: float
@export var background: Poem_BG
@export var emotion: float

# 这些数据会被作为一个独立的路径点加入path，如果当前没有路径点包含这个诗词title的tag
# 创建的路径点tag存储诗词
static var repo_id = "POEM_REPO"

func _init(note_data: Dictionary):
    super._init(note_data)
    var properties = note_data.get('properties',{})
    popularity = properties.get('popularity',0)
    background = Poem_BG.get(properties.get('poem_background'),Poem_BG.BOOK)
    emotion = properties.get('emotion',0)

# 在 PoemData.gd 内部添加

## 将诗词数据转化为一个用于在地图上行走的路径点
func to_life_path_point() -> PoetLifePoint:
    # 1. 实例化目标对象
    # 传入空字典 {} 是为了触发父类 _init 的默认逻辑，防止报错
    var point = PoetLifePoint.new({})
    
    # 2. 核心标识符处理
    # ⚠️注意：一定要生成新的 UUID，不能和诗词本身的 UUID 冲突
    # 建议后缀法，方便 Debug
    point.uuid = self.uuid + "_creation_point"
    
    # 3. 继承基础信息 (GameEntity)
    point.name = "创作：《" + self.name + "》" # 让名字在 UI 上直观一点
    point.description = self.description
    point.icon = self.icon
    
    # 数组必须使用 duplicate()，否则是引用传递，修改一个会影响另一个
    point.owner_uuids = self.owner_uuids.duplicate()
    
    # 4. 处理 Tags (完成你的需求：路径点塞诗词 tag)
    point.tags = self.tags.duplicate()
    # 打上特殊标签，方便 UI 层识别这是一个“写诗事件”而不是“普通路过”
    point.tags.append("event_type:poem_creation")
    point.tags.append("poem_ref:" + self.uuid) # 存诗词原本的 ID，方便反查
    
    # 5. 继承时空信息 (WorldEvent)
    # 因为 PoemData 也是 WorldEvent，直接拿过来
    point.position = self.position
    point.year = self.year
    point.location_uuid = self.location_uuid
    
    # 6. 继承情绪 (PoetLifePoint 特有)
    point.emotion = self.emotion
    
    return point