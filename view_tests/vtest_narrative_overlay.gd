class_name DebugNarrativeOverlay extends RefCounted

var view: Control

# 指向你的 NarrativeOverlay 场景
const SCENE_PATH = "res://characters/narrative_overlay.tscn"

func create_debug_view(idx: int):
	"""
	每次被调用都会创建对应的 view，用于 ViewTest 插件显示
	"""
	var view_scene := preload(SCENE_PATH)
	view = view_scene.instantiate()
	
	# 为了测试不同分辨率下的适配情况，我们给不同的 idx 设置不同的尺寸
	match idx:
		0:
			# 标准尺寸
			view.custom_minimum_size = Vector2(800, 600) 
		1:
			# 宽屏/平板模式
			view.custom_minimum_size = Vector2(1024, 600) 
		2:
			# 竖屏/移动端模式
			view.custom_minimum_size = Vector2(500, 800) 
		3:
			# 紧凑模式
			view.custom_minimum_size = Vector2(600, 400)
		_:
			return null
	
	# 强制设置尺寸以便在 ViewGallery 中正确占位
	view.size = view.custom_minimum_size
	
	# 确保在 Debug 模式下它是可见的 (NarrativeOverlay 默认可能 hidden)
	view.show()
	
	return view

func test_narrative_scenarios(map):
	# -------------------------------------------------------------------------
	# Case 0: 【核心测试】无力感叙事 (石壕吏)
	# 测试点：含有 disabled 的选项，且带有 reason (Tooltip)
	# -------------------------------------------------------------------------
	var v0 = map.get('0')
	if is_instance_valid(v0) and v0.has_method("apply_narrative"):
		var data_dict = {
			"name": "石壕吏",
			"description": "暮投石壕村，有吏夜捉人。老翁逾墙走，老妇出门看。",
			"example": "758年 陕州",
			"options": [
				{ 
					"text": "冲出去与官吏拼命", 
					"disabled": true, 
					"reason": "你手无缚鸡之力，冲出去只会死在乱军之中，无人记录这段历史。" 
				},
				{ 
					"text": "代替老妇去服役", 
					"disabled": true, 
					"reason": "你的身体虚弱，恐怕连长安都走不到。"
				},
				{ 
					"text": "在墙角默默记录",
					"disabled": false, 
					"effect": "record_poem"
				}
			],
			"provs_state_after": {"shan_zhou": "scorched"},
			# 这里的 icon 需要你项目中真实的图片路径，没有则传 null 或默认图标
			"icon": null 
		}
		var history_data = HistoryEventData.new(data_dict)
		# 手动补上 GameEntity 可能需要的 name 属性，如果 _init 没处理的话
		history_data.name = data_dict["name"] 
		history_data.description = data_dict["description"]
		
		v0.apply_narrative(history_data)

	# -------------------------------------------------------------------------
	# Case 1: 【标准事件】安史之乱爆发
	# 测试点：单个选项，地图状态变更 (叛乱)
	# -------------------------------------------------------------------------
	var v1 = map.get('1')
	if is_instance_valid(v1) and v1.has_method("apply_narrative"):
		var data_dict = {
			"name": "安史之乱",
			"description": "渔阳鼙鼓动地来，惊破霓裳羽衣曲。安禄山在范阳起兵，直指洛阳。",
			"example": "755年 范阳",
			"options": [
				{ "text": "我知道了", "disabled": false }
			],
			"provs_state_after": {"fan_yang": "rebellion", "luo_yang": "rebellion"},
			"icon": null
		}
		var history_data = HistoryEventData.new(data_dict)
		history_data.name = data_dict["name"]
		history_data.description = data_dict["description"]
		
		v1.apply_narrative(history_data)

	# -------------------------------------------------------------------------
	# Case 2: 【多重选择】马嵬坡之变
	# 测试点：多个有效选项布局测试
	# -------------------------------------------------------------------------
	var v2 = map.get('2')
	if is_instance_valid(v2) and v2.has_method("apply_narrative"):
		var data_dict = {
			"name": "马嵬坡之变",
			"description": "六军不发无奈何，宛转蛾眉马前死。禁军要求处死杨贵妃，否则拒绝开拔。",
			"example": "756年 马嵬驿",
			"options": [
				{ "text": "赐死杨玉环", "disabled": false, "effect": "tragic_history" },
				{ "text": "坚决保住她", "disabled": true, "reason": "禁军已经哗变，如果你不妥协，大唐皇室将在此终结。" }
			],
			"provs_state_after": {},
			"icon": null
		}
		var history_data = HistoryEventData.new(data_dict)
		history_data.name = data_dict["name"]
		history_data.description = data_dict["description"]
		
		v2.apply_narrative(history_data)
	
	# -------------------------------------------------------------------------
	# Case 3: 【简单通知】官军收复长安
	# 测试点：地图状态恢复 normal
	# -------------------------------------------------------------------------
	var v3 = map.get('3')
	if is_instance_valid(v3) and v3.has_method("apply_narrative"):
		var data_dict = {
			"name": "收复长安",
			"description": "剑外忽传收蓟北，初闻涕泪满衣裳。官军已收复京师！",
			"example": "757年 长安",
			"options": [
				{ "text": "漫卷诗书喜欲狂", "disabled": false }
			],
			"provs_state_after": {"chang_an": "normal"},
			"icon": null
		}
		var history_data = HistoryEventData.new(data_dict)
		history_data.name = data_dict["name"]
		history_data.description = data_dict["description"]
		
		v3.apply_narrative(history_data)


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('测试四种叙事交互流 (石壕/安史/马嵬/收复)', test_narrative_scenarios)
	]
