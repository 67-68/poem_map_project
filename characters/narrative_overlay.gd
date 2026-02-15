@tool
class_name NarrativeOverlay extends Control

# 引用子节点 (根据上面的新结构调整路径)
@onready var main_card: TextureRect = $Background
@onready var dimmer: ColorRect = $Dimmer
@onready var btn_container: VBoxContainer = $Background/Margin/VBox/BtnContainer

@export var test := false:
	set(val):
		if val:
			test = false
			var data = HistoryEventData.new(({
				"name": "石壕吏",
				"description": "暮投石壕村，有吏夜捉人。老翁逾墙走，老妇出门看。",
				"example": "758年 陕州",
				"options": [
					{ 
						"description": "冲出去与官吏拼命", 
						"is_disabled": true, 
						"disabled_reason": "你手无缚鸡之力，冲出去只会死在乱军之中，无人记录这段历史。" 
					},
					{ 
						"description": "代替老妇去服役", 
						"is_disabled": true, 
						"disabled_reason": "你的身体虚弱，恐怕连长安都走不到。"
					},
					{ 
						"description": "在墙角默默记录",
						"is_disabled": false, 
						"effect": "record_poem",
						'double_check': true,
						'double_check_reason': '真的要这么做吗？以她的年龄，去了就是必死的结局'
					}
				],
				"provs_state_after": {"shan_zhou": "scorched"},
				# 这里的 icon 需要你项目中真实的图片路径，没有则传 null 或默认图标
				"icon": 'ruined_village' 
			}))
			apply_narrative(data)

# 状态
var current_event_data: HistoryEventData
var _tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Global.request_narrative.connect(apply_narrative)
	
	# 确保这玩意在暂停时也能点
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide() 

func _play_open_animation():
	if _tween: _tween.kill()
	# 必须显式声明 Tween 的 Pause 模式，以防被 TimeService 杀掉
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 修正中心点，确保缩放动画是从屏幕中央弹出的 (假设你的锚点是全屏)
	main_card.pivot_offset = main_card.size / 2.0 
	
	show()
	
	# A. 遮罩变暗 (确保 Dimmer 基础颜色是不透明的黑！)
	dimmer.modulate.a = 0.0
	_tween.tween_property(dimmer, "modulate:a", 1.0, 0.5)
	
	# B. 卡片弹出 (从小变大 + 透明度)
	main_card.scale = Vector2(0.8, 0.8) 
	main_card.modulate.a = 0.0
	_tween.tween_property(main_card, "scale", Vector2(1.0, 1.0), 0.5)
	_tween.tween_property(main_card, "modulate:a", 1.0, 0.3)

func apply_narrative(data: HistoryEventData):
	# 1. 彻底暂停世界 (包括 BGM 变奏等逻辑可以在这里触发)
	# 在暂停之前切换
	Global.request_change_bg_modulate.emit(data.color)
	TimeService.pause_world(true) # 假设你有这个接口
	current_event_data = data
	
	# 2. 🧹 清理旧垃圾 (必须做！)
	for child in $Background/Margin/VBox/BtnContainer.get_children():
		child.queue_free()
	
	# 3. 填充内容
	$Background.texture = data.icon # 假设这是插画
	$Background/Margin/VBox/TitleLabel.text = data.name
	$Background/Margin/VBox/ContentLabel.text = data.description
	$Background/Margin/VBox/ExampleLabel.text = data.example # 比如诗词原文
	
	# 4. 生成新按钮
	for option in data.options:
		var btn = EventBtn.new(option) # 假设你封装好了这个
		btn_container.add_child(btn)
		# 只有点击有效选项才触发结束
		btn.option_made.connect(_on_option_selected)
	
	AudioManager.play_sad()

	# 5. 🎬 进场动画 (The Entrance)
	_play_open_animation()

func _on_option_selected():
	# 这里可以加个逻辑：记录玩家的选择，或者处理 disabled 选项的拒绝音效
	# 如果是有效选择，关闭界面
	_end_narrative()

func _end_narrative():
	# 1. 🎬 退场动画 (The Exit)
	Global.request_restore_bg_modulate.emit(-1)
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# 反向操作
	_tween.tween_property(dimmer, "modulate:a", 0.0, 0.3)
	_tween.tween_property(main_card, "scale", Vector2(0.9, 0.9), 0.3)
	_tween.tween_property(main_card, "modulate:a", 0.0, 0.3)
	
	# 等动画播完再执行逻辑！
	await _tween.finished
	
	hide()
	
	# 2. 应用后果 (地图变色)
	if current_event_data.provs_state_after:
		Global.faction_renderer.special_state.merge(current_event_data.provs_state_after, true)
		Global.faction_renderer.refresh_lut_image(Global.map.prov_2_fac)
	
	# 3. 恢复世界
	TimeService.resume_world()
	Logging.done('narrative finished')

	Global.history_event_confirmed.emit()
