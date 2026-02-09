class_name WorldEvent extends GameEntity

@export var position: Vector2
@export var year: int
@export var location_uuid: String

func _init(data: Dictionary = {}):
    # 1. 先让父类干活 (解析 uuid, name 等)
    super._init(data)
    
    if data.is_empty(): return
    
    var props = data.get("properties", data.get("property", {}))
    
    # 2. 解析坐标 (处理 Array -> Vector2 的转换)
    # JSON: "position": [100.0, 200.0]
    var raw_pos = props.get("position", data.get("position", null))
    if raw_pos is Vector2:
        position = raw_pos
    elif raw_pos is Array and raw_pos.size() >= 2: # 需要考虑到这里可能会使用poem data
        position = Util.geo_to_pixel(raw_pos[0], raw_pos[1])
    else:
        position = Vector2.ZERO
        
    # 3. 解析年份 (兼容 time 和 year 两个字段)
    # 优先读 props 里的 time，其次是 year
    year = props.get("time", props.get("year", data.get("year", Global.start_year)))
    
    # 4. 解析地点 ID
    location_uuid = props.get("location_uuid", data.get("location_uuid", ""))