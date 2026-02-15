class_name WorldEvent extends GameEntity

var position: Vector2:
    get:
        var res = _get_deprecated_position() 
        if not res: return Vector2.ZERO
        return res
    set(val):
        _set_deprecated_position(val)

var _position := Vector2(0,0)

func _get_deprecated_position():
    return _position

func _set_deprecated_position(val):
    _position = val

@export var year: int
@export var location_uuid: String
@export var uv_position: Vector2 #0-1
@export var audio: AudioStream = null
@export var color: Color




func _init(data: Dictionary = {}):
    # 1. 先让父类干活 (解析 uuid, name 等)
    super._init(data)
    
    if data.is_empty(): return
    
    var props = data.get("properties", data.get("property", {}))
    
    # 2. 解析坐标 (处理 Array -> Vector2 的转换)
    # JSON: "position": [100.0, 200.0]
    var uv_pos = props.get("uv_position", data.get("uv_position", null))
    if uv_pos is Vector2:
        uv_position = uv_pos
    elif uv_pos is Array:
        uv_position = Vector2(uv_pos[0],uv_pos[1])
    else:
        Logging.debug('使用了position')
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
    color = Color.from_string(data.get('color', props.get('color', 'white')), Color.WHITE)
    
    # 4. 解析地点 ID
    location_uuid = props.get("location_uuid", data.get("location_uuid", ""))
    var audio_path = props.get("audio", data.get("audio", null))
    if audio_path and FileAccess.file_exists(audio_path):
        audio = load(audio_path)

func get_local_pos(mesh: MeshInstance2D):
    var mesh_size = Util.get_mesh_instance_size(mesh)
    var pos = Vector2.ZERO
    pos.x = mesh_size.x * uv_position.x
    pos.y = mesh_size.y * uv_position.y
    return pos
