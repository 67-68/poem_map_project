class_name NarrativeOverlay extends Control

# 引用子节点 (根据上面的新结构调整路径)
@onready var main_card: TextureRect = $Background
@onready var dimmer: ColorRect = $Dimmer
@onready var btn_container: VBoxContainer = $Background/Margin/VBox/BtnContainer

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
	
	# 3. 填充内容
	$Background.texture = data.icon # 假设这是插画
	$Background/Margin/VBox/TitleLabel.text = data.name
	$Background/Margin/VBox/ContentLabel.text = data.description
	$Background/Margin/VBox/ExampleLabel.text = data.example # 比如诗词原文
	
	$Background/Margin/VBox/OptionBtns.apply_btns(data.options,_on_option_selected)
	
	AudioManager.play_sad()

	# 5. 🎬 进场动画 (The Entrance)
	_play_open_animation()

func _on_option_selected(_choice_result):
	# 这里可以加个逻辑：记录玩家的选择，或者处理 disabled 选项的拒绝音效
	# 如果是有效选择，关闭界面
	_end_narrative(_choice_result)

func _end_narrative(choice):
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
		# 手动merge Array[ProvStateOwnerData] 到 Dictionary
		for new_state in current_event_data.provs_state_after:
			# 直接更新字典，格式：{province_uuid: state_value}
			Global.faction_renderer.special_state[new_state.province_uuid] = new_state.state_value
		
		Global.faction_renderer.refresh_lut_image(Global.map.prov_2_fac)
	
	# 3. 恢复世界
	TimeService.resume_world()
	Logging.done('narrative finished')

	ConsequenceExecuter.execute_result(choice)
