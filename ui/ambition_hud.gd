class_name AmbitionHUD extends Control
# g说这里要分离判断逻辑，但我是一个独立游戏设计师🤓

var ambition
@onready var vague_label: Label = $Mar/HBox/VBox/VagueText
@onready var timer_rect: TextureRect = $Mar/HBox/VBox/HBox/IncenseTimer
@onready var time_label: Label = $Mar/HBox/VBox/HBox/TimeLabel
@onready var ambition_label: Label = $Mar/HBox/VBox/HBox/StageName
@onready var deadline_label: Label = $Mar/HBox/VBox/DeadlineResult
@onready var dynamic_state_label: Label = $Mar/HBox/VBox/DynamicStateLabel

func _ready() -> void:
	Logging.info("AmbitionHUD: Starting initialization")
	PlayerState.player_stat_changed.connect(_on_model_stat_changed)
	Logging.info("AmbitionHUD: Connected to player_stat_changed signal")
	
	# 修正你的幽灵 Lambda：必须更新自身的 ambition 引用！
	PlayerState.ambition_changed.connect(func(new_ambition): 
		Logging.info("AmbitionHUD: Received ambition_changed signal with new ambition: %s" % str(new_ambition))
		ambition = new_ambition # <--- 救命的赋值
		_load_static()
		_on_model_stat_changed('')
	)
	Logging.info("ambition hud connected to player stat changed signal")

	# 2. 状态嗅探与潜伏模式
	Logging.info("AmbitionHUD: Checking initial ambition state")
	ambition = PlayerState.ambition
	if not ambition:
		# 允许初始状态没有抱负！只是隐藏或者报警，绝对不能 return 断送生命周期！
		Logging.warn("HUD 还没等到抱负数据，进入潜伏模式等待信号...")
		hide() # 建议直接隐藏，等有了数据再显示
		Logging.info("AmbitionHUD: Entering stealth mode, hiding HUD")
		return # 这里的 return 是安全的，因为信号已经绑好了
	
	# 3. 如果一开始就有数据，正常兜底
	Logging.info("AmbitionHUD: Initial ambition found, displaying HUD")
	show()
	_load_static()
	_on_model_stat_changed("")
	Logging.info("AmbitionHUD: Initialization complete")

func _load_static():
	show()
	Logging.info("AmbitionHUD: Loading static content for ambition: %s" % str(ambition))

	# 1. 挂载阶段名称 (静态)
	Logging.info("AmbitionHUD: Setting ambition name: %s" % ambition.name)
	ambition_label.text = ambition.name
	var stage_name_placeholer = ambition.leveled_stages[ambition.current_stage] # placeholder
	Logging.info("AmbitionHUD: Setting deadline warning: %s" % ambition.deadline_warning)
	deadline_label.text = ambition.deadline_warning

	var deadline_text = TimeService.get_era_text(int(Global.year))
	Logging.info("AmbitionHUD: Setting time text: %s" % deadline_text)
	time_label.text = deadline_text

	var buff_description = ambition.buff_description
	var full_text = ambition.description + "\n" + buff_description
	Logging.info("AmbitionHUD: Setting vague text: %s" % full_text)
	vague_label.text = full_text
	Logging.info("AmbitionHUD: Static content loading complete")

func _on_model_stat_changed(_prop_name):
	Logging.info("AmbitionHUD: Stat changed signal received, prop: %s" % _prop_name)
	if not ambition:
		Logging.warn('AmbitionHUD: No ambition available for display')
		return
	show()
	Logging.info("ambition hud received stat changed signal")
	var current_stage_name = ambition.leveled_stages[ambition.current_stage]
	Logging.info("AmbitionHUD: Checking stage progression for current stage: %s" % current_stage_name)
	var operators = _find_requirement_by_stage_id(current_stage_name)
	if operators and operators.compare(PlayerState):
		Logging.info("AmbitionHUD: Stage requirements met, advancing to next stage")
		ambition.current_stage += 1
		var perception = _find_perception_by_stage_id(ambition.leveled_stages[ambition.current_stage])
		if perception:
			Logging.info("AmbitionHUD: Setting perception text: %s" % perception.perception_text)
			dynamic_state_label.text = perception.perception_text
		else:
			Logging.warn("AmbitionHUD: No perception found for new stage")
	else:
		Logging.info("AmbitionHUD: Stage requirements not yet met")

func _find_requirement_by_stage_id(stage_id: String) -> BaseRequirements:
	Logging.info("AmbitionHUD: Searching for requirement with stage_id: %s" % stage_id)
	for requirement in ambition.staged_requirements:
		if requirement.stage_id == stage_id:
			Logging.info("AmbitionHUD: Found requirement for stage: %s" % stage_id)
			return requirement.requirement
	Logging.warn("AmbitionHUD: No requirement found for stage_id: %s" % stage_id)
	return null

func _find_perception_by_stage_id(stage_id: String) -> StagedPerceptionData:
	Logging.info("AmbitionHUD: Searching for perception with stage_id: %s" % stage_id)
	for perception in ambition.staged_perceptions:
		if perception.stage_id == stage_id:
			Logging.info("AmbitionHUD: Found perception for stage: %s" % stage_id)
			return perception
	Logging.warn("AmbitionHUD: No perception found for stage_id: %s" % stage_id)
	return null
